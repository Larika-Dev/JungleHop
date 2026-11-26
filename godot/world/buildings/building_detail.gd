class_name BuildingDetail
extends RefCounted
## Procedural, fully modeled building exteriors (CLAUDE.md §5/§6 detail standard) built from
## data/buildings.json + the exterior openings in data/rooms.json, so every modeled window and
## door lines up with the streamed interior behind it.
##
## Modeled: walls with real openings and reveals, double-hung / modern sashes with muntins,
## stone sills, lintels and keystones, shutters, flower boxes, window AC units, recessed panel
## and glass doors with transoms, stoops, porches, storefronts (bulkheads, mullions, transoms,
## sign bands with lettering, awnings, blade signs), belt courses, quoins, water tables,
## cornices (box / dentil / bracketed Italianate / coping), parapets, gable / hip / gambrel roofs
## with overhangs, fascia, soffits, ridge caps, gutters and downspouts, chimneys, fire escapes,
## balconies, utility clutter (meters, conduit, vents, condensers, cameras) and rooftop
## mechanical clutter (RTUs, exhaust fans, vent stacks, hatches, dishes, water tanks, penthouses).
##
## build() is pure data (thread-safe): returns {"groups": Mesher.to_groups(), "labels": [...]}.
## Groups: main (always, near LOD), fine (small parts, shorter range), glass (windows, hidden
## while the real interior is streamed in), door (door leaves, same), far (simple massing LOD).

const UP := Vector3.UP

# Quality tiers: 0 Low .. 3 Ultra
var q := 2
var bd: Dictionary
var id: String
var W := 10.0
var D := 10.0
var h := 6.0
var typ := ""
var style := "house"   # house | commercial | historic | modern | parking
var fac: Dictionary
var rng := RandomNumberGenerator.new()
var m := Mesher.new()
var labels: Array = []
var floors: Array = []      # [{y, ftf, ceil}]
var openings: Array = [[], [], [], []]   # per face: {type, s, y, w}
var faces: Array = []
var wall_col := Color()
var wall_kind := Mesher.KIND_BRICK
var trim_col := Color()
var sash_col := Color()
var sill_col := Color()
var base_col := Color()
var roof_col := Color()
var roof_kind := Mesher.KIND_SHINGLE
var metal_col := Color()
var flat := true
var parapet := 0.0
var overhang := 0.3
var pitch := deg_to_rad(35.0)
var brick := false
var storefront := false
var biz_name := ""
var biz_type := ""
var ground_ftf := 3.0


## A facade frame: point(s, y, d) = o + a * s + UP * y + n * d (d > 0 is outward).
class Face:
	var o: Vector3
	var a: Vector3
	var n: Vector3
	var L: float
	var idx: int

	func _init(o_: Vector3, a_: Vector3, n_: Vector3, l_: float, i: int) -> void:
		o = o_
		a = a_
		n = n_
		L = l_
		idx = i

	func p(s: float, y: float, d: float) -> Vector3:
		return o + a * s + Vector3.UP * y + n * d


static var _palette: Dictionary = {}


## Palette color (linear) from data/palette.json. Loaded once on first use (call from the main
## thread before building on workers).
static func pal(key: String, fallback := Color(0.8, 0.8, 0.8)) -> Color:
	if _palette.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
		if d is Dictionary:
			for k in d:
				if d[k] is String and String(d[k]).begins_with("#"):
					_palette[k] = Color(d[k]).srgb_to_linear()
	return _palette.get(key, fallback.srgb_to_linear())


static func build(data: Dictionary, rooms: Array, quality: int) -> Dictionary:
	var b := BuildingDetail.new()
	b.q = quality
	b._setup(data, rooms)
	b._build_detail()
	return {"groups": b.m.to_groups(), "labels": b.labels, "tris": b.m.tris}


## Far LOD only (used at startup for every building).
static func build_far(data: Dictionary, quality: int) -> Dictionary:
	var far := BuildingDetail.new()
	far.q = quality
	far._setup(data, [])
	far.m.group = "far"
	far._build_far()
	return far.m.to_groups()


# ------------------------------------------------------------------------------------- setup
func _setup(data: Dictionary, rooms: Array) -> void:
	bd = data
	id = data["id"]
	rng.seed = hash(id + "detail")
	var fp: Array = data.get("footprintCm", [1000, 1000])
	W = fp[0] / 100.0
	D = fp[1] / 100.0
	h = data.get("roofCm", 600) / 100.0
	typ = data.get("typology", "house")
	fac = data.get("facade", {})
	var plan: String = data.get("plan", "")
	var biz = data.get("business")
	if biz is Dictionary:
		biz_name = String(biz.get("name", ""))
		biz_type = String(biz.get("type", ""))
	if typ == "house":
		style = "house"
	elif plan == "business" or plan == "cinema" or typ in ["downtown_commercial", "bar", "diner"]:
		style = "commercial"
	elif typ == "parking":
		style = "parking"
	elif typ in ["modern_academic", "office_lab", "hospital", "residence_highrise"]:
		style = "modern"
	else:
		style = "historic"
	for f in data.get("floorsList", []):
		floors.append({"y": f["yCm"] / 100.0, "ftf": f["ftfCm"] / 100.0, "ceil": f["ceilingCm"] / 100.0, "floor": f["floor"]})
	if floors.is_empty():
		floors.append({"y": 0.0, "ftf": h, "ceil": h - 0.3, "floor": 0})
	ground_ftf = floors[0]["ftf"]
	flat = String(fac.get("roof", "flat")) == "flat"
	m.dirt = rng.randf()
	_colors()
	faces = [
		Face.new(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), W, 0),
		Face.new(Vector3(W, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), D, 1),
		Face.new(Vector3(W, 0, D), Vector3(-1, 0, 0), Vector3(0, 0, 1), W, 2),
		Face.new(Vector3(0, 0, D), Vector3(0, 0, -1), Vector3(-1, 0, 0), D, 3)]
	storefront = style == "commercial" and W >= 4.0 and ground_ftf >= 3.2
	if flat:
		parapet = {"commercial": rng.randf_range(0.7, 1.3), "historic": 0.6, "modern": 1.05, "parking": 1.1}.get(style, 0.5)
	overhang = {"house": 0.4, "historic": 0.3, "commercial": 0.3}.get(style, 0.25)
	pitch = deg_to_rad(35.0 if style == "house" else 28.0)
	_openings(rooms)
	if style == "house" and (hash(id + "porch") % 100) < 65:
		var ds := W * 0.5
		for o in openings[0]:
			if o["type"] == "door" and o["y"] < 0.4:
				ds = o["s"]
		_has_porch = clampf(ds + 2.6, W * 0.5, W - 0.3) - clampf(ds - 2.6, 0.3, W * 0.5) >= 3.0


func _colors() -> void:
	var wall: String = fac.get("wall", "brick:running:BRICK_DOWNTOWN_A")
	var p: PackedStringArray = wall.split(":")
	brick = p[0] == "brick"
	if brick:
		wall_col = pal("BRICK_PAINTED_WHITE" if p.size() > 3 and p[3] == "painted" else p[2])
		wall_kind = Mesher.KIND_BRICK
	elif p[0] == "paint":
		wall_col = pal(p[1])
		wall_kind = Mesher.KIND_SIDING if p[1].begins_with("SIDING") else Mesher.KIND_STUCCO
	elif wall.contains("fieldstone"):
		wall_col = pal("FIELDSTONE_A")
		wall_kind = Mesher.KIND_FIELDSTONE
	elif wall.contains("boardform"):
		wall_col = pal("CONCRETE_BOARDFORM")
		wall_kind = Mesher.KIND_CONCRETE
	elif wall.contains("concrete"):
		wall_col = pal("CONCRETE_NEW")
		wall_kind = Mesher.KIND_CONCRETE
	elif wall.contains("limestone"):
		wall_col = pal("LIMESTONE_TRIM")
		wall_kind = Mesher.KIND_STONE
	else:
		wall_col = pal("STUCCO")
		wall_kind = Mesher.KIND_STUCCO
	# per-building weathering of the base color (value ±5 %)
	wall_col = wall_col * rng.randf_range(0.95, 1.05)
	trim_col = pal("TRIM_WHITE") if rng.randf() < 0.7 else pal("TRIM_WHITE_AGED")
	sill_col = pal("LIMESTONE_TRIM") if (brick or wall_kind == Mesher.KIND_STONE) else trim_col
	base_col = pal("GRANITE_CURB") if style == "historic" else pal("CONCRETE_AGED")
	metal_col = pal("GALV_STEEL")
	match style:
		"house":
			sash_col = trim_col
			if wall_kind == Mesher.KIND_SIDING and rng.randf() < 0.2:
				sash_col = pal(["SHUTTER_BLACK", "SHUTTER_GREEN"][rng.randi() % 2])
		"commercial":
			sash_col = pal(["TRIM_WHITE", "SHUTTER_BLACK", "SHUTTER_GREEN", "ALUMINUM_STOREFRONT", "TRIM_WHITE_AGED", "DOOR_RED"][rng.randi() % 6])
		"modern", "parking":
			sash_col = pal("ALUMINUM_STOREFRONT")
		_:
			sash_col = pal("TRIM_WHITE")
	var roof: String = fac.get("roof", "flat")
	if roof == "flat":
		roof_col = pal("TPO_ROOF") if (style == "modern" or rng.randf() < 0.55) else pal("ASPHALT_AGED")
		roof_kind = Mesher.KIND_MEMBRANE
	elif style == "historic" or bd.get("district", "") == "toadstool":
		roof_col = pal("SLATE_A" if rng.randf() < 0.6 else "SLATE_B")
		roof_kind = Mesher.KIND_SLATE
	elif style == "commercial" or rng.randf() < 0.08:
		roof_col = pal("STANDING_SEAM")
		roof_kind = Mesher.KIND_SEAM
	else:
		roof_col = pal("ASPHALT_SHINGLE") * rng.randf_range(0.85, 1.25)
		roof_kind = Mesher.KIND_SHINGLE


## Exterior windows / doors from the rooms' openings that sit on the outer wall lines.
func _openings(rooms: Array) -> void:
	if rooms.is_empty():
		return
	var x0 := 1e9
	var z0 := 1e9
	var x1 := -1e9
	var z1 := -1e9
	for r in rooms:
		var rc: Array = r["rect"]
		x0 = minf(x0, rc[0])
		z0 = minf(z0, rc[1])
		x1 = maxf(x1, rc[2])
		z1 = maxf(z1, rc[3])
	var seen := {}
	for r in rooms:
		var y: float = r["y"]
		for o in r.get("openings", []):
			var pp: Array = o["position"]
			var fi := -1
			var s := 0.0
			if absf(pp[2] - z0) < 0.15:
				fi = 0
				s = pp[0]
			elif absf(pp[0] - x1) < 0.15:
				fi = 1
				s = pp[2]
			elif absf(pp[2] - z1) < 0.15:
				fi = 2
				s = W - pp[0]
			elif absf(pp[0] - x0) < 0.15:
				fi = 3
				s = D - pp[2]
			if fi < 0:
				continue
			var key := "%d|%d|%d|%s" % [fi, roundi(s * 20.0), roundi(y * 10.0), o["type"]]
			if seen.has(key):
				continue
			seen[key] = true
			openings[fi].append({"type": o["type"], "s": s, "y": y, "w": o.get("widthCm", 91) / 100.0})


func _floor_at(y: float) -> Dictionary:
	var best: Dictionary = floors[0]
	for f in floors:
		if y >= f["y"] - 0.05:
			best = f
	return best


# ------------------------------------------------------------------------------------- far LOD
func _build_far() -> void:
	# massing like the old map blocks: the facade shader paints windows on it
	m.color = Color(wall_col.r, wall_col.g, wall_col.b, 1.0)
	var top := h + parapet
	m.box(Vector3(0, -2, 0), Vector3(W, top, D), "wall", 1 | 2 | 16 | 32)
	if flat:
		m.paint(roof_col, roof_kind)
		m.quad(Vector3(0, top, 0), Vector3(W, top, 0), Vector3(W, top, D), Vector3(0, top, D), UP, "roof")
	else:
		_roof(true)


# ------------------------------------------------------------------------------------- detail
func _build_detail() -> void:
	for f in faces:
		_facade(f)
	_base_course()
	if brick and (style == "historic" or (style == "commercial" and rng.randf() < 0.35)):
		_quoins()
	if flat:
		_flat_roof()
	else:
		_roof(false)
		if style == "house" and rng.randf() < 0.6:
			_chimney()
	_utilities()
	if style == "commercial" and floors.size() >= 3 and rng.randf() < 0.7:
		_fire_escape(faces[2])


## Recess depth of windows behind the wall face.
func _recess() -> float:
	match style:
		"house":
			return 0.07 if wall_kind == Mesher.KIND_SIDING else 0.11
		"modern", "parking":
			return 0.06
	return 0.12


