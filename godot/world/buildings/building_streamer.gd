class_name BuildingStreamer
extends Node3D
## Streams the modeled building exteriors (BuildingDetail) around the camera.
##
## Per building (Buildings/B_<id>, building transform applied):
##   Far    massing box + roof with shader-painted windows, visible beyond the detail range
##   Main   modeled facade, roof, storefront, cornice ... (visible within `detail_distance`)
##   Fine   small parts: muntins, balusters, dentils, louvers, straps (within ~45 % of it)
##   Glass  modeled window panes   } hidden while InteriorStreamer has the real interior loaded,
##   Doors  door leaves            } so you see the real rooms and hinged doors instead
##   Signs  Label3D lettering (storefront signs, awnings, blade signs, house numbers)
## Detail meshes are generated on worker threads and handed over a couple per frame.
## Landmarks (LM*) keep their hand-authored shells from the map.

signal idle

const SKIP_PREFIX := "LM"
const CHECK_EVERY := 0.3
const MAX_TASKS := 3
const FONTS := {
	"display": "res://assets/fonts/bebas-neue-latin-400-normal.woff2",
	"condensed": "res://assets/fonts/oswald-latin-600-normal.woff2",
	"serif": "res://assets/fonts/libre-baskerville-latin-700-normal.woff2",
}

var quality := 2
var detail_distance := 160.0
var fine_distance := 70.0
var _ids: Array = []
var _nodes: Dictionary = {}      # id -> {root, far, detail: Array[Node], glass: Array[Node]}
var _tasks: Dictionary = {}      # id -> WorkerThreadPool task id
var _results: Dictionary = {}    # id -> build result (filled from worker threads)
var _mutex := Mutex.new()
var _timer := 0.0
var _hidden_glass: Dictionary = {}   # ids with the interior streamed in
var _mats: Dictionary = {}
var _fonts: Dictionary = {}
var _want: Array = []
var _cam_pos := Vector3.ZERO
var _was_busy := false


func _ready() -> void:
	set_quality(Settings.quality, Settings.building_distance)
	CityData.all_rooms()   # load rooms.json on the main thread before workers read it
	BuildingDetail.pal("TRIM_WHITE")   # and the palette
	for bd in CityData.buildings:
		var bid: String = bd["id"]
		if bid.begins_with(SKIP_PREFIX):
			continue
		_ids.append(bid)
		_make_far(bd)


func set_quality(q: int, dist: float) -> void:
	if clampi(q, 0, 3) != quality:
		for bid in _nodes:
			if detail_loaded(bid):
				_drop_detail(bid)
	quality = clampi(q, 0, 3)
	detail_distance = dist
	fine_distance = dist * 0.45
	for bid in _nodes:
		_apply_ranges(bid)


## Toggle the modeled glass + door leaves for a building whose real interior is loaded.
func set_interior_loaded(bid: String, loaded: bool) -> void:
	if loaded:
		_hidden_glass[bid] = true
	else:
		_hidden_glass.erase(bid)
	var nd: Dictionary = _nodes.get(bid, {})
	for g in nd.get("glass", []):
		if is_instance_valid(g):
			g.visible = not loaded


func is_idle() -> bool:
	return _tasks.is_empty() and _results.is_empty() and _want.is_empty()


func detail_loaded(bid: String) -> bool:
	return not (_nodes.get(bid, {}).get("detail", []) as Array).is_empty()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_pos = cam.global_position
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_EVERY
		_refresh()
	# launch builds
	while _tasks.size() < MAX_TASKS and not _want.is_empty():
		var bid: String = _want.pop_front()
		if _tasks.has(bid) or detail_loaded(bid):
			continue
		var bd := CityData.building(bid)
		var rooms := CityData.rooms_for_building(bid)
		var q := quality
		_tasks[bid] = WorkerThreadPool.add_task(_build_task.bind(bid, bd, rooms, q), false, "building " + bid)
	# collect finished builds (a couple per frame keeps the hitch small)
	var done := 0
	for bid in _tasks.keys():
		if done >= 2:
			break
		if WorkerThreadPool.is_task_completed(_tasks[bid]):
			WorkerThreadPool.wait_for_task_completion(_tasks[bid])
			_tasks.erase(bid)
			_mutex.lock()
			var res: Dictionary = _results.get(bid, {})
			_results.erase(bid)
			_mutex.unlock()
			if not res.is_empty():
				_attach(bid, res)
				done += 1
	var busy := not is_idle()
	if _was_busy and not busy:
		idle.emit()
	_was_busy = busy


func _build_task(bid: String, bd: Dictionary, rooms: Array, q: int) -> void:
	var res := BuildingDetail.build(bd, rooms, q)
	_mutex.lock()
	_results[bid] = res
	_mutex.unlock()


func _refresh() -> void:
	var load_r := detail_distance + 40.0
	var unload_r := detail_distance + 90.0
	var want: Array = []
	for bid in CityData.buildings_near(_cam_pos, load_r + 60.0):
		if bid.begins_with(SKIP_PREFIX):
			continue
		var d := _distance(bid, _cam_pos)
		if d < load_r and not detail_loaded(bid) and not _tasks.has(bid):
			want.append([d, bid])
	want.sort_custom(func(a, b): return a[0] < b[0])
	_want.clear()
	for w in want:
		_want.append(w[1])
	for bid in _nodes:
		if detail_loaded(bid) and _distance(bid, _cam_pos) > unload_r:
			_drop_detail(bid)


