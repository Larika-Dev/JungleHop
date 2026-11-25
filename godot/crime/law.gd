## Law: the crime, police and justice autoload.
##
##   Law="*res://crime/law.gd"
##
## Plugs into the life core (`Life` autoload) when it exists: every crime becomes a Life action with
## category "crime", fines and loot go through Life.money, witnesses through Life.relationships, and
## the record is published as Life flags (crime.record, crime.wanted, crime.in_jail). Without Life it
## still runs, on GameClock or its own 1 real second = 1 game minute timer.
##
## See INTERFACES.md in this folder for the contract with jobs, education, NPCs and driving.
extends Node

const Catalog = preload("crime_catalog.gd")
const Record = preload("criminal_record.gd")
const Police = preload("police_response.gd")
const Witnesses = preload("witnesses.gd")
const HudScript = preload("ui/wanted_hud.gd")

## Longest sentence, in in-game hours (90 in-game days = 36 real hours of game time, skipped).
const MAX_JAIL_HOURS := 2160
## Dollars of unpaid fine that turn into one extra hour of jail.
const FINE_DOLLARS_PER_JAIL_HOUR := 50.0
## Bail costs this many dollars per in-game hour of sentence.
const BAIL_PER_HOUR := 20.0
## Bail is not offered above this sentence or for 4+ star crimes.
const BAIL_MAX_HOURS := 720
## In-game minutes the booking screen waits before the player is taken to jail anyway.
const BOOKING_TIMEOUT := 30
## Per-minute chance, outdoors with an open warrant and no real officer nodes, that a patrol recognizes you.
const WARRANT_RECOGNIZE_CHANCE := 0.002

signal crime_committed(crime_id: String, outcome: Dictionary)
signal crime_reported(crime_id: String, reporter_ids: Array)
signal wanted_changed(stars: int, state: String)
## For the NPC thread: spawn or move officers. kind is patrol | patrol_roadblock | armed | swat_helicopter.
signal police_dispatched(stars: int, units: int, kind: String, position: Vector3, eta_minutes: int)
signal police_event(event: String)
signal citation_issued(crime_id: String, fine: float, paid: bool)
signal arrested(booking: Dictionary)
signal sentence_started(hours: int)
signal released(reason: String)
signal convicted(entry: Dictionary)
signal record_changed(summary: Dictionary)
signal warrant_issued(charges: Array)
## For the NPC thread: harm is "hurt" or "killed".
signal npc_harmed(npc_id: String, harm: String, crime_id: String)

var record := Record.new()
var police := Police.new()
var rng := RandomNumberGenerator.new()

## Charges for the current wanted episode (crime ids, repeats allowed).
var charges: Array[String] = []
## Charges that stand after an escape where the player was identified.
var warrant: Array[String] = []
var identified := false
## Unpaid citations, added to the next booking.
var unpaid_fines := 0.0
## Non-empty while the booking screen is up: {charges, fine, fine_unpaid, jail_hours, bail, can_bail}
var booking: Dictionary = {}
var booking_timer := 0
var in_jail := false
var hiding := false
var stats := {"committed": 0, "reported": 0, "arrests": 0, "jail_hours": 0, "loot": 0.0}

var _clock_source := ""   # "life" | "gameclock" | "self"
var _self_clock_acc := 0.0
var _last_day := -1
var _hud: CanvasLayer


func _ready() -> void:
	rng.randomize()
	_hook_up.call_deferred()


func _hook_up() -> void:
	var life := _life()
	if life and life.get("clock") and life.clock.has_signal("minute_passed"):
		life.clock.minute_passed.connect(_on_minute)
		_clock_source = "life"
	elif _node("GameClock") and _node("GameClock").has_signal("minute_passed"):
		_node("GameClock").minute_passed.connect(_on_minute)
		_clock_source = "gameclock"
	else:
		_clock_source = "self"
	if life:
		_register_life_actions(life)
		if life.has_method("register_save_provider"):
			life.register_save_provider("crime", self)
		if life.get("actions") and life.actions.has_signal("action_started"):
			life.actions.action_started.connect(_on_life_action_started)
			life.actions.action_finished.connect(_on_life_action_finished)
	elif _node("GameState") and _node("GameState").has_method("register_saveable"):
		_node("GameState").register_saveable("crime", self)
	if DisplayServer.get_name() != "headless":
		_hud = HudScript.new()
		add_child(_hud)
	_publish()


