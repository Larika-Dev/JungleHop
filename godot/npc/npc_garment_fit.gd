class_name NpcGarmentFit
extends RefCounted
## Gives clothes real volume. The body is cut into thin slices along the trunk,
## each leg, each arm and each foot; every slice's outline is replaced by its
## convex hull (so cloth bridges over the chest, between the breasts, across
## the groin and the seat instead of following them), then cloth "hangs" from
## the widest point above (it can only come back in at a limited slope), is
## smoothed, and gets ease (looseness) on top. Garment vertices are pushed out
## onto that envelope. The same is done for the fat, slim and muscle shapes, so
## clothes still follow weight and muscle changes.

const BINS := 96          # angles per slice
const DT := 0.01          # slice spacing (m)

enum { R_NONE = -1, R_TRUNK, R_LEG_L, R_LEG_R, R_ARM_L, R_ARM_R, R_FOOT_L, R_FOOT_R }
const REGIONS := 7

static var _tables := {}
static var _lock := Mutex.new()


## Which region a body vertex belongs to (part from UV.x, side from its fraction).
static func region_of(uv: Vector2) -> int:
	var part := int(floorf(uv.x + 0.01))
	var right := uv.x - part > 0.25
	match part:
		0:
			return R_TRUNK
		1:
			return R_LEG_R if right else R_LEG_L
		2:
			return R_ARM_R if right else R_ARM_L
		4, 9:
			return R_FOOT_R if right else R_FOOT_L
	return R_NONE


## Slicing frame of a region: origin, slicing axis (points "up" the limb) and
## two cross axes.
static func frame(sex: String, r: int) -> Dictionary:
	var rp: Array = NpcMhMesh.rest_positions(sex) if NpcBody.use_mh else NpcBodyMesh.bone_rest_positions(sex)
	var o := Vector3.ZERO
	var a := Vector3.UP
	match r:
		R_LEG_L, R_LEG_R:
			var o2 := 0 if r == R_LEG_L else 3
			var hip: Vector3 = rp[NpcBodyMesh.B_THIGH_L + o2]
			var ankle: Vector3 = rp[NpcBodyMesh.B_FOOT_L + o2]
			o = ankle
			a = (hip - ankle).normalized()
		R_ARM_L, R_ARM_R:
			var o3 := 0 if r == R_ARM_L else 3
			var sh: Vector3 = rp[NpcBodyMesh.B_UPPERARM_L + o3]
			var wr: Vector3 = rp[NpcBodyMesh.B_HAND_L + o3]
			o = wr
			a = (sh - wr).normalized()
		R_FOOT_L, R_FOOT_R:
			var o4 := 0 if r == R_FOOT_L else 3
			o = rp[NpcBodyMesh.B_FOOT_L + o4]
			o.y = 0.0
			a = Vector3(0, 0, -1)
	var ref := Vector3.RIGHT if absf(a.x) < 0.7 else Vector3.BACK
	var e1 := (ref - a * a.dot(ref)).normalized()
	var e2 := e1.cross(a)
	return {"o": o, "a": a, "e1": e1, "e2": e2}


## Hull tables for every region of one body shape (-1 = base). Cached.
static func tables(sex: String, shape: int) -> Array:
	var key := "%s:%d" % [sex, shape]
	_lock.lock()   # warmed on the NPC loader thread (NPCs autoload)
	if not _tables.has(key):
		_tables[key] = _build_tables(sex, shape)
	var out: Array = _tables[key]
	_lock.unlock()
	return out


## Builds the fit tables for every shape the wardrobe refits (call from a
## worker thread at startup so the first dressed NPC does not hitch).
static func warm() -> void:
	var names: Array = NpcMhMesh.shape_list()
	for sex in ["male", "female"]:
		tables(sex, -1)
		for nm in NpcWardrobe.FIT_SHAPES:
			tables(sex, names.find(nm))


static func _build_tables(sex: String, shape: int) -> Array:
	var src: Array = NpcMhMesh.source(sex)
	var V: PackedVector3Array = src[0][Mesh.ARRAY_VERTEX] if shape < 0 else src[1][shape][Mesh.ARRAY_VERTEX]
	var UV: PackedVector2Array = src[0][Mesh.ARRAY_TEX_UV]
	var members := []
	for r in REGIONS:
		members.append(PackedInt32Array())
	for i in V.size():
		var r := region_of(UV[i])
		if r >= 0:
			members[r].append(i)
			if r == R_LEG_L or r == R_LEG_R:
				members[R_TRUNK].append(i)   # trunk hull spans both legs (skirts, crotch)
	var out := []
	for r in REGIONS:
		out.append(_table(frame(sex, r), V, members[r]))
	return out


