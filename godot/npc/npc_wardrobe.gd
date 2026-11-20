class_name NpcWardrobe
extends RefCounted
## Clothes and shoes as separate skinned meshes over the MakeHuman body.
## Each garment is cut from the body surface (by body part, height and angle),
## pushed out by its thickness, and keeps the body's bones and blend shapes, so
## it follows weight, muscle and the walk. Skirts and dresses add a flared tube.
## 10 outerwear, 20 shirts, 20 pants/skirts/dresses, 10 shoes.

const SLOTS := ["under_bottom", "under_top", "shoes", "bottom", "top", "outer"]
const UNDER := ["under_bottom", "under_top"]
# Laplacian smoothing passes per slot: clothes drape over the body instead of
# showing every muscle; shoes lose the toes.
const SMOOTH := {"under_bottom": 0, "under_top": 0, "shoes": 15, "bottom": 8, "top": 16, "outer": 20}
# Minimum distance off the skin per layer, so layers never cross each other.
const MIN_OFF := {"under_bottom": 0.0015, "under_top": 0.0028, "shoes": 0.006, "bottom": 0.0045, "top": 0.0075, "outer": 0.013}
# Patterns: 0 solid, 1 stripes, 2 plaid, 3 denim, 4 knit, 5 leather.
static var ITEMS := _items()
static var _cache := {}
static var _shader: Shader


static func _it(id: String, name: String, slot: String, c: String, c2: String, pattern: int, p: Dictionary) -> Dictionary:
	var d := {"id": id, "name": name, "slot": slot, "color": Color(c), "color2": Color(c2), "pattern": pattern,
		"thick": 0.004, "hem": 0.555, "neck": 0.815, "sleeve": 0.72, "vneck": 0.0, "turtle": false, "open": false,
		"coat": 0.0, "waist": 0.6, "leg_hem": 0.04, "skirt": 0.0, "flare": 1.25, "collar": 0.045, "sex": "any", "sport": false}
	d.merge(p, true)
	return d


