class_name StreetLights
extends Node3D
## Street lamps (CLAUDE.md §13): acorn lamps on the sidewalks, placed from the
## sidewalk triangles of the road mesh (about every 18 m). Posts and heads are one MultiMesh; real OmniLights are
## kept only for the lamps nearest the camera (pooled), switched on at dusk.

const CELL := 18.0
const POOL := 32
const LIGHT_RANGE := 20.0

var target: Node3D
var positions: PackedVector3Array = PackedVector3Array()
var _pool: Array[OmniLight3D] = []
var _head_mat: StandardMaterial3D
var _timer := 0.0


func setup(road_mesh: MeshInstance3D) -> void:
	var a := road_mesh.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var idx = a[Mesh.ARRAY_INDEX]
	var n: int = idx.size() if idx != null else v.size()
	var xf := road_mesh.global_transform
	var cells := {}
	for t in range(0, n, 3):
		var i0: int = idx[t] if idx != null else t
		var col := c[i0]
		# sidewalks: concrete or brick pavers (not asphalt, not markings)
		var paver := col.r > col.g * 2.2 and col.r > 0.15
		var concrete := absf(col.r - col.g) < 0.06 and col.r > 0.25 and col.r < 0.6
		if not (paver or concrete):
			continue
		var p := xf * ((v[i0] + v[idx[t + 1] if idx != null else t + 1] + v[idx[t + 2] if idx != null else t + 2]) / 3.0)
		if absf(p.x) > 900.0 or absf(p.z) > 800.0:
			continue
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not cells.has(key):
			cells[key] = p
	for key in cells:
		var p: Vector3 = cells[key]
		if not _in_building(p):
			positions.append(p)
	_build_meshes()
	for i in POOL:
		var l := OmniLight3D.new()
		l.light_color = CityData.color("LAMP_SODIUM", Color(1.0, 0.72, 0.4))
		l.light_energy = 2.2
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 1.2
		l.light_volumetric_fog_energy = 2.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)


func _in_building(p: Vector3) -> bool:
	for id in CityData.buildings_near(p, 60.0):
		var fp: Array = CityData.building(id).get("footprintCm", [0, 0])
		var l := CityData.building_transform(id).affine_inverse() * p
		if l.x > -0.5 and l.z > -0.5 and l.x < fp[0] / 100.0 + 0.5 and l.z < fp[1] / 100.0 + 0.5:
			return true
	return false


func _build_meshes() -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.09
	post.height = 3.9
	post.radial_segments = 10
	var iron := StandardMaterial3D.new()
	iron.albedo_color = CityData.color("IRON_BLACK", Color(0.1, 0.1, 0.1))
	iron.metallic = 0.6
	iron.roughness = 0.45
	post.material = iron
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.5
	head.radial_segments = 12
	head.rings = 6
	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = Color(0.95, 0.93, 0.88)
	_head_mat.roughness = 0.2
	_head_mat.emission_enabled = true
	_head_mat.emission = CityData.color("LAMP_SODIUM", Color(1.0, 0.72, 0.4))
	_head_mat.emission_energy_multiplier = 0.0
	head.material = _head_mat
	for part in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = post if part == 0 else head
		mm.instance_count = positions.size()
		for i in positions.size():
			var y := 1.95 if part == 0 else 4.15
			mm.set_instance_transform(i, Transform3D(Basis(), positions[i] + Vector3(0, y, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "LampPosts" if part == 0 else "LampHeads"
		if part == 1:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _process(d: float) -> void:
	_timer -= d
	if _timer > 0.0 or target == null:
		return
	_timer = 0.5
	var h := GameClock.hour_f
	var on := h >= 19.0 or h < 6.8
	_head_mat.emission_energy_multiplier = 6.0 if on else 0.0
	if not on:
		for l in _pool:
			l.visible = false
		return
	# nearest lamps get the real lights
	var p := target.global_position
	var near: Array = []
	for q in positions:
		var dd := q.distance_squared_to(p)
		if dd < 160.0 * 160.0:
			near.append([dd, q])
	near.sort_custom(func(x, y): return x[0] < y[0])
	for i in _pool.size():
		if i < near.size():
			_pool[i].position = near[i][1] + Vector3(0, 4.0, 0)
			_pool[i].visible = true
		else:
			_pool[i].visible = false
