class_name StreetProps
extends Node3D
## Street props, parked cars, shrubs and clutter from data/props.json (exported from the web city's
## road network by tools/godot/export-godot-props.ts). Each model is one MultiMesh per 64 m chunk
## with a visibility range (so far chunks cost nothing), meshes get automatic LODs, and densities /
## distances follow the graphics preset (Settings.quality 0 low .. 3 ultra):
##   litter & small clutter are thinned on Low/Medium, ranges scale 0.55 / 0.75 / 1.0 / 1.35.
## Near the player, solid props get box colliders, and café seating is spawned as real Furniture
## pieces (bistro table #27, bentwood chairs #69) so they can be sat on like indoor furniture.
## Utility poles are strung with sagging wires.

const DATA := "res://data/props.json"
const CHUNK := 64.0
const COLLIDE_RADIUS := 36.0
const FURNITURE_RADIUS := 55.0
## Fraction of each class kept per quality preset.
const DENSITY := {
	"litter": [0.25, 0.55, 0.85, 1.0],
	"foliage": [0.45, 0.7, 1.0, 1.0],
	"clutter": [0.6, 0.85, 1.0, 1.0],
}
const RANGE_SCALE := [0.55, 0.75, 1.0, 1.35]
const CAR_PAINT := [Color(0.93, 0.93, 0.92), Color(0.05, 0.05, 0.06), Color(0.62, 0.63, 0.65), Color(0.32, 0.33, 0.35),
	Color(0.08, 0.16, 0.32), Color(0.55, 0.06, 0.06), Color(0.32, 0.07, 0.09), Color(0.72, 0.68, 0.58), Color(0.12, 0.22, 0.16),
	Color(0.15, 0.24, 0.38), Color(0.45, 0.6, 0.72), Color(0.18, 0.18, 0.19), Color(0.86, 0.84, 0.8), Color(0.72, 0.36, 0.12)]
## boxwood, holly, azalea, yew, a russet October shrub, a yellowing one (sRGB, slightly lifted:
## the foliage shader darkens the inner volume)
const SHRUB_TINT := [Color(0.31, 0.45, 0.23), Color(0.2, 0.34, 0.22), Color(0.36, 0.5, 0.28), Color(0.27, 0.38, 0.2),
	Color(0.52, 0.38, 0.2), Color(0.45, 0.5, 0.24)]
const BIKE_PAINT := [Color(0.1, 0.1, 0.1), Color(0.7, 0.1, 0.08), Color(0.1, 0.3, 0.6), Color(0.85, 0.85, 0.82), Color(0.2, 0.45, 0.3), Color(0.9, 0.6, 0.1)]
const LITTER_PAINT := [Color(0.95, 0.95, 0.93), Color(0.85, 0.2, 0.15), Color(0.2, 0.4, 0.75), Color(0.95, 0.8, 0.2),
	Color(0.25, 0.6, 0.3), Color(0.9, 0.5, 0.15), Color(0.6, 0.3, 0.6), Color(0.7, 0.68, 0.62)]
const DUMPSTER_PAINT := [Color(0.16, 0.3, 0.2), Color(0.12, 0.25, 0.45), Color(0.35, 0.22, 0.14)]
const MAILBOX_PAINT := [Color(0.08, 0.08, 0.08), Color(0.25, 0.25, 0.27), Color(0.12, 0.2, 0.15), Color(0.5, 0.12, 0.1)]

var target: Node3D
var data: Dictionary = {}
var meshes := {}          # model -> info dict from PropModels.build
var _mmis: Array[GeometryInstance3D] = []
var _solid := {}          # Vector2i(16 m cell) -> Array of [Transform3D, Vector3 size]
var _bodies := {}         # Vector2i -> StaticBody3D
var _furn := []           # [model_id, Transform3D]
var _furn_cells := {}     # Vector2i(32 m) -> PackedInt32Array
var _furn_live := {}      # index -> FurniturePiece
var _timer := 0.0
var _quality := -1
var _box_shapes := {}