static func _items() -> Array:
	return [
		# Outerwear (10)
		_it("denim_jacket", "Denim jacket", "outer", "#4A6A8F", "#B08D57", 3, {"thick": 0.009, "hem": 0.54, "sleeve": 0.49, "open": true}),
		_it("bomber", "Bomber jacket", "outer", "#2F3F33", "#1A1A1A", 0, {"thick": 0.011, "hem": 0.56, "sleeve": 0.49, "open": true}),
		_it("hoodie", "Zip hoodie", "outer", "#7C7F84", "#5F646A", 4, {"thick": 0.010, "hem": 0.535, "sleeve": 0.49, "turtle": true}),
		_it("puffer", "Puffer jacket", "outer", "#142B4E", "#0E1E38", 0, {"thick": 0.022, "hem": 0.52, "sleeve": 0.49}),
		_it("rain_shell", "Rain shell", "outer", "#C9A227", "#3A3C3E", 0, {"thick": 0.009, "hem": 0.5, "sleeve": 0.48, "turtle": true}),
		_it("peacoat", "Wool peacoat", "outer", "#1E2633", "#B08D57", 4, {"thick": 0.013, "hem": 0.5, "sleeve": 0.49, "coat": 0.38}),
		_it("blazer", "Blazer", "outer", "#3A3C3E", "#1E1F1F", 4, {"thick": 0.008, "hem": 0.5, "sleeve": 0.49, "open": true}),
		_it("varsity", "ONSU varsity jacket", "outer", "#142B4E", "#80B4D9", 0, {"thick": 0.011, "hem": 0.555, "sleeve": 0.49}),
		_it("cardigan", "Cardigan", "outer", "#8E7A5E", "#6E5E48", 4, {"thick": 0.007, "hem": 0.5, "sleeve": 0.49, "open": true}),
		_it("trench", "Trench coat", "outer", "#B5A68A", "#8C7E62", 0, {"thick": 0.011, "hem": 0.5, "sleeve": 0.48, "coat": 0.30, "open": true}),
		# Shirts (20)
		_it("tee_white", "White tee", "top", "#F3F0E8", "#F3F0E8", 4, {}),
		_it("tee_black", "Black tee", "top", "#1E1F1F", "#1E1F1F", 4, {}),
		_it("tee_heaven", "ONSU tee", "top", "#80B4D9", "#142B4E", 4, {}),
		_it("tee_red", "Brick red tee", "top", "#8E3B2E", "#8E3B2E", 4, {}),
		_it("tee_olive", "Olive tee", "top", "#5E6B3A", "#5E6B3A", 4, {}),
		_it("vneck_gray", "Gray V-neck", "top", "#9A9A98", "#9A9A98", 4, {"vneck": 0.05}),
		_it("longsleeve_navy", "Navy long-sleeve", "top", "#142B4E", "#142B4E", 4, {"sleeve": 0.49}),
		_it("stripe_tee", "Striped tee", "top", "#F3F0E8", "#1F4E79", 1, {}),
		_it("polo_green", "Green polo", "top", "#2F5E3A", "#2F5E3A", 4, {"sleeve": 0.73, "vneck": 0.025}),
		_it("polo_pink", "Pink polo", "top", "#D98FA0", "#D98FA0", 4, {"sleeve": 0.73, "vneck": 0.025}),
		_it("oxford_blue", "Blue oxford shirt", "top", "#A9C4E2", "#A9C4E2", 0, {"sleeve": 0.49, "vneck": 0.03, "hem": 0.53}),
		_it("oxford_white", "White oxford shirt", "top", "#F4F2EC", "#F4F2EC", 0, {"sleeve": 0.49, "vneck": 0.03, "hem": 0.53}),
		_it("flannel_red", "Red flannel", "top", "#A8322A", "#1A1A1A", 2, {"sleeve": 0.49, "vneck": 0.03, "thick": 0.005}),
		_it("flannel_green", "Green flannel", "top", "#2F3F33", "#2B4E79", 2, {"sleeve": 0.49, "vneck": 0.03, "thick": 0.005}),
		_it("tank", "Tank top", "top", "#E9E4D8", "#E9E4D8", 4, {"sleeve": 2.0, "vneck": 0.04}),
		_it("henley", "Oatmeal henley", "top", "#CDBFA5", "#CDBFA5", 4, {"sleeve": 0.49, "vneck": 0.02}),
		_it("sweatshirt", "Crewneck sweatshirt", "top", "#5F646A", "#5F646A", 4, {"sleeve": 0.49, "thick": 0.007, "hem": 0.545}),
		_it("blouse", "Cream blouse", "top", "#F2E6D0", "#F2E6D0", 0, {"sleeve": 0.6, "vneck": 0.04, "sex": "female"}),
		_it("turtleneck", "Black turtleneck", "top", "#18191A", "#18191A", 4, {"sleeve": 0.49, "turtle": true}),
		_it("camisole", "Camisole", "top", "#B8577A", "#B8577A", 0, {"sleeve": 2.0, "vneck": 0.05, "sex": "female"}),
		# Pants, shorts, skirts, dresses (20)
		_it("jeans_dark", "Dark jeans", "bottom", "#24324A", "#B08D57", 3, {}),
		_it("jeans_light", "Light jeans", "bottom", "#6F8DB0", "#B08D57", 3, {}),
		_it("chinos_khaki", "Khaki chinos", "bottom", "#B9A57E", "#B9A57E", 0, {}),
		_it("chinos_navy", "Navy chinos", "bottom", "#1F2C44", "#1F2C44", 0, {}),
		_it("joggers", "Gray joggers", "bottom", "#7C7F84", "#7C7F84", 4, {"thick": 0.006, "leg_hem": 0.05}),
		_it("sweatpants", "ONSU sweatpants", "bottom", "#142B4E", "#80B4D9", 4, {"thick": 0.006, "leg_hem": 0.05}),
		_it("cargo_shorts", "Cargo shorts", "bottom", "#8A7B5E", "#8A7B5E", 0, {"leg_hem": 0.27, "thick": 0.006}),
		_it("denim_shorts", "Denim shorts", "bottom", "#6F8DB0", "#E9E4D8", 3, {"leg_hem": 0.40}),
		_it("athletic_shorts", "Athletic shorts", "bottom", "#1A1A1A", "#80B4D9", 0, {"leg_hem": 0.36, "thick": 0.005}),
		_it("slacks", "Charcoal slacks", "bottom", "#3A3C3E", "#3A3C3E", 0, {}),
		_it("corduroy", "Corduroy pants", "bottom", "#6B4A2A", "#6B4A2A", 1, {}),
		_it("leggings", "Black leggings", "bottom", "#18191A", "#18191A", 4, {"thick": 0.0025, "leg_hem": 0.045, "sex": "female"}),
		_it("skirt_pleated", "Pleated navy skirt", "bottom", "#142B4E", "#142B4E", 1, {"skirt": 0.36, "flare": 1.5, "sex": "female"}),
		_it("skirt_denim", "Denim mini skirt", "bottom", "#4A6A8F", "#B08D57", 3, {"skirt": 0.42, "flare": 1.12, "sex": "female"}),
		_it("skirt_midi", "Rust midi skirt", "bottom", "#9B4A2C", "#9B4A2C", 0, {"skirt": 0.2, "flare": 1.6, "sex": "female"}),
		_it("skirt_plaid", "Plaid skirt", "bottom", "#6B1F1A", "#2F3F33", 2, {"skirt": 0.38, "flare": 1.3, "sex": "female"}),
		_it("sundress", "Floral sundress", "bottom", "#E0B341", "#F3F0E8", 1, {"dress": true, "skirt": 0.3, "flare": 1.45, "sleeve": 2.0, "vneck": 0.05, "sex": "female"}),
		_it("shift_dress", "Black shift dress", "bottom", "#1E1F1F", "#1E1F1F", 0, {"dress": true, "skirt": 0.33, "flare": 1.15, "sleeve": 0.73, "sex": "female"}),
		_it("wrap_dress", "Green wrap dress", "bottom", "#2F5E3A", "#2F5E3A", 0, {"dress": true, "skirt": 0.26, "flare": 1.3, "sleeve": 0.6, "vneck": 0.06, "sex": "female"}),
		_it("sweater_dress", "Sweater dress", "bottom", "#B5A68A", "#B5A68A", 4, {"dress": true, "skirt": 0.31, "flare": 1.1, "sleeve": 0.49, "turtle": true, "thick": 0.006, "sex": "female"}),
		# Undergarments (separate pieces under everything)
		_it("briefs", "Briefs", "under_bottom", "#F1F0EB", "#5F646A", 4, {"thick": 0.0018, "uleg": 0.465, "uwaist": 0.565, "sex": "male"}),
		_it("boxer_briefs", "Boxer briefs", "under_bottom", "#1E1F1F", "#5F646A", 4, {"thick": 0.0018, "uleg": 0.40, "uwaist": 0.57, "sex": "male"}),
		_it("boxers", "Plaid boxers", "under_bottom", "#4C7A8C", "#F1F0EB", 2, {"thick": 0.004, "uleg": 0.39, "uwaist": 0.57, "sex": "male"}),
		_it("panties", "Panties", "under_bottom", "#E8C9B8", "#D9A99A", 4, {"thick": 0.0015, "uleg": 0.47, "uwaist": 0.55, "sex": "female"}),
		_it("boyshorts", "Boy shorts", "under_bottom", "#1E1F1F", "#3A3C3E", 4, {"thick": 0.0015, "uleg": 0.445, "uwaist": 0.555, "sex": "female"}),
		_it("bra", "Bra", "under_top", "#E8C9B8", "#D9A99A", 0, {"thick": 0.0025, "sex": "female"}),
		_it("bra_black", "Black bra", "under_top", "#1E1F1F", "#1E1F1F", 0, {"thick": 0.0025, "sex": "female"}),
		_it("sports_bra", "Sports bra", "under_top", "#5F646A", "#80B4D9", 4, {"thick": 0.003, "sport": true, "sex": "female"}),
		_it("undershirt", "White undershirt", "under_top", "#F4F2EC", "#F4F2EC", 4, {"thick": 0.0015, "hem": 0.545, "sleeve": 0.74, "neck": 0.818, "sex": "male"}),
		_it("tank_undershirt", "Tank undershirt", "under_top", "#F4F2EC", "#F4F2EC", 4, {"thick": 0.0015, "hem": 0.545, "sleeve": 2.0, "vneck": 0.03, "sex": "male"}),
		# Shoes (10)
		_it("sneaker_white", "White sneakers", "shoes", "#F1F0EB", "#D9D9D4", 5, {"thick": 0.008, "collar": 0.05}),
		_it("sneaker_black", "Black sneakers", "shoes", "#1E1F1F", "#F1F0EB", 5, {"thick": 0.008, "collar": 0.05}),
		_it("runner", "Running shoes", "shoes", "#4FC3FF", "#F1F0EB", 4, {"thick": 0.009, "collar": 0.05}),
		_it("hightop", "Canvas high-tops", "shoes", "#A8322A", "#F1F0EB", 4, {"thick": 0.007, "collar": 0.075}),
		_it("loafer", "Leather loafers", "shoes", "#4F3524", "#2B2422", 5, {"thick": 0.006, "collar": 0.035}),
		_it("work_boot", "Work boots", "shoes", "#8C5A2B", "#2B2422", 5, {"thick": 0.010, "collar": 0.12}),
		_it("chelsea", "Chelsea boots", "shoes", "#18191A", "#18191A", 5, {"thick": 0.007, "collar": 0.1}),
		_it("oxford_shoe", "Oxford dress shoes", "shoes", "#2B1A12", "#18191A", 5, {"thick": 0.006, "collar": 0.04}),
		_it("rain_boot", "Rain boots", "shoes", "#23382C", "#18191A", 5, {"thick": 0.008, "collar": 0.2}),
		_it("flats", "Ballet flats", "shoes", "#1E1F1F", "#1E1F1F", 5, {"thick": 0.005, "collar": 0.025, "sex": "female"}),
	]