func _facade(f: Face) -> void:
	var holes: Array = []   # [s0, s1, y0, y1, recess]
	var top := h + parapet
	var rec := _recess()
	var sf_zone := Vector2(-1, -1)
	if f.idx == 0 and storefront:
		sf_zone = Vector2(0.45, f.L - 0.45)
	# --- parking decks: open bays between columns on every floor
	if style == "parking":
		for fl in floors:
			var bays := maxi(1, floori(f.L / 6.0))
			var bw := f.L / bays
			for i in bays:
				holes.append([i * bw + 0.3, (i + 1) * bw - 0.3, fl["y"] + 1.05, fl["y"] + fl["ftf"] - 0.35, 0.0])
	for o in openings[f.idx]:
		var fl := _floor_at(o["y"])
		var w: float = o["w"]
		var s0: float = clampf(o["s"] - w * 0.5, 0.15, f.L - 0.15)
		var s1: float = clampf(o["s"] + w * 0.5, 0.15, f.L - 0.15)
		if s1 - s0 < 0.3:
			continue
		var y: float = o["y"]
		if o["type"] == "door":
			if f.idx == 0 and storefront and y < 0.5:
				continue   # handled by the storefront
			var dh := 2.13
			if fl["ftf"] >= 3.5 and style != "modern":
				dh = 2.13 + 0.5   # transom light
			holes.append([s0, s1, y, y + dh, 0.18 if style != "house" else 0.1, "door", o])
		else:
			if f.idx == 0 and storefront and y < 0.5:
				continue
			if style == "parking":
				continue
			var y0 := y + 0.9
			var y1 := y + 2.4
			if fl["ftf"] >= 4.0:
				y0 = y + 0.75
				y1 = y + 2.85
			elif fl["ftf"] >= 3.3:
				y0 = y + 0.85
				y1 = y + 2.5
			y1 = minf(y1, y + fl["ceil"] - 0.08)
			holes.append([s0, s1, y0, y1, rec, "window", o])
	if sf_zone.x >= 0.0:
		holes.append([sf_zone.x, sf_zone.y, 0.0, _sf_top(), 0.25, "storefront", null])
	# --- wall surface with the openings cut out
	m.group = "main"
	m.paint(wall_col, wall_kind)
	_wall_with_holes(f, -2.0, top, holes)
	if not flat and (f.idx == 1 or f.idx == 3):
		_gable_end(f)
	if flat:
		_parapet_inner(f)
	# --- opening kits
	for hl in holes:
		_reveal(f, hl)
		if hl.size() < 6:
			_parking_bay(f, hl)
			continue
		match hl[5]:
			"window":
				_window(f, hl)
			"door":
				_door(f, hl)
			"storefront":
				_storefront(f, hl)
	_bands(f)
	_cornice(f)
	if f.idx == 0 and _has_porch:
		_porch(f)


## Wall rectangle [0, L] x [y0, y1] at d = 0 minus rectangular holes.
func _wall_with_holes(f: Face, y0: float, y1: float, holes: Array) -> void:
	var ys := [y0, y1]
	for hl in holes:
		for v in [hl[2], hl[3]]:
			if v > y0 and v < y1 and not ys.has(v):
				ys.append(v)
	ys.sort()
	for i in ys.size() - 1:
		var ya: float = ys[i]
		var yb: float = ys[i + 1]
		if yb - ya < 0.001:
			continue
		var mid := (ya + yb) * 0.5
		var spans: Array = []
		for hl in holes:
			if hl[2] <= mid and hl[3] >= mid:
				spans.append([hl[0], hl[1]])
		spans.sort_custom(func(p1, p2): return p1[0] < p2[0])
		var cur := 0.0
		for sp in spans:
			if sp[0] > cur:
				_wq(f, cur, sp[0], ya, yb, 0.0)
			cur = maxf(cur, sp[1])
		if cur < f.L:
			_wq(f, cur, f.L, ya, yb, 0.0)


## Facade-aligned quad facing outward at depth d.
func _wq(f: Face, s0: float, s1: float, y0: float, y1: float, d: float, mat := "wall") -> void:
	m.quad(f.p(s0, y0, d), f.p(s1, y0, d), f.p(s1, y1, d), f.p(s0, y1, d), f.n, mat)


## Facade-aligned box.
func _fb(f: Face, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float, mat := "wall", faces_mask := 63) -> void:
	var a := f.p(s0, y0, d0)
	var b := f.p(s1, y1, d1)
	m.box(a, b, mat, faces_mask)


func _reveal(f: Face, hl: Array) -> void:
	var s0: float = hl[0]
	var s1: float = hl[1]
	var y0: float = hl[2]
	var y1: float = hl[3]
	var r: float = maxf(hl[4], 0.05)
	m.group = "main"
	m.paint(wall_col * 0.92, wall_kind)
	m.quad(f.p(s0, y0, 0), f.p(s0, y0, -r), f.p(s0, y1, -r), f.p(s0, y1, 0), f.a, "wall")
	m.quad(f.p(s1, y0, 0), f.p(s1, y0, -r), f.p(s1, y1, -r), f.p(s1, y1, 0), -f.a, "wall")
	m.quad(f.p(s0, y1, 0), f.p(s1, y1, 0), f.p(s1, y1, -r), f.p(s0, y1, -r), Vector3.DOWN, "wall")
	if hl.size() < 6 or hl[5] != "door":
		m.quad(f.p(s0, y0, 0), f.p(s1, y0, 0), f.p(s1, y0, -r), f.p(s0, y0, -r), UP, "wall")


func _glass(f: Face, s0: float, s1: float, y0: float, y1: float, d: float, shop: bool, sill_h: float, ceil_h: float, grp := "glass") -> void:
	var prev := m.group
	m.group = grp
	var seed := rng.randf()
	var c := Color(seed, 1.0 if shop else 0.0, clampf(sill_h / 4.0, 0, 1), clampf(ceil_h / 6.0, 0, 1))
	var w := s1 - s0
	var hh := y1 - y0
	var s := m.surf("glass")
	var base := s.v.size()
	var pts := [f.p(s0, y0, d), f.p(s1, y0, d), f.p(s1, y1, d), f.p(s0, y1, d)]
	var uvs := [Vector2(0, 0), Vector2(w, 0), Vector2(w, hh), Vector2(0, hh)]
	var order := [0, 1, 2, 3]
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(f.n) > 0.0:
		order = [0, 3, 2, 1]
	for i in order:
		s.v.append(pts[i])
		s.n.append(f.n)
		s.c.append(c)
		s.uv.append(uvs[i])
		s.uv2.append(Vector2(w, hh))
	s.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	m.tris += 2
	m.group = prev


# ------------------------------------------------------------------------------------- windows
func _window(f: Face, hl: Array) -> void:
	var s0: float = hl[0]
	var s1: float = hl[1]
	var y0: float = hl[2]
	var y1: float = hl[3]
	var r: float = hl[4]
	var o: Dictionary = hl[6]
	var fl := _floor_at(o["y"])
	var wtype: String = fac.get("window", "6/6")
	if style in ["modern", "parking"]:
		wtype = "modern"
	_glass(f, s0, s1, y0, y1, -r + 0.004, false, y0 - fl["y"], fl["ceil"], "glass")
	# --- sash frame
	m.group = "main"
	m.paint(sash_col, Mesher.KIND_SMOOTH)
	var fw := 0.055 if wtype != "modern" else 0.06
	_fb(f, s0, s0 + fw, y0, y1, -r, -r + 0.06)
	_fb(f, s1 - fw, s1, y0, y1, -r, -r + 0.06)
	_fb(f, s0, s1, y1 - fw, y1, -r, -r + 0.06)
	_fb(f, s0, s1, y0, y0 + 0.07, -r, -r + 0.06)
	var ym := (y0 + y1) * 0.5
	if wtype != "modern":
		_fb(f, s0, s1, ym - 0.028, ym + 0.028, -r, -r + 0.075)   # meeting rail
	elif s1 - s0 > 1.2:
		_fb(f, (s0 + s1) * 0.5 - 0.03, (s0 + s1) * 0.5 + 0.03, y0, y1, -r, -r + 0.07)
	# muntins (fine LOD)
	if q >= 1 and wtype != "modern":
		m.group = "fine"
		m.paint(sash_col, Mesher.KIND_SMOOTH)
		var cols := 3
		var rows := 2
		if wtype == "9/9":
			rows = 3
		elif wtype == "2/2":
			cols = 2
			rows = 1
		for sash in 2:
			var sy0 := (y0 + 0.07) if sash == 0 else ym + 0.028
			var sy1 := ym - 0.028 if sash == 0 else y1 - fw
			for i in range(1, cols):
				var ss := s0 + fw + (s1 - s0 - 2.0 * fw) * i / cols
				_fb(f, ss - 0.011, ss + 0.011, sy0, sy1, -r + 0.005, -r + 0.035)
			for j in range(1, rows):
				var yy := sy0 + (sy1 - sy0) * j / rows
				_fb(f, s0 + fw, s1 - fw, yy - 0.011, yy + 0.011, -r + 0.005, -r + 0.035)
	# --- surround
	m.group = "main"
	var wood := wall_kind == Mesher.KIND_SIDING or wall_kind == Mesher.KIND_STUCCO
	if wood or style == "house":
		# flat casing + head with crown
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		_fb(f, s0 - 0.1, s0, y0 - 0.02, y1, 0, 0.025, "wall", 59)
		_fb(f, s1, s1 + 0.1, y0 - 0.02, y1, 0, 0.025, "wall", 59)
		_fb(f, s0 - 0.12, s1 + 0.12, y1, y1 + 0.15, 0, 0.03)
		_fb(f, s0 - 0.15, s1 + 0.15, y1 + 0.15, y1 + 0.19, 0, 0.06)
		_fb(f, s0 - 0.07, s1 + 0.07, y0 - 0.06, y0, -r, 0.055)    # sill
	elif style == "modern":
		m.paint(sash_col, Mesher.KIND_SMOOTH)
		_fb(f, s0 - 0.02, s1 + 0.02, y0 - 0.03, y0, -r, 0.05, "metal")
	else:
		# masonry: stone sill, lintel (keystone on historic, soldier course or hood on commercial)
		m.paint(sill_col, Mesher.KIND_STONE)
		_fb(f, s0 - 0.09, s1 + 0.09, y0 - 0.09, y0, -r, 0.045)
		var lint: int = 0 if style == "historic" else (hash(id) % 3)
		if lint == 0:
			_fb(f, s0 - 0.1, s1 + 0.1, y1, y1 + 0.22, 0, 0.02)
			_fb(f, (s0 + s1) * 0.5 - 0.09, (s0 + s1) * 0.5 + 0.09, y1 - 0.02, y1 + 0.27, 0, 0.035)
		elif lint == 1:
			m.paint(wall_col * 0.82, Mesher.KIND_BRICK)
			_fb(f, s0 - 0.1, s1 + 0.1, y1, y1 + 0.215, 0, 0.012)
		else:
			m.paint(trim_col * 0.95, Mesher.KIND_SMOOTH)
			_fb(f, s0 - 0.14, s1 + 0.14, y1 + 0.03, y1 + 0.24, 0, 0.07)
			_fb(f, s0 - 0.17, s1 + 0.17, y1 + 0.24, y1 + 0.3, 0, 0.1)
			if q >= 1:
				m.group = "fine"
				_fb(f, s0 - 0.14, s0 - 0.07, y1 - 0.25, y1 + 0.03, 0, 0.07)
				_fb(f, s1 + 0.07, s1 + 0.14, y1 - 0.25, y1 + 0.03, 0, 0.07)
				m.group = "main"
	# --- shutters
	var shutter := false
	if style == "house" and fac.get("window", "") in ["6/6", "9/9"]:
		shutter = (hash(id + "sh") % 100) < 55
	elif style == "historic":
		shutter = (hash(id + "sh") % 100) < 30
	if shutter and s0 > 0.75 and s1 < f.L - 0.75:
		var sc := pal("SHUTTER_GREEN" if (hash(id) % 2 == 0) else "SHUTTER_BLACK")
		m.paint(sc, Mesher.KIND_WOOD)
		var sw := (s1 - s0) * 0.5
		var off := 0.1 if (wood or style == "house") else 0.02
		_fb(f, s0 - off - sw, s0 - off, y0, y1, 0.0, 0.035)
		_fb(f, s1 + off, s1 + off + sw, y0, y1, 0.0, 0.035)
		if q >= 2:
			m.group = "fine"
			m.paint(sc * 0.8, Mesher.KIND_WOOD)
			for side in [s0 - off - sw, s1 + off]:
				for k in range(1, 12):
					var yy: float = y0 + (y1 - y0) * k / 12.0
					_fb(f, side + 0.04, side + sw - 0.04, yy - 0.012, yy + 0.012, 0.035, 0.045, "wall", 8 | 16 | 32 | 1 | 2)
				_fb(f, side + 0.04, side + sw - 0.04, (y0 + y1) * 0.5 - 0.03, (y0 + y1) * 0.5 + 0.03, 0.035, 0.05)
			m.group = "main"
	# --- clutter on the window
	var fl_i: int = fl["floor"]
	if style == "commercial" and fl_i >= 1 and rng.randf() < 0.1:
		# window AC unit
		m.paint(pal("TRIM_WHITE_AGED") * 0.9, Mesher.KIND_SMOOTH)
		var sc2 := (s0 + s1) * 0.5
		_fb(f, sc2 - 0.33, sc2 + 0.33, y0 + 0.02, y0 + 0.42, -r + 0.06, 0.38, "metal")
		if q >= 1:
			m.group = "fine"
			m.paint(pal("ALUMINUM_STOREFRONT"), Mesher.KIND_SMOOTH)
			for k in 6:
				var yy := y0 + 0.07 + k * 0.055
				_fb(f, sc2 - 0.29, sc2 + 0.29, yy, yy + 0.02, 0.38, 0.39, "metal")
			m.paint(pal("TRIM_WHITE_AGED") * 0.6, Mesher.KIND_SMOOTH)
			_fb(f, sc2 - 0.2, sc2 - 0.17, y0 - 0.4, y0 + 0.02, 0.2, 0.36, "metal")
			m.group = "main"
	elif style == "house" and fl_i == 0 and f.idx == 0 and rng.randf() < 0.35:
		# flower box with planting
		m.paint(trim_col * 0.9, Mesher.KIND_WOOD)
		_fb(f, s0 - 0.02, s1 + 0.02, y0 - 0.32, y0 - 0.07, 0.06, 0.3)
		m.paint(pal("BOXWOOD"), Mesher.KIND_STUCCO)
		_fb(f, s0 + 0.02, s1 - 0.02, y0 - 0.07, y0 + 0.08, 0.09, 0.28)
		if q >= 1:
			m.group = "fine"
			for k in 4:
				var bs := s0 + 0.12 + (s1 - s0 - 0.24) * k / 3.0
				m.paint(pal(["RED_MAPLE_LEAF", "SUGAR_MAPLE_LEAF", "AZALEA", "DOGWOOD_LEAF"][k]), Mesher.KIND_STUCCO)
				_fb(f, bs - 0.07, bs + 0.07, y0 + 0.05, y0 + 0.16, 0.12, 0.25)
			m.group = "main"
	elif (style == "commercial" and fl_i >= 1 and (floors.size() >= 4 or bd.get("district", "") == "rosemary_row") and rng.randf() < 0.25) \
			or (typ == "residence_highrise" and fl_i >= 1 and f.idx % 2 == 0 and rng.randf() < 0.5):
		_balcony(f, s0, s1, fl["y"])


