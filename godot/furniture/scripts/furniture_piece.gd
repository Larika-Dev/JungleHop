class_name FurniturePiece
extends StaticBody3D
## One placed furniture model: the imported GLB, a box collider (world layer, so the player bumps into it
## and the look ray hits it), the FurnitureInteractable child, and animated moving parts
## (drawers slide out, doors and lids swing on their hinges, sliding doors slide).
##
## Models face +Z with their origin at the floor centre (see furniture_catalog.json).

const DRAWER_OPEN_FRACTION := 0.75
const DOOR_OPEN_DEG := 100.0
const LID_OPEN_DEG := 95.0
const ANIM_TIME := 0.35

var model_id: int = 0
var def: Dictionary = {}          # catalogue entry
var placement_index: int = -1     # index into the streamer's placement arrays
var room_id: String = ""
var interactable: FurnitureInteractable
var parts: Array[Dictionary] = [] # {key, kind: drawer|door|slide|lid, pivot: Node3D, open: bool, axis/offset...}
var light: OmniLight3D

static var _scene_cache: Dictionary = {}


static func create(p_def: Dictionary, p_room_id := "") -> FurniturePiece:
	var piece := FurniturePiece.new()
	piece.def = p_def
	piece.model_id = int(p_def.get("id", 0))
	piece.room_id = p_room_id
	piece.name = "F%03d_%s" % [piece.model_id, String(p_def.get("folder", "piece")).substr(4)]
	piece._build()
	return piece


static func load_model(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) as PackedScene
	return _scene_cache[path]


func _build() -> void:
	collision_layer = 1
	collision_mask = 0
	var size: Array = def.get("size_m", [0.5, 0.5, 0.5])
	var model_root := Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	var scene := load_model(String(def.get("model", "")))
	if scene:
		var inst := scene.instantiate()
		model_root.add_child(inst)
		_group_moving_parts(inst)
	var shape := CollisionShape3D.new()
	shape.name = "Collider"
	var box := BoxShape3D.new()
	box.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	shape.shape = box
	shape.position = Vector3(0, float(size[1]) * 0.5, 0)
	add_child(shape)
	if def.get("light_y") != null:
		light = OmniLight3D.new()
		light.name = "Bulb"
		light.position = Vector3(0, float(def["light_y"]), 0)
		light.light_color = Color(1.0, 0.85, 0.63) # INTERIOR_WARM
		light.light_energy = 1.2
		light.omni_range = 5.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
	interactable = FurnitureInteractable.new()
	interactable.name = "Interactable"
	interactable.piece = self
	interactable.furniture_kind = String(def.get("kind", ""))
	interactable.display_name = String(def.get("name", "Furniture"))
	add_child(interactable)
	set_meta("interactable", interactable)


# ---------------------------------------------------------------- moving parts

const _FIXED := ["drawer_rail", "drawer_divider", "door_track_bottom", "door_stiffener_inside"]
static var _re_drawer: RegEx
static var _re_door: RegEx
static var _re_slide: RegEx
static var _re_lid: RegEx


static func _init_patterns() -> void:
	if _re_drawer:
		return
	_re_drawer = RegEx.create_from_string("^(?:\\d+_)?((?:file_)?drawer(?:_\\d+)?|centre_pencil_drawer|cash_drawer|drawer_fronts_60|brass_drawer_pulls_60)(?:_|$)")
	_re_door = RegEx.create_from_string("^(?:\\d+_)?((?:lower_|upper_)?door(?:_\\d+|_l|_r)?|insulated_glass_door|cable_access_door)(?:_|$)")
	_re_slide = RegEx.create_from_string("^(?:\\d+_)?(sliding_rear_door_\\d+)")
	_re_lid = RegEx.create_from_string("^(?:\\d+_)?(lid|padded_lid|lid_cushion|lid_stay|piano_hinge_seg|power_box_flip_lid)(?:_|$)")


func _group_moving_parts(root: Node) -> void:
	_init_patterns()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var groups: Dictionary = {} # key -> {kind, meshes}
	for mi in meshes:
		var nm := String(mi.name)
		var bare := nm.substr(nm.find("_") + 1) if nm.length() > 4 and nm.substr(0, 3).is_valid_int() else nm
		if bare in _FIXED:
			continue
		var key := ""
		var kind := ""
		var m := _re_slide.search(nm)
		if m:
			key = m.get_string(1); kind = "slide"
		else:
			m = _re_drawer.search(nm)
			if m:
				key = m.get_string(1); kind = "drawer"
				if key == "brass_drawer_pulls_60": key = "drawer_fronts_60"
			else:
				m = _re_door.search(nm)
				if m:
					key = m.get_string(1); kind = "door"
					if key == "cable_access_door": kind = "lid"
				else:
					m = _re_lid.search(nm)
					if m:
						key = "power_box_flip_lid" if m.get_string(1) == "power_box_flip_lid" else "lid"; kind = "lid"
		if key == "":
			continue
		if not groups.has(key):
			groups[key] = {"kind": kind, "meshes": []}
		groups[key]["meshes"].append(mi)
	var all_aabb := _meshes_aabb(meshes)
	for key in groups.keys():
		var g: Dictionary = groups[key]
		_make_part(String(key), String(g["kind"]), g["meshes"], all_aabb)


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


