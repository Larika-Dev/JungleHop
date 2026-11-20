class_name FloorTravel
extends Interactable
## Stairs and elevators: a step block in the room that lets the player go to another floor.
## (Stair rooms in rooms.json are stacked per floor; travel moves you to the same room on that floor.)

var building_id := ""
var floor := 0
var floors := {}            # floor -> y (building-local)
var is_elevator := false


static func make(bid: String, room: Dictionary, p_floors: Dictionary) -> StaticBody3D:
	var rc: Array = room["rect"]
	var y: float = room["y"]
	var body := StaticBody3D.new()
	body.name = "Travel_" + String(room["roomId"])
	body.collision_layer = 4    # interact layer only: the player walks through it
	body.collision_mask = 0
	var it := FloorTravel.new()
	it.building_id = bid
	it.floor = int(room["floor"])
	it.floors = p_floors
	it.is_elevator = String(room.get("roomType", "")).begins_with("elevator")
	it.display_name = "Elevator" if it.is_elevator else "Stairs"
	body.add_child(it)
	# visual: a short flight of steps along the room's long side (or an elevator door panel)
	var w: float = rc[2] - rc[0]
	var d: float = rc[3] - rc[1]
	var along_x := w >= d
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CityData.color("TERRAZZO" if not it.is_elevator else "GALV_STEEL")
	var steps := 1 if it.is_elevator else 8
	for i in steps:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var run := minf(2.24, (w if along_x else d) * 0.6)
		if it.is_elevator:
			bm.size = Vector3(1.07, 2.13, 0.05)
			mi.position = Vector3((rc[0] + rc[2]) * 0.5, y + 1.065, rc[1] + 0.06)
		else:
			var tread := run / steps
			var hgt := 0.178 * (i + 1)
			var sw := minf(1.12, (d if along_x else w) * 0.45)
			bm.size = Vector3(tread, hgt, sw) if along_x else Vector3(sw, hgt, tread)
			if along_x:
				mi.position = Vector3(rc[0] + 0.3 + tread * (i + 0.5), y + hgt * 0.5, rc[1] + sw * 0.5 + 0.05)
			else:
				mi.position = Vector3(rc[0] + sw * 0.5 + 0.05, y + hgt * 0.5, rc[1] + 0.3 + tread * (i + 0.5))
		mi.mesh = bm
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = mi.position
		body.add_child(cs)
	body.set_meta("rect", rc)
	body.set_meta("y", y)
	return body


func get_actions(_actor: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys := floors.keys()
	keys.sort()
	for f in keys:
		if f == floor:
			continue
		if not is_elevator and absi(f - floor) != 1:
			continue
		var label := "Go %s to %s" % ["up" if f > floor else "down", _floor_name(f)]
		out.append({"id": "floor_%d" % f, "label": label, "minutes": 0.5})
	if out.is_empty():
		out.append({"id": "none", "label": "No other floors", "enabled": false})
	return out


static func _floor_name(f: int) -> String:
	if f < 0:
		return "basement"
	if f == 0:
		return "ground floor"
	return "floor %d" % (f + 1)


func perform(action_id: String, actor: Node) -> void:
	if not action_id.begins_with("floor_"):
		return
	var f := int(action_id.substr(6))
	var target := _target_room(f)
	if target.is_empty() or not actor.has_method("teleport"):
		return
	var rc: Array = target["rect"]
	var bt := CityData.building_transform(building_id)
	var local := Vector3(rc[2] - 0.6, float(target["y"]) + 0.05, rc[3] - 0.6)
	actor.teleport(bt * local, actor.rotation.y)
	super.perform(action_id, actor)


func _target_room(f: int) -> Dictionary:
	var best := {}
	var me_rc: Array = get_parent().get_meta("rect", [0, 0, 0, 0])
	var best_d := INF
	for r in CityData.rooms_for_building(building_id):
		if int(r["floor"]) != f:
			continue
		var rt := String(r.get("roomType", ""))
		var rc: Array = r["rect"]
		var dd := Vector2((rc[0] + rc[2]) - (me_rc[0] + me_rc[2]), (rc[1] + rc[3]) - (me_rc[1] + me_rc[3])).length()
		if not (rt == "stair" or rt.begins_with("elevator")):
			dd += 1000.0
		if dd < best_d:
			best_d = dd
			best = r
	return best