static func _table(f: Dictionary, V: PackedVector3Array, ids: PackedInt32Array) -> Dictionary:
	var o: Vector3 = f.o
	var a: Vector3 = f.a
	var e1: Vector3 = f.e1
	var e2: Vector3 = f.e2
	var T := PackedFloat32Array()
	var U := PackedVector2Array()
	T.resize(ids.size())
	U.resize(ids.size())
	var tmin := INF
	var tmax := -INF
	for k in ids.size():
		var d := V[ids[k]] - o
		T[k] = d.dot(a)
		U[k] = Vector2(d.dot(e1), d.dot(e2))
		tmin = minf(tmin, T[k])
		tmax = maxf(tmax, T[k])
	var ns := int(ceilf((tmax - tmin) / DT)) + 1
	var buckets := []
	buckets.resize(ns)
	for s in ns:
		buckets[s] = PackedInt32Array()
	for k in ids.size():
		var s := clampi(roundi((T[k] - tmin) / DT), 0, ns - 1)
		buckets[s].append(k)
	# slice centers (bounding-box middle), smoothed along the limb
	var cu := PackedFloat32Array()
	var cv := PackedFloat32Array()
	cu.resize(ns)
	cv.resize(ns)
	var has := PackedByteArray()
	has.resize(ns)
	for s in ns:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in buckets[s]:
			lo = Vector2(minf(lo.x, U[k].x), minf(lo.y, U[k].y))
			hi = Vector2(maxf(hi.x, U[k].x), maxf(hi.y, U[k].y))
		if buckets[s].size() >= 3:
			has[s] = 1
			cu[s] = (lo.x + hi.x) * 0.5
			cv[s] = (lo.y + hi.y) * 0.5
	_fill_gaps(cu, has, 1)
	_fill_gaps(cv, has, 1)
	for _i in 4:
		cu = _blur1(cu)
		cv = _blur1(cv)
	var R := PackedFloat32Array()
	R.resize(ns * BINS)
	for s in ns:
		if not has[s]:
			continue
		var pts := PackedVector2Array()
		# a slice plus half of each neighbour: steadier hulls
		for s2 in [s - 1, s, s + 1]:
			if s2 < 0 or s2 >= ns:
				continue
			for k in buckets[s2]:
				pts.append(U[k] - Vector2(cu[s], cv[s]))
		var hull := _hull(pts)
		for b in BINS:
			var ang := TAU * b / BINS
			R[s * BINS + b] = _ray(hull, Vector2(cos(ang), sin(ang)))
	_fill_gaps(R, has, BINS)
	return {"o": f.o, "a": f.a, "e1": f.e1, "e2": f.e2, "tmin": tmin, "ns": ns, "cu": cu, "cv": cv, "R": R}


static func _fill_gaps(arr: PackedFloat32Array, has: PackedByteArray, stride: int) -> void:
	var ns := has.size()
	var last := -1
	for s in ns:
		if has[s]:
			if last >= 0 and s - last > 1:
				for g in range(last + 1, s):
					var f := float(g - last) / (s - last)
					for b in stride:
						arr[g * stride + b] = lerpf(arr[last * stride + b], arr[s * stride + b], f)
			elif last < 0:
				for g in s:
					for b in stride:
						arr[g * stride + b] = arr[s * stride + b]
			last = s
	if last >= 0:
		for g in range(last + 1, ns):
			for b in stride:
				arr[g * stride + b] = arr[last * stride + b]


static func _blur1(a: PackedFloat32Array) -> PackedFloat32Array:
	var o := a.duplicate()
	for i in range(1, a.size() - 1):
		o[i] = (a[i - 1] + 2.0 * a[i] + a[i + 1]) * 0.25
	return o


## Andrew's monotone chain convex hull (counter-clockwise).
static func _hull(p: PackedVector2Array) -> PackedVector2Array:
	var pts := Array(p)
	if pts.size() < 3:
		return p
	pts.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var lower := []
	for q in pts:
		while lower.size() >= 2 and (lower[-1] - lower[-2]).cross(q - lower[-2]) <= 0.0:
			lower.pop_back()
		lower.append(q)
	var upper := []
	for i in range(pts.size() - 1, -1, -1):
		var q: Vector2 = pts[i]
		while upper.size() >= 2 and (upper[-1] - upper[-2]).cross(q - upper[-2]) <= 0.0:
			upper.pop_back()
		upper.append(q)
	lower.pop_back()
	upper.pop_back()
	return PackedVector2Array(lower + upper)


## Distance from the origin to the hull along direction d.
static func _ray(h: PackedVector2Array, d: Vector2) -> float:
	var best := 0.0
	var n := h.size()
	if n < 3:
		for q in h:
			best = maxf(best, q.dot(d))
		return best
	for i in n:
		var p0 := h[i]
		var p1 := h[(i + 1) % n]
		var e := p1 - p0
		var den := d.cross(e)
		if absf(den) < 1e-12:
			continue
		var t := p0.cross(e) / den
		var s := p0.cross(d) / den
		if t > 0.0 and s >= -1e-6 and s <= 1.0 + 1e-6:
			best = maxf(best, t)
	return best


