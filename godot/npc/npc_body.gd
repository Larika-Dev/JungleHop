## One NPC on screen: skeleton, skinned mesh with LODs, procedural walk with
## muscle flex, a collision capsule and an Interactable for talking.
## Pooled by NpcStreamer; `apply_record` turns a pooled body into a person.
class_name NpcBody
extends Node3D

signal reacted_to_crime(crime_id, crime_class, position)


# Read by Life (godot/life), crime (godot/crime) and the dialogue thread.
var npc_id: String = ""
var npc_index: int = -1
var display_name: String = ""
var age: int = 0
var sex: String = "male"
var traits: Dictionary = {}
var interests: Array = []
var personality_id: int = 0
var occupation: String = ""
var attractiveness: float = 5.5
var alertness: float = 0.5
var is_police := false
var record: Dictionary = {}

var lod := -1
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var collider: AnimatableBody3D
var interactable: Node3D

var _material: ShaderMaterial
var _phase := 0.0
var _t := 0.0
var _speed := 0.0
var _shape_idx := {}
var _build := {}
var _height_m := 1.75
var _flee_until := 0.0
var _barefoot := false
var grip := 0.0

static var _skins := {}
static var _meshes := {}
static var _shader: Shader


static func mesh_for(p_sex: String, p_lod: int) -> ArrayMesh:
	var key := "%s%d" % [p_sex, p_lod]
	if not _meshes.has(key):
		_meshes[key] = NpcBodyMesh.get_mesh(p_sex, p_lod)
	return _meshes[key]


func _init() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	if _shader == null:
		_shader = load("res://npc/npc_body.gdshader")
	_material = ShaderMaterial.new()
	_material.shader = _shader
	mesh_instance.material_override = _material
	collider = AnimatableBody3D.new()
	collider.name = "Collider"
	collider.sync_to_physics = false
	collider.collision_layer = (1 << 2) | (1 << 3)   # layers 3 (interact) and 4 (npc)
	collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	collider.add_child(shape)
	add_child(collider)
	var script := load("res://npc/npc_interactable.gd") if ResourceLoader.exists("res://core/interaction/interactable.gd") else null
	if script:
		interactable = script.new()
		interactable.name = "Interactable"
		collider.add_child(interactable)
	add_to_group("npc")