func _process(delta: float) -> void:
	if _clock_source != "self":
		return
	_self_clock_acc += delta
	while _self_clock_acc >= 1.0:
		_self_clock_acc -= 1.0
		_on_minute(0)


# --------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------

## Commit a crime. ctx (all optional):
##   position: Vector3      where it happened (default: the player)
##   victim_id: String      NPC id of the victim
##   victim_node: Node      the victim's node (for police checks and reactions)
##   witnesses: Array       witness dictionaries (see witnesses.gd); default: scan the scene tree
##   is_night: bool         default: from the clock
##   success: bool          force the outcome instead of rolling `chance`
## Returns {ok, reason, success, crime_id, seen, reported, identified, stars, loot, fine, message}
func commit(crime_id: String, ctx: Dictionary = {}) -> Dictionary:
	var crime := Catalog.find(crime_id)
	if crime.is_empty():
		return {"ok": false, "reason": "Unknown crime '%s'" % crime_id}
	if in_jail or not booking.is_empty():
		return {"ok": false, "reason": "You are in custody"}
	var pos: Vector3 = ctx.get("position", _player_pos())
	var victim_id := String(ctx.get("victim_id", ""))
	var success := bool(ctx.get("success", _roll_success(crime)))
	var out := {"ok": true, "reason": "", "success": success, "crime_id": crime_id, "seen": 0,
		"reported": false, "identified": false, "stars": police.stars, "loot": 0.0, "fine": 0.0, "message": ""}
	stats.committed += 1
	_add_skill_xp(crime, success)

	if crime_id == "bribery":
		return _resolve_bribe(crime, success, pos, out)

	# A stealthy crime that works goes unnoticed by the victim.
	var victim_noticed := not (success and String(crime.get("skill", "")) == "stealth")
	var witnesses: Array = ctx.get("witnesses", _scan_witnesses(crime, pos, victim_id))
	for w in witnesses:
		if not w.has("friendship"):
			_fill_relationship(w)
	var seen := Witnesses.evaluate(crime, witnesses, bool(ctx.get("is_night", _is_night())), rng, victim_noticed)
	out.seen = seen.seen_by.size()
	out.reported = seen.reported
	out.identified = seen.identified

	if success:
		out.loot = _give_loot(crime)
		if String(crime.get("harm", "")) != "" and victim_id != "":
			npc_harmed.emit(victim_id, String(crime.harm), crime_id)
	_apply_witness_relationships(crime, seen.seen_by)
	_notify_npcs(crime, seen, pos)

	var parts: Array[String] = []
	parts.append(_success_text(crime, success, out.loot))
	if int(crime.stars) == 0:
		if seen.police_saw:
			out.fine = float(crime.fine)
			_cite(crime_id, out.fine)
			parts.append("A cop saw it: $%d ticket." % int(out.fine))
	elif seen.reported:
		stats.reported += 1
		charges.append(crime_id)
		identified = identified or seen.identified
		var changed := police.raise(int(crime.stars), pos, true)
		if seen.police_saw:
			police.saw_player(pos)
		crime_reported.emit(crime_id, seen.reporters.map(func(w): return String(w.get("id", ""))))
		if changed or seen.police_saw:
			_dispatch()
		parts.append("Someone called the police." if not seen.police_saw else "Police saw you!")
	elif out.seen > 0:
		parts.append("Someone saw, but kept quiet.")
	out.stars = police.stars
	out.message = " ".join(parts)
	_toast(out.message)
	_publish()
	crime_committed.emit(crime_id, out)
	return out


func wanted() -> int:
	return police.stars


func is_wanted() -> bool:
	return police.stars > 0


## Background check for jobs and schools. tier: none | basic | standard | trusted.
## Returns {ok: bool, reason: String}. Also fails while wanted or in custody.
func job_check(tier: String) -> Dictionary:
	if in_jail or not booking.is_empty():
		return {"ok": false, "reason": "You are in custody"}
	if not warrant.is_empty() and tier != "none":
		return {"ok": false, "reason": "There is a warrant out for you"}
	return record.job_check(tier, _now())


