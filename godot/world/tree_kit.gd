class_name TreeKit
## Unit-height tree meshes for MultiMesh instancing (height 1 at scale 1; instances scale uniformly
## by the species height). Broadleaf crowns are clustered lumps; loblolly pines are stacked cones.
## Leaf colors come from the city palette per species (CLAUDE.md §4.6).

## Cheap far version (about 20 triangles): one crown shape + trunk.
static func make_far(pine: bool, leaf: Color, bark: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(st, Vector3.ZERO, 0.03, 0.02, 0.45, bark, 3)
	if pine:
		_cone(st, Vector3(0, 0.35, 0), 0.16, 0.65, leaf, 5)
	else:
		_cone(st, Vector3(0, 0.62, 0), 0.3, 0.3, leaf, 6)
		_cone(st, Vector3(0, 0.62, 0), 0.3, -0.3, leaf.darkened(0.2), 6)
	return _finish(st)


static func make(pine: bool, leaf: Color, bark: Color, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var trunk_top := 0.55 if pine else 0.4
	_cyl(st, Vector3.ZERO, 0.022 if pine else 0.03, 0.012, trunk_top + 0.25, bark, 7)
	if pine:
		var tiers := 5
		for i in tiers:
			var t := float(i) / tiers
			var y0 := lerpf(0.38, 0.88, t)
			var r := lerpf(0.17, 0.06, t)
			_cone(st, Vector3(0, y0, 0), r, 0.2, leaf.darkened(0.08 * (tiers - i) / tiers), 9)
	else:
		var lumps := [Vector3(0, 0.68, 0), Vector3(0.14, 0.6, 0.05), Vector3(-0.13, 0.62, -0.06),
			Vector3(0.03, 0.62, 0.15), Vector3(-0.04, 0.6, -0.15), Vector3(0.02, 0.84, 0.0)]
		for i in lumps.size():
			var c: Vector3 = lumps[i] + Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
			var r := 0.2 if i == 0 else rng.randf_range(0.14, 0.18)
			var col := leaf.lightened(rng.randf_range(0.0, 0.12)) if i % 2 == 0 else leaf.darkened(rng.randf_range(0.0, 0.12))
			_blob(st, c, Vector3(r, r * 0.8, r), col)
	return _finish(st)


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	return mesh


static func _v(st: SurfaceTool, p: Vector3, c: Color) -> void:
	st.set_color(c)
	st.add_vertex(p)


static func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, c: Color, seg: int) -> void:
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_v(st, p00, c); _v(st, p10, c); _v(st, p11, c)
		_v(st, p00, c); _v(st, p11, c); _v(st, p01, c)


static func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, c: Color, seg: int) -> void:
	var top := base + Vector3(0, h, 0)
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		_v(st, p0, c.darkened(0.1)); _v(st, top, c); _v(st, p1, c.darkened(0.1))
		_v(st, p0, c.darkened(0.3)); _v(st, p1, c.darkened(0.3)); _v(st, base, c.darkened(0.3))


## Low-poly ellipsoid (icosphere level 1 feel via lat/long 6x8).
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	var lat := 4
	var lon := 7
	for i in lat:
		var t0 := PI * i / lat
		var t1 := PI * (i + 1) / lat
		for j in lon:
			var p0 := TAU * j / lon
			var p1 := TAU * (j + 1) / lon
			var a := c + Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)) * r
			var b := c + Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)) * r
			var d := c + Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)) * r
			var e := c + Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)) * r
			var shade := col.darkened(0.25 * float(i) / lat)
			_v(st, a, shade); _v(st, b, shade); _v(st, e, shade)
			_v(st, a, shade); _v(st, e, shade); _v(st, d, shade)