func _setup_skeleton(p_sex: String) -> void:
	skeleton.clear_bones()
	var model: Array = NpcBodyMesh.bone_rest_positions(p_sex)
	for i in NpcBodyMesh.BONES.size():
		skeleton.add_bone(NpcBodyMesh.BONES[i])
	for i in NpcBodyMesh.BONES.size():
		var parent: int = NpcBodyMesh.PARENT[i]
		if parent >= 0:
			skeleton.set_bone_parent(i, parent)
		var local: Vector3 = model[i] - (model[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
	skeleton.reset_bone_poses()
	if not _skins.has(p_sex):
		_skins[p_sex] = skeleton.create_skin_from_rest_transforms()
	mesh_instance.skin = _skins[p_sex]


## Makes this body look like `rec` (an NpcPopulation record or the same keys).
func apply_record(rec: Dictionary) -> void:
	record = rec
	npc_index = rec.get("id", -1)
	npc_id = rec.get("npc_id", "npc_%04d" % npc_index)
	display_name = NpcPopulation.full_name(rec)
	age = rec.age
	traits = rec.get("traits", {})
	interests = rec.get("interests", [])
	personality_id = rec.get("personality_id", 0)
	occupation = rec.get("occupation", "")
	attractiveness = rec.get("attractiveness", 5.5)
	alertness = clampf(0.3 + 0.5 * float(traits.get("lawful", 0.5)), 0.0, 1.0)
	name = "NPC_%s" % npc_id
	if rec.sex != sex or skeleton.get_bone_count() == 0:
		sex = rec.sex
		_setup_skeleton(sex)
		lod = -1
	var p := NpcAppearance.body_params(rec)
	_height_m = rec.height_cm / 100.0
	var s: float = _height_m / NpcBodyMesh.REF_HEIGHT[sex]
	scale = Vector3(s, s, s)
	_build = p.shape
	_material.set_shader_parameter("skin_color", p.skin)
	_material.set_shader_parameter("hair_color", p.hair)
	_material.set_shader_parameter("eye_color", p.eyes)
	_material.set_shader_parameter("top_color", p.top)
	_material.set_shader_parameter("bottom_color", p.bottom)
	_material.set_shader_parameter("shoe_color", p.shoes)
	_material.set_shader_parameter("bottom_cut", p.bottom_cut)
	_material.set_shader_parameter("sleeve_cut", p.sleeve_cut)
	var hs: String = p.hair_style
	var hair: Array = {"buzz": [0.962, 0.945, 0.9, 0.55], "short": [0.966, 0.946, 0.9, 1.0], "medium": [0.968, 0.94, 0.88, 1.0],
		"long": [0.969, 0.925, 0.862, 1.0], "bun": [0.97, 0.94, 0.89, 1.0], "ponytail": [0.97, 0.935, 0.875, 1.0],
		"curly": [0.964, 0.944, 0.89, 1.0], "bald": [1.1, 0.95, 0.915, 0.35]}.get(hs, [0.966, 0.946, 0.9, 1.0])
	_material.set_shader_parameter("hair_front", hair[0])
	record["_hair_front"] = hair[0]
	_material.set_shader_parameter("stubble", 0.0)
	_material.set_shader_parameter("hair_side", hair[1])
	_material.set_shader_parameter("hair_back", hair[2])
	_material.set_shader_parameter("hair_amount", hair[3])
	set_barefoot(bool(rec.get("outfit", {}).get("barefoot", false)))
	if interactable and interactable.has_method("setup"):
		interactable.setup(self)
	if lod >= 0:
		_apply_build_shapes()


## For the player (or any NPC) whose body changes with how they live. Life
## tracks weight, muscle (0..10) and grooming; call this when they change.
##   weight_kg: body weight; muscle: 0..10; grooming: 0 (unkempt) .. 1 (fresh)
##   days_unshaven: stubble grows over about 10 days for men.
func set_body_condition(weight_kg: float, muscle: float, grooming: float = 1.0, days_unshaven: float = 0.0) -> void:
	_build = NpcAppearance.body_shape(_height_m * 100.0, weight_kg, clampf(muscle / 10.0, 0.0, 1.0))
	_apply_build_shapes()
	var stub := 0.0 if sex == "female" else clampf(days_unshaven / 10.0, 0.0, 1.0)
	_material.set_shader_parameter("stubble", stub)
	# Unkempt: hair less defined at the hairline, a duller look overall.
	_material.set_shader_parameter("hair_front", lerpf(0.975, record.get("_hair_front", 0.966), clampf(grooming, 0.0, 1.0)))


## Same, straight from Life.body.visual_params() (godot/life):
##   body.apply_life_body(Life.body.visual_params())
## Connect Life.body.weight_changed to call it again as the player changes.
func apply_life_body(v: Dictionary) -> void:
	var groom := float(v.get("grooming_norm", 1.0))
	set_body_condition(float(v.get("weight_kg", 70.0)), float(v.get("muscle", 3.0)), groom, (1.0 - groom) * 10.0)


## 0 = close-up (full muscle flex), 1 = mid, 2 = far.
func set_lod(l: int) -> void:
	if l == lod:
		return
	lod = l
	mesh_instance.mesh = mesh_for(sex, l)
	_shape_idx.clear()
	for i in NpcBodyMesh.SHAPES.size():
		_shape_idx[NpcBodyMesh.SHAPES[i]] = mesh_instance.find_blend_shape_by_name(NpcBodyMesh.SHAPES[i])
	_material.set_shader_parameter("detail", 1.0 if l == 0 else (0.4 if l == 1 else 0.0))
	_material.set_shader_parameter("painted_eyes", 1.0 if l == 2 else 0.0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if l < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_build_shapes()


func _apply_build_shapes() -> void:
	for k in ["fat", "slim", "muscle"]:
		_set_shape(k, _build.get(k, 0.0))
	_set_shape("barefoot", 1.0 if _barefoot else 0.0)


## 0 = relaxed hands, 1 = closed fists (holding a cup, a bag, a railing).
func set_grip(amount: float) -> void:
	grip = clampf(amount, 0.0, 1.0)


func set_barefoot(on: bool) -> void:
	_barefoot = on
	_material.set_shader_parameter("barefoot", 1.0 if on else 0.0)
	_apply_build_shapes()


## Curls each finger toward the palm: knuckle and middle joint per finger.
func _pose_fingers(curl: float) -> void:
	var specs: Array = NpcBodyMesh.finger_specs(sex)
	for side in [-1, 1]:
		for fi in 5:
			var d: Vector3 = specs[fi][1]
			d.x *= side
			var palm := Vector3(-side, 0, 0) if fi > 0 else Vector3(-side * 0.4, 0, 0.9).normalized()
			var axis := d.cross(palm).normalized()
			var bi := NpcBodyMesh.B_FINGER0 + (0 if side < 0 else 10) + fi * 2
			var a1 := deg_to_rad(lerpf(12.0, 75.0, curl) + fi * 2.0)
			var a2 := deg_to_rad(lerpf(18.0, 95.0, curl) + fi * 3.0)
			if fi == 0:
				a1 *= 0.5
				a2 *= 0.7
			skeleton.set_bone_pose_rotation(bi, Quaternion(axis, a1))
			skeleton.set_bone_pose_rotation(bi + 1, Quaternion(axis, a2))


func _set_shape(n: String, v: float) -> void:
	var i: int = _shape_idx.get(n, -1)
	if i >= 0:
		mesh_instance.set_blend_shape_value(i, v)


## Advances the walk or idle animation. `speed` in m/s (0 = standing).
func animate(delta: float, speed: float) -> void:
	_t += delta
	_speed = lerpf(_speed, speed, clampf(delta * 6.0, 0.0, 1.0))
	var walk := clampf(_speed / 0.6, 0.0, 1.0)
	var cycle := 0.83 * _height_m
	_phase = fposmod(_phase + delta * (_speed / cycle if _speed > 0.05 else 0.0), 1.0)
	var flex := lod == 0 or lod == 1
	for side in [0, 1]:  # 0 = left, 1 = right
		var p := fposmod(_phase + (0.5 if side == 0 else 0.0), 1.0)
		var hip := (22.0 * cos(TAU * p) + 3.0) * walk
		var knee := (5.0 + 15.0 * _bump(p, 0.12, 0.07) + 58.0 * _bump(p, 0.72, 0.11)) * walk + 3.0 * (1.0 - walk)
		var ankle := _ankle_curve(p) * walk
		var o := 0 if side == 0 else 3
		skeleton.set_bone_pose_rotation(NpcBodyMesh.B_THIGH_L + o, Quaternion(Vector3.RIGHT, deg_to_rad(hip)))
		skeleton.set_bone_pose_rotation(NpcBodyMesh.B_SHIN_L + o, Quaternion(Vector3.RIGHT, deg_to_rad(-knee)))
		skeleton.set_bone_pose_rotation(NpcBodyMesh.B_FOOT_L + o, Quaternion(Vector3.RIGHT, deg_to_rad(ankle)))
		# Arms swing with the opposite leg.
		var arm := -14.0 * cos(TAU * p) * walk + 2.0 * sin(_t * 1.3 + side) * (1.0 - walk)
		var arm_out := deg_to_rad(4.0) * (1.0 if side == 1 else -1.0)
		skeleton.set_bone_pose_rotation(NpcBodyMesh.B_UPPERARM_L + o, Quaternion(Vector3.RIGHT, deg_to_rad(arm)) * Quaternion(Vector3.BACK, arm_out * 0.0))
		skeleton.set_bone_pose_rotation(NpcBodyMesh.B_FOREARM_L + o, Quaternion(Vector3.RIGHT, deg_to_rad(12.0 + 10.0 * walk * maxf(0.0, -cos(TAU * p)))))
		if flex:
			var nm := "L" if side == 0 else "R"
			# Gastrocnemius and soleus fire from midstance to push-off.
			var calf := 0.12 + (0.88 * _bump(p, 0.5, 0.1) + 0.25 * _bump(p, 0.32, 0.1)) * walk + 0.1 * (1.0 - walk) * (0.5 + 0.5 * sin(_t * 0.7 + side * 2.0))
			var quad := 0.08 + (0.9 * _bump(p, 0.07, 0.07) + 0.35 * _bump(p, 0.95, 0.05)) * walk
			var glute := 0.05 + 0.8 * _bump(p, 0.05, 0.08) * walk
			_set_shape("calf_flex_" + nm, clampf(calf, 0.0, 1.0))
			_set_shape("quad_flex_" + nm, clampf(quad, 0.0, 1.0))
			_set_shape("glute_flex_" + nm, clampf(glute, 0.0, 1.0))
	# Pelvis bob, sway and twist; chest counter-rotates; breathing.
	var bob := (-0.012 * cos(TAU * 2.0 * _phase)) * walk * (_height_m / 1.75)
	var rest_pelvis := skeleton.get_bone_rest(NpcBodyMesh.B_PELVIS).origin
	skeleton.set_bone_pose_position(NpcBodyMesh.B_PELVIS, rest_pelvis + Vector3(0.012 * sin(TAU * _phase) * walk, bob - 0.004 * walk, 0))
	skeleton.set_bone_pose_rotation(NpcBodyMesh.B_PELVIS, Quaternion(Vector3.UP, deg_to_rad(4.0 * sin(TAU * _phase) * walk)) * Quaternion(Vector3.RIGHT, deg_to_rad(-3.0 * walk)))
	var breath := sin(_t * TAU * 0.25)
	skeleton.set_bone_pose_rotation(NpcBodyMesh.B_CHEST, Quaternion(Vector3.UP, deg_to_rad(-6.0 * sin(TAU * _phase) * walk)) * Quaternion(Vector3.RIGHT, deg_to_rad(0.8 * breath + 2.0 * walk)))
	if lod < 2:
		_pose_fingers(grip + 0.08 * walk * (0.5 + 0.5 * sin(TAU * _phase)))
	skeleton.set_bone_pose_rotation(NpcBodyMesh.B_HEAD, Quaternion(Vector3.UP, deg_to_rad(2.0 * sin(TAU * _phase) * walk + 6.0 * sin(_t * 0.31) * (1.0 - walk))))


static func _bump(p: float, c: float, w: float) -> float:
	var d := fposmod(p - c + 0.5, 1.0) - 0.5
	return exp(-(d * d) / (w * w))


## Ankle angle over the gait cycle (degrees, + = toes up). Heel strike at 0.
static func _ankle_curve(p: float) -> float:
	const K := [[0.0, 0.0], [0.08, -6.0], [0.3, 4.0], [0.45, 10.0], [0.6, -16.0], [0.68, -12.0], [0.8, 2.0], [0.92, 3.0], [1.0, 0.0]]
	for i in K.size() - 1:
		if p <= K[i + 1][0]:
			var f: float = (p - K[i][0]) / (K[i + 1][0] - K[i][0])
			f = f * f * (3.0 - 2.0 * f)
			return lerpf(K[i][1], K[i + 1][1], f)
	return 0.0


## Called by the crime thread's Law autoload when this NPC witnesses a crime.
func react_to_crime(crime_id, crime_class, crime_position, _reported := false) -> void:
	_flee_until = _t + 20.0
	reacted_to_crime.emit(crime_id, crime_class, crime_position)
	var mgr := get_node_or_null("/root/NPCs")
	if mgr and mgr.has_method("on_npc_witnessed_crime"):
		mgr.on_npc_witnessed_crime(npc_index, crime_id, crime_class, crime_position)


## Turn to look at a point (when talked to).
func face_toward(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func is_fleeing() -> bool:
	return _t < _flee_until
