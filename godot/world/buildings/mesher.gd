class_name Mesher
extends RefCounted
## Fast indexed mesh builder for procedural building exteriors (plain packed arrays, so it can
## run on a worker thread). Geometry goes into named surfaces "<group>:<material>"; the
## BuildingStreamer turns each group into one MeshInstance3D (main / fine / glass / door / far).
##
## Vertex data read by world/shaders/facade.gdshader:
##   COLOR.rgb  linear base color (palette), COLOR.a  surface kind (KIND_* / 20)
##   UV2.x      height above the building's ground floor (m), UV2.y  per-building dirt 0..1
## Glass (world/shaders/window_glass.gdshader): UV = position in the pane (m), UV2 = pane size,
##   COLOR = (seed, shop flag, sill height / 4, ceiling height / 6).

const KIND_BRICK := 2
const KIND_FIELDSTONE := 3
const KIND_SIDING := 4
const KIND_CONCRETE := 5
const KIND_STUCCO := 6
const KIND_STONE := 8
const KIND_SMOOTH := 10
const KIND_WOOD := 11
const KIND_SHINGLE := 12
const KIND_SLATE := 13
const KIND_MEMBRANE := 14
const KIND_SEAM := 16
const KIND_FABRIC := 18
const KIND_AUTO := 20

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_INDEX] = idx
		return a

var surfaces: Dictionary = {}   # "group:mat" -> Surf
var group := "main"
var color := Color(1, 1, 1, 1)  # linear rgb + kind in alpha
var dirt := 0.5
var tris := 0


func surf(mat: String) -> Surf:
	var key := group + ":" + mat
	var s: Surf = surfaces.get(key)
	if s == null:
		s = Surf.new()
		surfaces[key] = s
	return s


## Sets the current color from a linear Color and a KIND_* value.
func paint(c: Color, kind: int) -> void:
	color = Color(c.r, c.g, c.b, float(kind) / 20.0)


## Quad a-b-c-d (any winding) facing n. uvs: optional 4 UVs; uv2s: optional 4 UV2s.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, mat := "wall",
		uvs: PackedVector2Array = PackedVector2Array(), col_override = null) -> void:
	var s := surf(mat)
	var cc: Color = color if col_override == null else col_override
	var p := [a, b, c, d]
	var u := uvs
	# Godot front faces are clockwise seen from the front: (b-a)x(c-a) must point away from n.
	if (b - a).cross(c - a).dot(n) > 0.0:
		p = [a, d, c, b]
		if u.size() == 4:
			u = PackedVector2Array([uvs[0], uvs[3], uvs[2], uvs[1]])
	var base := s.v.size()
	for i in 4:
		var q: Vector3 = p[i]
		s.v.append(q)
		s.n.append(n)
		s.c.append(cc)
		s.uv.append(u[i] if u.size() == 4 else Vector2(q.x + q.z, q.y))
		s.uv2.append(Vector2(q.y, dirt))
	s.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	tris += 2


func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, mat := "wall") -> void:
	var s := surf(mat)
	var p := [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		p = [a, c, b]
	var base := s.v.size()
	for q in p:
		s.v.append(q)
		s.n.append(n)
		s.c.append(color)
		s.uv.append(Vector2(q.x + q.z, q.y))
		s.uv2.append(Vector2(q.y, dirt))
	s.idx.append_array(PackedInt32Array([base, base + 1, base + 2]))
	tris += 1


## Axis-aligned box between two corners. faces: bitmask 1 -x, 2 +x, 4 -y, 8 +y, 16 -z, 32 +z.
func box(p0: Vector3, p1: Vector3, mat := "wall", faces := 59) -> void:
	var lo := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z))
	var hi := Vector3(maxf(p0.x, p1.x), maxf(p0.y, p1.y), maxf(p0.z, p1.z))
	if hi.x - lo.x < 0.002 or hi.y - lo.y < 0.002 or hi.z - lo.z < 0.002:
		return
	if faces & 1:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), Vector3.LEFT, mat)
	if faces & 2:
		quad(Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3.RIGHT, mat)
	if faces & 4:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3.DOWN, mat)
	if faces & 8:
		quad(Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.UP, mat)
	if faces & 16:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3.FORWARD, mat)
	if faces & 32:
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.BACK, mat)


