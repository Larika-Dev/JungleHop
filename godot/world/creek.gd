class_name Creek
extends MeshInstance3D
## Battle Ravine creek (CLAUDE.md §8, centerline from docs/phase-1/concept-layout.json):
## a water ribbon following the creek bed, 30 cm above the ground under it.

const CENTERLINE := [Vector2(580, 160), Vector2(560, 300), Vector2(540, 450), Vector2(505, 600), Vector2(490, 770)]
const HALF_W := 4.0
const STEP := 4.0


## height_at(x, z) -> ground height; built once physics has the terrain.
func build(height_at: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var along: Array[float] = []
	var acc := 0.0
	for i in CENTERLINE.size() - 1:
		var a: Vector2 = CENTERLINE[i]
		var b: Vector2 = CENTERLINE[i + 1]
		var n := int(ceil(a.distance_to(b) / STEP))
		for s in n:
			var p := a.lerp(b, float(s) / n)
			pts.append(Vector3(p.x, 0, p.y))
			along.append(acc + a.distance_to(p))
		acc += a.distance_to(b)
	var last: Vector2 = CENTERLINE[-1]
	pts.append(Vector3(last.x, 0, last.y))
	along.append(acc)
	# water level: the lowest ground across the bed, smoothed so it only flows downhill
	var levels: Array[float] = []
	for p in pts:
		var lo := INF
		for o in [-2.0, 0.0, 2.0]:
			var gh: float = height_at.call(p.x + o, p.z)
			if gh > -60.0:
				lo = minf(lo, gh)
		if lo == INF:
			lo = -18.0
		levels.append(lo + 0.3)
	for i in range(1, levels.size()):
		levels[i] = minf(levels[i], levels[i - 1] + 0.05)
	var prev_l := PackedVector3Array()
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var c := Vector3(pts[i].x, levels[i], pts[i].z)
		var l := c - side * HALF_W
		var r := c + side * HALF_W
		if i > 0:
			var v := [prev_l[0], prev_l[1], r, l]
			var uv := [Vector2(0, along[i - 1] / 8.0), Vector2(1, along[i - 1] / 8.0), Vector2(1, along[i] / 8.0), Vector2(0, along[i] / 8.0)]
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(uv[j])
				st.add_vertex(v[j])
		prev_l = PackedVector3Array([l, r])
	mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://world/shaders/water.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