func _balcony(f: Face, s0: float, s1: float, fy: float) -> void:
	var a := s0 - 0.45
	var b := s1 + 0.45
	var dep := 1.1
	m.group = "main"
	m.paint(pal("CONCRETE_AGED"), Mesher.KIND_CONCRETE)
	_fb(f, a, b, fy - 0.16, fy, 0, dep)
	var rail := pal("IRON_BLACK")
	m.paint(rail, Mesher.KIND_SMOOTH)
	# top rail + posts
	_fb(f, a, b, fy + 1.03, fy + 1.07, dep - 0.04, dep, "metal")
	_fb(f, a, a + 0.04, fy + 1.03, fy + 1.07, 0, dep, "metal")
	_fb(f, b - 0.04, b, fy + 1.03, fy + 1.07, 0, dep, "metal")
	for s in [a, b - 0.04]:
		_fb(f, s, s + 0.04, fy, fy + 1.03, dep - 0.04, dep, "metal")
	if q >= 1:
		m.group = "fine"
		_fb(f, a, b, fy + 0.08, fy + 0.11, dep - 0.035, dep - 0.005, "metal")
		var n := int((b - a) / 0.12)
		for i in range(1, n):
			var s := a + (b - a) * i / n
			_fb(f, s - 0.008, s + 0.008, fy + 0.11, fy + 1.03, dep - 0.03, dep - 0.014, "metal")
		for i in range(1, 8):
			var d := dep * i / 8.0
			_fb(f, a + 0.012, a + 0.028, fy + 0.11, fy + 1.03, d - 0.008, d + 0.008, "metal")
			_fb(f, b - 0.028, b - 0.012, fy + 0.11, fy + 1.03, d - 0.008, d + 0.008, "metal")
		# brackets under the slab
		m.paint(pal("CONCRETE_AGED") * 0.9, Mesher.KIND_CONCRETE)
		for s in [a + 0.2, b - 0.3]:
			_fb(f, s, s + 0.1, fy - 0.45, fy - 0.16, 0, 0.35)
		m.group = "main"


func _parking_bay(f: Face, hl: Array) -> void:
	# open deck bay: slab, soffit and a dark back plane, cable guard rails
	var s0: float = hl[0]
	var s1: float = hl[1]
	var y0: float = hl[2]
	var y1: float = hl[3]
	var fy := y0 - 1.05
	var dep := minf(7.0, (D if f.idx % 2 == 0 else W) * 0.45)
	m.group = "main"
	m.paint(pal("CONCRETE_AGED") * 0.8, Mesher.KIND_CONCRETE)
	m.quad(f.p(s0, y1 + 0.3, -0.05), f.p(s1, y1 + 0.3, -0.05), f.p(s1, y1 + 0.3, -dep), f.p(s0, y1 + 0.3, -dep), Vector3.DOWN, "wall")
	m.paint(pal("ASPHALT_AGED"), Mesher.KIND_CONCRETE)
	m.quad(f.p(s0, fy + 0.02, -0.05), f.p(s1, fy + 0.02, -0.05), f.p(s1, fy + 0.02, -dep), f.p(s0, fy + 0.02, -dep), UP, "wall")
	m.paint(pal("CONCRETE_AGED") * 0.35, Mesher.KIND_CONCRETE)
	_wq(f, s0, s1, fy, y1 + 0.3, -dep)
	m.paint(metal_col, Mesher.KIND_SMOOTH)
	for k in 3:
		var yy := y0 + 0.15 + k * 0.25
		_fb(f, s0, s1, yy, yy + 0.015, -0.1, -0.085, "metal")


# ------------------------------------------------------------------------------------- doors
func _door(f: Face, hl: Array) -> void:
	var s0: float = hl[0]
	var s1: float = hl[1]
	var y0: float = hl[2]
	var y1: float = hl[3]
	var r: float = hl[4]
	var back := f.idx != 0
	var leaf_top := y0 + 2.11
	var service := back and style in ["commercial", "modern", "parking"]
	# leaf (hidden while the interior is streamed in: the real hinged Door takes over)
	m.group = "door"
	var dc: Color
	if service:
		dc = pal("STEEL_DOOR_GRAY")
	elif style == "house" or style == "historic":
		dc = pal(["DOOR_RED", "DOOR_BLACK", "DOOR_GREEN", "DOOR_HEAVENBLUE", "DOOR_RED"][hash(id + "door") % 5])
		if style == "house" and rng.randf() < 0.3:
			dc = trim_col
	else:
		dc = pal("ALUMINUM_STOREFRONT")
	var glass_door := not service and style in ["commercial", "modern"]
	m.paint(dc, Mesher.KIND_SMOOTH)
	if glass_door:
		_fb(f, s0 + 0.02, s1 - 0.02, y0, leaf_top, -r - 0.045, -r, "metal", 63)
		_glass(f, s0 + 0.12, s1 - 0.12, y0 + 0.3, leaf_top - 0.12, -r + 0.003, true, 0.3, 3.0, "door")
		m.group = "door"
		m.paint(pal("BRASS"), Mesher.KIND_SMOOTH)
		_fb(f, s1 - 0.2, s1 - 0.16, y0 + 0.85, y0 + 1.25, -r, -r + 0.06, "metal")
	else:
		_fb(f, s0 + 0.02, s1 - 0.02, y0, leaf_top, -r - 0.045, -r, "wall", 63)
		if q >= 1 and not service:
			# six raised panels
			m.paint(dc * 1.08, Mesher.KIND_SMOOTH)
			var pw := (s1 - s0 - 0.04 - 0.36) * 0.5
			var hs := [[0.12, 0.62], [0.74, 1.4], [1.52, 1.99]]
			for c in 2:
				var ps := s0 + 0.14 + c * (pw + 0.08)
				for rr in hs:
					_fb(f, ps, ps + pw, y0 + rr[0], y0 + rr[1], -r, -r + 0.012)
		m.paint(pal("BRASS"), Mesher.KIND_SMOOTH)
		_fb(f, s1 - 0.12, s1 - 0.07, y0 + 0.93, y0 + 1.03, -r, -r + 0.06, "metal")
		if service:
			m.paint(pal("GALV_STEEL"), Mesher.KIND_SMOOTH)
			_fb(f, s0 + 0.1, s1 - 0.1, y0 + 0.95, y0 + 1.0, -r, -r + 0.05, "metal")   # panic bar
	# transom
	if y1 - y0 > 2.3:
		m.group = "main"
		m.paint(sash_col if not service else dc, Mesher.KIND_SMOOTH)
		_fb(f, s0, s1, leaf_top, leaf_top + 0.06, -r, -r + 0.06)
		_glass(f, s0 + 0.03, s1 - 0.03, leaf_top + 0.06, y1 - 0.03, -r + 0.004, false, 2.2, 3.0, "glass")
	# frame / surround
	m.group = "main"
	m.paint(pal("LIMESTONE_TRIM"), Mesher.KIND_STONE)
	_fb(f, s0, s1, y0 - 0.02, y0 + 0.012, -r, 0.04)   # threshold
	if style == "house":
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		_fb(f, s0 - 0.11, s0, y0, y1, 0, 0.03)
		_fb(f, s1, s1 + 0.11, y0, y1, 0, 0.03)
		_fb(f, s0 - 0.14, s1 + 0.14, y1, y1 + 0.2, 0, 0.04)
		_fb(f, s0 - 0.18, s1 + 0.18, y1 + 0.2, y1 + 0.26, 0, 0.09)
	elif style == "historic" and not back:
		# pilasters, entablature and a pediment
		m.paint(pal("COLUMN_WHITE"), Mesher.KIND_SMOOTH)
		_fb(f, s0 - 0.36, s0 - 0.08, y0, y1 + 0.1, 0, 0.1)
		_fb(f, s1 + 0.08, s1 + 0.36, y0, y1 + 0.1, 0, 0.1)
		_fb(f, s0 - 0.42, s1 + 0.42, y1 + 0.1, y1 + 0.42, 0, 0.14)
		_fb(f, s0 - 0.48, s1 + 0.48, y1 + 0.42, y1 + 0.5, 0, 0.2)
		var pc := (s0 + s1) * 0.5
		var pw2 := (s1 - s0) * 0.5 + 0.48
		var ph := pw2 * 0.35
		m.tri(f.p(pc - pw2, y1 + 0.5, 0.18), f.p(pc + pw2, y1 + 0.5, 0.18), f.p(pc, y1 + 0.5 + ph, 0.18), f.n)
		m.quad(f.p(pc - pw2, y1 + 0.5, 0.0), f.p(pc - pw2, y1 + 0.5, 0.2), f.p(pc, y1 + 0.5 + ph, 0.2), f.p(pc, y1 + 0.5 + ph, 0.0),
			(UP - f.a * 0.35).normalized(), "wall")
		m.quad(f.p(pc + pw2, y1 + 0.5, 0.0), f.p(pc + pw2, y1 + 0.5, 0.2), f.p(pc, y1 + 0.5 + ph, 0.2), f.p(pc, y1 + 0.5 + ph, 0.0),
			(UP + f.a * 0.35).normalized(), "wall")
	elif service:
		# light over the back door
		m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
		var c := (s0 + s1) * 0.5
		_fb(f, c - 0.1, c + 0.1, y1 + 0.15, y1 + 0.35, 0, 0.18, "metal")
	elif style == "modern" and not back:
		# metal entry canopy
		m.paint(pal("ALUMINUM_STOREFRONT"), Mesher.KIND_SMOOTH)
		_fb(f, s0 - 1.2, s1 + 1.2, y1 + 0.5, y1 + 0.68, 0, 2.2, "metal")
		if q >= 1:
			m.group = "fine"
			_fb(f, s0 - 1.1, s0 - 1.05, y1 + 0.68, y1 + 2.2, 0, 0.05, "metal")
			m.strut(f.p(s0 - 1.08, y1 + 2.1, 0.04), f.p(s0 - 1.08, y1 + 0.68, 2.1), 0.03, 0.03)
			m.strut(f.p(s1 + 1.08, y1 + 2.1, 0.04), f.p(s1 + 1.08, y1 + 0.68, 2.1), 0.03, 0.03)
			m.group = "main"
	# stoop
	if y0 < 0.3 and (style == "house" or style == "historic") and not (f.idx == 0 and _has_porch):
		m.paint(pal("CONCRETE_AGED") if style == "house" else pal("GRANITE_CURB"), Mesher.KIND_CONCRETE)
		_fb(f, s0 - 0.45, s1 + 0.45, -2.0, -0.02, 0, 1.25)
		_fb(f, s0 - 0.35, s1 + 0.35, -2.0, -0.19, 1.25, 1.56)
		_fb(f, s0 - 0.25, s1 + 0.25, -2.0, -0.36, 1.56, 1.87)
		if q >= 1 and style == "historic":
			m.group = "fine"
			m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
			for s in [s0 - 0.4, s1 + 0.37]:
				m.strut(f.p(s, 0.9, 0.1), f.p(s, 0.55, 1.85), 0.04, 0.04)
				_fb(f, s - 0.015, s + 0.015, -0.02, 0.9, 0.08, 0.11, "metal")
				_fb(f, s - 0.015, s + 0.015, -0.36, 0.55, 1.83, 1.86, "metal")
			m.group = "main"
	# address numerals by the front door
	if f.idx == 0 and not service and q >= 1:
		labels.append({"text": str(100 + (hash(id) % 880)), "pos": f.p(s1 + 0.32, y0 + 1.75, 0.03), "n": f.n,
			"size": 0.12, "color": pal("BRASS").linear_to_srgb(), "font": "serif", "lit": false})


