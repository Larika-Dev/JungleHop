extends CharacterBody3D
## First/third-person player (CLAUDE.md §16): eye height 165 cm, walk 1.4 m/s, run 4 m/s,
## step-up 20 cm, capsule radius 30 cm. Look ray finds Interactables. See docs/INTERFACES.md.

signal focus_changed(target: Interactable)
signal sat_down(xform: Transform3D)
signal stood_up

const WALK := 1.4
const RUN := 4.0
const FLY := 25.0
const JUMP_V := 3.6
const GRAVITY := 9.81
const RADIUS := 0.3
const REACH := 2.5
const HOLD_FOR_MENU := 0.35
const RAY_MASK := 1 | 4 | 8   # world, interact, npc

var camera: Camera3D
var appearance: CharacterAppearance
var focus: Interactable = null
var flying := false
var third_person := false
var sitting := false
## "stand" | "sit" | "lie"
var posture := "stand"
var _stand_from := Vector3.ZERO
var input_enabled := true

var _yaw := 0.0
var _pitch := 0.0
var _head: Node3D
var _arm: SpringArm3D
var _eye := 1.65
var _e_down_t := -1.0
var _menu_from_hold := false
var _snap_frames := 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 8
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	_eye = clampf(GameState.player_profile.get("height_cm", 175) / 100.0 - 0.1, 1.45, 1.85)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = _eye + 0.1
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_head = Node3D.new()
	_head.position.y = _eye
	add_child(_head)
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.spring_length = 0.0
	_arm.margin = 0.15
	_head.add_child(_arm)
	camera = Camera3D.new()
	camera.near = 0.03
	camera.far = Settings.view_distance
	camera.fov = Settings.fov
	_arm.add_child(camera)
	camera.make_current()
	appearance = CharacterAppearance.new()
	appearance.name = "Appearance"
	add_child(appearance)
	appearance.build(GameState.player_profile)
	_set_view(false)
	GameState.profile_changed.connect(func(): appearance.build(GameState.player_profile))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	_yaw = yaw
	rotation.y = yaw
	velocity = Vector3.ZERO
	_snap_frames = 3
	var streamer := get_tree().get_first_node_in_group("interior_streamer")
	if streamer and streamer.has_method("load_now"):
		streamer.load_now(pos)


func set_input_enabled(on: bool) -> void:
	input_enabled = on
	if not on:
		_e_down_t = -1.0


## Sit on a seat. xform.origin = seat surface (where the hips go), -Z = the way the seat faces.
func sit_at(xform: Transform3D) -> void:
	_enter_pose("sit", xform)
	var hip := appearance.hip_height_sitting()
	global_position = xform.origin - Vector3(0, hip, 0)
	_head.position = Vector3(0, _eye - (appearance.hip_height_standing() - hip), 0)
	sat_down.emit(xform)


## Lie on a bed. xform.origin = mattress surface at the hips, -Z = toward the head.
func lie_at(xform: Transform3D) -> void:
	_enter_pose("lie", xform)
	global_position = xform.origin
	_head.position = Vector3(0, 0.2, -appearance.hip_to_eye())
	_pitch = deg_to_rad(60.0)
	sat_down.emit(xform)


func _enter_pose(pose: String, xform: Transform3D) -> void:
	sitting = true
	posture = pose
	velocity = Vector3.ZERO
	_stand_from = global_position
	_yaw = xform.basis.get_euler().y
	rotation.y = _yaw
	appearance.set_pose(pose)


## Leave a seat or bed: step out in front of it (back to where you were if that is blocked).
func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	posture = "stand"
	appearance.set_pose("stand")
	_head.position = Vector3(0, _eye, 0)
	_pitch = 0.0
	var out := global_position + Basis(Vector3.UP, _yaw) * Vector3(0, 0, -0.6)
	out.y = maxf(out.y, _stand_from.y) + 0.05
	var probe := Transform3D(Basis.IDENTITY, out)
	global_position = _stand_from + Vector3.UP * 0.05 if test_move(probe, Vector3.UP * 0.01) else out
	stood_up.emit()


