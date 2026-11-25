extends Node
## The player's home: a rented room in Cathedral Mount (a shared apartment above the
## Hamilton Strip shops by default). Weekly rent through Life's bills; "Go home" and
## "Go to work" travel actions (the clock moves by the walk); shown on the map.
## Saved through GameState.

signal home_changed(room_id: String)

const WEEKLY_RENT := 150.0
const WALK_MPS := 1.4
const HOME_TYPES := ["apartment_bed", "bedroom", "dorm_single", "dorm_double"]

var room_id := ""
var building_id := ""
var household: Array = []   # npc ids living with you (partner who moved in, spouse)
var _loaded := false


func _ready() -> void:
	GameState.register_saveable("home", self)
	GameState.game_started.connect(_on_game_started)
	_register_actions.call_deferred()
	_hook_romance.call_deferred()


func _on_game_started() -> void:
	if _loaded:
		_loaded = false
		return
	# Deferred: Life resets money (and its bills) on the same signal.
	(func(): assign(pick_starter())).call_deferred()


## Nearest rentable bedroom to The Summit, above ground (apartments over the shops).
func pick_starter() -> String:
	var best := ""
	var best_d := INF
	for r in CityData.all_rooms():
		if str(r.get("roomType", "")) != "apartment_bed" or int(r.get("floor", 0)) < 1:
			continue
		var c: Vector3 = CityData.room_world_center(str(r.roomId))
		var d := Vector2(c.x, c.z).length()
		if d < best_d:
			best_d = d
			best = str(r.roomId)
	return best


func assign(rid: String) -> void:
	if rid == "":
		return
	room_id = rid
	building_id = str(CityData.room(rid).get("buildingId", ""))
	var life := get_node_or_null("/root/Life")
	if life and life.get("money"):
		life.money.add_bill("rent", WEEKLY_RENT, 7, "Rent: %s" % place_name())
	home_changed.emit(room_id)


func place_name() -> String:
	var b: Dictionary = CityData.building(building_id) if building_id != "" else {}
	var n := str(b.get("name", "your building"))
	return n if n != "" else "your building"


## Just inside the room's door (the middle of a bedroom is usually the bed).
func home_position() -> Vector3:
	if room_id == "":
		return Vector3.ZERO
	var r: Dictionary = CityData.room(room_id)
	var rc: Array = r.get("rect", [])
	if rc.size() < 4:
		return CityData.room_world_center(room_id) + Vector3(0, 0.1, 0)
	var y := float(r.get("y", 0.0))
	var center := Vector3((rc[0] + rc[2]) * 0.5, y, (rc[1] + rc[3]) * 0.5)
	var local := center
	for o in r.get("openings", []):
		if str(o.get("type", "")) == "door":
			var dp: Array = o.position
			var door := Vector3(float(dp[0]), y, float(dp[2]))
			var dir := (center - door)
			dir.y = 0.0
			local = door + dir.normalized() * minf(0.9, dir.length())
			break
	return CityData.building_transform(str(r.buildingId)) * local + Vector3(0, 0.1, 0)


## Game minutes to walk from p to q (street distance, about 1.3x straight line).
static func walk_minutes(p: Vector3, q: Vector3) -> float:
	var m := Vector2(p.x - q.x, p.z - q.z).length() * 1.3
	return clampf(m / WALK_MPS / 60.0, 1.0, 90.0)


func travel_to(dest: Vector3, label: String) -> bool:
	var pl := GameState.get_player()
	if pl == null or dest == Vector3.ZERO:
		return false
	var mins := walk_minutes(pl.global_position, dest)
	var life := get_node_or_null("/root/Life")
	if life and life.get("clock"):
		life.clock.advance_minutes(mins)
	else:
		GameClock.advance_minutes(mins)
	pl.teleport(dest, pl.rotation.y)
	UI.notify("You walk to %s (%d min)." % [label, int(round(mins))])
	return true


func _work_building() -> String:
	var js := get_node_or_null("/root/JobSystem")
	if js == null:
		return ""
	if js.active_job != "":
		return str(js.get_job(js.active_job).get("building", ""))
	for jid in js.employment:
		return str(js.get_job(jid).get("building", ""))
	return ""


func _door_of(bid: String) -> Vector3:
	# Just outside the front of the building (local -z is the street side).
	var b: Dictionary = CityData.building(bid)
	var fp: Array = b.get("footprintCm", [0, 0])
	return CityData.building_transform(bid) * Vector3(float(fp[0]) / 200.0, 0.2, -1.5)


