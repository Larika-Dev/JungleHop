class_name NpcWardrobe
extends RefCounted
## Clothes and shoes as separate skinned meshes over the MakeHuman body.
## Each garment is cut from the body surface (by body part, height and angle),
## pushed out by its thickness, and keeps the body's bones and blend shapes, so
## it follows weight, muscle and the walk. Skirts and dresses add a flared tube.
## 10 outerwear, 20 shirts, 20 pants/skirts/dresses, 10 shoes.

const SLOTS := ["shoes", "bottom", "top", "outer"]
# Patterns: 0 solid, 1 stripes, 2 plaid, 3 denim, 4 knit, 5 leather.
static var ITEMS := _items()
static var _cache := {}
static var _shader: Shader


static func _it(id: String, name: String, slot: String, c: String, c2: String, pattern: int, p: Dictionary) -> Dictionary:
	var d := {"id": id, "name": name, "slot": slot, "color": Color(c), "color2": Color(c2), "pattern": pattern,
		"thick": 0.004, "hem": 0.555, "neck": 0.815, "sleeve": 0.72, "vneck": 0.0, "turtle": false, "open": false,
		"coat": 0.0, "waist": 0.6, "leg_hem": 0.04, "skirt": 0.0, "flare": 1.25, "collar": 0.045, "sex": "any"}
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
	if rng.randf() > 0.35:
		out.outer = ""
	if item(out.bottom).get("dress", false):
		out.top = ""
	out.merge(rec.get("wardrobe", {}), true)
	return out


## How far this body vertex is pushed out for the garment (meters), or -1 if
## the garment doesn't cover it. part/yn/df as in npc_body.gdshader.
static func _cover(it: Dictionary, part: int, yn: float, df: float) -> float:
	var t: float = it.thick
	match it.slot:
		"shoes":
			if part == 4 or (part == 1 and yn < it.collar):
				return t
		"top", "outer":
			return _upper(it, part, yn, df, t)
		"bottom":
			if it.get("dress", false):
				var u := _upper(it, part, yn, df, t)
				if u >= 0.0 or (part == 0 and yn > 0.5):
					return t
			elif part == 0 and yn < it.waist:
				return t
			elif part == 1 and it.skirt <= 0.0 and yn > it.leg_hem:
				return t
			elif part == 1 and it.skirt > 0.0 and yn > 0.44:
				return t
	return -1.0


static func _upper(it: Dictionary, part: int, yn: float, df: float, t: float) -> float:
	var top_y: float = it.neck - (it.vneck * clampf(1.0 - df / 25.0, 0.0, 1.0))
	if part == 0 and yn > it.hem and yn < top_y and not (it.open and df < 6.0):
		return t
	if part == 2 and yn > it.sleeve:
		return t
	if part == 6 and it.turtle and yn < 0.86:
		return t
	return -1.0


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
	th.resize(n)
	for i in n:
		var part := int(floor(UV[i].x + 0.01))
		th[i] = _cover(it, part, UV[i].y, absf(UV2[i].x * 360.0 - 270.0)) if part <= 6 else -1.0
	var remap := PackedInt32Array()
	remap.resize(n)
	remap.fill(-1)
	var keep := PackedInt32Array()
	var idx := PackedInt32Array()
	for t in range(0, I.size(), 3):
		if th[I[t]] < 0.0 or th[I[t + 1]] < 0.0 or th[I[t + 2]] < 0.0:
			continue
		for k in 3:
			var v := I[t + k]
			if remap[v] < 0:
				remap[v] = keep.size()
				keep.append(v)
			idx.append(remap[v])
	var out := _gather(keep, V, N, th, UV, UV2, B, W, idx)
	var out_shapes := []
	for s in shapes:
		out_shapes.append(_gather(keep, s[Mesh.ARRAY_VERTEX], s[Mesh.ARRAY_NORMAL], th, null, null, null, null, null))
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
	rx += it.thick + 0.004
	rz += it.thick + 0.004
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
			uv.append(Vector2(0.0, y / H))
			uv2.append(Vector2(fposmod(ang / TAU, 1.0), 0.5))
			var side := NpcBodyMesh.B_THIGH_L if d.x < 0.0 else NpcBodyMesh.B_THIGH_R
			var wl := 0.45 * f * absf(cos(ang))
			b.append_array([pelvis, side, 0, 0])
			w.append_array([1.0 - wl, wl, 0.0, 0.0])
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
