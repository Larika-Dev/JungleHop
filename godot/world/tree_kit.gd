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


static var _solid_mat: ShaderMaterial
static var _leaf_mat: ShaderMaterial
static var _needle_mat: ShaderMaterial


static func _mat(cards: bool, needles: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/shaders/foliage.gdshader")
	m.set_shader_parameter("cards", cards)
	m.set_shader_parameter("needles", needles)
	return m


## Near version: the solid crown volume plus alpha-cut leaf / needle cards scattered over it.
## cards_per_lump scales with the foliage quality (0 = no cards).
static func make(pine: bool, leaf: Color, bark: Color, seed: int, cards_per_lump: int = 34) -> ArrayMesh:
	var mesh := make_solid(pine, leaf, bark, seed)
	if cards_per_lump <= 0:
		return mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	if pine:
		for i in 5:
			var t := float(i) / 5
			var y0 := lerpf(0.38, 0.88, t)
			var r := lerpf(0.17, 0.06, t)
			for k in int(cards_per_lump * lerpf(1.0, 0.5, t)):
				var a := rng.randf() * TAU
				var rr := r * sqrt(rng.randf_range(0.35, 1.0))
				var y := y0 + 0.2 * (1.0 - rr / r) * rng.randf_range(0.6, 1.0)
				var c := Vector3(cos(a) * rr, y, sin(a) * rr)
				var out := Vector3(cos(a), 0.35, sin(a)).normalized()
				_card(st, c, out, 0.09, leaf.darkened(rng.randf_range(0.0, 0.2)), rng, out)
	else:
		var lumps := [Vector3(0, 0.68, 0), Vector3(0.14, 0.6, 0.05), Vector3(-0.13, 0.62, -0.06),
			Vector3(0.03, 0.62, 0.15), Vector3(-0.04, 0.6, -0.15), Vector3(0.02, 0.84, 0.0)]
		var center := Vector3(0, 0.66, 0)
		for i in lumps.size():
			var lc: Vector3 = lumps[i]
			var r := 0.2 if i == 0 else 0.16
			for k in cards_per_lump:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 1), rng.randf_range(-1, 1)).normalized()
				var c := lc + d * Vector3(r, r * 0.8, r) * rng.randf_range(0.72, 1.05)
				var out := (c - center).normalized()
				var col := leaf.lightened(rng.randf_range(0.0, 0.15)) if rng.randf() < 0.5 else leaf.darkened(rng.randf_range(0.0, 0.15))
				_card(st, c, d, rng.randf_range(0.11, 0.15), col, rng, out)
	st.commit(mesh)
	if pine:
		if _needle_mat == null:
			_needle_mat = _mat(true, true)
		mesh.surface_set_material(1, _needle_mat)
	else:
		if _leaf_mat == null:
			_leaf_mat = _mat(true, false)
		mesh.surface_set_material(1, _leaf_mat)
	return mesh


## One leaf card: a quad centred at c facing roughly along d, with a crown-outward normal
## (so the cluster shades like a soft volume rather than flat planes).
static func _card(st: SurfaceTool, c: Vector3, d: Vector3, size: float, col: Color, rng: RandomNumberGenerator, n: Vector3) -> void:
	var f := (d + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
	var up := Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT
	var a := f.cross(up).normalized() * size * 0.5
	var b := f.cross(a).normalized() * size * 0.5
	var p := [c - a - b, c + a - b, c + a + b, c - a + b]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uv[idx])
		st.add_vertex(p[idx])


static func make_solid(pine: bool, leaf: Color, bark: Color, seed: int) -> ArrayMesh:
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
			if i > 0:
				_limb(st, Vector3(0, trunk_top + 0.05, 0), lumps[i] * Vector3(0.8, 1.0, 0.8), 0.016, 0.006, bark, 5)
		for i in lumps.size():
			var c: Vector3 = lumps[i] + Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
			var r := 0.2 if i == 0 else rng.randf_range(0.14, 0.18)
			var col := leaf.lightened(rng.randf_range(0.0, 0.12)) if i % 2 == 0 else leaf.darkened(rng.randf_range(0.0, 0.12))
			_blob(st, c, Vector3(r, r * 0.8, r), col)
	return _finish(st)


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit()
	if _solid_mat == null:
		_solid_mat = _mat(false, false)
	mesh.surface_set_material(0, _solid_mat)
	return mesh


static var _crown := false

static func _v(st: SurfaceTool, p: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_uv(Vector2(1.0 if _crown else 0.0, 0.0))
	st.add_vertex(p)


static func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, c: Color, seg: int) -> void:
	_crown = false
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_v(st, p00, c); _v(st, p10, c); _v(st, p11, c)
		_v(st, p00, c); _v(st, p11, c); _v(st, p01, c)


## A tapered limb from a to b (bark).
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c: Color, seg: int) -> void:
	_crown = false
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var side2 := axis.cross(side)
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var d0 := side * cos(a0) + side2 * sin(a0)
		var d1 := side * cos(a1) + side2 * sin(a1)
		var p00 := a + d0 * r0
		var p01 := a + d1 * r0
		var p10 := b + d0 * r1
		var p11 := b + d1 * r1
		_v(st, p00, c); _v(st, p10, c); _v(st, p11, c)
		_v(st, p00, c); _v(st, p11, c); _v(st, p01, c)


static func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, c: Color, seg: int) -> void:
	_crown = true
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
	_crown = true
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
