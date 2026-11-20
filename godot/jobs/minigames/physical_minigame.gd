class_name PhysicalMinigame
extends JobMinigame
## Close-up 3D workstation: real objects on a work surface that you pick up and
## move with the mouse (or drive with WASD). Rendered in its own SubViewport
## world so it never disturbs the city scene.
##
## Subclasses build objects with add_item()/add_zone()/add_box() in _setup()
## and react in _on_drop(item, zone), _on_hover(item, zone, delta) and
## _mg_process(delta). Units are metres, Y up, the surface is at y = 0.

var viewport: SubViewport
var container: SubViewportContainer
var world_root: Node3D
var camera: Camera3D
var hint_label: Label

## name -> {node: Node3D, home: Vector3, lift: float, draggable: bool, data: Dictionary}
var items: Dictionary = {}
## name -> {pos: Vector3, radius: float, node: Node3D, data: Dictionary}
var zones: Dictionary = {}
var held := ""
var held_offset := Vector3.ZERO
var mouse_ground := Vector3.ZERO
var mouse_down := false
var _mats := {}


func _build_body(parent: Control) -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_view_input)
	parent.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	container.add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.15, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.82, 0.78)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.94, 0.85)  # toward INTERIOR_WARM
	sun.shadow_enabled = true
	world_root.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 50
	world_root.add_child(camera)
	set_camera(Vector3(0, 1.1, 0.95), Vector3(0, 0, -0.05))
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -64
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", C_TEXT)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 6)
	parent.add_child(hint_label)


func set_camera(pos: Vector3, look_at_pos: Vector3) -> void:
	camera.position = pos
	camera.look_at_from_position(pos, look_at_pos, Vector3.UP)


func set_hint(t: String) -> void:
	if hint_label:
		hint_label.text = t


func mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


## Box with its base at pos.y.
func add_box(size: Vector3, color: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	(parent if parent else world_root).add_child(mi)
	return mi


func add_cylinder(radius: float, height: float, color: Color, pos: Vector3, parent: Node3D = null, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0 else top_radius
	cm.height = height
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	(parent if parent else world_root).add_child(mi)
	return mi


func add_label(text: String, pos: Vector3, size := 0.035, parent: Node3D = null, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size / 32.0
	l.font_size = 32
	l.outline_size = 8
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.no_depth_test = true
	(parent if parent else world_root).add_child(l)
	return l


## A movable object. `node` is a Node3D whose origin sits on the surface.
func add_item(id: String, node: Node3D, draggable := true, data := {}) -> void:
	if node.get_parent() == null:
		world_root.add_child(node)
	items[id] = {"node": node, "home": node.position, "draggable": draggable, "data": data}


func remove_item(id: String) -> void:
	if items.has(id):
		var n: Node3D = items[id].node
		items.erase(id)
		if held == id:
			held = ""
		n.queue_free()


func add_zone(id: String, pos: Vector3, radius: float, data := {}, marker_color := Color(1, 1, 1, 0.0)) -> void:
	var node: Node3D = null
	if marker_color.a > 0.0:
		node = add_cylinder(radius, 0.004, marker_color, pos)
	zones[id] = {"pos": pos, "radius": radius, "node": node, "data": data}


func zone_at(p: Vector3) -> String:
	var best := ""
	var best_d := INF
	for id in zones:
		var z: Dictionary = zones[id]
		var d := Vector2(p.x - z.pos.x, p.z - z.pos.z).length()
		if d <= z.radius and d < best_d:
			best = id
			best_d = d
	return best


func item_pos(id: String) -> Vector3:
	return items[id].node.position


# ---------------------------------------------------------------- input

func _screen_to_ground(screen: Vector2, plane_y := 0.0) -> Vector3:
	var o := camera.project_ray_origin(screen)
	var n := camera.project_ray_normal(screen)
	if absf(n.y) < 0.0001:
		return mouse_ground
	var t := (plane_y - o.y) / n.y
	return o + n * t


func _item_under(screen: Vector2) -> String:
	var best := ""
	var best_d := 60.0
	for id in items:
		var it: Dictionary = items[id]
		if not it.draggable:
			continue
		var p: Vector3 = it.node.global_position + Vector3(0, 0.04, 0)
		if camera.is_position_behind(p):
			continue
		var d := camera.unproject_position(p).distance_to(screen)
		if d < best_d:
			best_d = d
			best = id
	return best


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_ground = _screen_to_ground(event.position)
		if held != "" and items.has(held):
			var n: Node3D = items[held].node
			n.position = Vector3(mouse_ground.x, 0.06, mouse_ground.z) + held_offset
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_ground = _screen_to_ground(event.position)
		mouse_down = event.pressed
		if event.pressed:
			var id := _item_under(event.position)
			if id != "":
				grab(id)
			else:
				_on_click_ground(mouse_ground)
		elif held != "":
			release()


func grab(id: String) -> bool:
	if not items.has(id) or not items[id].draggable:
		return false
	held = id
	items[id].node.position.y = 0.06
	_on_grab(id)
	return true


## Drop the held item where it is; _on_drop decides what happens.
func release() -> void:
	if held == "" or not items.has(held):
		held = ""
		return
	var id := held
	held = ""
	var n: Node3D = items[id].node
	n.position.y = 0.0
	var z := zone_at(n.position)
	var keep := _on_drop(id, z)
	if not keep and items.has(id):
		items[id].node.position = items[id].home


## Test helper: pick up `id`, carry it to zone `zone_id` and let go.
func move_item_to_zone(id: String, zone_id: String) -> void:
	if not grab(id):
		return
	var z: Dictionary = zones[zone_id]
	items[id].node.position = Vector3(z.pos.x, 0.06, z.pos.z)
	release()


func _mg_process(delta: float) -> void:
	if held != "" and items.has(held):
		var z := zone_at(items[held].node.position)
		if z != "":
			_on_hover(held, z, delta)
	_phys_process(delta)


# ---------------------------------------------------------------- hooks

func _on_grab(_id: String) -> void:
	pass


## Return true if the item should stay where it was dropped.
func _on_drop(_id: String, _zone: String) -> bool:
	return false


func _on_hover(_id: String, _zone: String, _delta: float) -> void:
	pass


func _on_click_ground(_p: Vector3) -> void:
	pass


func _phys_process(_delta: float) -> void:
	pass