static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}


static func items_for(slot: String, sex: String) -> Array:
	return ITEMS.filter(func(it): return it.slot == slot and (it.sex == "any" or it.sex == sex))


## Picks an outfit for a record, steady per NPC: {shoes, bottom, top, outer} item ids
## ("" = none). rec.wardrobe overrides any slot.
static func outfit_for(rec: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(rec.get("npc_id", "x")) + "wardrobe")
	var sex: String = rec.get("sex", "male")
	var out := {}
	for slot in SLOTS:
		var pool := items_for(slot, sex)
		if slot == "bottom" and sex == "female" and rng.randf() < 0.55:
			pool = pool.filter(func(it): return it.sex == "any")
		out[slot] = pool[rng.randi() % pool.size()].id
	if sex == "male" and rng.randf() < 0.65:
		out.under_top = ""
	if rng.randf() > 0.35:
		out.outer = ""
	if item(out.bottom).get("dress", false):
		out.top = ""
	out.merge(rec.get("wardrobe", {}), true)
	return out


## For a body vertex: x = how far the garment sits off the skin (m), y = the
## signed distance (in height fractions) inside the garment's edges. Vertices a
## little outside (y > -MARGIN) are kept so the shader can cut clean hems.
const MARGIN := 0.025
const NONE := Vector2(0.0, -1.0)