## The player gives up. Works whenever police are after them.
func surrender() -> bool:
	if police.stars == 0 and warrant.is_empty():
		return false
	_arrest(true)
	return true


## The player fights the cuffs. Breaking free adds a resisting charge and a star.
func resist_arrest() -> bool:
	if police.stars == 0:
		return false
	var p := 0.3 + 0.03 * _skill("fitness") + 0.02 * _skill("athletics")
	charges.append("resisting_arrest")
	if rng.randf() < p:
		police.raise(police.stars + 1, police.last_known, false)
		police.lost_player()
		_dispatch()
		_toast("You broke free!")
		_publish()
		return true
	_arrest(false)
	return false


## Booking: take the sentence. Skips the clock for the jail time.
func serve_sentence() -> void:
	if booking.is_empty():
		return
	var hours := int(booking.jail_hours)
	booking = {}
	if hours <= 0:
		_release("No jail time")
		return
	in_jail = true
	_set_flag("crime.in_jail", true)
	_set_flag("crime.booked", false)
	stats.jail_hours += hours
	sentence_started.emit(hours)
	_toast("Sentenced to %s." % _hours_text(hours))
	_advance_clock(hours * 60)
	_release("Sentence served")


## Booking: pay bail instead of jail. Returns false if not offered or not affordable.
func post_bail() -> bool:
	if booking.is_empty() or not bool(booking.can_bail):
		return false
	if not _spend(float(booking.bail), "Bail"):
		_toast("You can't afford bail.")
		return false
	booking = {}
	_release("Bail posted")
	return true


func pay_fines() -> bool:
	if unpaid_fines <= 0.0:
		return false
	if not _spend(unpaid_fines, "Unpaid tickets"):
		return false
	unpaid_fines = 0.0
	_publish()
	return true


## Called by real officer nodes (NPC thread).
func police_saw_player(officer: Node = null) -> void:
	var pos := _player_pos()
	if police.stars == 0 and not warrant.is_empty():
		charges = warrant.duplicate()
		warrant.clear()
		identified = true
		police.raise(1, pos, false)
		_toast("A cop recognized you. There's a warrant!")
	police.saw_player(pos)
	_dispatch()
	_publish()


func police_lost_player(_officer: Node = null) -> void:
	police.lost_player()
	_publish()


func police_contact(_officer: Node = null) -> void:
	if police.stars > 0 or not warrant.is_empty():
		_arrest(false)


## Advance one in-game minute (connected to the clock; tests call it directly).
func tick_minute() -> void:
	_on_minute(0)


# --------------------------------------------------------------------------------------------
# Clock
# --------------------------------------------------------------------------------------------

func _on_minute(_total) -> void:
	if in_jail:
		return
	var day := int(floor(_now() / 1440.0))
	if day != _last_day:
		_last_day = day
		var gone := record.expunge(_now())
		if not gone.is_empty():
			_toast("%d old conviction(s) cleared from your record." % gone.size())
			_publish()
	if not booking.is_empty():
		booking_timer -= 1
		if booking_timer <= 0:
			if bool(booking.can_bail) and bool(booking.get("auto_bail", false)):
				post_bail()
			else:
				serve_sentence()
		return
	police.simulate = get_tree() == null or get_tree().get_nodes_in_group("police").is_empty()
	if police.stars == 0:
		if not warrant.is_empty() and police.simulate and _visibility() >= 0.9 and rng.randf() < WARRANT_RECOGNIZE_CHANCE:
			police_saw_player()
		return
	var before := police.stars
	for ev in police.tick(rng, _visibility(), _escape()):
		police_event.emit(ev)
		match ev:
			"arrived":
				_toast("Police are on the scene.")
			"spotted":
				_toast("Police spotted you!")
			"lost":
				if not charges.has("evading_police"):
					charges.append("evading_police")
				_toast("You lost them. Stay out of sight.")
			"star_dropped":
				if police.stars > 0:
					_toast("The search is cooling off.")
			"cleared":
				_on_wanted_cleared()
			"caught":
				_arrest(false)
				return
	if police.stars != before:
		_dispatch()
	_publish()


