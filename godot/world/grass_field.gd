class_name GrassField
extends Node3D
## Real 3D grass (CLAUDE.md §8: instanced blades near the camera). Lawn triangles of the terrain
## (GRASS_OCT-colored vertices) are bucketed into 16 m chunks once; chunks around the camera are
## filled with blade clumps (MultiMesh), one chunk per frame, and dropped when far away.
## Density and radius come from Settings.grass_density (0 = off).

const CHUNK := 16.0
const MAX_RADIUS := 44.0

var target: Node3D
var _tris := {}          # Vector2i -> PackedVector3Array (3 verts per lawn triangle)
var _colors := {}        # Vector2i -> PackedColorArray (1 per triangle)
var _live := {}          # Vector2i -> MultiMeshInstance3D
var _clump: ArrayMesh
var _mat: ShaderMaterial
var _density := -1.0
var _radius := 0.0
var _holes: Array = []   # [Transform3D inverse, Vector2 size] of buildings near the camera
var _last_center := Vector2i(999999, 999999)


func setup(terrain_meshes: Array) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://world/shaders/grass.gdshader")
	_clump = _make_clump()
	_clump.surface_set_material(0, _mat)
	for m in terrain_meshes:
		var mi := m as MeshInstance3D
		var xf := mi.global_transform
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := idx.size() if idx.size() > 0 else v.size()
		for t in range(0, n, 3):
			var i0 := idx[t] if idx.size() > 0 else t
			var i1 := idx[t + 1] if idx.size() > 0 else t + 1
			var i2 := idx[t + 2] if idx.size() > 0 else t + 2
			if not (_is_lawn(c[i0]) and _is_lawn(c[i1]) and _is_lawn(c[i2])):
				continue
			var p0 := xf * v[i0]
			var p1 := xf * v[i1]
			var p2 := xf * v[i2]
			var cen := (p0 + p1 + p2) / 3.0
			var key := Vector2i(floori(cen.x / CHUNK), floori(cen.z / CHUNK))
			if not _tris.has(key):
				_tris[key] = PackedVector3Array()
				_colors[key] = PackedColorArray()
			_tris[key].append_array([p0, p1, p2])
			_colors[key].append((c[i0] + c[i1] + c[i2]) / 3.0)


static func _is_lawn(c: Color) -> bool:
	return c.g > c.r * 1.15 and c.g > c.b * 1.6


func _process(_d: float) -> void:
	if target == null or _tris.is_empty():
		return
	var dens := Settings.grass_density
	if not is_equal_approx(dens, _density):
		_density = dens
		_radius = lerpf(18.0, MAX_RADIUS, clampf(dens, 0.0, 1.0))
		_mat.set_shader_parameter("fade_end", _radius - 2.0)
		for k in _live:
			_live[k].queue_free()
		_live.clear()
		_last_center = Vector2i(999999, 999999)
	if _density <= 0.01:
		return
	var p := target.global_position
	var center := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	var reach := int(ceil(_radius / CHUNK))
	if center != _last_center:
		_last_center = center
		_refresh_holes(p)
		for k in _live.keys():
			if absi(k.x - center.x) > reach + 1 or absi(k.y - center.y) > reach + 1:
				_live[k].queue_free()
				_live.erase(k)
	# build the nearest missing chunk
	var best := Vector2i.ZERO
	var best_d := INF
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var k := center + Vector2i(dx, dz)
			if _live.has(k) or not _tris.has(k):
				continue
			var cc := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
			var d := cc.distance_to(Vector2(p.x, p.z))
			if d < _radius + CHUNK * 0.7 and d < best_d:
				best_d = d
				best = k
	if best_d < INF:
		_build(best)


func _refresh_holes(p: Vector3) -> void:
	_holes.clear()
	for id in CityData.buildings_near(p, MAX_RADIUS + 80.0):
		var bd := CityData.building(id)
		var fp: Array = bd.get("footprintCm", [0, 0])
		_holes.append([CityData.building_transform(id).affine_inverse(), Vector2(fp[0] / 100.0, fp[1] / 100.0)])


func _in_building(q: Vector3) -> bool:
	for h in _holes:
		var l: Vector3 = h[0] * q
		var s: Vector2 = h[1]
		if l.x > -0.3 and l.z > -0.3 and l.x < s.x + 0.3 and l.z < s.y + 0.3:
			return true
	return false


func _build(k: Vector2i) -> void:
	var tris: PackedVector3Array = _tris[k]
	var cols: PackedColorArray = _colors[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var per_m2 := lerpf(1.2, 4.5, clampf(_density, 0.0, 1.0))
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	for t in range(0, tris.size(), 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var area := (b - a).cross(c - a).length() * 0.5
		var count := int(area * per_m2 + rng.randf())
		for i in count:
			var r1 := sqrt(rng.randf())
			var r2 := rng.randf()
			var q := a * (1.0 - r1) + b * (r1 * (1.0 - r2)) + c * (r1 * r2)
			if _in_building(q):
				continue
			var s := rng.randf_range(0.7, 1.25)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			xs.append(Transform3D(basis, q))
			var col: Color = cols[t / 3]
			cs.append(Color(col.r, col.g, col.b, rng.randf()))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _clump
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "Grass_%d_%d" % [k.x, k.y]
	add_child(mmi)
	_live[k] = mmi


## A clump of 7 curved, tapered blades (about 12-22 cm tall), 3 segments each.
func _make_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1795
	for b in 7:
		var ang := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		var h := rng.randf_range(0.12, 0.22)
		var w := rng.randf_range(0.008, 0.013)
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.03, 0.08)
		var side := Vector3(-sin(ang), 0, cos(ang))
		var pts: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for s in 4:
			var t := s / 3.0
			var center := off + Vector3(0, h * t, 0) + lean * t * t
			var ww := w * (1.0 - t * 0.92)
			pts.append(center - side * ww)
			pts.append(center + side * ww)
			uvs.append(Vector2(0, t))
			uvs.append(Vector2(1, t))
		var nrm := side.cross(Vector3.UP).normalized()
		for s in 3:
			var i := s * 2
			for j in [i, i + 1, i + 3, i, i + 3, i + 2]:
				st.set_uv(uvs[j])
				st.set_normal((nrm + Vector3.UP * 0.6).normalized())
				st.add_vertex(pts[j])
	return st.commit()