static func _cover(it: Dictionary, part: int, yn: float, df: float, x: float = 0.0) -> Vector2:
	var t: float = it.thick
	match it.slot:
		"under_bottom":
			if part == 0:
				return Vector2(t, it.uwaist - yn)
			if part == 1:
				return Vector2(t, yn - it.uleg)
		"under_top":
			if it.id.begins_with("bra") or it.id == "sports_bra":
				if part != 0:
					return NONE
				var front := clampf(1.0 - df / 75.0, 0.0, 1.0)
				# cups in front, a narrower band at the back
				var lo := lerpf(0.695, 0.672, front)
				var hi := lerpf(0.735, 0.775 if not it.sport else 0.79, front)
				var m := minf(yn - lo, hi - yn)
				# straps over the shoulders
				var ax := absf(x)
				var strap := minf(0.012 - absf(ax - 0.075), 0.82 - yn) / 3.0
				if it.sport:
					strap = minf(0.03 - absf(ax - 0.07), 0.82 - yn) / 3.0
				return Vector2(t, maxf(m, strap))
			return _upper(it, part, yn, df, t)
		"shoes":
			if part == 4:
				return Vector2(t, 1.0)
			if part == 1:
				return Vector2(t, it.collar - yn)
		"top", "outer":
			return _upper(it, part, yn, df, t)
		"bottom":
			if it.get("dress", false):
				var u := _upper(it, part, yn, df, t)
				if part == 0:
					var lower := Vector2(t * 1.4, 0.62 - yn)
					return u if u.y > lower.y else lower
				return u
			if part == 0:
				return Vector2(t * 1.3, it.waist - yn)
			if part == 1:
				if it.skirt > 0.0:
					return Vector2(t, yn - 0.44)
				var loose := 1.0 + 0.6 * clampf((yn - 0.3) / 0.2, 0.0, 1.0)
				return Vector2(t * loose, yn - it.leg_hem)
	return NONE