## Distance from p to the building's footprint (XZ).
func _distance(bid: String, p: Vector3) -> float:
	var bd := CityData.building(bid)
	var t: Dictionary = bd["transform"]
	var fp: Array = bd.get("footprintCm", [1000, 1000])
	var rot: float = t["rotY"]
	var dx: float = p.x - t["x"]
	var dz: float = p.z - t["z"]
	var lx := cos(rot) * dx - sin(rot) * dz
	var lz := sin(rot) * dx + cos(rot) * dz
	var qx := maxf(maxf(-lx, lx - fp[0] / 100.0), 0.0)
	var qz := maxf(maxf(-lz, lz - fp[1] / 100.0), 0.0)
	return Vector2(qx, qz).length()


# ------------------------------------------------------------------------------------------ nodes
func _make_far(bd: Dictionary) -> void:
	var bid: String = bd["id"]
	var root := Node3D.new()
	root.name = "B_" + bid
	root.transform = CityData.building_transform(bid)
	add_child(root)
	var groups := BuildingDetail.build_far(bd, quality)
	var mi := _mesh_instance("Far", groups.get("far", []))
	root.add_child(mi)
	_nodes[bid] = {"root": root, "far": mi, "detail": [], "glass": []}
	_apply_ranges(bid)


func _mesh_instance(nm: String, surfaces: Array) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for s in surfaces:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s[1])
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(nm, s[0]))
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	return mi


func _attach(bid: String, res: Dictionary) -> void:
	var nd: Dictionary = _nodes.get(bid, {})
	if nd.is_empty() or _distance(bid, _cam_pos) > detail_distance + 90.0:
		return
	var root: Node3D = nd["root"]
	var groups: Dictionary = res["groups"]
	var detail: Array = []
	var glass: Array = []
	for g in ["main", "fine", "glass", "door"]:
		if not groups.has(g):
			continue
		var mi := _mesh_instance(g.capitalize(), groups[g])
		root.add_child(mi)
		detail.append(mi)
		if g == "glass" or g == "door":
			glass.append(mi)
			mi.visible = not _hidden_glass.has(bid)
	if not res["labels"].is_empty() and quality >= 0:
		var signs := Node3D.new()
		signs.name = "Signs"
		root.add_child(signs)
		detail.append(signs)
		for l in res["labels"]:
			signs.add_child(_label(l))
	nd["detail"] = detail
	nd["glass"] = glass
	_apply_ranges(bid)


func _drop_detail(bid: String) -> void:
	var nd: Dictionary = _nodes[bid]
	for n in nd["detail"]:
		if is_instance_valid(n):
			n.queue_free()
	nd["detail"] = []
	nd["glass"] = []
	_apply_ranges(bid)


func _apply_ranges(bid: String) -> void:
	var nd: Dictionary = _nodes[bid]
	var far: MeshInstance3D = nd["far"]
	var has_detail := not (nd["detail"] as Array).is_empty()
	# Godot measures visibility ranges to the instance AABB center: pad by the building's size
	var aabb: AABB = far.get_aabb()
	var pad := Vector2(aabb.size.x, aabb.size.z).length() * 0.5
	var near_end := detail_distance + pad
	far.visibility_range_begin = near_end if has_detail else 0.0
	far.visibility_range_begin_margin = 6.0
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for n in nd["detail"]:
		if n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			var fine := String(gi.name) == "Fine"
			gi.visibility_range_end = (fine_distance + pad) if fine else near_end
			gi.visibility_range_end_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if fine and quality < 2:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(gi.name) in ["Glass"]:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n is Node3D:
			for l in n.get_children():
				if l is Label3D:
					l.visibility_range_end = fine_distance + pad
	far.visible = true


func _label(l: Dictionary) -> Label3D:
	var lb := Label3D.new()
	lb.text = l["text"]
	lb.font = _font(l.get("font", "display"))
	lb.font_size = 96
	lb.outline_size = 0
	lb.pixel_size = float(l["size"]) / 96.0 * 1.25
	if l.has("max_w"):
		var tw: float = lb.font.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.font_size).x * lb.pixel_size
		if tw > float(l["max_w"]) and tw > 0.0:
			lb.pixel_size *= float(l["max_w"]) / tw
	lb.modulate = l["color"]
	lb.shaded = not bool(l.get("lit", false))
	lb.double_sided = false
	lb.no_depth_test = false
	lb.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var n: Vector3 = l["n"]
	lb.position = l["pos"]
	# Label3D faces +Z: turn it to face along the outward normal
	lb.basis = Basis.looking_at(-n, Vector3.UP)
	if bool(l.get("glow", false)):
		lb.outline_size = 10
		lb.outline_modulate = Color(l["color"].r, l["color"].g, l["color"].b, 0.35)
	return lb


func _font(key: String) -> Font:
	if not _fonts.has(key):
		_fonts[key] = load(FONTS.get(key, FONTS["display"]))
	return _fonts[key]


func _material(group: String, key: String) -> Material:
	var k := group + ":" + key
	if _mats.has(k):
		return _mats[k]
	var mat: Material
	match key:
		"glass":
			var g := ShaderMaterial.new()
			g.shader = load("res://world/shaders/window_glass.gdshader")
			mat = g
		"metal":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.vertex_color_is_srgb = false
			s.metallic = 0.55
			s.roughness = 0.45
			mat = s
		_:
			var f := ShaderMaterial.new()
			f.shader = load("res://world/shaders/facade.gdshader")
			f.set_shader_parameter("windows", group.to_lower() == "far")
			mat = f
	_mats[k] = mat
	return mat