func _register_actions() -> void:
	var life := get_node_or_null("/root/Life")
	if life == null or life.get("actions") == null:
		return
	var A = life.actions
	A.register({"id": "go_home", "name": "Go home", "category": "home", "target": "self", "minutes": 0,
		"description": "Walk back to your room. Time passes for the walk."})
	A.set_check("go_home", func(_d, _t):
		if room_id == "": return "You don't have a home"
		var pl := GameState.get_player()
		if pl and pl.global_position.distance_to(home_position()) < 6.0: return "You're home"
		return "")
	A.set_handler("go_home", func(_d, _t, res):
		travel_to(home_position(), "home")
		return res)
	A.register({"id": "go_to_work", "name": "Go to work", "category": "work", "target": "self", "minutes": 0,
		"requires": {"flags": ["job.employed"]}, "description": "Walk to your workplace."})
	A.set_check("go_to_work", func(_d, _t):
		var b := _work_building()
		if b == "": return "No job"
		var pl := GameState.get_player()
		if pl and pl.global_position.distance_to(_door_of(b)) < 10.0: return "You're here"
		return "")
	A.set_handler("go_to_work", func(_d, _t, res):
		travel_to(_door_of(_work_building()), "work")
		return res)
	A.register({"id": "go_to_campus", "name": "Walk to campus (Founders' Quad)", "category": "school", "target": "self",
		"minutes": 0, "description": "Classes, libraries and the registrar."})
	A.set_handler("go_to_campus", func(_d, _t, res):
		travel_to(Vector3(190, -6.2, 420), "Founders' Quad")
		return res)


# --- Living together ---------------------------------------------------------------

func _hook_romance() -> void:
	var life := get_node_or_null("/root/Life")
	if life and life.get("actions") and life.actions.has_signal("action_finished"):
		life.actions.action_finished.connect(_on_action_finished)


func _on_action_finished(id: String, target: Variant, result: Dictionary) -> void:
	if not result.get("ok", true) or not result.get("success", true):
		return
	var life := get_node_or_null("/root/Life")
	var nid: String = life.actions.npc_id(target) if life and target != null and life.actions.has_method("npc_id") else ""
	if nid == "":
		return
	match id:
		"move_in_together", "get_married":
			add_to_household(nid)
		"break_up", "divorce":
			remove_from_household(nid)


## A partner moves in: they live (and sleep) at your place and pay half the rent.
func add_to_household(nid: String) -> void:
	if room_id == "" or nid in household:
		return
	household.append(nid)
	_apply_household(nid)
	var life := get_node_or_null("/root/Life")
	var who: String = life.relationships.display_name(nid) if life else nid
	UI.notify("%s moves in with you. Rent is split from now on." % who)
	_update_rent()


func remove_from_household(nid: String) -> void:
	if not (nid in household):
		return
	household.erase(nid)
	var npcs := get_node_or_null("/root/NPCs")
	if npcs and npcs.has_method("restore_home"):
		npcs.restore_home(nid)
	var life := get_node_or_null("/root/Life")
	var who: String = life.relationships.display_name(nid) if life else nid
	UI.notify("%s moves out." % who)
	_update_rent()


func _apply_household(nid: String) -> void:
	var npcs := get_node_or_null("/root/NPCs")
	if npcs == null or not npcs.has_method("relocate_home"):
		return
	if not npcs.ready_state:
		await npcs.population_ready
	npcs.relocate_home(nid, building_id)


func _update_rent() -> void:
	var life := get_node_or_null("/root/Life")
	if life == null or life.get("money") == null or room_id == "":
		return
	var share := WEEKLY_RENT / float(1 + household.size())
	var nd: int = int(life.money.bills.get("rent", {}).get("next_day", -1))
	life.money.add_bill("rent", snappedf(share, 0.01), 7, "Rent: %s%s" % [place_name(), " (split)" if not household.is_empty() else ""], nd)


func save_data() -> Dictionary:
	return {"room_id": room_id, "household": household.duplicate()}


func load_data(d: Dictionary) -> void:
	_loaded = true
	var npcs := get_node_or_null("/root/NPCs")
	for nid in household:
		if npcs and npcs.has_method("restore_home"):
			npcs.restore_home(nid)
	household = d.get("household", []).duplicate()
	room_id = str(d.get("room_id", ""))
	building_id = str(CityData.room(room_id).get("buildingId", "")) if room_id != "" else ""
	for nid in household:
		_apply_household(nid)
	home_changed.emit(room_id)