static func _upper(it: Dictionary, part: int, yn: float, df: float, t: float) -> Vector2:
	if part == 0:
		var top_y: float = it.neck - (it.vneck * clampf(1.0 - df / 25.0, 0.0, 1.0))
		var m := minf(yn - it.hem, top_y - yn)
		if it.open:
			m = minf(m, (df - 5.0) / 400.0)
		# looser over the belly and back than over the shoulders
		var loose := 1.0 + 0.8 * clampf((0.72 - yn) / 0.12, 0.0, 1.0)
		return Vector2(t * loose, m)
	if part == 2:
		return Vector2(t * 1.2, yn - it.sleeve)
	if part == 6:
		return Vector2(t, 0.86 - yn) if it.turtle else Vector2(t, it.neck - yn)
	return NONE


static func mesh(sex: String, id: String) -> ArrayMesh:
	var key := sex + ":" + id
	if not _cache.has(key):
		_cache[key] = _build(sex, item(id))
	return _cache[key]


static func material(it: Dictionary, tint = null) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://npc/npc_cloth.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("color", tint if tint is Color else it.color)
	m.set_shader_parameter("color2", it.color2)
	m.set_shader_parameter("pattern", it.pattern)
	m.set_shader_parameter("is_shoe", 1.0 if it.slot == "shoes" else 0.0)
	return m


static func _build(sex: String, it: Dictionary) -> ArrayMesh:
	var src: ArrayMesh = NpcBody.mesh_for(sex, 0)
	var a := src.surface_get_arrays(0)
	var shapes := src.surface_get_blend_shape_arrays(0)
	var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var UV: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var UV2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var n := V.size()
	var th := PackedFloat32Array()
	var mg := PackedFloat32Array()
	th.resize(n)
	mg.resize(n)
	for i in n:
		var part := int(floor(UV[i].x + 0.01))
		var cv := _cover(it, part, UV[i].y, absf(UV2[i].x * 360.0 - 270.0), V[i].x) if part <= 6 else NONE
		th[i] = cv.x
		mg[i] = cv.y
	var remap := PackedInt32Array()
	remap.resize(n)
	remap.fill(-1)
	var keep := PackedInt32Array()
	var idx := PackedInt32Array()
	for t in range(0, I.size(), 3):
		var m0 := mg[I[t]]
		var m1 := mg[I[t + 1]]
		var m2 := mg[I[t + 2]]
		if minf(m0, minf(m1, m2)) < -MARGIN or maxf(m0, maxf(m1, m2)) <= 0.0:
			continue
		for k in 3:
			var v := I[t + k]
			if remap[v] < 0:
				remap[v] = keep.size()
				keep.append(v)
			idx.append(remap[v])
	var out := _gather(keep, V, N, th, UV, UV2, B, W, idx)
	var ouv2: PackedVector2Array = out[Mesh.ARRAY_TEX_UV2]
	for j in keep.size():
		ouv2[j].y = mg[keep[j]]   # hem cut in the shader
	out[Mesh.ARRAY_TEX_UV2] = ouv2
	var out_shapes := []
	for s in shapes:
		out_shapes.append(_gather(keep, s[Mesh.ARRAY_VERTEX], s[Mesh.ARRAY_NORMAL], th, null, null, null, null, null))
	_drape(it, out, out_shapes, keep, V, N, th, UV, UV2)
	if it.skirt > 0.0 or it.coat > 0.0:
		_add_skirt(it, V, UV, src.get_blend_shape_count(), out, out_shapes)
	var m := ArrayMesh.new()
	m.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for i in src.get_blend_shape_count():
		m.add_blend_shape(src.get_blend_shape_name(i))
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, out_shapes)
	m.resource_name = "garment_%s_%s" % [it.id, sex]
	return m


