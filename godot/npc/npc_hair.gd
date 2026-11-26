class_name NpcHair
extends RefCounted
## Hair as strand cards grown from the scalp of the MakeHuman body, per sex and
## style (short, medium, long, ponytail, bun, curly; buzz and bald use only the
## painted scalp). Cards follow gravity, stay off the head and lie on the back,
## and are skinned to the head bone. Alpha-cut strands in npc_hair.gdshader.

static var _cache := {}
static var _shader: Shader

const STYLE := {
	# length m, gravity, curl, volume (push away from the head), card width
	"short": [0.035, 0.25, 0.0, 0.006, 0.016],
	"medium": [0.13, 1.0, 0.0, 0.012, 0.02],
	"long": [0.34, 1.0, 0.0, 0.012, 0.02],
	"ponytail": [0.26, 1.0, 0.0, 0.004, 0.018],
	"bun": [0.07, 0.0, 0.0, 0.004, 0.02],
	"curly": [0.06, 0.3, 1.0, 0.022, 0.02],
}


static func mesh(sex: String, style: String) -> ArrayMesh:
	if not STYLE.has(style):
		return null
	var key := sex + style
	if not _cache.has(key):
		_cache[key] = _build(sex, style)
	return _cache[key]


static func material(color: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://npc/npc_hair.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("hair_color", color)
	return m


static func _build(sex: String, style: String) -> ArrayMesh:
	var src: ArrayMesh = NpcBody.mesh_for(sex, 0)
	var a := src.surface_get_arrays(0)
	var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var UV: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var roots := []
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for i in V.size():
		if int(floor(UV[i].x + 0.01)) == 11:
			roots.append(i)
			lo = lo.min(V[i])
			hi = hi.max(V[i])
	var c := (lo + hi) * 0.5
	var rad := (hi - lo) * 0.5
	var chin_y := lo.y - 0.02
	var st: Array = STYLE[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_of(sex, style))
	var want := 4200
	var step := maxi(1, roots.size() / want)
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var tie := c + Vector3(0, rad.y * 0.2, rad.z + 0.015) if style == "ponytail" else c + Vector3(0, rad.y * 0.55, rad.z * 0.85)
	const SEGS := 7
	for r in range(0, roots.size(), step):
		var vi: int = roots[r]
		var p0: Vector3 = V[vi] + N[vi] * 0.001
		var n0: Vector3 = N[vi]
		var length: float = st[0] * rng.randf_range(0.8, 1.15)
		var p := p0
		# comb: away from the face (back and to the side), parted at the middle
		var sx := signf(p0.x) if absf(p0.x) > 0.004 else (1.0 if r % 2 == 0 else -1.0)
		# roots near the middle comb mostly back (a thin parting, not a bald wedge)
		var comb := Vector3(sx * 0.6 * clampf(absf(p0.x) / 0.035, 0.2, 1.0), 0.15, 1.0).normalized()
		var d := (n0 * 0.5 + comb).normalized()
		var tied := false
		var face_y := c.y + rad.y * 0.05
		var pts := [p]
		for k in SEGS:
			var f := float(k + 1) / SEGS
			var target := Vector3.DOWN
			var g: float = st[1]
			if (style == "ponytail" or style == "bun") and not tied:
				var to_tie := tie - p
				if to_tie.length() < 0.02:
					tied = true
				else:
					target = to_tie.normalized()
					g = 3.0
			if tied and style == "bun":
				target = (p - tie).normalized().cross(Vector3.UP).normalized() + Vector3.DOWN * 0.2
				g = 2.0
			d = (d + target * g * 0.9).normalized()
			if st[2] > 0.0:
				d = (d + Vector3(sin(f * 14.0 + r), cos(f * 11.0 + r * 0.7), sin(f * 9.0 + r * 1.3)) * 0.7).normalized()
			# steer away from the face early, so strands curve round it instead of being clamped
			if p.z < c.z - rad.z * 0.1 and p.y < face_y + rad.y * 0.55 and absf(p.x) < rad.x * 0.95:
				d = (d + Vector3(sx * 0.45, 0.0, 0.5)).normalized()
			p += d * length / SEGS
			var vol := Vector3.ONE * float(st[3])
			var q := (p - c) / (rad + vol)
			if q.length() < 1.0:
				p = c + q.normalized() * (rad + vol)
			# never over the face: below the hairline in front, keep to the sides
			if p.z < c.z - rad.z * 0.15 and p.y < face_y + rad.y * 0.2 and absf(p.x) < rad.x * 0.8:
				p.z = maxf(p.z, c.z - rad.z * 0.15)   # last resort: never hang in front of the face
			# long hair falls behind the neck and shoulders
			if p.y < chin_y and absf(p.x) < 0.2:
				p.z = maxf(p.z, c.z + rad.z * 0.55 + 0.03 * (chin_y - p.y) / 0.2)
			pts.append(p)
		var base := pos.size()
		var w0: float = st[4]
		for k in pts.size():
			var pk: Vector3 = pts[k]
			var dir: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var out := (pk - c).normalized()
			var side := dir.cross(out).normalized()
			var w := w0 * 0.7 * (1.0 - 0.6 * float(k) / SEGS)
			pos.append(pk - side * w * 0.5)
			pos.append(pk + side * w * 0.5)
			nrm.append(out)
			nrm.append(out)
			var v := float(k) / SEGS
			var s := rng.randf()
			uv.append(Vector2(s, v))
			uv.append(Vector2(s + 1.0, v))
			if k > 0:
				var a0 := base + (k - 1) * 2
				idx.append_array([a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in pos.size():
		bones.append_array([NpcBodyMesh.B_HEAD, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.resource_name = "hair_%s_%s" % [sex, style]
	return m


static func key_of(sex: String, style: String) -> String:
	return sex + ":" + style
