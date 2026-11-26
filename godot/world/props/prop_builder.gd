class_name PropBuilder
extends RefCounted
## Code-built prop geometry (CLAUDE.md §13: street furniture is real geometry at cm dimensions).
## Everything is written into a few layers so one prop is 1-3 draw calls:
##   "solid"  - opaque, drawn with prop.gdshader: vertex color = sRGB palette color,
##              UV = (roughness, metallic), UV2 = (tint mask 0..1, emission)
##   "glass"  - transparent glazing (car windows, shelter panels)
##   "leaf"   - foliage volume (foliage.gdshader, solid), "card" - alpha-cut leaf cards
## Coordinates are meters, Y up, model origin at the base center; a transform stack (push/pop,
## translate, rotate_y/x/z, scale) works like the three.js GeoBuilder used by the web city.

const LAYERS := ["solid", "glass", "leaf", "card"]

var _v := {}     # layer -> PackedVector3Array
var _n := {}
var _c := {}
var _uv := {}
var _uv2 := {}
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var rough := 0.6
var metal := 0.0
var tint := 0.0
var glow := 0.0
var layer := "solid"
var color := Color.WHITE


func _init() -> void:
	for l in LAYERS:
		_v[l] = PackedVector3Array(); _n[l] = PackedVector3Array(); _c[l] = PackedColorArray()
		_uv[l] = PackedVector2Array(); _uv2[l] = PackedVector2Array()


# ------------------------------------------------------------------ state
## Material presets: paint (matte), satin, gloss, metal, chrome, rubber, wood, glow, plastic.
func mat(kind: String, col: Color, tinted := false) -> PropBuilder:
	color = col
	tint = 1.0 if tinted else 0.0
	glow = 0.0
	layer = "solid"
	match kind:
		"paint": rough = 0.78; metal = 0.0
		"satin": rough = 0.5; metal = 0.25
		"gloss": rough = 0.28; metal = 0.0
		"car": rough = 0.22; metal = 0.35
		"metal": rough = 0.38; metal = 0.85
		"chrome": rough = 0.12; metal = 1.0
		"rubber": rough = 0.88; metal = 0.0
		"plastic": rough = 0.55; metal = 0.0
		"wood": rough = 0.85; metal = 0.0
		"stone": rough = 0.92; metal = 0.0
		"glow": rough = 0.3; metal = 0.0; glow = 1.0
		"glass": rough = 0.05; metal = 0.0; layer = "glass"
		"leaf": rough = 0.8; metal = 0.0; layer = "leaf"
		"card": rough = 0.6; metal = 0.0; layer = "card"
	return self


func push() -> void:
	_stack.append(_xf)


func pop() -> void:
	_xf = _stack.pop_back()


func translate(x: float, y: float, z: float) -> void:
	_xf = _xf * Transform3D(Basis(), Vector3(x, y, z))


func rotate_y(a: float) -> void:
	_xf = _xf * Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)


func rotate_x(a: float) -> void:
	_xf = _xf * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)


func rotate_z(a: float) -> void:
	_xf = _xf * Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO)


func scale(x: float, y: float, z: float) -> void:
	_xf = _xf * Transform3D(Basis().scaled(Vector3(x, y, z)), Vector3.ZERO)


# ------------------------------------------------------------------ primitives
func tri(a: Vector3, b: Vector3, c: Vector3, col := Color(-1, 0, 0)) -> void:
	var wa := _xf * a
	var wb := _xf * b
	var wc := _xf * c
	var n := (wc - wa).cross(wb - wa)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	_put(wa, n, col); _put(wb, n, col); _put(wc, n, col)


## Triangle with explicit (model-space) normals for smooth shading.
func tri_n(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var bs := _xf.basis.inverse().transposed()
	_put(_xf * a, (bs * na).normalized(), Color(-1, 0, 0))
	_put(_xf * b, (bs * nb).normalized(), Color(-1, 0, 0))
	_put(_xf * c, (bs * nc).normalized(), Color(-1, 0, 0))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(a, b, c); tri(a, c, d)


func _put(p: Vector3, n: Vector3, col: Color) -> void:
	_v[layer].append(p)
	_n[layer].append(n)
	_c[layer].append(color if col.r < 0.0 else col)
	_uv[layer].append(Vector2(rough, metal))
	_uv2[layer].append(Vector2(tint, glow))


## Axis-aligned box from (x0,y0,z0) to (x1,y1,z1) in the current frame.
func box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, bottom := true) -> void:
	var p := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1),
		Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]
	quad(p[4], p[5], p[6], p[7])            # top (+y)
	if bottom:
		quad(p[3], p[2], p[1], p[0])
	quad(p[0], p[1], p[5], p[4])            # -z
	quad(p[2], p[3], p[7], p[6])            # +z
	quad(p[3], p[0], p[4], p[7])            # -x
	quad(p[1], p[2], p[6], p[5])            # +x


