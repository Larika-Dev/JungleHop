class_name TitleScreen
extends Node3D
## Title screen: the city at golden hour behind a slow orbiting camera, with the main menu.

const CITY_SCENE := "res://world/city.tscn"
const ORBIT_CENTER := Vector3(150.0, 20.0, 420.0)   # over Founders' Quad toward the Carillon Spire

var _cam: Camera3D
var _t := 0.0
var _menu: Control


func _ready() -> void:
	GameState.in_game = false
	GameClock.paused = true
	GameClock.set_time(1, 17, 40)   # golden hour backdrop
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var map: Node3D = load("res://assets/map/city.glb").instantiate()
	add_child(map)
	for mi in map.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				m = m.duplicate()
				m.vertex_color_use_as_albedo = true
				m.roughness = 0.9
				mi.set_surface_override_material(s, m)
	add_child(DayNight.new())
	_cam = Camera3D.new()
	_cam.far = 4000.0
	_cam.fov = 60.0
	add_child(_cam)
	_cam.make_current()
	_build_menu()


func _process(delta: float) -> void:
	_t += delta * 0.03
	var p := ORBIT_CENTER + Vector3(cos(_t) * 420.0, 120.0, sin(_t) * 420.0)
	_cam.look_at_from_position(p, ORBIT_CENTER, Vector3.UP)


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 620
	shade.color = Color(UI.NAVY, 0.78)
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(80, 180)
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var t := Label.new()
	t.text = "CATHEDRAL\nMOUNT"
	t.theme_type_variation = "HeaderLarge"
	t.add_theme_constant_override("line_spacing", -18)
	v.add_child(t)
	var sub := Label.new()
	sub.text = "Life in a college town. State of Pamlico."
	sub.add_theme_color_override("font_color", UI.BLUE)
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	v.add_child(gap)
	var first: Button = null
	if GameState.has_save(1):
		first = _btn(v, "Continue", func(): load_and_start(1))
	var ng := _btn(v, "New Game", _new_game)
	_btn(v, "Settings", func(): UI.open_panel(load("res://ui/settings_menu.gd").new()))
	_btn(v, "Quit", func(): get_tree().quit())
	(first if first else ng).grab_focus()
	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(80, -60)
	ver.add_theme_color_override("font_color", Color(UI.CREAM, 0.5))
	root.add_child(ver)
	_menu = root


func _btn(v: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	v.add_child(b)
	return b


func _new_game() -> void:
	var cc = load("res://ui/character_creator.gd").new()
	cc.confirmed.connect(func(profile: Dictionary):
		UI.close_all()
		start_new(profile))
	UI.open_panel(cc)


static func start_new(profile: Dictionary) -> void:
	GameState.player_profile = profile
	GameClock.set_time(1, GameClock.START_HOUR, 0)
	GameClock.speed = 1.0
	if GameState.has_meta("pending_player_pos"):
		GameState.remove_meta("pending_player_pos")
	GameState.get_tree().change_scene_to_file(CITY_SCENE)


static func load_and_start(slot: int) -> void:
	var data := GameState.load_game(slot)
	if data.is_empty():
		UI.notify("No save found.")
		return
	if data.has("player_pos"):
		GameState.set_meta("pending_player_pos", data["player_pos"])
	GameState.get_tree().paused = false
	GameState.get_tree().change_scene_to_file(CITY_SCENE)