var _has_porch := false


# ------------------------------------------------------------------------------------- storefront
func _sf_top() -> float:
	return minf(3.3, ground_ftf - 1.0)


func _storefront(f: Face, hl: Array) -> void:
	var s0: float = hl[0]
	var s1: float = hl[1]
	var yt: float = hl[3]
	var r: float = hl[4]
	var fc := pal(["ALUMINUM_STOREFRONT", "SHUTTER_BLACK", "SHUTTER_GREEN", "DOOR_RED", "WALNUT_DARK", "TRIM_WHITE"][hash(id + "sf") % 6])
	var bulk := 0.45
	var transom := yt - 0.55
	# doors on the storefront (from the rooms' exterior doors on the ground floor front)
	var doors: Array = []
	for o in openings[0]:
		if o["type"] == "door" and o["y"] < 0.5:
			doors.append([clampf(o["s"] - o["w"] * 0.5, s0 + 0.1, s1 - 1.0), 0.0])
	for dd in doors:
		dd[1] = dd[0] + 0.96
	# bulkhead (skipping door spans)
	m.group = "main"
	var spans := _minus_spans(s0, s1, doors)
	var bc := fc if rng.randf() < 0.5 else wall_col * 0.7
	m.paint(bc, Mesher.KIND_SMOOTH if bc == fc else wall_kind)
	for sp in spans:
		_fb(f, sp[0], sp[1], 0.0, bulk, -r - 0.02, -r + 0.07, "wall", 63)
		if q >= 1:
			m.group = "fine"
			m.paint(bc * 1.1, Mesher.KIND_SMOOTH)
			var n := maxi(1, int((sp[1] - sp[0]) / 1.2))
			for i in n:
				var a: float = sp[0] + (sp[1] - sp[0]) * i / n + 0.1
				var b: float = sp[0] + (sp[1] - sp[0]) * (i + 1) / n - 0.1
				_fb(f, a, b, 0.1, bulk - 0.08, -r + 0.07, -r + 0.085)
			m.group = "main"
			m.paint(bc, Mesher.KIND_SMOOTH if bc == fc else wall_kind)
	# glass: display windows (permanently lit shop interior, not hidden when streaming)
	for sp in spans:
		_glass(f, sp[0], sp[1], bulk, transom, -r + 0.005, true, bulk, 3.6, "main")
	_glass(f, s0, s1, transom + 0.08, yt - 0.06, -r + 0.005, true, 2.9, 3.6, "main")
	for dd in doors:
		_glass(f, dd[0], dd[1], 2.13, transom, -r + 0.005, true, 2.1, 3.6, "main")
	# frames and mullions
	m.paint(fc, Mesher.KIND_SMOOTH)
	_fb(f, s0, s1, yt - 0.06, yt, -r - 0.01, -r + 0.08, "metal")
	_fb(f, s0, s1, transom, transom + 0.08, -r - 0.01, -r + 0.08, "metal")
	_fb(f, s0, s0 + 0.08, 0, yt, -r - 0.01, -r + 0.08, "metal")
	_fb(f, s1 - 0.08, s1, 0, yt, -r - 0.01, -r + 0.08, "metal")
	for sp in spans:
		_fb(f, sp[0], sp[1], bulk, bulk + 0.06, -r - 0.01, -r + 0.08, "metal")
		var n := maxi(1, int((sp[1] - sp[0]) / 1.7))
		for i in range(1, n):
			var ms: float = sp[0] + (sp[1] - sp[0]) * i / n
			_fb(f, ms - 0.035, ms + 0.035, bulk, transom, -r - 0.01, -r + 0.08, "metal")
	if q >= 1:
		m.group = "fine"
		var nt := maxi(2, int((s1 - s0) / 0.6))
		for i in range(1, nt):
			var ms := s0 + (s1 - s0) * i / nt
			_fb(f, ms - 0.015, ms + 0.015, transom + 0.08, yt - 0.06, -r, -r + 0.04, "metal")
		m.group = "main"
	# door leaves (hidden while the interior is streamed in)
	for dd in doors:
		m.group = "door"
		m.paint(fc, Mesher.KIND_SMOOTH)
		_fb(f, dd[0], dd[1], 0, 2.11, -r - 0.045, -r, "metal")
		_glass(f, dd[0] + 0.11, dd[1] - 0.11, 0.32, 1.98, -r + 0.003, true, 0.3, 3.6, "door")
		m.group = "door"
		m.paint(pal("BRASS"), Mesher.KIND_SMOOTH)
		_fb(f, dd[1] - 0.2, dd[1] - 0.16, 0.85, 1.3, -r, -r + 0.07, "metal")
		_fb(f, dd[0] + 0.05, dd[1] - 0.05, 0.08, 0.3, -r, -r + 0.004, "metal")   # kick plate
		m.group = "main"
		m.paint(fc, Mesher.KIND_SMOOTH)
		_fb(f, dd[0] - 0.05, dd[0], 0, 2.18, -r - 0.01, -r + 0.08, "metal")
		_fb(f, dd[1], dd[1] + 0.05, 0, 2.18, -r - 0.01, -r + 0.08, "metal")
		_fb(f, dd[0] - 0.05, dd[1] + 0.05, 2.13, 2.2, -r - 0.01, -r + 0.08, "metal")
	# tile entry floor in the recess
	m.paint(pal(["TERRAZZO", "HEX_TILE_WHITE", "VCT_B"][hash(id) % 3]), Mesher.KIND_SMOOTH)
	_fb(f, s0, s1, -0.3, 0.005, -r, 0.0, "wall", 8)
	# sign band
	var ys0 := yt + 0.12
	var ys1 := minf(yt + 0.95, ground_ftf - 0.15)
	if ys1 - ys0 > 0.35:
		var sign_bg := pal(["SHUTTER_BLACK", "ONSU_NAVY", "IRON_GREEN", "WALNUT_DARK", "CINEMA_MAROON"][hash(id + "sg") % 5])
		if rng.randf() < 0.35:
			sign_bg = wall_col * 0.8
		m.paint(sign_bg, Mesher.KIND_SMOOTH)
		_fb(f, s0 + 0.1, s1 - 0.1, ys0, ys1, 0, 0.06)
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		_fb(f, s0 + 0.05, s1 - 0.05, ys1, ys1 + 0.06, 0, 0.1)
		_fb(f, s0 + 0.05, s1 - 0.05, ys0 - 0.05, ys0, 0, 0.08)
		if biz_name != "":
			var band_h := ys1 - ys0
			var size := minf(band_h * 0.55, (s1 - s0 - 0.5) / maxf(biz_name.length() * 0.5, 1.0))
			var tcol: Color = [pal("SIGN_CREAM"), pal("MARKING_WHITE"), pal("MARQUEE_BULB"), pal("BRASS_WORN")][hash(id + "tc") % 4]
			labels.append({"text": biz_name.to_upper(), "pos": f.p((s0 + s1) * 0.5, (ys0 + ys1) * 0.5, 0.075), "n": f.n,
				"size": size, "color": tcol.linear_to_srgb(), "font": ["display", "condensed", "serif"][hash(id + "fn") % 3], "lit": true,
				"max_w": s1 - s0 - 0.6})
		# gooseneck lamps over the sign
		if q >= 1:
			m.group = "fine"
			m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
			var nl := clampi(int((s1 - s0) / 2.5), 1, 5)
			for i in nl:
				var ls := s0 + (s1 - s0) * (i + 0.5) / nl
				m.strut(f.p(ls, ys1 + 0.1, 0.02), f.p(ls, ys1 + 0.35, 0.3), 0.03, 0.03)
				_fb(f, ls - 0.1, ls + 0.1, ys1 + 0.28, ys1 + 0.38, 0.25, 0.45, "metal")
			m.group = "main"
	# awning or blade sign
	if rng.randf() < 0.6:
		_awning(f, s0, s1, yt + 0.05)
	elif ys1 - ys0 > 0.35:
		_blade_sign(f, s1 - 0.55, ys1 + 0.1)
	# neon OPEN sign in the window for bars and food
	if biz_type in ["bar", "diner", "pizza", "takeout", "breakfast", "tacos", "cafe"] or typ == "bar":
		var os_: float = (spans[0][0] + spans[0][1]) * 0.5 if spans.size() > 0 else s0 + 1.0
		labels.append({"text": "OPEN", "pos": f.p(os_, 1.6, -r + 0.02), "n": f.n, "size": 0.16,
			"color": pal("NEON_RED").linear_to_srgb(), "font": "condensed", "lit": true, "glow": true})


func _minus_spans(s0: float, s1: float, cuts: Array) -> Array:
	var out: Array = []
	var cur := s0
	var cs := cuts.duplicate()
	cs.sort_custom(func(p1, p2): return p1[0] < p2[0])
	for c in cs:
		if c[0] > cur + 0.05:
			out.append([cur, c[0]])
		cur = maxf(cur, c[1])
	if s1 > cur + 0.05:
		out.append([cur, s1])
	return out


func _awning(f: Face, s0: float, s1: float, ytop: float) -> void:
	var cols := ["AWNING_HARBOR_BLUE", "AWNING_COFFEE", "AWNING_LINEN", "CURB_PAINT_RED", "SHUTTER_GREEN", "CINEMA_MAROON", "ONSU_NAVY"]
	var c1 := pal(cols[hash(id + "aw") % cols.size()])
	var c2 := pal("TRIM_WHITE")
	var striped := rng.randf() < 0.4
	var dep := rng.randf_range(1.0, 1.5)
	var drop := 0.75
	var val := 0.25
	var a := s0 + 0.05
	var b := s1 - 0.05
	m.group = "main"
	var n_str := maxi(1, int((b - a) / 0.3)) if striped else 1
	for i in n_str:
		var sa := a + (b - a) * i / n_str
		var sb := a + (b - a) * (i + 1) / n_str
		m.paint(c1 if (i % 2 == 0) else c2, Mesher.KIND_FABRIC)
		var nrm := (f.n * drop + UP * dep).normalized()
		m.quad(f.p(sa, ytop, 0.02), f.p(sb, ytop, 0.02), f.p(sb, ytop - drop, dep), f.p(sa, ytop - drop, dep), nrm, "wall")
		m.quad(f.p(sa, ytop, 0.02), f.p(sb, ytop, 0.02), f.p(sb, ytop - drop, dep), f.p(sa, ytop - drop, dep), -nrm, "wall",
			PackedVector2Array(), Color(m.color.r * 0.55, m.color.g * 0.55, m.color.b * 0.55, m.color.a))
		m.quad(f.p(sa, ytop - drop, dep), f.p(sb, ytop - drop, dep), f.p(sb, ytop - drop - val, dep), f.p(sa, ytop - drop - val, dep), f.n, "wall")
		m.quad(f.p(sa, ytop - drop, dep), f.p(sb, ytop - drop, dep), f.p(sb, ytop - drop - val, dep), f.p(sa, ytop - drop - val, dep), -f.n, "wall")
	m.paint(c1, Mesher.KIND_FABRIC)
	for s in [a, b]:
		var side_n := -f.a if s == a else f.a
		m.tri(f.p(s, ytop, 0.02), f.p(s, ytop - drop, dep), f.p(s, ytop - drop, 0.02), side_n)
		m.tri(f.p(s, ytop, 0.02), f.p(s, ytop - drop, dep), f.p(s, ytop - drop, 0.02), -side_n)
	if q >= 1:
		m.group = "fine"
		m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
		var na := maxi(2, int((b - a) / 1.8) + 1)
		for i in na:
			var s := a + 0.03 + (b - a - 0.06) * i / (na - 1)
			m.strut(f.p(s, ytop - drop - 0.25, 0.02), f.p(s, ytop - drop + 0.02, dep - 0.03), 0.025, 0.025)
		_fb(f, a, b, ytop - drop - 0.02, ytop - drop + 0.01, dep - 0.04, dep - 0.01, "metal")
		m.group = "main"
	if biz_name != "" and dep > 0:
		labels.append({"text": biz_name.to_upper(), "pos": f.p((a + b) * 0.5, ytop - drop - val * 0.5, dep + 0.01), "n": f.n,
			"size": val * 0.55, "color": (c2 if not striped else pal("SHUTTER_BLACK")).linear_to_srgb(), "font": "condensed", "lit": false,
			"max_w": b - a - 0.4})