func _set_view(third: bool) -> void:
	third_person = third
	_arm.spring_length = 3.2 if third else 0.0
	_arm.position = Vector3(0.45, 0.15, 0) if third else Vector3.ZERO
	appearance.set_first_person(not third)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := Settings.mouse_sensitivity * 0.01
		_yaw -= event.relative.x * s
		_pitch += (event.relative.y if Settings.invert_y else -event.relative.y) * s
		_pitch = clampf(_pitch, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_view"):
		_set_view(not third_person)
	elif event.is_action_pressed("fly") and OS.is_debug_build():
		flying = not flying
		UI.notify("Free-fly " + ("on" if flying else "off"))
	elif event.is_action_pressed("interact"):
		_e_down_t = 0.0
		_menu_from_hold = false
	elif event.is_action_released("interact"):
		if _e_down_t >= 0.0 and not _menu_from_hold:
			if sitting:
				stand_up()
			elif focus:
				_run_first(focus)
		_e_down_t = -1.0
	elif event.is_action_pressed("action_menu") and focus:
		UI.open_action_menu(focus, self)
	elif event.is_action_pressed("life_menu") or (event.is_action_pressed("action_menu") and focus == null):
		UI.open_life_menu()
	elif event.is_action_pressed("people"):
		UI.open_people()


func _run_first(it: Interactable) -> void:
	for a in it.get_actions(self):
		if a.get("enabled", true):
			it.perform(String(a["id"]), self)
			return


func _process(delta: float) -> void:
	if _e_down_t >= 0.0:
		_e_down_t += delta
		if _e_down_t > HOLD_FOR_MENU and not _menu_from_hold and focus:
			_menu_from_hold = true
			UI.open_action_menu(focus, self)
	rotation.y = _yaw
	_head.rotation.x = _pitch
	_update_focus()


func _update_focus() -> void:
	var it: Interactable = null
	if input_enabled and not sitting:
		var space := get_world_3d().direct_space_state
		var from := _head.global_position
		var to := from + (-_head.global_transform.basis.z) * (REACH + (_arm.spring_length if third_person else 0.0))
		var q := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [get_rid()])
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit and hit.collider:
			it = Interactable.find_from(hit.collider)
			if it and not it.enabled:
				it = null
	if it != focus:
		focus = it
		focus_changed.emit(focus)


func _physics_process(delta: float) -> void:
	if sitting:
		if input_enabled and (Input.is_action_just_pressed("jump") or Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.5):
			stand_up()
		return
	var dir2 := Vector2.ZERO
	if input_enabled:
		dir2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_y := Basis(Vector3.UP, _yaw)
	var wish := basis_y * Vector3(dir2.x, 0, dir2.y)
	if flying:
		var look := _head.global_transform.basis
		var v := (look * Vector3(dir2.x, 0, dir2.y)) * FLY * (3.0 if Input.is_action_pressed("run") else 1.0)
		if input_enabled and Input.is_action_pressed("jump"):
			v.y += FLY
		velocity = v
		move_and_slide()
		appearance.animate(0.0, delta)
		return
	var speed := RUN if (input_enabled and Input.is_action_pressed("run")) else WALK
	var target_v := wish * speed
	var accel := 12.0 if is_on_floor() else 2.0
	velocity.x = move_toward(velocity.x, target_v.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target_v.z, accel * speed * delta)
	if is_on_floor():
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_V
	else:
		velocity.y -= GRAVITY * delta
	if _snap_frames > 0:
		_snap_frames -= 1
		velocity.y = minf(velocity.y, 0.0)
	_step_up(delta)
	move_and_slide()
	if global_position.y < -200.0:
		var c := get_parent()
		if c and c.has_method("ground_height"):
			global_position.y = c.ground_height(global_position) + 1.0
			velocity = Vector3.ZERO
	appearance.animate(Vector2(velocity.x, velocity.z).length(), delta)


## Climb curbs and steps up to 20 cm (CLAUDE.md §16).
func _step_up(delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() < 0.1 or not is_on_floor():
		return
	var motion := hv * delta + hv.normalized() * 0.1
	if not test_move(global_transform, motion):
		return
	var up := Transform3D(global_transform.basis, global_position + Vector3.UP * 0.21)
	if test_move(global_transform, Vector3.UP * 0.21):
		return
	if test_move(up, motion):
		return
	global_position.y += 0.21