func _meshes_aabb(list: Array) -> AABB:
	var first := true
	var box := AABB()
	for mi: MeshInstance3D in list:
		if mi.mesh == null:
			continue
		var a: AABB = mi.transform * mi.mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


func _make_part(key: String, kind: String, list: Array, whole: AABB) -> void:
	var box := _meshes_aabb(list)
	if box.size == Vector3.ZERO:
		return
	var pivot := Node3D.new()
	pivot.name = "Part_" + key
	var hinge_x := box.position.x
	var info := {"key": key, "kind": kind, "pivot": pivot, "open": false, "box": box}
	match kind:
		"drawer":
			pivot.position = Vector3.ZERO
			info["offset"] = Vector3(0, 0, clampf(box.size.z * DRAWER_OPEN_FRACTION, 0.05, 0.45))
		"slide":
			pivot.position = Vector3.ZERO
			var dir := 1.0 if box.get_center().x < whole.get_center().x else -1.0
			info["offset"] = Vector3(dir * box.size.x * 0.9, 0, 0)
		"door":
			# hinge: the knuckle if there is one, else the side nearer the carcass edge
			var knuckle_x := INF
			for mi: MeshInstance3D in list:
				if String(mi.name).contains("hinge_knuckle") and mi.mesh:
					knuckle_x = (mi.transform * mi.mesh.get_aabb()).get_center().x
			var left: bool
			if knuckle_x != INF:
				left = absf(knuckle_x - box.position.x) < absf(knuckle_x - box.end.x)
			elif key.ends_with("_l"):
				left = true
			elif key.ends_with("_r"):
				left = false
			else:
				left = box.get_center().x <= whole.get_center().x
			hinge_x = box.position.x if left else box.end.x
			pivot.position = Vector3(hinge_x, 0, box.end.z)
			info["axis"] = Vector3.UP
			info["angle"] = deg_to_rad(-DOOR_OPEN_DEG if left else DOOR_OPEN_DEG)
		"lid":
			pivot.position = Vector3(0, box.end.y, box.position.z)
			info["axis"] = Vector3.RIGHT
			info["angle"] = deg_to_rad(-LID_OPEN_DEG)
	var first_parent: Node = (list[0] as Node).get_parent()
	first_parent.add_child(pivot)
	for mi: MeshInstance3D in list:
		var xf := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		pivot.add_child(mi)
		mi.transform = Transform3D(xf.basis, xf.origin - pivot.position)
	info["rest"] = pivot.transform
	parts.append(info)


func has_openables() -> bool:
	return not parts.is_empty()


func any_open() -> bool:
	for p in parts:
		if p["open"]:
			return true
	return false


## Opens (or closes) the part nearest to `near` (world position), or every part when `near` is INF.
func set_part_open(open: bool, near := Vector3.INF) -> void:
	var targets: Array = []
	if near == Vector3.INF:
		targets = parts
	else:
		var best := -1
		var best_d := INF
		var local := to_local(near)
		for i in parts.size():
			var p: Dictionary = parts[i]
			if p["open"] == open:
				continue
			var d := (p["box"] as AABB).get_center().distance_to(local)
			if d < best_d:
				best_d = d; best = i
		if best >= 0:
			targets = [parts[best]]
	for p in targets:
		_animate_part(p, open)


func _animate_part(p: Dictionary, open: bool) -> void:
	p["open"] = open
	var pivot: Node3D = p["pivot"]
	var rest: Transform3D = p["rest"]
	var target := rest
	if open:
		match String(p["kind"]):
			"drawer", "slide":
				target = Transform3D(rest.basis, rest.origin + (p["offset"] as Vector3))
			_:
				target = Transform3D(rest.basis.rotated(p["axis"], p["angle"]), rest.origin)
	if not is_inside_tree():
		pivot.transform = target
		return
	var tw := create_tween()
	tw.tween_property(pivot, "transform", target, ANIM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func toggle_light() -> bool:
	if light:
		light.visible = not light.visible
		return light.visible
	return false


# ---------------------------------------------------------------- poses

## Seat transforms in world space. origin = seat surface, basis -Z = the way the sitter faces.
func seat_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for s in def.get("seats", []):
		var local := Transform3D(Basis(Vector3.UP, PI), Vector3(float(s[0]), float(s[1]), float(s[2])))
		out.append(global_transform * local)
	return out


## Bed transforms: origin = mattress top under the hips, basis -Z points from feet to head.
func bed_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var depth := float(def.get("size_m", [0, 0, 2.0])[2])
	for s in def.get("beds", []):
		var hips := Vector3(float(s[0]), float(s[1]), float(s[2]) + depth * 0.35)
		out.append(global_transform * Transform3D(Basis.IDENTITY, hips))
	return out


## Where a person stands to use this piece: 55 cm in front of its front face, facing it.
func approach_transform() -> Transform3D:
	var depth := float(def.get("size_m", [0, 0, 0.5])[2])
	var local := Transform3D(Basis.IDENTITY, Vector3(0, 0, depth * 0.5 + 0.55))
	return global_transform * local