func _blade_sign(f: Face, s: float, y: float) -> void:
	m.group = "main"
	m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
	_fb(f, s - 0.03, s + 0.03, y + 0.85, y + 0.9, 0, 1.05, "metal")
	_fb(f, s - 0.08, s + 0.08, y + 0.75, y + 1.0, 0, 0.04, "metal")
	var bg := pal(["ONSU_NAVY", "SHUTTER_GREEN", "CINEMA_MAROON", "SHUTTER_BLACK"][hash(id + "bl") % 4])
	m.paint(bg, Mesher.KIND_SMOOTH)
	_fb(f, s - 0.025, s + 0.025, y - 0.05, y + 0.85, 0.15, 0.95)
	m.paint(pal("BRASS_WORN"), Mesher.KIND_SMOOTH)
	_fb(f, s - 0.03, s + 0.03, y - 0.08, y - 0.05, 0.13, 0.97)
	if biz_name != "":
		var short := biz_name.split(" ")[0].to_upper()
		for side in [-1.0, 1.0]:
			labels.append({"text": short, "pos": f.p(s + side * 0.03, y + 0.4, 0.55), "n": f.a * side,
				"size": 0.2, "color": pal("SIGN_CREAM").linear_to_srgb(), "font": "display", "lit": true, "max_w": 0.68})


# ------------------------------------------------------------------------------------- bands, quoins, base
func _bands(f: Face) -> void:
	m.group = "main"
	if style == "modern":
		# spandrel bands at every floor line
		m.paint(pal("CONCRETE_NEW"), Mesher.KIND_CONCRETE)
		for fl in floors:
			if fl["y"] < 0.5:
				continue
			_fb(f, -0.02, f.L + 0.02, fl["y"] - 0.35, fl["y"] + 0.55, 0, 0.05)
		if q >= 2:
			m.group = "fine"
			m.paint(pal("ALUMINUM_STOREFRONT"), Mesher.KIND_SMOOTH)
			var n := int(f.L / 1.5)
			for i in range(1, n):
				var s := f.L * i / n
				_fb(f, s - 0.025, s + 0.025, 0.3, h, 0, 0.14, "metal")
			m.group = "main"
		return
	if (brick and style == "commercial") or style == "historic":
		m.paint(sill_col if style == "historic" else wall_col * 0.85, Mesher.KIND_STONE if style == "historic" else wall_kind)
		for fl in floors:
			if fl["y"] < 0.5 or fl["y"] > h - 0.5:
				continue
			_fb(f, -0.03, f.L + 0.03, fl["y"] - 0.08, fl["y"] + 0.12, 0, 0.035)
	if style == "commercial" and f.idx == 0:
		# corner piers on the storefront level
		m.paint(wall_col * 0.95, wall_kind)
		_fb(f, -0.03, 0.45, -2.0, ground_ftf, 0, 0.07)
		_fb(f, f.L - 0.45, f.L + 0.03, -2.0, ground_ftf, 0, 0.07)
		m.paint(sill_col, Mesher.KIND_STONE)
		_fb(f, -0.05, 0.47, ground_ftf - 0.2, ground_ftf, 0, 0.1)
		_fb(f, f.L - 0.47, f.L + 0.05, ground_ftf - 0.2, ground_ftf, 0, 0.1)


func _quoins() -> void:
	m.group = "main"
	m.paint(pal("LIMESTONE_TRIM"), Mesher.KIND_STONE)
	var top := h - 0.3
	var y := 0.6
	var i := 0
	while y + 0.3 < top:
		var long := 0.45 if i % 2 == 0 else 0.25
		var short := 0.25 if i % 2 == 0 else 0.45
		for c in [[0.0, 0.0], [W, 0.0], [W, D], [0.0, D]]:
			var sx := -1.0 if c[0] == 0.0 else 1.0
			var sz := -1.0 if c[1] == 0.0 else 1.0
			var x0: float = c[0] + sx * 0.025
			var z0: float = c[1] + sz * 0.025
			m.box(Vector3(x0 - sx * long, y, z0), Vector3(x0, y + 0.28, z0 - sz * short), "wall", 59)
		y += 0.31
		i += 1


func _base_course() -> void:
	m.group = "main"
	var top := 0.55 if style in ["historic", "commercial"] else 0.3
	m.paint(base_col, Mesher.KIND_STONE if style == "historic" else Mesher.KIND_CONCRETE)
	for f in faces:
		var segs: Array = [[0.0, f.L]]
		if f.idx == 0 and storefront:
			segs = [[0.0, 0.45], [f.L - 0.45, f.L]]
		for o in openings[f.idx]:
			if o["type"] == "door" and o["y"] < 0.4:
				var nsegs: Array = []
				for sg in segs:
					nsegs.append_array(_minus_spans(sg[0], sg[1], [[o["s"] - o["w"] * 0.5 - 0.02, o["s"] + o["w"] * 0.5 + 0.02]]))
				segs = nsegs
		for sg in segs:
			_fb(f, sg[0] - 0.04, sg[1] + 0.04, -2.0, top, 0, 0.04, "wall", 63 - 4)
			_fb(f, sg[0] - 0.05, sg[1] + 0.05, top, top + 0.05, 0, 0.055, "wall", 63 - 4)


# ------------------------------------------------------------------------------------- roofs
func _parapet_inner(f: Face) -> void:
	var t := 0.25
	var top := h + parapet
	# inner face of the parapet, facing back into the roof
	var s0 := t if true else 0.0
	m.paint(wall_col * 0.9, wall_kind)
	m.quad(f.p(s0, h, -t), f.p(f.L - t, h, -t), f.p(f.L - t, top, -t), f.p(s0, top, -t), -f.n, "wall")


func _flat_roof() -> void:
	var t := 0.25
	var top := h + parapet
	m.group = "main"
	m.paint(roof_col, roof_kind)
	m.quad(Vector3(t, h, t), Vector3(W - t, h, t), Vector3(W - t, h, D - t), Vector3(t, h, D - t), UP, "roof")
	# coping
	var cc := metal_col if style in ["modern", "parking"] or rng.randf() < 0.4 else pal("CAPSTONE")
	m.paint(cc, Mesher.KIND_SMOOTH if cc == metal_col else Mesher.KIND_STONE)
	var mat := "metal" if cc == metal_col else "wall"
	var skip_front: bool = style == "commercial" or (style == "historic" and fac.get("cornice", "") != "coping")
	if not skip_front:
		m.box(Vector3(-0.04, top, -0.04), Vector3(W + 0.04, top + 0.07, t + 0.03), mat)
	m.box(Vector3(-0.04, top, D - t - 0.03), Vector3(W + 0.04, top + 0.07, D + 0.04), mat)
	m.box(Vector3(-0.04, top, t), Vector3(t + 0.03, top + 0.07, D - t), mat)
	m.box(Vector3(W - t - 0.03, top, t), Vector3(W + 0.04, top + 0.07, D - t), mat)
	# raised center parapet panel on some storefront blocks
	if style == "commercial" and W > 6.0 and rng.randf() < 0.3:
		var f: Face = faces[0]
		m.paint(wall_col, wall_kind)
		_fb(f, W * 0.3, W * 0.7, top - 0.1, top + 0.7, 0, 0.0, "wall", 63)
		_fb(f, W * 0.3, W * 0.7, top - 0.1, top + 0.7, -t, 0.0, "wall", 63)
		m.paint(sill_col, Mesher.KIND_STONE)
		_fb(f, W * 0.3 - 0.05, W * 0.7 + 0.05, top + 0.7, top + 0.8, -t - 0.04, 0.1)
		if q >= 1:
			labels.append({"text": str(1880 + hash(id) % 60), "pos": f.p(W * 0.5, top + 0.32, 0.01), "n": f.n,
				"size": 0.24, "color": sill_col.linear_to_srgb(), "font": "serif", "lit": false})
	_roof_clutter(t)
	# scuppers + downspouts at the back corners
	var bf: Face = faces[2]
	for s in [0.6, bf.L - 0.6]:
		_downspout(bf, s, h + 0.1, 0.0)


func _downspout(f: Face, s: float, ytop: float, out: float) -> void:
	var dc := pal("MULLION_WHITE") if style == "house" else metal_col
	m.group = "main"
	m.paint(dc, Mesher.KIND_SMOOTH)
	_fb(f, s - 0.05, s + 0.05, -0.15, ytop - 0.2, 0.02, 0.1, "metal")
	_fb(f, s - 0.12, s + 0.12, ytop - 0.35, ytop - 0.05, 0.0, 0.25, "metal")   # conductor head / elbow
	if out > 0.0:
		_fb(f, s - 0.05, s + 0.05, ytop - 0.15, ytop - 0.05, 0.02, out, "metal")
	m.paint(pal("CONCRETE_AGED"), Mesher.KIND_CONCRETE)
	_fb(f, s - 0.15, s + 0.15, -0.3, -0.22, 0.05, 0.65)
	_fb(f, s - 0.05, s + 0.05, -0.22, -0.12, 0.05, 0.4, "metal")
	if q >= 1:
		m.group = "fine"
		m.paint(dc * 0.8, Mesher.KIND_SMOOTH)
		var y := 0.6
		while y < ytop - 0.5:
			_fb(f, s - 0.07, s + 0.07, y, y + 0.03, 0.0, 0.11, "metal")
			y += 1.8
		m.group = "main"


func _roof_clutter(t: float) -> void:
	var area := (W - 2.0 * t - 1.0) * (D - 2.0 * t - 1.0)
	if area < 6.0:
		return
	var placed: Array = []   # Rect2 in (x, z)
	var n_rtu := clampi(int(area / 70.0) + 1, 1, [2, 4, 6, 8][q])
	if style == "house":
		n_rtu = 0
	for i in n_rtu:
		var sx := rng.randf_range(1.2, 2.4)
		var sz := rng.randf_range(0.9, 1.4)
		var hh := rng.randf_range(0.9, 1.6)
		var r := _place(placed, sx, sz, t)
		if r.size.x <= 0.0:
			break
		_rtu(r, hh)
	if q >= 1:
		var nv := clampi(int(area / 25.0) + 2, 2, [0, 6, 10, 14][q])
		for i in nv:
			var r := _place(placed, 0.5, 0.5, t)
			if r.size.x <= 0.0:
				break
			var c := Vector3(r.get_center().x, h, r.get_center().y)
			m.group = "fine"
			m.paint(metal_col * rng.randf_range(0.8, 1.1), Mesher.KIND_SMOOTH)
			var kind := rng.randi() % 3
			if kind == 0:
				# plumbing vent stack
				m.cyl(c, 0.05, rng.randf_range(0.3, 0.6), 6)
			elif kind == 1:
				# mushroom exhaust fan
				m.cyl(c, 0.28, 0.12, 8)
				m.cyl(c + Vector3(0, 0.12, 0), 0.2, 0.35, 8)
				m.cyl(c + Vector3(0, 0.47, 0), 0.34, 0.12, 10, "metal", true, 0.05)
			else:
				# gooseneck intake
				m.box(c - Vector3(0.18, 0, 0.18), c + Vector3(0.18, 0.5, 0.18), "metal")
				m.box(c + Vector3(-0.18, 0.5, -0.18), c + Vector3(0.18, 0.72, 0.36), "metal")
	# roof hatch
	var hr := _place(placed, 0.9, 0.9, t)
	if hr.size.x > 0.0:
		m.group = "main"
		m.paint(metal_col * 0.9, Mesher.KIND_SMOOTH)
		m.box(Vector3(hr.position.x, h, hr.position.y), Vector3(hr.end.x, h + 0.38, hr.end.y), "metal")
		if q >= 1:
			m.group = "fine"
			m.paint(pal("SAFETY_YELLOW", Color(0.9, 0.72, 0.1)), Mesher.KIND_SMOOTH)
			m.box(Vector3(hr.position.x + 0.05, h + 0.38, hr.position.y), Vector3(hr.position.x + 0.09, h + 1.3, hr.position.y + 0.04), "metal")
			m.box(Vector3(hr.end.x - 0.09, h + 0.38, hr.position.y), Vector3(hr.end.x - 0.05, h + 1.3, hr.position.y + 0.04), "metal")
	# pipe run on sleepers
	if q >= 2 and W > 6.0:
		m.group = "fine"
		var z := rng.randf_range(t + 0.6, D - t - 0.6)
		m.paint(pal("GALV_STEEL") * 0.7, Mesher.KIND_SMOOTH)
		m.box(Vector3(t + 0.4, h + 0.18, z - 0.04), Vector3(W - t - 0.4, h + 0.26, z + 0.04), "metal")
		var x := t + 0.6
		m.paint(pal("CONCRETE_AGED") * 0.8, Mesher.KIND_CONCRETE)
		while x < W - t - 0.6:
			m.box(Vector3(x - 0.1, h, z - 0.15), Vector3(x + 0.1, h + 0.18, z + 0.15))
			x += 2.4
	# satellite dish
	if q >= 1 and rng.randf() < 0.35:
		var r := _place(placed, 0.8, 0.8, t)
		if r.size.x > 0.0:
			m.group = "fine"
			var c := Vector3(r.get_center().x, h, r.get_center().y)
			m.paint(pal("TRIM_WHITE_AGED"), Mesher.KIND_SMOOTH)
			m.cyl(c, 0.03, 0.8, 5)
			var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(55)).rotated(Vector3.UP, rng.randf() * TAU), c + Vector3(0, 0.95, 0))
			m.cyl_xf(xf, 0.38, 0.04, 12)
			m.strut(c + Vector3(0, 0.95, 0), xf * Vector3(0, 0.45, 0), 0.02, 0.02)
	# wooden water tank on taller downtown blocks
	if style == "commercial" and floors.size() >= 4 and rng.randf() < 0.35:
		var r := _place(placed, 3.4, 3.4, t)
		if r.size.x > 0.0:
			_water_tank(Vector3(r.get_center().x, h, r.get_center().y))
	# stair / elevator penthouse
	if int(bd.get("elevators", 0)) > 0 and floors.size() >= 3:
		var r := _place(placed, 3.2, 3.6, t)
		if r.size.x > 0.0:
			m.group = "main"
			m.paint(wall_col * 0.95, wall_kind)
			var ph := 3.0
			m.box(Vector3(r.position.x, h, r.position.y), Vector3(r.end.x, h + ph, r.end.y))
			m.paint(metal_col, Mesher.KIND_SMOOTH)
			m.box(Vector3(r.position.x - 0.05, h + ph, r.position.y - 0.05), Vector3(r.end.x + 0.05, h + ph + 0.08, r.end.y + 0.05), "metal")
			m.paint(pal("STEEL_DOOR_GRAY"), Mesher.KIND_SMOOTH)
			m.box(Vector3(r.position.x + 0.8, h, r.position.y - 0.03), Vector3(r.position.x + 1.72, h + 2.1, r.position.y), "metal")