func _on_wanted_cleared() -> void:
	if identified and not charges.is_empty():
		warrant.append_array(charges)
		warrant_issued.emit(warrant.duplicate())
		_toast("You got away, but they know who you are. Warrant issued.")
	else:
		_toast("You got away clean.")
	charges.clear()
	identified = false
	police.clear()


# --------------------------------------------------------------------------------------------
# Arrest and booking
# --------------------------------------------------------------------------------------------

func _arrest(surrendered: bool) -> void:
	var all: Array[String] = []
	all.append_array(charges)
	all.append_array(warrant)
	if police.was_pursued and not surrendered and not all.has("evading_police"):
		all.append("evading_police")
	if all.is_empty():
		police.clear()
		_publish()
		return
	stats.arrests += 1
	var fine := unpaid_fines
	var jail := 0
	var serious := false
	for id in all:
		var c := Catalog.find(id)
		fine += float(c.fine)
		jail += int(c.jail_hours)
		serious = serious or int(c.stars) >= 4
		var entry := record.add_conviction(id, _now())
		convicted.emit(entry)
	if surrendered:
		jail = int(round(jail * 0.75))   # cooperation knocks a quarter off
	unpaid_fines = 0.0
	var paid := _spend(fine, "Court fines") if fine > 0.0 else true
	var unpaid := 0.0 if paid else fine
	if unpaid > 0.0:
		# Pay what you have; the rest becomes jail time.
		var cash := _cash()
		if cash > 0.0 and _spend(cash, "Court fines (partial)"):
			unpaid -= cash
		jail += int(ceil(unpaid / FINE_DOLLARS_PER_JAIL_HOUR))
	jail = mini(jail, MAX_JAIL_HOURS)
	var can_bail := not serious and jail > 0 and jail <= BAIL_MAX_HOURS
	booking = {
		"charges": all.duplicate(),
		"names": all.map(func(id): return String(Catalog.find(id).name)),
		"fine": fine, "fine_unpaid": unpaid, "jail_hours": jail,
		"bail": float(round(jail * BAIL_PER_HOUR)), "can_bail": can_bail,
		"surrendered": surrendered,
	}
	booking_timer = BOOKING_TIMEOUT
	charges.clear()
	warrant.clear()
	identified = false
	police.clear()
	_set_flag("crime.booked", true)
	_toast("Arrested." if not surrendered else "You surrendered.")
	arrested.emit(booking.duplicate())
	_publish()
	if jail <= 0:
		booking = {}
		_release("Fined and released")


func _release(reason: String) -> void:
	in_jail = false
	booking = {}
	_set_flag("crime.in_jail", false)
	_set_flag("crime.booked", false)
	released.emit(reason)
	_toast(reason + ".")
	_publish()


func _resolve_bribe(crime: Dictionary, success: bool, pos: Vector3, out: Dictionary) -> Dictionary:
	if success:
		police.clear()
		charges.clear()
		identified = false
		out.message = "The officer pockets the cash and looks the other way."
	else:
		charges.append("bribery")
		police.raise(maxi(police.stars + 1, int(crime.stars)), pos, false)
		police.saw_player(pos)
		_dispatch()
		out.message = "The officer is not for sale. Now you're charged with bribery."
	out.stars = police.stars
	_toast(out.message)
	_publish()
	crime_committed.emit("bribery", out)
	return out


func _cite(crime_id: String, fine: float) -> void:
	var paid := _spend(fine, "Ticket: " + String(Catalog.find(crime_id).name))
	if not paid:
		unpaid_fines += fine
	var entry := record.add_conviction(crime_id, _now())
	convicted.emit(entry)
	citation_issued.emit(crime_id, fine, paid)


func _dispatch() -> void:
	police_dispatched.emit(police.stars, police.units(), police.response_kind(), police.last_known, police.eta)


# --------------------------------------------------------------------------------------------
# Witnesses and NPCs
# --------------------------------------------------------------------------------------------

