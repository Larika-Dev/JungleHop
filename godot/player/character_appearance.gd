class_name CharacterAppearance
extends Node3D
## Procedural player body built from GameState.player_profile (light customization):
## sex, height, build, skin tone, hair style + color, shirt and pants colors. Limbs swing with speed.
## The NPC thread may later supply a detailed body; this class keeps the same build(profile) entry point.

const SKIN_TONES := [Color("#F3D7C2"), Color("#E8BC9A"), Color("#C98E66"), Color("#A56B47"), Color("#7A4A2F"), Color("#4E2F1E")]
const HAIR_STYLES := ["Bald", "Short", "Medium", "Long", "Ponytail", "Buzz", "Bun"]
const HAIR_COLORS := [Color("#1C1714"), Color("#3B2A1E"), Color("#6A4A2E"), Color("#A77B4A"), Color("#D9B97A"), Color("#8E3B2E"), Color("#9A9A9A")]
const HAIR_COLOR_NAMES := ["Black", "Dark brown", "Brown", "Light brown", "Blonde", "Auburn", "Gray"]
const CLOTH_COLORS := [Color("#80B4D9"), Color("#142B4E"), Color("#F3F0E8"), Color("#2F3F33"), Color("#6B1F1A"), Color("#3A3C3E"), Color("#E0B341"), Color("#B8577A"), Color("#5F646A"), Color("#1A1A1A")]
const CLOTH_COLOR_NAMES := ["Heaven blue", "Navy", "White", "Forest", "Brick red", "Charcoal", "Mustard", "Rose", "Slate", "Black"]

var _parts := {}
var _phase := 0.0
var _pose := "stand"
var _first_person := true
var _height := 1.75
var _body: Node3D   # detailed NPC body (godot/npc) when available


## Uses the detailed NPC body (MakeHuman base, separate clothes) when the NPC
## module is present; falls back to the simple capsule body below.
func _build_detailed(p: Dictionary) -> bool:
	if not ResourceLoader.exists("res://npc/npc_body.gd") or not ResourceLoader.exists("res://npc/models/mh_male.json"):
		return false
	var rec: Dictionary = load("res://npc/npc_appearance.gd").record_from_profile(p)
	rec["wardrobe"] = {"top": "tee_white", "bottom": "chinos_khaki", "shoes": "sneaker_white", "outer": ""}
	rec["wardrobe_tint"] = {"top": CLOTH_COLORS[clampi(int(p.get("shirt_color", 0)), 0, CLOTH_COLORS.size() - 1)],
		"bottom": CLOTH_COLORS[clampi(int(p.get("pants_color", 1)), 0, CLOTH_COLORS.size() - 1)]}
	_body = load("res://npc/npc_body.gd").new()
	_body.name = "Body"
	add_child(_body)
	_body.remove_from_group("npc")
	_body.collider.collision_layer = 0
	_body.apply_record(rec)
	_body.set_lod(0)
	return true


func build(p: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_parts.clear()
	_body = null
	_height = clampf(float(p.get("height_cm", 175)) / 100.0, 1.4, 2.1)
	if _build_detailed(p):
		return
	var female: bool = p.get("sex", "male") == "female"
	var bw := lerpf(0.85, 1.3, float(p.get("build", 0.5)))
	var mus := 1.0 + (float(p.get("muscle", 4)) - 4.0) * 0.045   # broader shoulders and limbs
	var s := _height / 1.75
	var skin := _mat(SKIN_TONES[clampi(int(p.get("skin", 2)), 0, SKIN_TONES.size() - 1)], 0.6)
	var shirt := _mat(CLOTH_COLORS[clampi(int(p.get("shirt_color", 0)), 0, CLOTH_COLORS.size() - 1)], 0.9)
	var pants := _mat(CLOTH_COLORS[clampi(int(p.get("pants_color", 3)), 0, CLOTH_COLORS.size() - 1)], 0.9)
	var hc: Color = HAIR_COLORS[clampi(int(p.get("hair_color", 1)), 0, HAIR_COLORS.size() - 1)]
	hc = hc.lerp(Color("#B8B8B4"), clampf((float(p.get("age", 20)) - 45.0) / 30.0, 0.0, 0.8))
	var hair := _mat(hc, 0.7)
	var shoes := _mat(Color("#18191A"), 0.5)
	var shoulder := (0.22 if not female else 0.19) * lerpf(bw, mus, 0.5) * s
	var hip := (0.16 if not female else 0.18) * bw * s
	var leg_len := 0.86 * s
	var torso_len := 0.56 * s
	# legs (pivot at hip)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * hip * 0.55, leg_len + 0.04 * s, 0)
		add_child(leg)
		leg.add_child(_capsule(0.075 * bw * s, leg_len * 0.55, Vector3(0, -leg_len * 0.27, 0), pants))
		leg.add_child(_capsule(0.06 * bw * mus * s, leg_len * 0.52, Vector3(0, -leg_len * 0.73, 0), pants))
		leg.add_child(_box(Vector3(0.1, 0.07, 0.26) * s, Vector3(0, -leg_len - 0.005, -0.05 * s), shoes))
		_parts["leg_%d" % side] = leg
	# torso
	var torso := Node3D.new()
	torso.position = Vector3(0, leg_len, 0)
	add_child(torso)
	torso.add_child(_box(Vector3(hip * 2.1, 0.2 * s, 0.2 * bw * s), Vector3(0, 0.08 * s, 0), pants))
	var chest := _capsule(shoulder * 0.95, torso_len, Vector3(0, torso_len * 0.55, 0), shirt)
	chest.scale = Vector3(1.0, 1.0, 0.55 * (1.1 if female else 1.0))
	torso.add_child(chest)
	_parts["torso"] = torso
	# head + neck
	var head := Node3D.new()
	head.position = Vector3(0, leg_len + torso_len + 0.06 * s, 0)
	add_child(head)
	head.add_child(_capsule(0.05 * s, 0.1 * s, Vector3(0, 0.02 * s, 0), skin))
	var skull := _sphere(0.105 * s, Vector3(0, 0.16 * s, 0), skin)
	skull.scale = Vector3(0.9, 1.1, 1.0)
	head.add_child(skull)
	_add_hair(head, int(p.get("hair_style", 1)), s, hair, female)
	_parts["head"] = head
	# arms (pivot at shoulder)
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * (shoulder + 0.03 * s), leg_len + torso_len * 0.95, 0)
		add_child(arm)
		arm.add_child(_capsule(0.05 * bw * mus * s, 0.3 * s, Vector3(0, -0.15 * s, 0), shirt))
		arm.add_child(_capsule(0.042 * bw * mus * s, 0.28 * s, Vector3(0, -0.43 * s, 0), skin))
		arm.add_child(_sphere(0.045 * s, Vector3(0, -0.6 * s, 0), skin))
		_parts["arm_%d" % side] = arm
	set_first_person(_first_person)
	set_pose(_pose)