func _place(placed: Array, sx: float, sz: float, t: float) -> Rect2:
	for attempt in 12:
		var x := rng.randf_range(t + 0.5, maxf(t + 0.5, W - t - 0.5 - sx))
		var z := rng.randf_range(t + 0.5, maxf(t + 0.5, D - t - 0.5 - sz))
		var r := Rect2(x, z, sx, sz)
		if r.end.x > W - t - 0.3 or r.end.y > D - t - 0.3:
			continue
		var ok := true
		for p in placed:
			if (p as Rect2).grow(0.5).intersects(r):
				ok = false
				break
		if ok:
			placed.append(r)
			return r
	return Rect2()


func _rtu(r: Rect2, hh: float) -> void:
	var y := h
	m.group = "main"
	m.paint(metal_col * 0.6, Mesher.KIND_SMOOTH)
	m.box(Vector3(r.position.x - 0.08, y, r.position.y - 0.08), Vector3(r.end.x + 0.08, y + 0.2, r.end.y + 0.08), "metal")   # curb
	var c := pal(["GALV_STEEL", "TRIM_WHITE_AGED", "CONCRETE_NEW"][rng.randi() % 3])
	m.paint(c, Mesher.KIND_SMOOTH)
	m.box(Vector3(r.position.x, y + 0.2, r.position.y), Vector3(r.end.x, y + 0.2 + hh, r.end.y), "metal")
	if q >= 1:
		m.group = "fine"
		var top := y + 0.2 + hh
		# condenser fans on top
		var nf := 1 if r.size.x < 1.7 else 2
		for i in nf:
			var fx := r.position.x + r.size.x * (i + 0.5) / nf
			var fc := Vector3(fx, top, r.get_center().y)
			m.paint(pal("SHUTTER_BLACK"), Mesher.KIND_SMOOTH)
			m.cyl(fc, minf(0.36, r.size.y * 0.35), 0.06, 12)
			m.paint(c * 0.8, Mesher.KIND_SMOOTH)
			m.box(fc - Vector3(0.38, -0.06, 0.015), fc + Vector3(0.38, 0.08, 0.015), "metal")
			m.box(fc - Vector3(0.015, -0.06, 0.38), fc + Vector3(0.015, 0.08, 0.38), "metal")
		# side louvers / coil fins
		m.paint(c * 0.7, Mesher.KIND_SMOOTH)
		var nl := int(hh / 0.08) - 2
		for k in nl:
			var ly := y + 0.32 + k * 0.08
			m.box(Vector3(r.position.x + 0.1, ly, r.end.y), Vector3(r.end.x - 0.1, ly + 0.025, r.end.y + 0.03), "metal", 8 | 32 | 4)
		# service panel + duct into the roof
		m.paint(c * 0.9, Mesher.KIND_SMOOTH)
		m.box(Vector3(r.position.x - 0.02, y + 0.4, r.position.y + 0.15), Vector3(r.position.x, y + 0.2 + hh - 0.2, r.get_center().y), "metal")
		m.paint(metal_col * 0.85, Mesher.KIND_SMOOTH)
		m.box(Vector3(r.end.x, y, r.get_center().y - 0.25), Vector3(r.end.x + 0.5, y + 0.6, r.get_center().y + 0.25), "metal")
		m.cyl(Vector3(r.end.x + 0.25, y + 0.6, r.get_center().y), 0.02, 0.0, 4)
		# electrical disconnect + conduit
		m.paint(pal("SHUTTER_GREEN") * 0.8, Mesher.KIND_SMOOTH)
		m.box(Vector3(r.get_center().x - 0.15, y + 0.3, r.position.y - 0.25), Vector3(r.get_center().x + 0.15, y + 0.75, r.position.y - 0.1), "metal")


func _water_tank(c: Vector3) -> void:
	m.group = "main"
	m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
	for dx in [-1.1, 1.1]:
		for dz in [-1.1, 1.1]:
			m.box(c + Vector3(dx - 0.08, 0, dz - 0.08), c + Vector3(dx + 0.08, 2.4, dz + 0.08), "metal")
	m.box(c + Vector3(-1.4, 2.4, -1.4), c + Vector3(1.4, 2.55, 1.4), "metal")
	m.paint(pal("WALNUT_DARK") * 1.6, Mesher.KIND_WOOD)
	m.cyl(c + Vector3(0, 2.55, 0), 1.5, 3.4, 16, "wall", false)
	m.paint(pal("ASPHALT_SHINGLE"), Mesher.KIND_SHINGLE)
	m.cyl(c + Vector3(0, 5.95, 0), 1.58, 1.0, 16, "wall", true, 0.05)
	if q >= 1:
		m.group = "fine"
		m.paint(pal("IRON_BLACK") * 1.5, Mesher.KIND_SMOOTH)
		for k in 4:
			m.cyl(c + Vector3(0, 2.8 + k * 0.85, 0), 1.53, 0.05, 16, "metal", false)
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			m.strut(c + Vector3(cos(a) * 1.1, 0.2, sin(a) * 1.1), c + Vector3(cos(a + PI * 0.5) * 1.1, 2.3, sin(a + PI * 0.5) * 1.1), 0.04, 0.04)
		# ladder
		var lx := c + Vector3(1.55, 0, 0)
		m.box(lx + Vector3(0, 2.55, -0.22), lx + Vector3(0.04, 6.0, -0.19), "metal")
		m.box(lx + Vector3(0, 2.55, 0.19), lx + Vector3(0.04, 6.0, 0.22), "metal")
		var y := 2.7
		while y < 6.0:
			m.box(lx + Vector3(0, y, -0.2), lx + Vector3(0.03, y + 0.025, 0.2), "metal")
			y += 0.3


## Pitched roofs (ridge along local X): gable, hip, gambrel. far = massing version.
func _roof(far: bool) -> void:
	var kind: String = fac.get("roof", "gable")
	var o := 0.0 if far else overhang
	var tn := tan(pitch)
	var hr := h + (D * 0.5) * tn
	var ye := h - o * tn   # eave line height at the overhang
	m.paint(roof_col, roof_kind)
	var x0 := -o
	var x1 := W + o
	var z0 := -o
	var z1 := D + o
	var zm := D * 0.5
	if kind == "hip" and W >= D * 0.6:
		var rx0 := minf(zm, W * 0.5)
		var rx1 := maxf(W - zm, W * 0.5)
		var nf := Vector3(0, D * 0.5 + o, -(hr - ye)).normalized()
		var nb := Vector3(0, D * 0.5 + o, (hr - ye)).normalized()
		var nl := Vector3(-(hr - ye), rx0 + o, 0).normalized()
		var nr := Vector3((hr - ye), W - rx1 + o, 0).normalized()
		m.quad(Vector3(x0, ye, z0), Vector3(x1, ye, z0), Vector3(rx1, hr, zm), Vector3(rx0, hr, zm), nf, "roof")
		m.quad(Vector3(x1, ye, z1), Vector3(x0, ye, z1), Vector3(rx0, hr, zm), Vector3(rx1, hr, zm), nb, "roof")
		m.tri(Vector3(x0, ye, z1), Vector3(x0, ye, z0), Vector3(rx0, hr, zm), nl, "roof")
		m.tri(Vector3(x1, ye, z0), Vector3(x1, ye, z1), Vector3(rx1, hr, zm), nr, "roof")
		if not far:
			_eaves([[faces[0], true], [faces[1], true], [faces[2], true], [faces[3], true]], ye, o)
			m.paint(roof_col * 0.8, roof_kind)
			m.box(Vector3(rx0, hr - 0.04, zm - 0.12), Vector3(rx1, hr + 0.06, zm + 0.12), "roof")
			for hip in [[Vector3(x0, ye, z0), Vector3(rx0, hr, zm)], [Vector3(x1, ye, z0), Vector3(rx1, hr, zm)],
					[Vector3(x0, ye, z1), Vector3(rx0, hr, zm)], [Vector3(x1, ye, z1), Vector3(rx1, hr, zm)]]:
				m.strut(hip[0] + Vector3(0, 0.03, 0), hip[1] + Vector3(0, 0.03, 0), 0.2, 0.07, "roof")
		return
	if kind == "gambrel":
		var zb := D * 0.2
		var yb := h + zb * tan(deg_to_rad(62.0))
		var hr2 := yb + (zm - zb) * tan(deg_to_rad(24.0))
		var yel := h - o * tan(deg_to_rad(62.0))
		var n1 := Vector3(0, zb + o, -(yb - yel)).normalized()
		var n2 := Vector3(0, zm - zb, -(hr2 - yb)).normalized()
		for side in [0, 1]:
			var zs := 1.0 if side == 0 else -1.0
			var zE := z0 if side == 0 else z1
			var zB := zb if side == 0 else D - zb
			var na := Vector3(0, n1.y, n1.z * zs)
			var nb2 := Vector3(0, n2.y, n2.z * zs)
			m.quad(Vector3(x0, yel, zE), Vector3(x1, yel, zE), Vector3(x1, yb, zB), Vector3(x0, yb, zB), na, "roof")
			m.quad(Vector3(x0, yb, zB), Vector3(x1, yb, zB), Vector3(x1, hr2, zm), Vector3(x0, hr2, zm), nb2, "roof")
		# gable-end pentagons (wall material)
		m.paint(wall_col if not far else Color(wall_col.r, wall_col.g, wall_col.b, 1.0), wall_kind if not far else 20)
		for xx in [0.0, W]:
			var nx := Vector3.LEFT if xx == 0.0 else Vector3.RIGHT
			var pts := [Vector3(xx, h, 0), Vector3(xx, yb, zb), Vector3(xx, hr2, zm), Vector3(xx, yb, D - zb), Vector3(xx, h, D)]
			m.tri(pts[0], pts[1], pts[4], nx)
			m.tri(pts[1], pts[3], pts[4], nx)
			m.tri(pts[1], pts[2], pts[3], nx)
		if not far:
			_eaves([[faces[0], true], [faces[2], true]], yel, o)
			_rakes([0.0, zb, zm, D - zb, D], [yel + (o * tan(deg_to_rad(62.0))), yb, hr2, yb, yel + (o * tan(deg_to_rad(62.0)))], o)
			m.paint(roof_col * 0.8, roof_kind)
			m.box(Vector3(x0, hr2 - 0.04, zm - 0.1), Vector3(x1, hr2 + 0.05, zm + 0.1), "roof")
		return
	# gable (default)
	var ng := Vector3(0, zm + o, -(hr - ye)).normalized()
	m.quad(Vector3(x0, ye, z0), Vector3(x1, ye, z0), Vector3(x1, hr, zm), Vector3(x0, hr, zm), ng, "roof")
	m.quad(Vector3(x1, ye, z1), Vector3(x0, ye, z1), Vector3(x0, hr, zm), Vector3(x1, hr, zm), Vector3(0, ng.y, -ng.z), "roof")
	if far:
		m.color = Color(wall_col.r, wall_col.g, wall_col.b, 1.0)
		m.tri(Vector3(0, h, 0), Vector3(0, h, D), Vector3(0, hr, zm), Vector3.LEFT)
		m.tri(Vector3(W, h, 0), Vector3(W, h, D), Vector3(W, hr, zm), Vector3.RIGHT)
		return
	_eaves([[faces[0], true], [faces[2], true]], ye, o)
	_rakes([0.0, zm, D], [h, hr, h], o)
	m.paint(roof_col * 0.8, roof_kind)
	m.box(Vector3(x0, hr - 0.04, zm - 0.12), Vector3(x1, hr + 0.06, zm + 0.12), "roof")
	# dormers on attic houses
	if style == "house" and bool(bd.get("attic", false)) and W > 9.0 and rng.randf() < 0.5:
		var nd := 2 if W < 13.0 else 3
		for i in nd:
			_dormer(W * (i + 1) / (nd + 1), hr, ye, o)