func _scan_witnesses(crime: Dictionary, pos: Vector3, victim_id: String) -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	var radius: float = float(crime.get("radius", 20.0))
	var seen_nodes := {}
	for group in ["npc", "police", "security_camera"]:
		for n in tree.get_nodes_in_group(group):
			if not (n is Node3D) or seen_nodes.has(n):
				continue
			seen_nodes[n] = true
			var d := (n as Node3D).global_position.distance_to(pos)
			if d > radius:
				continue
			var id := String(n.get("npc_id")) if n.get("npc_id") != null else ""
			var kind := "civilian"
			if n.is_in_group("security_camera"):
				kind = "camera"
			elif n.is_in_group("police") or bool(n.get("is_police")):
				kind = "police"
			var w := {"id": id, "kind": kind, "distance": d, "node": n,
				"can_see": _line_of_sight(n as Node3D, pos),
				"alertness": float(n.get("alertness")) if n.get("alertness") != null else 1.0,
				"is_victim": id != "" and id == victim_id}
			_fill_relationship(w)
			out.append(w)
	return out


func _fill_relationship(w: Dictionary) -> void:
	var id := String(w.get("id", ""))
	var life := _life()
	if id == "" or life == null or life.get("relationships") == null:
		return
	var rel = life.relationships.get_rel(id) if life.relationships.has_method("get_rel") else null
	if rel == null:
		return
	var f = rel.get("friendship") if rel is Object else rel.get("friendship", 0.0)
	w.friendship = float(f) if f != null else 0.0
	var traits = rel.get("traits") if rel is Object else rel.get("traits", {})
	if traits is Dictionary and not w.has("lawful"):
		w.lawful = float(traits.get("lawful", 0.5))
		w.wild = float(traits.get("wild", 0.3))
	if life.relationships.has_method("has_flag") and not w.has("knows_player"):
		w.knows_player = bool(life.relationships.has_flag(id, "met"))


func _line_of_sight(n: Node3D, pos: Vector3) -> bool:
	if not n.is_inside_tree() or n.get_world_3d() == null:
		return true
	var space := n.get_world_3d().direct_space_state
	if space == null:
		return true
	var from := n.global_position + Vector3(0, 1.6, 0)
	var to := pos + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)   # layer 1: static world only
	if n is CollisionObject3D:
		q.exclude = [(n as CollisionObject3D).get_rid()]
	return space.intersect_ray(q).is_empty()


func _apply_witness_relationships(crime: Dictionary, seen_by: Array) -> void:
	var life := _life()
	if life == null or life.get("relationships") == null:
		return
	var rels = life.relationships
	var weight := 1.0 + Catalog.class_rank(String(crime["class"]))
	for w in seen_by:
		var id := String(w.get("id", ""))
		if id == "" or String(w.get("kind", "")) == "camera":
			continue
		var delta := Witnesses.witness_friendship_delta(crime, w)
		var victim := bool(w.get("is_victim", false))
		if delta != 0.0 and rels.has_method("change"):
			rels.change(id, delta, 0.0, ("You %s them" if victim else "Saw you: %s") % String(crime.name).to_lower())
		if rels.has_method("remember"):
			rels.remember(id, ("victim_of_" if victim else "saw_you_") + String(crime.id), weight)
		if rels.has_method("add_flag"):
			rels.add_flag(id, "crime_victim" if victim else "witnessed_crime")
			if delta <= -60.0:
				rels.add_flag(id, "enemy")


func _notify_npcs(crime: Dictionary, seen: Dictionary, pos: Vector3) -> void:
	for w in seen.seen_by:
		var n = w.get("node")
		if n is Node and is_instance_valid(n) and n.has_method("react_to_crime"):
			n.react_to_crime(String(crime.id), String(crime["class"]), pos, seen.reporters.has(w))


# --------------------------------------------------------------------------------------------
# Life bridge
# --------------------------------------------------------------------------------------------

