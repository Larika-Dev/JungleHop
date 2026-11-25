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
var _loaded := false


func _ready() -> void:
	GameState.register_saveable("home", self)
	GameState.game_started.connect(_on_game_started)
	_register_actions.call_deferred()


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


func home_position() -> Vector3:
	return CityData.room_world_center(room_id) + Vector3(0, 0.1, 0) if room_id != "" else Vector3.ZERO


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


func save_data() -> Dictionary:
	return {"room_id": room_id}


func load_data(d: Dictionary) -> void:
	_loaded = true
	room_id = str(d.get("room_id", ""))
	building_id = str(CityData.room(room_id).get("buildingId", "")) if room_id != "" else ""
	home_changed.emit(room_id)
