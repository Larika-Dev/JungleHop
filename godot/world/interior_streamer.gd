class_name InteriorStreamer
extends Node3D
## Builds walkable building interiors from rooms.json for buildings near the player
## (CLAUDE.md §7.6: within 35 m). Every room gets a floor slab, a ceiling with an emissive
## light panel, walls with door and window openings, glass, hinged doors (Door interactable)
## and, in stair / elevator rooms, a FloorTravel interactable to change floors.
##
## Output: Interiors/BLD_<buildingId> (building transform applied), and inside it one Node3D per
## room named by roomId with meta("room") = rooms.json entry.

signal building_loaded(id: String, node: Node3D)
signal building_unloaded(id: String)

const LOAD_RADIUS := 35.0
const UNLOAD_RADIUS := 50.0
const WALL_T := 0.06        # each room contributes half of a 12 cm partition
const SLAB_T := 0.12
const DOOR_H := 2.13
const SILL_H := 0.9
const WIN_H := 1.5
const CHECK_EVERY := 0.4

var target: Node3D
var loaded: Dictionary = {}     # id -> Node3D
var _queue: Array[String] = []
var _timer := 0.0
var _mats: Dictionary = {}


func _ready() -> void:
	add_to_group("interior_streamer")


func _process(delta: float) -> void:
	if target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_EVERY
		_refresh()
		_update_lights()
	if not _queue.is_empty():
		var id: String = _queue.pop_front()
		if not loaded.has(id) and _footprint_distance(id, target.global_position) < UNLOAD_RADIUS:
			_build(id)


var _lit_key := ""

## Room lights are on only for the floor of the building the player is in (cheap and plenty).
func _update_lights() -> void:
	var r := CityData.room_at(target.global_position)
	var key := "" if r.is_empty() else "%s|%d" % [r["buildingId"], int(r["floor"])]
	if key == _lit_key:
		return
	_set_lights(_lit_key, false)
	_lit_key = key
	_set_lights(_lit_key, true)


func _set_lights(key: String, on: bool) -> void:
	if key == "":
		return
	var parts := key.split("|")
	var root: Node3D = loaded.get(parts[0])
	if root == null:
		return
	var n := 0
	for room_node in root.get_children():
		if room_node.has_meta("room") and int(room_node.get_meta("room")["floor"]) == int(parts[1]):
			var l := room_node.get_node_or_null("Light")
			if l and n < 40:
				l.visible = on
				n += 1


## Builds every interior within the radius right now (used at spawn, so the player never
## stands in a building that has no floor yet).
func load_now(pos: Vector3) -> void:
	for id in CityData.buildings_near(pos, 220.0):
		if not loaded.has(id) and _footprint_distance(id, pos) < LOAD_RADIUS:
			_build(id)


func is_loaded(id: String) -> bool:
	return loaded.has(id)


func _refresh() -> void:
	var p := target.global_position
	for id in CityData.buildings_near(p, 220.0):
		if loaded.has(id) or _queue.has(id):
			continue
		if _footprint_distance(id, p) < LOAD_RADIUS:
			_queue.append(id)
	_queue.sort_custom(func(a, b): return _footprint_distance(a, p) < _footprint_distance(b, p))
	for id in loaded.keys():
		if _footprint_distance(id, p) > UNLOAD_RADIUS:
			building_unloaded.emit(id)
			loaded[id].queue_free()
			loaded.erase(id)


## XZ distance from a world point to the building's footprint rectangle.
func _footprint_distance(id: String, p: Vector3) -> float:
	var bd := CityData.building(id)
	if bd.is_empty():
		return INF
	var local := CityData.building_transform(id).affine_inverse() * p
	var fp: Array = bd.get("footprintCm", [1000, 1000])
	var fx: float = fp[0] / 100.0
	var fz: float = fp[1] / 100.0
	var dx := maxf(maxf(-local.x, local.x - fx), 0.0)
	var dz := maxf(maxf(-local.z, local.z - fz), 0.0)
	return Vector2(dx, dz).length()


func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"_glass":
			m.albedo_color = Color(0.75, 0.85, 0.9, 0.22)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"_light":
			m.albedo_color = Color(1, 1, 1)
			m.emission_enabled = true
			m.emission = CityData.color("INTERIOR_WARM", Color(1, 0.85, 0.63))
			m.emission_energy_multiplier = 1.6
		"_door":
			m.albedo_color = CityData.color("WALNUT_DARK", Color(0.31, 0.21, 0.14))
			m.roughness = 0.6
		_:
			m.albedo_color = CityData.color(key)
			m.roughness = 0.85
	_mats[key] = m
	return m