func _register_life_actions(life: Node) -> void:
	var acts = life.get("actions")
	if acts == null or not acts.has_method("register"):
		return
	for c in Catalog.menu_crimes():
		var def := {
			"id": "crime_" + String(c.id),
			"name": String(c.name),
			"category": "crime",
			"target": String(c.target),
			"minutes": int(c.minutes),
			"description": String(c.desc),
			"requires": {"not_flags": ["crime.in_jail", "crime.booked"]},
			"crime_class": String(c["class"]),
			"wanted_stars": int(c.stars),
		}
		if c.has("place"):
			def.place = c.place
		if c.has("cost"):
			def.cost = c.cost
		if c.has("requires_flag"):
			def.requires.flags = [String(c.requires_flag)]
		acts.register(def)
		var cid := String(c.id)
		acts.set_check(def.id, func(_d, target): return _life_check(cid, target))
		acts.set_handler(def.id, func(_d, target, result): return _life_handle(cid, target, result))
	acts.register({"id": "crime_hide", "name": "Hide from the police", "category": "crime", "target": "self",
		"minutes": 15, "description": "Lie low. Much harder to spot while hiding."})
	acts.set_check("crime_hide", func(_d, _t): return "" if police.stars > 0 else "Nobody is looking for you")
	acts.register({"id": "crime_surrender", "name": "Turn yourself in", "category": "crime", "target": "self",
		"minutes": 0, "description": "Give up. A quarter off the sentence."})
	acts.set_check("crime_surrender", func(_d, _t): return "" if police.stars > 0 or not warrant.is_empty() else "You are not wanted")
	acts.set_handler("crime_surrender", func(_d, _t, result): surrender(); return result)
	acts.register({"id": "crime_pay_fines", "name": "Pay unpaid tickets", "category": "money", "target": "self",
		"minutes": 5, "description": "Clear unpaid tickets before they become jail time."})
	acts.set_check("crime_pay_fines", func(_d, _t): return "" if unpaid_fines > 0.0 else "No unpaid tickets")
	acts.set_handler("crime_pay_fines", func(_d, _t, result): pay_fines(); return result)


func _life_check(crime_id: String, target) -> String:
	var c := Catalog.find(crime_id)
	if in_jail or not booking.is_empty():
		return "You are in custody"
	var target_is_police := _is_police(target)
	if bool(c.get("police_only", false)) and not target_is_police:
		return "Only works on a police officer"
	if crime_id == "bribery" and police.stars == 0 and warrant.is_empty():
		return "You are not in trouble"
	return ""


func _life_handle(crime_id: String, target, result) -> Variant:
	var ctx := {}
	if target is Node:
		if target.get("npc_id") != null:
			ctx.victim_id = String(target.get("npc_id"))
			ctx.victim_node = target
		if target is Node3D:
			ctx.position = (target as Node3D).global_position
	elif target is String:
		ctx.victim_id = target
	var out := commit(crime_id, ctx)
	if result is Dictionary:
		result.message = out.get("message", "")
		result.crime = out
		result.success = bool(out.get("success", true))
	return result


func _on_life_action_started(id, _target) -> void:
	if String(id) == "crime_hide":
		hiding = true


func _on_life_action_finished(id, _target, _result) -> void:
	if String(id) == "crime_hide":
		hiding = false


func _is_police(target) -> bool:
	if target is Node:
		return target.is_in_group("police") or bool(target.get("is_police"))
	return false


# --------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------

func _roll_success(crime: Dictionary) -> bool:
	if not crime.has("chance"):
		return true
	var p := float(crime.chance)
	if crime.has("skill"):
		p += 0.03 * _skill(String(crime.skill))
	return rng.randf() < clampf(p, 0.05, 0.98)


func _give_loot(crime: Dictionary) -> float:
	if not crime.has("loot"):
		return 0.0
	var lo := int(crime.loot[0])
	var hi := int(crime.loot[1])
	var amount := float(rng.randi_range(lo, hi))
	var life := _life()
	if life and life.get("money") and life.money.has_method("add"):
		life.money.add(amount, "Stolen: " + String(crime.name).to_lower())
	stats.loot += amount
	return amount


func _add_skill_xp(crime: Dictionary, success: bool) -> void:
	var life := _life()
	if not crime.has("skill") or life == null or life.get("skills") == null:
		return
	life.skills.add_xp(String(crime.skill), 6 if success else 2)


func _skill(id: String) -> int:
	var life := _life()
	if life == null or life.get("skills") == null or not life.skills.has_method("level"):
		return 0
	return int(life.skills.level(id))


func _visibility() -> float:
	var v := 1.0
	if hiding:
		v = 0.15
	elif _player_indoors():
		v = 0.5
	if _is_night():
		v *= 0.7
	return v


func _escape() -> float:
	return 1.0 + 0.05 * _skill("athletics") + 0.03 * _skill("fitness") + 0.03 * _skill("stealth")