func _add_hair(head: Node3D, style: int, s: float, m: Material, _female: bool) -> void:
	match style:
		0:
			return
		1, 5:
			var cap := _sphere(0.112 * s, Vector3(0, 0.19 * s, 0.01 * s), m)
			cap.scale = Vector3(0.93, 0.95 if style == 1 else 0.85, 1.02)
			head.add_child(cap)
		2, 3:
			var cap := _sphere(0.118 * s, Vector3(0, 0.18 * s, 0.015 * s), m)
			cap.scale = Vector3(0.97, 1.05, 1.05)
			head.add_child(cap)
			var back_len := 0.16 * s if style == 2 else 0.34 * s
			head.add_child(_box(Vector3(0.2 * s, back_len, 0.07 * s), Vector3(0, 0.2 * s - back_len * 0.5, 0.08 * s), m))
		4:
			var cap := _sphere(0.115 * s, Vector3(0, 0.19 * s, 0.01 * s), m)
			head.add_child(cap)
			head.add_child(_capsule(0.035 * s, 0.22 * s, Vector3(0, 0.08 * s, 0.13 * s), m))
		6:
			head.add_child(_sphere(0.113 * s, Vector3(0, 0.19 * s, 0.01 * s), m))
			head.add_child(_sphere(0.06 * s, Vector3(0, 0.3 * s, 0.07 * s), m))


func set_first_person(fp: bool) -> void:
	_first_person = fp
	if _body:
		for mi in _body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if fp else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	# In first person hide head/torso/arms (keeps the camera clear); legs stay for looking down.
	for k in _parts:
		var n: Node3D = _parts[k]
		var visible_fp: bool = String(k).begins_with("leg")
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (visible_fp or not fp) else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mi.visible = true


func hip_height_standing() -> float:
	return 0.9 * (_height / 1.75)


func hip_height_sitting() -> float:
	return hip_height_standing() - 0.42 * (_height / 1.75)


func hip_to_eye() -> float:
	return _height - 0.1 - hip_height_standing()


func set_pose(pose: String) -> void:
	_pose = pose
	if _body:
		position.y = -0.42 * (_height / 1.75) if pose == "sit" else 0.0
		return
	if _parts.is_empty():
		return
	var sit := pose == "sit"
	for side in [-1, 1]:
		_parts["leg_%d" % side].rotation.x = deg_to_rad(90) if sit else 0.0
		_parts["arm_%d" % side].rotation.x = deg_to_rad(20) if sit else 0.0
	position = Vector3(0, -0.42 * (_height / 1.75), 0) if sit else Vector3.ZERO
	basis = Basis.IDENTITY
	if pose == "lie":
		# body along -Z (head toward -Z), hips at the origin, lying on the back
		basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
		position = Vector3(0, 0.12, hip_height_standing())


func animate(speed: float, delta: float) -> void:
	if _body:
		_body.animate(delta, 0.0 if _pose == "sit" else speed)
		return
	if _parts.is_empty() or _pose == "sit":
		return
	var stride := clampf(speed / 1.4, 0.0, 2.8)
	_phase += delta * (2.2 + speed * 1.7)
	var swing := sin(_phase) * deg_to_rad(28.0) * minf(stride, 1.6)
	if stride < 0.05:
		swing = lerpf(_parts["leg_1"].rotation.x, 0.0, 0.2)
	_parts["leg_-1"].rotation.x = swing
	_parts["leg_1"].rotation.x = -swing
	_parts["arm_-1"].rotation.x = -swing * 0.8
	_parts["arm_1"].rotation.x = swing * 0.8
	_parts["torso"].position.y = _parts["leg_1"].position.y - 0.04 * (_height / 1.75) + absf(sin(_phase)) * 0.02 * minf(stride, 1.5)


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _capsule(r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	cm.radial_segments = 16
	cm.rings = 6
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	return mi


static func _sphere(r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	return mi


static func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	return mi
