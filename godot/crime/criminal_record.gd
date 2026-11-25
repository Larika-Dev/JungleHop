## The player's criminal record: convictions, expungement, and job background checks.
##
## Days are in-game days (1 in-game day = 24 real minutes).
extends RefCounted

const Catalog = preload("crime_catalog.gd")

## In-game days after which a conviction drops off the record. -1 = never.
const EXPUNGE_DAYS := {"infraction": 7, "misdemeanor": 30, "felony": -1}

## Background-check tiers used by jobs and education. Jobs pick one per job.
##   none      no check (gig work, day labour)
##   basic     retail, food service: no violent felony ever, no felony in the last 30 days
##   standard  office, trades, campus jobs: no felony ever, no theft or fraud in the last 14 days
##   trusted   bank, school, hospital, childcare, police: no felony, no active misdemeanor,
##             no theft, fraud or violent conviction ever
const TIERS: Array[String] = ["none", "basic", "standard", "trusted"]

## Each entry: {crime_id, name, class, category, day, total_minutes}
var convictions: Array[Dictionary] = []
## Everything ever convicted, including expunged entries (expunged ones still count for "ever" checks
## of theft/fraud/violence at the trusted tier, the way real deep background checks work).
var history: Array[Dictionary] = []


func add_conviction(crime_id: String, total_minutes: float) -> Dictionary:
	var c := Catalog.find(crime_id)
	if c.is_empty():
		return {}
	var entry := {
		"crime_id": crime_id,
		"name": String(c.name),
		"class": String(c["class"]),
		"category": String(c.category),
		"day": int(floor(total_minutes / 1440.0)) + 1,
		"total_minutes": total_minutes,
	}
	convictions.append(entry)
	history.append(entry.duplicate())
	return entry


## Drops convictions whose clean period has passed. Returns the entries removed.
func expunge(now_minutes: float) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	var last := _last_conviction_minutes()
	for e in convictions:
		var days: int = int(EXPUNGE_DAYS.get(String(e["class"]), -1))
		# A misdemeanor only clears after a clean stretch with no newer conviction.
		var since: float = float(e.total_minutes)
		if String(e["class"]) == "misdemeanor":
			since = last
		if days >= 0 and now_minutes - since >= days * 1440.0:
			removed.append(e)
		else:
			keep.append(e)
	convictions = keep
	return removed


func _last_conviction_minutes() -> float:
	var last := -1.0e12
	for e in convictions:
		last = maxf(last, float(e.total_minutes))
	return last


func count(crime_class: String) -> int:
	var n := 0
	for e in convictions:
		if String(e["class"]) == crime_class:
			n += 1
	return n


func is_clean() -> bool:
	return convictions.is_empty()


func has_felony() -> bool:
	return count("felony") > 0


func _any(list: Array[Dictionary], pred: Callable) -> bool:
	for e in list:
		if pred.call(e):
			return true
	return false


## Background check. Returns {"ok": bool, "reason": String}.
func job_check(tier: String, now_minutes: float) -> Dictionary:
	var days_ago := func(e: Dictionary) -> float: return (now_minutes - float(e.total_minutes)) / 1440.0
	match tier:
		"none", "":
			return {"ok": true, "reason": ""}
		"basic":
			if _any(history, func(e): return e["class"] == "felony" and e.category == "violent"):
				return {"ok": false, "reason": "Violent felony on your record"}
			if _any(convictions, func(e): return e["class"] == "felony" and days_ago.call(e) < 30.0):
				return {"ok": false, "reason": "Felony conviction in the last 30 days"}
		"standard":
			if has_felony():
				return {"ok": false, "reason": "Felony on your record"}
			if _any(convictions, func(e): return (e.category == "theft" or e.category == "fraud") and days_ago.call(e) < 14.0):
				return {"ok": false, "reason": "Recent theft or fraud conviction"}
		"trusted":
			if has_felony():
				return {"ok": false, "reason": "Felony on your record"}
			if count("misdemeanor") > 0:
				return {"ok": false, "reason": "Misdemeanor on your record"}
			if _any(history, func(e): return e.category in ["theft", "fraud", "violent"] and e["class"] != "infraction"):
				return {"ok": false, "reason": "Past theft, fraud or violence conviction"}
		_:
			push_warning("CriminalRecord: unknown job tier '%s'" % tier)
	return {"ok": true, "reason": ""}


## Compact summary that other systems read from Life.get_flag("crime.record").
func summary() -> Dictionary:
	return {
		"infractions": count("infraction"),
		"misdemeanors": count("misdemeanor"),
		"felonies": count("felony"),
		"clean": is_clean(),
		"violent": _any(history, func(e): return e.category == "violent" and e["class"] != "infraction"),
		"theft": _any(history, func(e): return e.category == "theft"),
		"fraud": _any(history, func(e): return e.category == "fraud"),
		"last_day": int(convictions.back().day) if not convictions.is_empty() else 0,
	}


func to_save() -> Dictionary:
	return {"convictions": convictions.duplicate(true), "history": history.duplicate(true)}


func from_save(d: Dictionary) -> void:
	convictions.clear()
	history.clear()
	for e in d.get("convictions", []):
		convictions.append(e)
	for e in d.get("history", []):
		history.append(e)