## A copy of a region table where cloth hangs from `t_top` down: below that it
## can only come in by `k` metres per metre, then it is smoothed. Slices above
## t_top keep the plain hull. Smoothing may cut up to `tol` into the hull.
static func draped(tab: Dictionary, t_top: float, k: float, smooth := 2, tol := 0.0) -> Dictionary:
	var ns: int = tab.ns
	var R: PackedFloat32Array = tab.R.duplicate()
	var top := clampi(int(floorf((t_top - tab.tmin) / DT)), 0, ns - 1)
	for s in range(top - 1, -1, -1):
		for b in BINS:
			R[s * BINS + b] = maxf(R[s * BINS + b], R[(s + 1) * BINS + b] - k * DT)
	var base := R.duplicate()
	for _i in smooth:
		var R2 := R.duplicate()
		for s in ns:
			for b in BINS:
				var bl := s * BINS + (b + BINS - 1) % BINS
				var br := s * BINS + (b + 1) % BINS
				var c := s * BINS + b
				var up := c + BINS if s + 1 < ns else c
				var dn := c - BINS if s > 0 else c
				R2[c] = (4.0 * R[c] + R[bl] + R[br] + R[up] + R[dn]) / 8.0
		R = R2
	# bumps smaller than `tol` are smoothed away (the ease covers them)
	for i in R.size():
		R[i] = maxf(R[i], base[i] - tol)
	var out := tab.duplicate()
	out.R = R
	return out


## Envelope radius and slice centre at (t, angle).
static func lookup(tab: Dictionary, t: float, ang: float) -> Vector3:
	var ns: int = tab.ns
	var fs := clampf((t - tab.tmin) / DT, 0.0, ns - 1.0)
	var s0 := int(floorf(fs))
	var s1 := mini(s0 + 1, ns - 1)
	var ft := fs - s0
	var fb := fposmod(ang / TAU, 1.0) * BINS
	var b0 := int(floorf(fb)) % BINS
	var b1 := (b0 + 1) % BINS
	var fa := fb - floorf(fb)
	var R: PackedFloat32Array = tab.R
	var r0 := lerpf(R[s0 * BINS + b0], R[s0 * BINS + b1], fa)
	var r1 := lerpf(R[s1 * BINS + b0], R[s1 * BINS + b1], fa)
	var cu: PackedFloat32Array = tab.cu
	var cv: PackedFloat32Array = tab.cv
	return Vector3(lerpf(r0, r1, ft), lerpf(cu[s0], cu[s1], ft), lerpf(cv[s0], cv[s1], ft))


## Pushes point p out onto the envelope of `tab` plus `ease`; `min_off` keeps it
## off the skin. `fold` adds soft drape folds where cloth stands off the body.
## Returns [new position, gap to the body, how far out the point sits (0..1),
## angle around the slice (0..1, 0.75 = front)].
static func project(tab: Dictionary, p: Vector3, ease: float, min_off: float, fold: float, squash_x := 1.0) -> Array:
	var d: Vector3 = p - tab.o
	var t := d.dot(tab.a)
	var u := d.dot(tab.e1)
	var v := d.dot(tab.e2)
	var c0 := lookup(tab, t, 0.0)
	var q := Vector2(u - c0.y, v - c0.z)
	# squash_x < 1 aims points near the middle straight forward or back (the
	# crotch of trousers: cloth runs from the front panel to the back one)
	var ang := atan2(q.y, q.x * squash_x)
	var L := lookup(tab, t, ang)
	q = Vector2(u - L.y, v - L.z)
	var r := q.length()
	ang = atan2(q.y, q.x * squash_x)
	var R := maxf(L.x + ease, r + min_off)
	var gap := R - r
	# how far out the point sits in its slice (1 = on the hull); points deep in
	# a slice (the crotch underside) have no useful direction
	var rel := clampf(r / maxf(L.x, 1e-4), 0.0, 1.0)
	if fold > 0.0:
		var g := clampf(gap / 0.03, 0.0, 1.0)
		var n := sin(ang * 9.0 + sin(t * 11.0) * 1.3) * 0.6 + sin(ang * 17.0 + t * 23.0 + 1.7) * 0.4
		R += fold * g * n
	var dir := Vector2(cos(ang), sin(ang))
	var out: Vector3 = tab.o + tab.a * t + tab.e1 * (L.y + dir.x * R) + tab.e2 * (L.z + dir.y * R)
	return [out, gap, rel, fposmod(ang / TAU, 1.0)]


## Slice-local t of a point in a region table.
static func t_of(tab: Dictionary, p: Vector3) -> float:
	return (p - tab.o).dot(tab.a)