## Oriented box: xf places a box of `size` centered on its origin.
func obox(xf: Transform3D, size: Vector3, mat := "wall", faces := 63) -> void:
	var h := size * 0.5
	var ax := [xf.basis.x.normalized(), xf.basis.y.normalized(), xf.basis.z.normalized()]
	var cs := []
	for i in 8:
		var l := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		cs.append(xf * l)
	# corner index = x | y<<1 | z<<2
	var fl := [[0, 4, 6, 2, -ax[0], 1], [1, 5, 7, 3, ax[0], 2], [0, 1, 5, 4, -ax[1], 4], [2, 3, 7, 6, ax[1], 8],
		[0, 1, 3, 2, -ax[2], 16], [4, 5, 7, 6, ax[2], 32]]
	for f in fl:
		if faces & int(f[5]):
			quad(cs[f[0]], cs[f[1]], cs[f[2]], cs[f[3]], f[4], mat)


## Box spanning from point a to point b (a thin strut / pipe / stringer) with cross-section w x t.
func strut(a: Vector3, b: Vector3, w: float, t: float, mat := "metal") -> void:
	var dir := b - a
	var l := dir.length()
	if l < 0.005:
		return
	var z := dir / l
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	obox(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, t, l), mat)


## Vertical cylinder (or cone when r1 != r0) from bottom center c, height h.
func cyl(c: Vector3, r0: float, h: float, segs := 8, mat := "metal", cap := true, r1 := -1.0) -> void:
	if r1 < 0.0:
		r1 = r0
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var nm := Vector3(cos((a0 + a1) * 0.5), (r0 - r1) / maxf(h, 0.01), sin((a0 + a1) * 0.5)).normalized()
		quad(c + d0 * r0, c + d1 * r0, c + d1 * r1 + Vector3(0, h, 0), c + d0 * r1 + Vector3(0, h, 0), nm, mat)
		if cap and r1 > 0.001:
			tri(c + Vector3(0, h, 0), c + d0 * r1 + Vector3(0, h, 0), c + d1 * r1 + Vector3(0, h, 0), Vector3.UP, mat)


## Horizontal cylinder along an arbitrary axis (pipes, dishes): xf origin = center, basis.y = axis.
func cyl_xf(xf: Transform3D, r: float, h: float, segs := 8, mat := "metal") -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := xf * Vector3(cos(a0) * r, -h * 0.5, sin(a0) * r)
		var p1 := xf * Vector3(cos(a1) * r, -h * 0.5, sin(a1) * r)
		var p2 := xf * Vector3(cos(a1) * r, h * 0.5, sin(a1) * r)
		var p3 := xf * Vector3(cos(a0) * r, h * 0.5, sin(a0) * r)
		var nm := (xf.basis * Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))).normalized()
		quad(p0, p1, p2, p3, nm, mat)
		var top := xf * Vector3(0, h * 0.5, 0)
		tri(top, p3, p2, (xf.basis.y).normalized(), mat)
		var bot := xf * Vector3(0, -h * 0.5, 0)
		tri(bot, p0, p1, -(xf.basis.y).normalized(), mat)


## Moves everything into arrays for ArrayMesh.add_surface_from_arrays: group -> [[mat, arrays], ...].
func to_groups() -> Dictionary:
	var out := {}
	for key in surfaces:
		var parts: PackedStringArray = String(key).split(":")
		if not out.has(parts[0]):
			out[parts[0]] = []
		out[parts[0]].append([parts[1], (surfaces[key] as Surf).arrays()])
	return out