static func _gather(keep: PackedInt32Array, V: PackedVector3Array, N: PackedVector3Array, th: PackedFloat32Array, UV, UV2, B, W, idx) -> Array:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	pv.resize(keep.size())
	pn.resize(keep.size())
	for j in keep.size():
		var v := keep[j]
		pv[j] = V[v] + N[v] * th[v]
		pn[j] = N[v]
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_NORMAL] = pn
	if UV != null:
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var b := PackedInt32Array()
		var w := PackedFloat32Array()
		uv.resize(keep.size())
		uv2.resize(keep.size())
		b.resize(keep.size() * 4)
		w.resize(keep.size() * 4)
		for j in keep.size():
			var v := keep[j]
			uv[j] = UV[v]
			uv2[j] = UV2[v]
			for k in 4:
				b[j * 4 + k] = B[v * 4 + k]
				w[j * 4 + k] = W[v * 4 + k]
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_BONES] = b
		arr[Mesh.ARRAY_WEIGHTS] = w
		arr[Mesh.ARRAY_INDEX] = idx
	return arr


## A flared tube from the hips to the hem, around both legs.
static func _add_skirt(it: Dictionary, V: PackedVector3Array, UV: PackedVector2Array, nshapes: int, out: Array, out_shapes: Array) -> void:
	var H := 0.0
	for p in V:
		H = maxf(H, p.y)
	var y0 := (0.52 if it.coat <= 0.0 else 0.5) * H
	var rx := 0.0
	var zmin := 1.0
	var zmax := -1.0
	for i in V.size():
		var part := int(floor(UV[i].x + 0.01))
		if (part == 0 or part == 1) and absf(V[i].y - y0) < 0.02 * H:
			rx = maxf(rx, absf(V[i].x))
			zmin = minf(zmin, V[i].z)
			zmax = maxf(zmax, V[i].z)
	var cz := (zmin + zmax) * 0.5
	var rz := (zmax - zmin) * 0.5
	rx += it.thick + 0.012
	rz += it.thick + 0.012
	var y1: float = (it.skirt if it.coat <= 0.0 else it.coat) * H
	var flare: float = it.flare if it.coat <= 0.0 else 1.12
	var rings := int((y0 - y1) / 0.02) + 1
	const SEG := 40
	var pv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = out[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = out[Mesh.ARRAY_TEX_UV2]
	var b: PackedInt32Array = out[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = out[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	var base := pv.size()
	var pelvis := NpcBodyMesh.B_PELVIS
	var shape_scale := {"fat": 1.12, "slim": 0.94}
	var ring_pts := []
	for r in rings + 1:
		var f := float(r) / rings
		var y := lerpf(y0, y1, f)
		var s := lerpf(1.0, flare, f)
		for k in SEG:
			var ang := TAU * k / SEG
			var d := Vector3(cos(ang) * rx * s, 0, sin(ang) * rz * s)
			pv.append(Vector3(d.x, y, cz + d.z))
			pn.append(Vector3(cos(ang) * rz, 0.15, sin(ang) * rx).normalized())
			uv.append(Vector2(12.0, y / H))
			uv2.append(Vector2(fposmod(ang / TAU, 1.0), 1.0))
			# the hem follows the legs: left half with the left thigh, right with the right
			var u := clampf(cos(ang), -1.0, 1.0)
			var wl := 0.9 * f * (0.5 - 0.5 * u)
			var wr := 0.9 * f * (0.5 + 0.5 * u)
			b.append_array([pelvis, NpcBodyMesh.B_THIGH_L, NpcBodyMesh.B_THIGH_R, 0])
			w.append_array([1.0 - wl - wr, wl, wr, 0.0])
			if r < rings:
				var a0 := base + r * SEG + k
				var a1 := base + r * SEG + (k + 1) % SEG
				idx.append_array([a0, a1 + SEG, a1, a0, a0 + SEG, a1 + SEG])
	for si in out_shapes.size():
		var sp: PackedVector3Array = out_shapes[si][Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = out_shapes[si][Mesh.ARRAY_NORMAL]
		var nm: String = NpcBody.shape_names()[si]
		var sc: float = shape_scale.get(nm, 1.0)
		for j in range(base, pv.size()):
			var p := pv[j]
			sp.append(Vector3(p.x * sc, p.y, cz + (p.z - cz) * sc))
			sn.append(pn[j])
		out_shapes[si][Mesh.ARRAY_VERTEX] = sp
		out_shapes[si][Mesh.ARRAY_NORMAL] = sn
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_BONES] = b
	out[Mesh.ARRAY_WEIGHTS] = w
	out[Mesh.ARRAY_INDEX] = idx


## Smooths the garment so it hangs over the body instead of following every
## muscle (shoes lose the toes), keeps it at least a minimum distance off the
## skin, and adds real fold geometry where cloth bunches (elbows, knees, ankles,
## waist). The same offsets go onto every blend shape so the garment still
## follows weight, muscle and face shapes.
static func _drape(it: Dictionary, out: Array, out_shapes: Array, keep: PackedInt32Array, V: PackedVector3Array, N: PackedVector3Array, th: PackedFloat32Array, UV: PackedVector2Array, UV2: PackedVector2Array) -> void:
	var pv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	var n := pv.size()
	# weld UV-seam duplicates so smoothing doesn't open cracks
	var weld := PackedInt32Array()
	weld.resize(n)
	var seen := {}
	for j in n:
		var k := Vector3i(roundi(V[keep[j]].x * 20000.0), roundi(V[keep[j]].y * 20000.0), roundi(V[keep[j]].z * 20000.0))
		if not seen.has(k):
			seen[k] = j
		weld[j] = seen[k]
	var nb := []
	nb.resize(n)
	for j in n:
		nb[j] = PackedInt32Array()
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := weld[idx[t + e]]
			var b := weld[idx[t + (e + 1) % 3]]
			if not nb[a].has(b):
				nb[a].append(b)
				nb[b].append(a)
	var cur := pv.duplicate()
	var iters: int = SMOOTH.get(it.slot, 3)
	for _i in iters:
		var nxt := cur.duplicate()
		for j in n:
			if weld[j] != j:
				continue
			var lst: PackedInt32Array = nb[j]
			if lst.size() < 3:
				continue   # hem edge: keep it put
			var acc := Vector3.ZERO
			for b in lst:
				acc += cur[b]
			nxt[j] = cur[j].lerp(acc / lst.size(), 0.6)
		cur = nxt
	var min_off: float = maxf(float(it.thick) * 0.75, MIN_OFF.get(it.slot, 0.004))
	var delta := PackedVector3Array()
	delta.resize(n)
	for j in n:
		var w := weld[j]
		var v := keep[j]
		var p := cur[w]
		var skin := V[v]
		var off := (p - skin).dot(N[v])
		if off < min_off:
			p += N[v] * (min_off - off)
		if it.slot == "shoes" and skin.y < 0.02 and N[v].y < -0.3:
			p.y = minf(p.y, -0.002)   # flat sole
		# fold geometry: rings that bunch at the joints (about 6 cm apart)
		var part := int(floor(UV[v].x + 0.01))
		var yn := UV[v].y
		var ang := UV2[v].x
		var joint := 0.0
		if part == 2:
			joint = exp(-pow((yn - 0.63) / 0.035, 2.0)) + 0.6 * clampf((0.53 - yn) / 0.04, 0.0, 1.0)
		elif part == 1 and it.slot != "shoes":
			joint = exp(-pow((yn - 0.285) / 0.035, 2.0)) + clampf((0.13 - yn) / 0.06, 0.0, 1.0)
		elif part == 0 and not it.slot in UNDER:
			joint = 0.6 * exp(-pow((yn - 0.58) / 0.03, 2.0))
		if joint > 0.0 and not it.slot in UNDER:
			var wave := sin(yn * 175.0 + sin(ang * 31.0) * 1.7 + sin(ang * 13.0 + yn * 40.0))
			p += N[v] * (0.0045 * joint * (0.5 + 0.5 * wave))
		delta[j] = p - pv[j]
	for j in n:
		pv[j] += delta[j]
	out[Mesh.ARRAY_VERTEX] = pv
	for sa in out_shapes:
		var sp: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
		for j in n:
			sp[j] += delta[j]
		sa[Mesh.ARRAY_VERTEX] = sp
	# smooth normals from the new surface
	var nn := PackedVector3Array()
	nn.resize(n)
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var fnrm := (pv[c] - pv[a]).cross(pv[b] - pv[a])
		nn[weld[a]] += fnrm
		nn[weld[b]] += fnrm
		nn[weld[c]] += fnrm
	var on: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
	for j in n:
		var v2 := nn[weld[j]]
		if v2.length_squared() > 1e-14:
			v2 = v2.normalized()
			on[j] = v2 if v2.dot(on[j]) >= 0.0 else -v2
	out[Mesh.ARRAY_NORMAL] = on