func _ready() -> void:
	if not FileAccess.file_exists(DATA):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(d) != TYPE_DICTIONARY:
		return
	data = d
	_build()
	Settings.settings_changed.connect(_on_settings)


func _on_settings() -> void:
	if Settings.quality != _quality:
		_build()


static func class_of(model: String) -> String:
	if model.begins_with("litter_") or model in ["trash_bag", "cardboard", "leaf_pile", "weeds"]:
		return "litter"
	if model in ["fern", "shrub_wild", "rock", "shrub", "hedge", "log", "stump"]:
		return "foliage"
	if model in ["bicycle", "drain", "tree_grate", "planter", "aframe"]:
		return "clutter"
	return ""


func _build() -> void:
	_quality = clampi(Settings.quality, 0, 3)
	for m in _mmis:
		m.queue_free()
	_mmis.clear()
	_solid.clear()
	for k in _bodies:
		_bodies[k].queue_free()
	_bodies.clear()
	var detail: float = [0.45, 0.7, 1.0, 1.0][_quality]
	var rs: float = RANGE_SCALE[_quality]
	var props: Dictionary = data.get("props", {})
	for model in props:
		var info: Dictionary = meshes.get(model, {})
		if info.is_empty() or info.get("detail", -1.0) != detail:
			info = PropModels.build(model, detail)
			info.detail = detail
			info.mesh = _with_lods(info.mesh)
			meshes[model] = info
		if info.mesh == null:
			continue
		var cls := class_of(model)
		var keep: float = DENSITY[cls][_quality] if cls != "" else 1.0
		_place(model, props[model], info, keep, rs)
	_build_poles(rs)
	_index_furniture()