func _player_indoors() -> bool:
	var cd := _node("CityData")
	if cd and cd.has_method("room_at"):
		var r = cd.room_at(_player_pos())
		return r != null and not (r is Dictionary and r.is_empty()) and not (r is String and r == "")
	return false


func _player() -> Node3D:
	var gs := _node("GameState")
	if gs and gs.has_method("get_player"):
		var p = gs.get_player()
		if p is Node3D:
			return p
	if get_tree():
		var ps := get_tree().get_nodes_in_group("player")
		if not ps.is_empty() and ps[0] is Node3D:
			return ps[0]
	return null


func _player_pos() -> Vector3:
	var p := _player()
	return p.global_position if p and p.is_inside_tree() else Vector3.ZERO


func _now() -> float:
	var life := _life()
	if life and life.get("clock") and life.clock.get("total_minutes") != null:
		return float(life.clock.total_minutes)
	var gc := _node("GameClock")
	if gc and gc.get("total_minutes") != null:
		return float(gc.total_minutes)
	return float(Time.get_ticks_msec()) / 1000.0


func _is_night() -> bool:
	var h := fmod(_now() / 60.0, 24.0)
	return h < 6.0 or h >= 20.0


func _advance_clock(minutes: int) -> void:
	var life := _life()
	if life and life.get("clock") and life.clock.has_method("advance_minutes"):
		life.clock.advance_minutes(minutes)
	elif _node("GameClock") and _node("GameClock").has_method("advance_minutes"):
		_node("GameClock").advance_minutes(minutes)


func _cash() -> float:
	var life := _life()
	if life and life.get("money"):
		var c = life.money.get("cash")
		return float(c) if c != null else 0.0
	return 0.0


func _spend(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		return true
	var life := _life()
	if life and life.get("money") and life.money.has_method("spend"):
		return bool(life.money.spend(amount, reason))
	return true   # no money system yet: fines are free rather than blocking play


func _set_flag(k: String, v) -> void:
	var life := _life()
	if life and life.has_method("set_flag"):
		life.set_flag(k, v)


func _publish() -> void:
	_set_flag("crime.wanted", police.stars)
	_set_flag("crime.record", record.summary())
	_set_flag("crime.has_felony", record.has_felony())
	_set_flag("crime.warrant", not warrant.is_empty())
	_set_flag("crime.unpaid_fines", unpaid_fines)
	wanted_changed.emit(police.stars, police.state)
	record_changed.emit(record.summary())


func _toast(text: String) -> void:
	if text == "":
		return
	var ui := _node("UI")
	if ui and ui.has_method("notify"):
		ui.notify(text)
	elif _hud and _hud.has_method("toast"):
		_hud.toast(text)


func _success_text(crime: Dictionary, success: bool, loot: float) -> String:
	if not success:
		return "%s failed." % String(crime.name)
	if loot > 0.0:
		return "%s: +$%d." % [String(crime.name), int(loot)]
	return "%s." % String(crime.name)


func _hours_text(h: int) -> String:
	if h >= 48:
		return "%d days" % int(round(h / 24.0))
	return "%d hours" % h


func _life() -> Node:
	return _node("Life")


func _node(n: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + n)


# --------------------------------------------------------------------------------------------
# Save / load (Life save provider and GameState saveable)
# --------------------------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"record": record.to_save(), "police": police.to_save(), "charges": charges.duplicate(),
		"warrant": warrant.duplicate(), "identified": identified, "unpaid_fines": unpaid_fines, "stats": stats.duplicate()}


func from_save(d: Dictionary) -> void:
	record.from_save(d.get("record", {}))
	police.from_save(d.get("police", {}))
	charges.clear()
	for c in d.get("charges", []):
		charges.append(String(c))
	warrant.clear()
	for c in d.get("warrant", []):
		warrant.append(String(c))
	identified = bool(d.get("identified", false))
	unpaid_fines = float(d.get("unpaid_fines", 0.0))
	stats.merge(d.get("stats", {}), true)
	booking = {}
	in_jail = false
	_publish()


func save_data() -> Dictionary:
	return to_save()


func load_data(d: Dictionary) -> void:
	from_save(d)