# ------------------------------------------------------------------------------------------ build
class Builder:
	var surfaces: Dictionary = {}   # mat key -> SurfaceTool
	var shapes: Array = []          # [center: Vector3, size: Vector3]

	func st(key: String) -> SurfaceTool:
		if not surfaces.has(key):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = s
		return surfaces[key]

	## Axis-aligned box from min corner a to max corner b (building-local).
	func box(key: String, a: Vector3, b: Vector3, collide := true) -> void:
		var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
		var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
		if hi.x - lo.x < 0.005 or hi.y - lo.y < 0.005 or hi.z - lo.z < 0.005:
			return
		var s := st(key)
		var c := [
			Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
			Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
		_quad(s, c[0], c[1], c[2], c[3], Vector3.FORWARD)   # -z
		_quad(s, c[5], c[4], c[7], c[6], Vector3.BACK)      # +z
		_quad(s, c[4], c[0], c[3], c[7], Vector3.LEFT)      # -x
		_quad(s, c[1], c[5], c[6], c[2], Vector3.RIGHT)     # +x
		_quad(s, c[3], c[7], c[6], c[2], Vector3.UP)        # +y
		_quad(s, c[0], c[1], c[5], c[4], Vector3.DOWN)      # -y
		if collide:
			shapes.append([(lo + hi) * 0.5, hi - lo])

	func quad_down(key: String, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
		_quad(st(key), Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.DOWN)

	func _quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		# Godot front faces are clockwise when seen from the front.
		for v in [a, b, c, a, c, d]:
			s.set_normal(n)
			s.set_uv(Vector2(v.x + v.z, v.y))
			s.add_vertex(v)


func _build(id: String) -> void:
	var rooms := CityData.rooms_for_building(id)
	if rooms.is_empty():
		return
	var root := Node3D.new()
	root.name = "BLD_" + id
	root.transform = CityData.building_transform(id)
	root.set_meta("building_id", id)
	var b := Builder.new()
	var doors := {}      # dedupe key -> [pos: Vector3, along_x: bool, width: float]
	var floors := {}     # floor -> y
	var travel_rooms: Array = []
	for r in rooms:
		var rc: Array = r["rect"]
		var x0: float = rc[0]
		var z0: float = rc[1]
		var x1: float = rc[2]
		var z1: float = rc[3]
		var y: float = r["y"]
		var h: float = maxf(r.get("ceilingCm", 280) / 100.0, 2.3)
		floors[int(r["floor"])] = y
		var room_node := Node3D.new()
		room_node.name = String(r["roomId"])
		room_node.set_meta("room", r)
		root.add_child(room_node)
		var lamp := OmniLight3D.new()
		lamp.name = "Light"
		lamp.position = Vector3((x0 + x1) * 0.5, y + h - 0.3, (z0 + z1) * 0.5)
		lamp.omni_range = clampf(Vector2(x1 - x0, z1 - z0).length() * 0.75, 3.0, 18.0)
		lamp.light_energy = 1.4
		lamp.light_color = CityData.color(String(r.get("lightingKey", "INTERIOR_WARM")), Color(1, 0.85, 0.63))
		lamp.shadow_enabled = false
		lamp.visible = false
		room_node.add_child(lamp)
		# floor slab and ceiling
		var ff: String = r.get("floorFinish", "OAK_FLOOR")
		b.box(ff, Vector3(x0 - WALL_T, y - SLAB_T, z0 - WALL_T), Vector3(x1 + WALL_T, y, z1 + WALL_T))
		b.quad_down(r.get("ceilingFinish", "CEILING_WHITE"), x0, z0, x1, z1, y + h)
		var cx := (x0 + x1) * 0.5
		var cz := (z0 + z1) * 0.5
		var pw := minf(1.2, (x1 - x0) * 0.4)
		var pd := minf(0.6, (z1 - z0) * 0.4)
		b.quad_down("_light", cx - pw * 0.5, cz - pd * 0.5, cx + pw * 0.5, cz + pd * 0.5, y + h - 0.01)
		# walls with openings
		var wf: String = r.get("wallFinish", "PAINT_OFFICE")
		var ops: Array = r.get("openings", [])
		_wall(b, wf, ops, x0, z0, x1, z0, y, h, Vector3(0, 0, -1), doors)   # north edge (local -z)
		_wall(b, wf, ops, x0, z1, x1, z1, y, h, Vector3(0, 0, 1), doors)
		_wall(b, wf, ops, x0, z0, x0, z1, y, h, Vector3(-1, 0, 0), doors)
		_wall(b, wf, ops, x1, z0, x1, z1, y, h, Vector3(1, 0, 0), doors)
		var rt: String = r.get("roomType", "")
		if rt == "stair" or rt.begins_with("elevator"):
			travel_rooms.append(r)
	# mesh
	var mesh := ArrayMesh.new()
	for key in b.surfaces:
		var s: SurfaceTool = b.surfaces[key]
		s.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(key))
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = mesh
	root.add_child(mi)
	# collision
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	for sh in b.shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sh[1]
		cs.shape = bs
		cs.position = sh[0]
		body.add_child(cs)
	root.add_child(body)
	# doors
	for k in doors:
		var d: Array = doors[k]
		var door := Door.make(d[0], d[1], d[2], _mat("_door"))
		root.add_child(door)
	# floor travel (stairs / elevators)
	for r in travel_rooms:
		var ft := FloorTravel.make(id, r, floors)
		root.add_child(ft)
	add_child(root)
	loaded[id] = root
	building_loaded.emit(id, root)


## One wall run along a room edge (a -> b, axis-aligned), offset outward by WALL_T, with openings cut.
func _wall(b: Builder, key: String, ops: Array, ax: float, az: float, bx: float, bz: float,
		y: float, h: float, n: Vector3, doors: Dictionary) -> void:
	var along_x := absf(bz - az) < 0.001
	var s0 := ax if along_x else az
	var s1 := bx if along_x else bz
	var fixed := az if along_x else ax
	# openings on this edge -> [s_center, width, type]
	var cuts: Array = []
	for o in ops:
		var p: Array = o["position"]
		var on := absf((p[2] if along_x else p[0]) - fixed) < 0.12
		var s: float = p[0] if along_x else p[2]
		if on and s > s0 - 0.05 and s < s1 + 0.05:
			cuts.append([s, o.get("widthCm", 91) / 100.0, o["type"]])
	cuts.sort_custom(func(c1, c2): return c1[0] < c2[0])
	var cur := s0 - WALL_T
	var end := s1 + WALL_T
	var top := y + h
	for c in cuts:
		var c0: float = clampf(c[0] - c[1] * 0.5, s0, s1)
		var c1: float = clampf(c[0] + c[1] * 0.5, s0, s1)
		if c0 < cur:
			c0 = cur
		if c1 <= c0:
			continue
		_seg(b, key, along_x, fixed, n, cur, c0, y, top)   # solid wall up to the opening
		if c[2] == "door":
			_seg(b, key, along_x, fixed, n, c0, c1, minf(y + DOOR_H, top), top)
			var mid := (c0 + c1) * 0.5
			var dpos := Vector3(mid, y, fixed) if along_x else Vector3(fixed, y, mid)
			var dk := "%d_%d_%d" % [roundi(dpos.x * 10), roundi(dpos.y * 10), roundi(dpos.z * 10)]
			if not doors.has(dk):
				doors[dk] = [dpos, along_x, c1 - c0]
		else:
			var wtop := minf(y + SILL_H + WIN_H, top)
			_seg(b, key, along_x, fixed, n, c0, c1, y, y + SILL_H)
			_seg(b, key, along_x, fixed, n, c0, c1, wtop, top)
			_seg(b, "_glass", along_x, fixed, n, c0, c1, y + SILL_H, wtop, 0.01)
		cur = c1
	_seg(b, key, along_x, fixed, n, cur, end, y, top)


func _seg(b: Builder, key: String, along_x: bool, fixed: float, n: Vector3, s0: float, s1: float,
		y0: float, y1: float, t: float = WALL_T) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var sign := n.z if along_x else n.x
	var inner := fixed
	var outer := fixed + sign * WALL_T
	if t != WALL_T:   # glass: thin pane at the outer face of this half-wall
		inner = fixed + sign * (WALL_T - t)
		outer = fixed + sign * WALL_T
	if along_x:
		b.box(key, Vector3(s0, y0, inner), Vector3(s1, y1, outer))
	else:
		b.box(key, Vector3(inner, y0, s0), Vector3(outer, y1, s1))