func _gable_end(f: Face) -> void:
	var kind: String = fac.get("roof", "gable")
	if kind != "gable" and not (kind == "hip" and W < D * 0.6):
		return
	var tn := tan(pitch)
	var hr := h + (D * 0.5) * tn
	m.group = "main"
	m.paint(wall_col, wall_kind)
	m.tri(f.p(0, h, 0), f.p(f.L, h, 0), f.p(f.L * 0.5, hr, 0), f.n)
	# attic vent
	if q >= 1:
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		var vy := h + (hr - h) * 0.45
		_fb(f, f.L * 0.5 - 0.35, f.L * 0.5 + 0.35, vy - 0.3, vy + 0.3, 0, 0.04)
		m.group = "fine"
		m.paint(trim_col * 0.75, Mesher.KIND_SMOOTH)
		for k in 6:
			var yy := vy - 0.24 + k * 0.09
			_fb(f, f.L * 0.5 - 0.28, f.L * 0.5 + 0.28, yy, yy + 0.035, 0.04, 0.07)
		m.group = "main"


## Fascia, soffit and gutter along the eaves of the given faces.
func _eaves(list: Array, ye: float, o: float) -> void:
	for e in list:
		var f: Face = e[0]
		m.group = "main"
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		# fascia board (wraps the overhang corners)
		_fb(f, -o, f.L + o, ye - 0.2, ye + 0.02, o - 0.03, o)
		# soffit
		m.paint(trim_col * 0.85, Mesher.KIND_SMOOTH)
		m.quad(f.p(-o, h - 0.02, 0), f.p(f.L + o, h - 0.02, 0), f.p(f.L + o, ye - 0.18, o - 0.03), f.p(-o, ye - 0.18, o - 0.03), Vector3.DOWN, "wall")
		# frieze board
		_fb(f, 0, f.L, h - 0.25, h - 0.02, 0, 0.025)
		# gutter
		var gc := pal("MULLION_WHITE") if style == "house" else (pal("COPPER_PATINA") if style == "historic" else metal_col)
		m.paint(gc, Mesher.KIND_SMOOTH)
		_fb(f, -o, f.L + o, ye - 0.15, ye - 0.03, o, o + 0.13, "metal")
		if f.idx == 0 or f.idx == 2:
			for s in [0.12, f.L - 0.12]:
				_downspout(f, s, ye - 0.1, o + 0.08)
		if q >= 2 and f.idx % 2 == 0:
			m.group = "fine"
			m.paint(gc * 0.8, Mesher.KIND_SMOOTH)
			var x := -o + 0.6
			while x < f.L + o - 0.3:
				_fb(f, x, x + 0.02, ye - 0.04, ye - 0.02, o, o + 0.13, "metal")
				x += 0.75
		if style == "historic" and fac.get("cornice", "") == "dentil" and q >= 1:
			m.group = "fine"
			m.paint(trim_col, Mesher.KIND_SMOOTH)
			var s := 0.06
			while s < f.L - 0.06:
				_fb(f, s, s + 0.06, h - 0.2, h - 0.11, 0.025, 0.1)
				s += 0.12
		m.group = "main"


## Rake boards along the gable ends: profile given as z stations and heights (on the wall line).
func _rakes(zs: Array, ys: Array, o: float) -> void:
	m.group = "main"
	m.paint(trim_col, Mesher.KIND_SMOOTH)
	for xx in [-o, W + o]:
		for i in zs.size() - 1:
			var a := Vector3(xx, ys[i], zs[i])
			var b := Vector3(xx, ys[i + 1], zs[i + 1])
			if i == 0:
				a = Vector3(xx, ys[0] - (ys[1] - ys[0]) / maxf(zs[1] - zs[0], 0.01) * o, zs[0] - o)
			if i == zs.size() - 2:
				b = Vector3(xx, ys[i + 1] - (ys[i] - ys[i + 1]) / maxf(zs[i + 1] - zs[i], 0.01) * o, zs[i + 1] + o)
			m.strut(a + Vector3(0, -0.06, 0), b + Vector3(0, -0.06, 0), 0.05, 0.2, "wall")
	# rake soffits (underside of the gable overhang)
	m.paint(trim_col * 0.85, Mesher.KIND_SMOOTH)
	for side in [[-o, 0.0], [W, W + o]]:
		for i in zs.size() - 1:
			var y0: float = ys[i] - 0.15
			var y1: float = ys[i + 1] - 0.15
			m.quad(Vector3(side[0], y0, zs[i]), Vector3(side[1], y0, zs[i]), Vector3(side[1], y1, zs[i + 1]), Vector3(side[0], y1, zs[i + 1]), Vector3.DOWN, "wall")


func _dormer(xc: float, hr: float, ye: float, o: float) -> void:
	var tn := tan(pitch)
	var w := 1.4
	var zf := 1.0   # dormer face sits 1 m behind the front wall line
	var yb := h + zf * tn
	var yt := yb + 1.5
	var z_back := (yt + 0.5 - h) / tn
	m.group = "main"
	m.paint(wall_col, wall_kind)
	m.box(Vector3(xc - w * 0.5, yb - 0.2, zf), Vector3(xc + w * 0.5, yt, minf(z_back, D * 0.5)), "wall", 1 | 2 | 16)
	m.paint(roof_col, roof_kind)
	var nl := Vector3(-0.6, 0.8, 0).normalized()
	m.quad(Vector3(xc - w * 0.5 - 0.15, yt, zf - 0.2), Vector3(xc, yt + 0.5, zf - 0.2), Vector3(xc, yt + 0.5, minf(z_back, D * 0.5)), Vector3(xc - w * 0.5 - 0.15, yt, minf(z_back, D * 0.5)), nl, "roof")
	m.quad(Vector3(xc + w * 0.5 + 0.15, yt, zf - 0.2), Vector3(xc, yt + 0.5, zf - 0.2), Vector3(xc, yt + 0.5, minf(z_back, D * 0.5)), Vector3(xc + w * 0.5 + 0.15, yt, minf(z_back, D * 0.5)), Vector3(0.6, 0.8, 0).normalized(), "roof")
	m.paint(wall_col, wall_kind)
	m.tri(Vector3(xc - w * 0.5, yt, zf), Vector3(xc + w * 0.5, yt, zf), Vector3(xc, yt + 0.45, zf), Vector3.FORWARD)
	# dormer window
	var df := Face.new(Vector3(xc - w * 0.5, 0, zf), Vector3(1, 0, 0), Vector3(0, 0, -1), w, 0)
	var g0 := yb + 0.15
	var g1 := yt - 0.15
	_glass(df, 0.3, w - 0.3, g0, g1, -0.01, false, 0.6, 2.2, "glass")
	m.group = "main"
	m.paint(trim_col, Mesher.KIND_SMOOTH)
	_fb(df, 0.2, 0.3, g0, g1, -0.02, 0.03)
	_fb(df, w - 0.3, w - 0.2, g0, g1, -0.02, 0.03)
	_fb(df, 0.2, w - 0.2, g1, g1 + 0.1, -0.02, 0.03)
	_fb(df, 0.2, w - 0.2, g0 - 0.08, g0, -0.02, 0.06)
	_fb(df, 0.3, w - 0.3, (g0 + g1) * 0.5 - 0.025, (g0 + g1) * 0.5 + 0.025, -0.02, 0.01)


func _chimney() -> void:
	var tn := tan(pitch)
	var hr := h + (D * 0.5) * tn
	var x0 := -0.75 if rng.randf() < 0.5 else W + 0.0
	var zc := D * rng.randf_range(0.35, 0.65)
	var top := hr + 0.9
	m.group = "main"
	m.paint(pal(["BRICK_DOWNTOWN_A", "BRICK_DOWNTOWN_C", "BRICK_CAMPUS_A"][hash(id + "ch") % 3]), Mesher.KIND_BRICK)
	m.box(Vector3(x0, -2.0, zc - 0.5), Vector3(x0 + 0.75, 1.9, zc + 0.5), "wall", 59)
	# shoulders
	m.quad(Vector3(x0, 1.9, zc - 0.5), Vector3(x0 + 0.75, 1.9, zc - 0.5), Vector3(x0 + 0.75, 2.4, zc - 0.32), Vector3(x0, 2.4, zc - 0.32), Vector3(0, 0.34, -0.94).normalized(), "wall")
	m.quad(Vector3(x0, 1.9, zc + 0.5), Vector3(x0 + 0.75, 1.9, zc + 0.5), Vector3(x0 + 0.75, 2.4, zc + 0.32), Vector3(x0, 2.4, zc + 0.32), Vector3(0, 0.34, 0.94).normalized(), "wall")
	var xs := x0 + 0.06 if x0 < 0.0 else x0
	m.box(Vector3(xs, 2.4, zc - 0.32), Vector3(xs + 0.69, top, zc + 0.32), "wall", 59)
	m.paint(pal("CONCRETE_AGED"), Mesher.KIND_CONCRETE)
	m.box(Vector3(xs - 0.05, top, zc - 0.37), Vector3(xs + 0.74, top + 0.1, zc + 0.37))
	if q >= 1:
		m.group = "fine"
		m.paint(pal("TERRAZZO_FLECK_C", Color(0.4, 0.4, 0.4)), Mesher.KIND_SMOOTH)
		m.cyl(Vector3(xs + 0.35, top + 0.1, zc), 0.1, 0.35, 8)


func _porch(f: Face) -> void:
	# front porch across the middle of the house, around the front door
	var door_s := f.L * 0.5
	for o in openings[0]:
		if o["type"] == "door" and o["y"] < 0.4:
			door_s = o["s"]
	var a := clampf(door_s - 2.6, 0.3, f.L * 0.5)
	var b := clampf(door_s + 2.6, f.L * 0.5, f.L - 0.3)
	if b - a < 3.0:
		return
	var dep := 2.4
	var deck := -0.02
	var roof_y := minf(2.95, floors[0]["ftf"] + 0.05)
	m.group = "main"
	m.paint(pal("OAK_FLOOR") * 0.7, Mesher.KIND_WOOD)
	_fb(f, a, b, deck - 0.08, deck, 0, dep)
	m.paint(trim_col, Mesher.KIND_SMOOTH)
	_fb(f, a, b, -2.0, deck - 0.08, dep - 0.04, dep, "wall", 63)   # skirt
	m.paint(pal("BRICK_DOWNTOWN_A") * 0.9, Mesher.KIND_BRICK)
	for s in [a, b - 0.3]:
		_fb(f, s, s + 0.3, -2.0, deck - 0.08, dep - 0.34, dep - 0.04)   # brick piers
	# steps
	m.paint(pal("OAK_FLOOR") * 0.65, Mesher.KIND_WOOD)
	var sw := 1.4
	_fb(f, door_s - sw * 0.5, door_s + sw * 0.5, -2.0, -0.19, dep, dep + 0.3)
	_fb(f, door_s - sw * 0.5, door_s + sw * 0.5, -2.0, -0.36, dep + 0.3, dep + 0.6)
	# posts / columns
	m.paint(pal("COLUMN_WHITE"), Mesher.KIND_SMOOTH)
	var np := maxi(2, int((b - a) / 2.4) + 1)
	var posts: Array = []
	for i in np:
		var s := a + 0.1 + (b - a - 0.2) * i / (np - 1)
		posts.append(s)
		_fb(f, s - 0.09, s + 0.09, deck, roof_y - 0.25, dep - 0.28, dep - 0.1)
		_fb(f, s - 0.13, s + 0.13, deck, deck + 0.12, dep - 0.32, dep - 0.06)
		_fb(f, s - 0.13, s + 0.13, roof_y - 0.33, roof_y - 0.25, dep - 0.32, dep - 0.06)
	# beam + roof
	m.paint(trim_col, Mesher.KIND_SMOOTH)
	_fb(f, a - 0.05, b + 0.05, roof_y - 0.25, roof_y, dep - 0.32, dep + 0.05)
	m.paint(trim_col * 0.9, Mesher.KIND_SMOOTH)
	m.quad(f.p(a, roof_y - 0.02, 0), f.p(b, roof_y - 0.02, 0), f.p(b, roof_y - 0.25, dep), f.p(a, roof_y - 0.25, dep), Vector3.DOWN, "wall")
	m.paint(roof_col, roof_kind)
	var rn := (UP * dep + f.n * 0.45).normalized()
	m.quad(f.p(a - 0.25, roof_y + 0.45, 0), f.p(b + 0.25, roof_y + 0.45, 0), f.p(b + 0.25, roof_y, dep + 0.35), f.p(a - 0.25, roof_y, dep + 0.35), rn, "roof")
	m.paint(trim_col, Mesher.KIND_SMOOTH)
	_fb(f, a - 0.25, b + 0.25, roof_y - 0.12, roof_y + 0.02, dep + 0.3, dep + 0.36)
	m.tri(f.p(a - 0.25, roof_y + 0.45, 0), f.p(a - 0.25, roof_y, dep + 0.35), f.p(a - 0.25, roof_y - 0.1, 0), -f.a)
	m.tri(f.p(b + 0.25, roof_y + 0.45, 0), f.p(b + 0.25, roof_y, dep + 0.35), f.p(b + 0.25, roof_y - 0.1, 0), f.a)
	# porch light by the door
	m.paint(pal("IRON_BLACK"), Mesher.KIND_SMOOTH)
	_fb(f, door_s + 0.65, door_s + 0.8, 1.65, 1.95, 0, 0.12, "metal")
	# railings with balusters (not across the steps)
	if q >= 1:
		m.group = "fine"
		m.paint(trim_col, Mesher.KIND_SMOOTH)
		for i in posts.size() - 1:
			var p0: float = posts[i] + 0.09
			var p1: float = posts[i + 1] - 0.09
			if door_s > p0 - 0.1 and door_s < p1 + 0.1:
				continue
			_fb(f, p0, p1, deck + 0.85, deck + 0.92, dep - 0.24, dep - 0.14)
			_fb(f, p0, p1, deck + 0.08, deck + 0.14, dep - 0.22, dep - 0.16)
			var n := int((p1 - p0) / 0.12)
			for k in range(1, n):
				var s := p0 + (p1 - p0) * k / n
				_fb(f, s - 0.02, s + 0.02, deck + 0.14, deck + 0.85, dep - 0.21, dep - 0.17)
		for side in [a, b]:
			var sd := 1.0 if side == a else -1.0
			_fb(f, side + sd * 0.02 - 0.03, side + sd * 0.02 + 0.03, deck + 0.85, deck + 0.92, 0.0, dep - 0.28)
			var n2 := int((dep - 0.3) / 0.12)
			for k in range(1, n2):
				var d := (dep - 0.3) * k / n2
				_fb(f, side + sd * 0.02 - 0.02, side + sd * 0.02 + 0.02, deck + 0.1, deck + 0.85, d - 0.02, d + 0.02)
		m.group = "main"


