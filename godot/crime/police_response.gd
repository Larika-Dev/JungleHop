## Wanted level and police response, as a small state machine ticked once per in-game minute.
##
## States:
##   clear       no stars
##   responding  units are driving to the last known position (eta in game minutes)
##   searching   units are on scene looking for the player; unseen time counts toward losing a star
##   pursuit     officers have eyes on the player; each minute they may catch them or lose them
##
## If the NPC system spawns real officer nodes (group "police"), it drives sightings itself with
## Law.police_saw_player() / police_lost_player() / police_contact(); set `simulate = false` and the
## dice rolls below are skipped. Otherwise the response is simulated so crime works without NPCs.
extends RefCounted

const MAX_STARS := 5
## Units dispatched per star level.
const UNITS: Array[int] = [0, 1, 2, 4, 6, 10]
## What kind of response each level brings (for the NPC thread to spawn).
const RESPONSE_KIND: Array[String] = ["", "patrol", "patrol", "patrol_roadblock", "armed", "swat_helicopter"]
## In-game minutes until the first unit arrives.
const RESPONSE_MINUTES: Array[int] = [0, 8, 6, 4, 3, 2]
## Unseen in-game minutes before the level drops by one star (1 game minute = 1 real second).
const SEARCH_TIMEOUT: Array[int] = [0, 20, 30, 45, 60, 90]
## Per-minute chances in simulated mode.
const SPOT_CHANCE: Array[float] = [0.0, 0.04, 0.05, 0.06, 0.08, 0.10]
const CATCH_CHANCE: Array[float] = [0.0, 0.25, 0.20, 0.15, 0.12, 0.10]
const LOSE_CHANCE: Array[float] = [0.0, 0.35, 0.30, 0.25, 0.20, 0.15]

var stars := 0
var state := "clear"
var eta := 0
var minutes_unseen := 0
var pursuit_minutes := 0
var was_pursued := false      # true once a pursuit happened this episode (evading_police charge)
var last_known := Vector3.ZERO
var simulate := true


func units() -> int:
	return UNITS[stars]


func response_kind() -> String:
	return RESPONSE_KIND[stars]


## Raises the wanted level. `escalate` adds a star when already wanted (crime spree).
## Returns true when the level changed.
func raise(to_stars: int, at: Vector3, escalate: bool) -> bool:
	var target := to_stars
	if escalate and stars > 0 and to_stars > 0:
		target = maxi(stars + 1, to_stars)
	target = clampi(target, 0, MAX_STARS)
	last_known = at
	if target <= stars:
		# Same or lower level: police still get a fresh last-known position.
		if stars > 0:
			minutes_unseen = 0
		return false
	var was_clear := stars == 0
	stars = target
	minutes_unseen = 0
	if was_clear or state == "responding":
		state = "responding"
		eta = RESPONSE_MINUTES[stars]
	return true


func clear() -> void:
	stars = 0
	state = "clear"
	eta = 0
	minutes_unseen = 0
	pursuit_minutes = 0
	was_pursued = false


func saw_player(at: Vector3) -> void:
	if stars == 0:
		return
	last_known = at
	state = "pursuit"
	was_pursued = true
	minutes_unseen = 0


func lost_player() -> void:
	if state == "pursuit":
		state = "searching"
		pursuit_minutes = 0


## Advance one in-game minute.
##   visibility  0..1+, how easy the player is to spot (outside in daylight = 1, indoors 0.5, hiding 0.15)
##   escape      0..1+, how good the player is at getting away (1 = average)
## Returns a list of event names that happened this minute:
##   "arrived", "spotted", "lost", "star_dropped", "cleared", "caught"
func tick(rng: RandomNumberGenerator, visibility: float = 1.0, escape: float = 1.0) -> Array[String]:
	var ev: Array[String] = []
	if stars == 0:
		return ev
	match state:
		"responding":
			eta -= 1
			if eta <= 0:
				state = "searching"
				ev.append("arrived")
		"searching":
			minutes_unseen += 1
			if simulate and rng.randf() < SPOT_CHANCE[stars] * visibility:
				saw_player(last_known)
				ev.append("spotted")
		"pursuit":
			pursuit_minutes += 1
			if simulate:
				if rng.randf() < CATCH_CHANCE[stars] / maxf(escape, 0.2):
					ev.append("caught")
					return ev
				if rng.randf() < LOSE_CHANCE[stars] * escape / maxf(visibility, 0.2):
					lost_player()
					ev.append("lost")
	if state != "pursuit" and minutes_unseen >= SEARCH_TIMEOUT[stars]:
		stars -= 1
		minutes_unseen = 0
		ev.append("star_dropped")
		if stars == 0:
			ev.append("cleared")
			state = "clear"
	return ev


func to_save() -> Dictionary:
	return {"stars": stars, "state": state, "eta": eta, "minutes_unseen": minutes_unseen,
		"was_pursued": was_pursued, "last_known": [last_known.x, last_known.y, last_known.z]}


func from_save(d: Dictionary) -> void:
	stars = int(d.get("stars", 0))
	state = String(d.get("state", "clear"))
	eta = int(d.get("eta", 0))
	minutes_unseen = int(d.get("minutes_unseen", 0))
	was_pursued = bool(d.get("was_pursued", false))
	var lk: Array = d.get("last_known", [0, 0, 0])
	last_known = Vector3(float(lk[0]), float(lk[1]), float(lk[2]))