## Box centered on x/z: half sizes hx, hz, from y0 to y1.
func boxc(cx: float, cz: float, hx: float, hz: float, y0: float, y1: float) -> void:
	box(cx - hx, y0, cz - hz, cx + hx, y1, cz + hz)


## Box with chamfered vertical edges (rounded look for bins, cabinets, car bodies).
func cbox(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, ch: float) -> void:
	var pts := [Vector2(x0 + ch, z0), Vector2(x1 - ch, z0), Vector2(x1, z0 + ch), Vector2(x1, z1 - ch),
		Vector2(x1 - ch, z1), Vector2(x0 + ch, z1), Vector2(x0, z1 - ch), Vector2(x0, z0 + ch)]
	prism(pts, y0, y1)


## Vertical prism from a convex polygon in xz (counter-clockwise seen from above is not required).
func prism(pts: Array, y0: float, y1: float, caps := true) -> void:
	var n := pts.size()
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= n
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		_wall(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), Vector3(c.x, (y0 + y1) * 0.5, c.y))
		if caps:
			_face_out(Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3.UP)
			_face_out(Vector3(c.x, y0, c.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y), Vector3.DOWN)


## Quad oriented so its normal points away from `center`.
func _wall(a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot((a + c) * 0.5 - center) < 0.0:
		quad(a, b, c, d)
	else:
		quad(d, c, b, a)


func _face_out(a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot(want) >= 0.0:
		tri(a, b, c)
	else:
		tri(a, c, b)


## Vertical cylinder (radius r, y0..y1) at (cx, cz).
func cyl(r: float, y0: float, y1: float, seg := 12, caps := true, cx := 0.0, cz := 0.0, r_top := -1.0) -> void:
	var rt := r if r_top < 0.0 else r_top
	lathe([Vector2(r, y0), Vector2(rt, y1)], seg, caps, cx, cz)


## Surface of revolution around the Y axis from (radius, y) profile points, smooth shaded.
func lathe(profile: Array, seg := 12, caps := true, cx := 0.0, cz := 0.0) -> void:
	var m := profile.size()
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for i in m - 1:
			var p: Vector2 = profile[i]
			var q: Vector2 = profile[i + 1]
			var o := Vector3(cx, 0, cz)
			var v00 := o + d0 * p.x + Vector3(0, p.y, 0)
			var v01 := o + d1 * p.x + Vector3(0, p.y, 0)
			var v10 := o + d0 * q.x + Vector3(0, q.y, 0)
			var v11 := o + d1 * q.x + Vector3(0, q.y, 0)
			var slope := Vector2(q.x - p.x, q.y - p.y)
			var ny := -slope.x / maxf(slope.length(), 1e-6)
			var nr := slope.y / maxf(slope.length(), 1e-6)
			var n0 := (d0 * nr + Vector3(0, ny, 0)).normalized()
			var n1 := (d1 * nr + Vector3(0, ny, 0)).normalized()
			if p.x < 1e-5 and q.x < 1e-5:
				continue
			tri_n(v00, v11, v10, n0, n1, n0)
			tri_n(v00, v01, v11, n0, n1, n1)
		if caps:
			var f: Vector2 = profile[0]
			var l: Vector2 = profile[m - 1]
			var o := Vector3(cx, 0, cz)
			if f.x > 1e-4:
				tri(o + Vector3(0, f.y, 0), o + d1 * f.x + Vector3(0, f.y, 0), o + d0 * f.x + Vector3(0, f.y, 0))
			if l.x > 1e-4:
				tri(o + Vector3(0, l.y, 0), o + d0 * l.x + Vector3(0, l.y, 0), o + d1 * l.x + Vector3(0, l.y, 0))


## Round bar from a to b (radius r).
func bar(a: Vector3, b: Vector3, r: float, seg := 8, caps := false) -> void:
	var axis := b - a
	var L := axis.length()
	if L < 1e-5:
		return
	push()
	var y := axis / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_xf = _xf * Transform3D(Basis(x, y, z), a)
	cyl(r, 0.0, L, seg, caps)
	pop()


## Torus in the local YZ plane (a wheel rolling along z), centered at c.
func ring(c: Vector3, R: float, r: float, seg := 18, tube := 6) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for j in tube:
			var b0 := TAU * j / tube
			var b1 := TAU * (j + 1) / tube
			var p := func(a: float, b: float) -> Vector3:
				var dir := Vector3(0, cos(a), sin(a))
				return c + dir * (R + r * cos(b)) + Vector3(r * sin(b), 0, 0)
			var nn := func(a: float, b: float) -> Vector3:
				var dir := Vector3(0, cos(a), sin(a))
				return (dir * cos(b) + Vector3(sin(b), 0, 0)).normalized()
			tri_n(p.call(a0, b0), p.call(a1, b1), p.call(a1, b0), nn.call(a0, b0), nn.call(a1, b1), nn.call(a1, b0))
			tri_n(p.call(a0, b0), p.call(a0, b1), p.call(a1, b1), nn.call(a0, b0), nn.call(a0, b1), nn.call(a1, b1))


## Flat disc lying in xz at height y.
func disc(r: float, y: float, seg := 16, cx := 0.0, cz := 0.0) -> void:
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		tri(Vector3(cx, y, cz), Vector3(cx + cos(a0) * r, y, cz + sin(a0) * r), Vector3(cx + cos(a1) * r, y, cz + sin(a1) * r))


## Lumpy ellipsoid (trash bags, rocks, shrub volumes). Smooth normals, deterministic jitter.
func blob(c: Vector3, r: Vector3, jitter := 0.15, seed := 1, lat := 5, lon := 8) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var k := {}
	var pt := func(i: int, j: int) -> Vector3:
		var key := Vector2i(i, j % lon)
		if not k.has(key):
			var t := PI * i / lat
			var ph := TAU * (j % lon) / lon
			var dir := Vector3(sin(t) * cos(ph), cos(t), sin(t) * sin(ph))
			var amt := 1.0 + (rng.randf_range(-jitter, jitter) if i > 0 and i < lat else 0.0)
			k[key] = dir * amt
		return k[key]
	for i in lat:
		for j in lon:
			var a: Vector3 = pt.call(i, j)
			var b: Vector3 = pt.call(i, j + 1)
			var d: Vector3 = pt.call(i + 1, j)
			var e: Vector3 = pt.call(i + 1, j + 1)
			tri_n(c + a * r, c + e * r, c + b * r, a, e, b)
			tri_n(c + a * r, c + d * r, c + e * r, a, d, e)


## Alpha-cut leaf card (layer "card"): quad at c facing f, normal n (crown-outward).
func card(c: Vector3, f: Vector3, size: float, n: Vector3, col: Color) -> void:
	var up := Vector3.UP if absf(f.normalized().y) < 0.9 else Vector3.RIGHT
	var a := f.cross(up).normalized() * size * 0.5
	var b := f.cross(a).normalized() * size * 0.5
	var p := [c - a - b, c + a - b, c + a + b, c - a + b]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var nn := (_xf.basis * n).normalized()
	for idx in [0, 1, 2, 0, 2, 3]:
		_v["card"].append(_xf * p[idx])
		_n["card"].append(nn)
		_c["card"].append(col)
		_uv["card"].append(uv[idx])
		_uv2["card"].append(Vector2.ZERO)


## Loft through cross sections: stations = [[z, [Vector2(x, y), ...]], ...] (same point count, a
## closed loop each, counter-clockwise in x-right / y-up). Ends are capped with fans. Used for car bodies and glasshouses.
func loft(stations: Array, cap_ends := true) -> void:
	var m: int = stations[0][1].size()
	for s in stations.size() - 1:
		var za: float = stations[s][0]
		var zb: float = stations[s + 1][0]
		var A: Array = stations[s][1]
		var B: Array = stations[s + 1][1]
		for i in m:
			var j := (i + 1) % m
			var a0 := Vector3(A[i].x, A[i].y, za)
			var a1 := Vector3(A[j].x, A[j].y, za)
			var b0 := Vector3(B[i].x, B[i].y, zb)
			var b1 := Vector3(B[j].x, B[j].y, zb)
			tri(a0, b0, b1); tri(a0, b1, a1)
	if cap_ends:
		for e in [0, stations.size() - 1]:
			var z: float = stations[e][0]
			var S: Array = stations[e][1]
			var c := Vector2.ZERO
			for p in S:
				c += p
			c /= m
			for i in m:
				var j := (i + 1) % m
				if e == 0:
					tri(Vector3(c.x, c.y, z), Vector3(S[i].x, S[i].y, z), Vector3(S[j].x, S[j].y, z))
				else:
					tri(Vector3(c.x, c.y, z), Vector3(S[j].x, S[j].y, z), Vector3(S[i].x, S[i].y, z))


# ------------------------------------------------------------------ output
## The finished mesh: one surface per non-empty layer, in LAYERS order. `materials` maps
## layer -> Material. Returns null when nothing was built.
func commit(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for l in LAYERS:
		var v: PackedVector3Array = _v[l]
		if v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = _n[l]
		arr[Mesh.ARRAY_COLOR] = _c[l]
		arr[Mesh.ARRAY_TEX_UV] = _uv[l]
		arr[Mesh.ARRAY_TEX_UV2] = _uv2[l]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials.get(l))
	return mesh if mesh.get_surface_count() > 0 else null


func vertex_count() -> int:
	var n := 0
	for l in LAYERS:
		n += _v[l].size()
	return n