## Godot only builds LODs on import: run the same simplifier on code-built meshes.
static func _with_lods(mesh: ArrayMesh) -> ArrayMesh:
	if mesh == null:
		return null
	var im := ImporterMesh.new()
	for s in mesh.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _place(model: String, list: Array, info: Dictionary, keep: float, rs: float) -> void:
	var chunks := {}
	var tinted := model.begins_with("car_") or model in ["bicycle", "shrub", "shrub_wild", "hedge", "fern", "dumpster", "mailbox_post", "planter", "trash_bag"] or model.begins_with("litter_")
	var size: Vector3 = info.collide
	var i := 0
	for e in list:
		i += 1
		var h := _hash(float(e[0]), float(e[2]))
		if keep < 1.0 and h > keep:
			continue
		var basis := Basis(Vector3.UP, float(e[3]))
		var v := int(e[4]) if e.size() > 4 else 0
		var s := 1.0
		match model:
			"shrub", "shrub_wild", "fern", "rock", "leaf_pile", "weeds":
				s = 0.7 + 0.6 * _hash(float(e[2]), float(e[0]))
			"hedge", "planter":
				s = 0.92 + 0.16 * h
		if s != 1.0:
			basis = basis.scaled(Vector3(s, s * (0.85 + 0.3 * h), s))
		var xf := Transform3D(basis, Vector3(e[0], e[1], e[2]))
		var key := Vector2i(floori(float(e[0]) / CHUNK), floori(float(e[2]) / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append([xf, _tint(model, v, h)])
		if size != Vector3.ZERO:
			var ck := Vector2i(floori(float(e[0]) / 16.0), floori(float(e[2]) / 16.0))
			if not _solid.has(ck):
				_solid[ck] = []
			_solid[ck].append([xf, size * Vector3(s, 1.0, s)])
	var vis: float = info.range * rs
	var foliage := false
	for si in info.mesh.get_surface_count():
		if info.mesh.surface_get_material(si) is ShaderMaterial and (info.mesh.surface_get_material(si) as ShaderMaterial).shader.resource_path.ends_with("foliage.gdshader"):
			foliage = true
	for key in chunks:
		var arr: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = foliage   # the foliage shader takes its tint from COLOR
		mm.mesh = info.mesh
		mm.instance_count = arr.size()
		for j in arr.size():
			mm.set_instance_transform(j, arr[j][0])
			mm.set_instance_custom_data(j, arr[j][1])
			if foliage:
				var tc: Color = arr[j][1]
				mm.set_instance_color(j, Color(tc.r, tc.g, tc.b, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [model, key.x, key.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = vis + CHUNK * 0.5
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if _quality >= 2 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if info.shadow and (_quality >= 1 or info.range >= 200.0) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("tinted", tinted)
		add_child(mmi)
		_mmis.append(mmi)


func _tint(model: String, v: int, h: float) -> Color:
	var c := Color(1, 1, 1)
	if model.begins_with("car_"):
		c = CAR_PAINT[v % CAR_PAINT.size()]
	elif model == "shrub" or model == "shrub_wild":
		c = SHRUB_TINT[v % SHRUB_TINT.size()]   # these meshes are built white
	elif model in ["hedge", "fern", "planter", "planter_big"]:
		c = Color(0.88, 0.95, 0.85).lerp(Color(1.08, 1.0, 0.85), h)
	elif model == "bicycle":
		c = BIKE_PAINT[v % BIKE_PAINT.size()]
	elif model.begins_with("litter_"):
		c = LITTER_PAINT[v % LITTER_PAINT.size()]
	elif model == "dumpster":
		c = DUMPSTER_PAINT[v % DUMPSTER_PAINT.size()]
	elif model == "mailbox_post":
		c = MAILBOX_PAINT[v % MAILBOX_PAINT.size()]
	elif model == "trash_bag":
		c = [Color(0.06, 0.06, 0.06), Color(0.1, 0.16, 0.1), Color(0.75, 0.75, 0.72)][v % 3]
	c.a = h
	return c


static func _hash(x: float, z: float) -> float:
	var h := int(floor(x * 73.0)) * 73856093 ^ int(floor(z * 91.0)) * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0


# ------------------------------------------------------------------ utility poles + wires
func _build_poles(rs: float) -> void:
	var poles: Array = data.get("poles", [])
	if poles.is_empty():
		return
	if not meshes.has("pole"):
		var info := PropModels.build("pole")
		info.mesh = _with_lods(info.mesh)
		meshes["pole"] = info
	_place("pole", poles.map(func(p): return [p[0], p[1], p[2], p[3], 0]), meshes["pole"], 1.0, rs)
	# wires: 3 conductors on the crossarm + 1 lower comms line, catenary sag, thin tubes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var attach := [Vector3(-0.95, 9.86, 0), Vector3(0.0, 9.86, 0), Vector3(0.95, 9.86, 0), Vector3(0.0, 7.0, 0.2)]
	var by_chunk := {}
	for w in data.get("wires", []):
		var a: Array = poles[int(w[0])]
		var b: Array = poles[int(w[1])]
		var ta := Transform3D(Basis(Vector3.UP, float(a[3])), Vector3(a[0], a[1], a[2]))
		var tb := Transform3D(Basis(Vector3.UP, float(b[3])), Vector3(b[0], b[1], b[2]))
		var key := Vector2i(floori(float(a[0]) / 128.0), floori(float(a[2]) / 128.0))
		if not by_chunk.has(key):
			by_chunk[key] = []
		for k in attach.size():
			by_chunk[key].append([ta * attach[k], tb * attach[k], 0.012 if k < 3 else 0.018])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/shaders/prop.gdshader")
	mat.set_shader_parameter("instanced", false)
	mat.set_shader_parameter("grime", 0.0)
	for key in by_chunk:
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for span in by_chunk[key]:
			_wire(st, span[0], span[1], span[2])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 260.0 * rs
		add_child(mi)
		_mmis.append(mi)


static func _wire(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var seg := 10
	var L := a.distance_to(b)
	var sag := 0.012 * L + 0.25
	var pts := []
	for i in seg + 1:
		var t := float(i) / seg
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	for i in seg:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		for k in 3:
			var a0 := TAU * k / 3.0
			var a1 := TAU * (k + 1) / 3.0
			var o0 := (side * cos(a0) + Vector3.UP * sin(a0)) * r
			var o1 := (side * cos(a1) + Vector3.UP * sin(a1)) * r
			for v in [[p0, o0], [p1, o1], [p1, o0], [p0, o0], [p0, o1], [p1, o1]]:
				st.set_color(Color(0.08, 0.08, 0.08))
				st.set_uv(Vector2(0.45, 0.3))
				st.set_uv2(Vector2.ZERO)
				st.set_normal(v[1].normalized())
				st.add_vertex(v[0] + v[1])


# ------------------------------------------------------------------ café furniture
func _index_furniture() -> void:
	if not _furn.is_empty():
		return
	for e in data.get("furniture", []):
		var xf := Transform3D(Basis(Vector3.UP, float(e[4])), Vector3(e[1], e[2], e[3]))
		_furn.append([int(e[0]), xf])
		var key := Vector2i(floori(float(e[1]) / 32.0), floori(float(e[3]) / 32.0))
		if not _furn_cells.has(key):
			_furn_cells[key] = PackedInt32Array()
		_furn_cells[key].append(_furn.size() - 1)


func _process(d: float) -> void:
	_timer -= d
	if _timer > 0.0 or target == null:
		return
	_timer = 0.4
	var p := target.global_position
	_stream_colliders(p)
	_stream_furniture(p)


func _stream_colliders(p: Vector3) -> void:
	var c := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
	var reach := int(ceil(COLLIDE_RADIUS / 16.0))
	for k in _bodies.keys():
		if absi(k.x - c.x) > reach + 1 or absi(k.y - c.y) > reach + 1:
			_bodies[k].queue_free()
			_bodies.erase(k)
	for x in range(c.x - reach, c.x + reach + 1):
		for z in range(c.y - reach, c.y + reach + 1):
			var k := Vector2i(x, z)
			if _bodies.has(k) or not _solid.has(k):
				continue
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			for e in _solid[k]:
				var xf: Transform3D = e[0]
				var size: Vector3 = e[1]
				var shape := CollisionShape3D.new()
				shape.shape = _box(size)
				shape.transform = Transform3D(xf.basis.orthonormalized(), xf.origin + Vector3(0, size.y * 0.5, 0))
				body.add_child(shape)
			add_child(body)
			_bodies[k] = body


func _box(size: Vector3) -> BoxShape3D:
	var key := Vector3i(roundi(size.x * 100), roundi(size.y * 100), roundi(size.z * 100))
	if not _box_shapes.has(key):
		var b := BoxShape3D.new()
		b.size = size
		_box_shapes[key] = b
	return _box_shapes[key]


func _stream_furniture(p: Vector3) -> void:
	if _furn.is_empty() or get_node_or_null("/root/Furniture") == null:
		return
	var want := {}
	var c := Vector2i(floori(p.x / 32.0), floori(p.z / 32.0))
	for x in range(c.x - 2, c.x + 3):
		for z in range(c.y - 2, c.y + 3):
			for i in _furn_cells.get(Vector2i(x, z), PackedInt32Array()):
				var xf: Transform3D = _furn[i][1]
				if xf.origin.distance_squared_to(p) < FURNITURE_RADIUS * FURNITURE_RADIUS:
					want[i] = true
	for i in _furn_live.keys():
		if not want.has(i):
			if is_instance_valid(_furn_live[i]):
				_furn_live[i].queue_free()
			_furn_live.erase(i)
	var furniture := get_node("/root/Furniture")
	for i in want:
		if _furn_live.has(i):
			continue
		var piece = furniture.spawn_piece(_furn[i][0], _furn[i][1], self, "")
		if piece:
			_furn_live[i] = piece


## Visible prop instances (for tests / the perf HUD).
func instance_count() -> int:
	var n := 0
	for m in _mmis:
		if m is MultiMeshInstance3D:
			n += m.multimesh.instance_count
	return n