# ------------------------------------------------------------------------------------- services
func _utilities() -> void:
	# side + rear clutter (CLAUDE.md §5: meters, conduit, vents, condensers, cameras)
	var sides := [faces[2], faces[1] if rng.randf() < 0.5 else faces[3]]
	for f: Face in sides:
		var s := _free_s(f, 1.6)
		if s < 0.0:
			continue
		m.group = "main"
		# electric meter + conduit to the roof line
		m.paint(metal_col, Mesher.KIND_SMOOTH)
		_fb(f, s, s + 0.3, 1.35, 1.8, 0, 0.13, "metal")
		m.paint(metal_col * 0.8, Mesher.KIND_SMOOTH)
		_fb(f, s + 0.1, s + 0.2, 1.8, h - 0.4, 0.02, 0.06, "metal")
		_fb(f, s - 0.2, s + 0.5, 1.95, 2.4, 0, 0.15, "metal")   # service disconnect
		# gas meter with riser
		m.paint(pal("TRIM_WHITE_AGED") * 0.85, Mesher.KIND_SMOOTH)
		_fb(f, s + 0.75, s + 1.1, 0.15, 0.6, 0.08, 0.32, "metal")
		m.paint(pal("MARKING_YELLOW") * 0.8, Mesher.KIND_SMOOTH)
		_fb(f, s + 0.88, s + 0.94, -0.3, 0.15, 0.17, 0.23, "metal")
		_fb(f, s + 0.88, s + 0.94, 0.6, 0.75, 0.0, 0.23, "metal")
		if q >= 1:
			m.group = "fine"
			m.paint(pal("GLASS_TINT", Color(0.6, 0.7, 0.75)), Mesher.KIND_SMOOTH)
			_fb(f, s + 0.08, s + 0.22, 1.55, 1.69, 0.13, 0.17, "metal")   # meter dial
			m.paint(metal_col * 0.7, Mesher.KIND_SMOOTH)
			var y := 2.6
			while y < h - 0.5:
				_fb(f, s + 0.07, s + 0.23, y, y + 0.03, 0.0, 0.07, "metal")
				y += 1.8
			# hose bib
			m.paint(pal("BRASS"), Mesher.KIND_SMOOTH)
			_fb(f, s + 1.4, s + 1.47, 0.45, 0.52, 0.0, 0.12, "metal")
			if style == "house":
				# dryer vent
				m.paint(trim_col, Mesher.KIND_SMOOTH)
				_fb(f, s + 1.9, s + 2.1, 0.5, 0.7, 0, 0.09, "metal")
			else:
				# security camera on a bracket
				m.paint(pal("TRIM_WHITE"), Mesher.KIND_SMOOTH)
				_fb(f, f.L - 0.5, f.L - 0.45, 3.0, 3.1, 0, 0.25, "metal")
				_fb(f, f.L - 0.56, f.L - 0.39, 2.9, 3.02, 0.15, 0.42, "metal")
			m.group = "main"
		# AC condenser on a pad (houses / small buildings)
		if style == "house" or (style == "commercial" and not flat):
			var cs := s + 2.4
			if cs + 0.9 < f.L:
				m.paint(pal("CONCRETE_AGED"), Mesher.KIND_CONCRETE)
				_fb(f, cs - 0.1, cs + 0.9, -0.5, -0.05, 0.25, 1.25)
				m.paint(pal("TRIM_WHITE_AGED") * 0.9, Mesher.KIND_SMOOTH)
				_fb(f, cs, cs + 0.8, -0.05, 0.75, 0.35, 1.15, "metal")
				if q >= 1:
					m.group = "fine"
					m.paint(pal("SHUTTER_BLACK"), Mesher.KIND_SMOOTH)
					var c := f.p(cs + 0.4, 0.75, 0.75)
					m.cyl(c, 0.3, 0.025, 12)
					m.paint(metal_col * 0.6, Mesher.KIND_SMOOTH)
					for k in 9:
						var yy := 0.02 + k * 0.08
						_fb(f, cs + 0.03, cs + 0.77, yy, yy + 0.02, 1.15, 1.17, "metal", 8 | 16 | 32)
					_fb(f, cs + 0.3, cs + 0.36, 0.2, 0.3, 0.0, 0.35, "metal")   # line set
					m.group = "main"
	# fire department connection on bigger public / commercial buildings
	if q >= 1 and style != "house" and floors.size() >= 3:
		var f: Face = faces[0]
		var s := 0.25 if not storefront else 0.2
		m.group = "fine"
		m.paint(pal("BRASS"), Mesher.KIND_SMOOTH)
		var c := f.p(s, 0.75, 0.08)
		m.box(c - Vector3(0.05, 0.05, 0.05), c + Vector3(0.05, 0.05, 0.05), "metal")


## A stretch of facade [s, s + w] free of openings at ground level, or -1.
func _free_s(f: Face, w: float) -> float:
	var busy: Array = []
	for o in openings[f.idx]:
		if o["y"] < 0.5:
			busy.append([o["s"] - o["w"] * 0.5 - 0.3, o["s"] + o["w"] * 0.5 + 0.3])
	var spans := _minus_spans(0.6, f.L - 0.6, busy)
	var best := -1.0
	for sp in spans:
		if sp[1] - sp[0] >= w + 2.6:
			return sp[0] + 0.2
		if sp[1] - sp[0] >= w and best < 0.0:
			best = sp[0]
	return best


# ------------------------------------------------------------------------------------- fire escape
func _fire_escape(f: Face) -> void:
	var sc := f.L * 0.5
	for o in openings[f.idx]:
		if o["type"] == "window" and o["y"] > 1.0:
			sc = clampf(o["s"], 2.0, f.L - 2.0)
			break
	if f.L < 4.5:
		return
	var iron := pal("IRON_BLACK")
	var dep := 1.05
	var a := sc - 1.6
	var b := sc + 1.6
	for i in range(1, floors.size()):
		var fy: float = floors[i]["y"]
		m.group = "main"
		m.paint(iron, Mesher.KIND_SMOOTH)
		_fb(f, a, b, fy - 0.06, fy, 0.05, dep, "metal")   # grate platform
		_fb(f, a, b, fy + 1.0, fy + 1.04, dep - 0.04, dep, "metal")
		_fb(f, a, a + 0.04, fy + 1.0, fy + 1.04, 0.05, dep, "metal")
		_fb(f, b - 0.04, b, fy + 1.0, fy + 1.04, 0.05, dep, "metal")
		for s in [a, b - 0.04]:
			_fb(f, s, s + 0.04, fy, fy + 1.0, dep - 0.04, dep, "metal")
		m.strut(f.p(a + 0.2, fy - 0.05, 0.02), f.p(a + 0.2, fy - 0.7, 0.02) + f.n * 0.0 + Vector3(0, 0, 0), 0.04, 0.04)
		m.strut(f.p(a + 0.2, fy - 0.7, 0.03), f.p(a + 0.2, fy - 0.06, dep - 0.05), 0.04, 0.04)
		m.strut(f.p(b - 0.2, fy - 0.7, 0.03), f.p(b - 0.2, fy - 0.06, dep - 0.05), 0.04, 0.04)
		if q >= 1:
			m.group = "fine"
			var n := int((b - a) / 0.15)
			for k in range(1, n):
				var s := a + (b - a) * k / n
				_fb(f, s - 0.008, s + 0.008, fy, fy + 1.0, dep - 0.03, dep - 0.014, "metal")
			_fb(f, a, b, fy + 0.5, fy + 0.53, dep - 0.035, dep - 0.005, "metal")
		# stair up to the next platform
		if i + 1 < floors.size():
			var fy2: float = floors[i + 1]["y"]
			m.group = "main"
			var sb := f.p(b - 0.25, fy, 0.55)
			var st := f.p(a + 0.75, fy2, 0.55)
			for dd in [0.18, 0.92]:
				m.strut(f.p(b - 0.25, fy, dd), f.p(a + 0.75, fy2, dd), 0.03, 0.18)
			m.strut(f.p(b - 0.25, fy + 0.9, dep - 0.08), f.p(a + 0.75, fy2 + 0.9, dep - 0.08), 0.03, 0.03)
			if q >= 1:
				m.group = "fine"
				var steps := int((fy2 - fy) / 0.2)
				for k in range(1, steps):
					var t := float(k) / steps
					var p := sb.lerp(st, t)
					m.box(p - Vector3(0.0, 0.015, 0.0) - (f.n * 0.37) - f.a * 0.11, p + Vector3(0, 0.015, 0) + f.n * 0.37 + f.a * 0.11, "metal")
	# drop ladder below the first platform
	if floors.size() >= 2:
		var fy1: float = floors[1]["y"]
		m.group = "main"
		m.paint(iron, Mesher.KIND_SMOOTH)
		var ls := b - 0.5
		_fb(f, ls - 0.22, ls - 0.19, 1.9, fy1, dep - 0.3, dep - 0.27, "metal")
		_fb(f, ls + 0.19, ls + 0.22, 1.9, fy1, dep - 0.3, dep - 0.27, "metal")
		if q >= 1:
			m.group = "fine"
			var y := 2.0
			while y < fy1:
				_fb(f, ls - 0.19, ls + 0.19, y, y + 0.025, dep - 0.3, dep - 0.27, "metal")
				y += 0.3


# ------------------------------------------------------------------------------------- cornices
func _cornice(f: Face) -> void:
	if not flat:
		return
	var kind: String = fac.get("cornice", "box")
	var top := h + parapet
	if style == "modern" or style == "parking" or kind == "coping" or kind == "none":
		return
	var main_face := f.idx == 0 or (style == "historic")
	if not main_face:
		return
	m.group = "main"
	var cc := trim_col
	if style == "commercial":
		cc = [trim_col, pal("TRIM_WHITE_AGED"), pal("SHUTTER_GREEN"), pal("SHUTTER_BLACK"), wall_col * 0.75, pal("LIMESTONE_TRIM")][hash(id + "cc") % 6]
	m.paint(cc, Mesher.KIND_SMOOTH)
	var y := top
	# profile from the top down: [height, projection]
	var prof := [[0.06, 0.42], [0.2, 0.36], [0.08, 0.2], [0.35, 0.05]]
	if kind == "italianate":
		prof = [[0.07, 0.62], [0.22, 0.55], [0.06, 0.3], [0.55, 0.06]]
	var ret := 0.4
	for p in prof:
		_fb(f, -ret if f.idx == 0 else -0.05, f.L + (ret if f.idx == 0 else 0.05), y - p[0], y, 0, p[1])
		y -= p[0]
	var corona_bot: float = top - prof[0][0] - prof[1][0]
	if q < 1:
		return
	m.group = "fine"
	m.paint(cc * 0.95, Mesher.KIND_SMOOTH)
	if kind == "italianate":
		# paired scroll brackets under the corona + frieze panels
		var n := maxi(2, int(f.L / 1.2))
		for i in n + 1:
			var s := 0.25 + (f.L - 0.5) * i / n
			_fb(f, s - 0.07, s + 0.07, corona_bot - 0.52, corona_bot, 0.06, 0.28)
			_fb(f, s - 0.07, s + 0.07, corona_bot - 0.14, corona_bot, 0.28, 0.5)
			_fb(f, s - 0.06, s + 0.06, corona_bot - 0.62, corona_bot - 0.52, 0.06, 0.16)
		for i in n:
			var s0 := 0.25 + (f.L - 0.5) * i / n + 0.15
			var s1 := 0.25 + (f.L - 0.5) * (i + 1) / n - 0.15
			_fb(f, s0, s1, corona_bot - 0.45, corona_bot - 0.12, 0.06, 0.085)
	elif kind == "dentil" or kind == "box":
		var s := 0.0
		while s < f.L - 0.06:
			_fb(f, s, s + 0.06, corona_bot - 0.09, corona_bot, 0.2, 0.28)
			s += 0.12
