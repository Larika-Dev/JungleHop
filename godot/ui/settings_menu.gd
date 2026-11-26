extends PanelContainer
## Settings: Graphics, Audio, Controls (rebindable keys). Used from the title screen and pause menu.

var _waiting_action := ""
var _bind_buttons := {}


func _ready() -> void:
	custom_minimum_size = Vector2(900, 640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "Settings"
	title.theme_type_variation = "HeaderMedium"
	v.add_child(title)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_graphics())
	tabs.add_child(_audio())
	tabs.add_child(_controls())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(on_back)
	row.add_child(back)
	await get_tree().process_frame
	UI.center(self)
	back.grab_focus()


func on_back() -> void:
	Settings.save_settings()
	UI.close_panel(self)


func _grid(tab_name: String) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 10)
	sc.add_child(g)
	return g


func _label(g: GridContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size.x = 300
	g.add_child(l)


func _slider(g: GridContainer, t: String, lo: float, hi: float, step: float, val: float, fmt: String, cb: Callable) -> void:
	_label(g, t)
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.x = 320
	var l := Label.new()
	l.custom_minimum_size.x = 90
	l.text = fmt % val
	s.value_changed.connect(func(x):
		l.text = fmt % x
		cb.call(x)
		Settings.apply())
	h.add_child(s)
	h.add_child(l)
	g.add_child(h)


func _check(g: GridContainer, t: String, val: bool, cb: Callable) -> void:
	_label(g, t)
	var c := CheckButton.new()
	c.button_pressed = val
	c.toggled.connect(func(x):
		cb.call(x)
		Settings.apply())
	g.add_child(c)


var _gfx_grid: GridContainer


func _graphics() -> Control:
	_gfx_grid = _grid("Graphics")
	_fill_graphics()
	return _gfx_grid.get_parent()


## Rebuilt whenever the preset changes so every control shows the preset's value.
func _fill_graphics() -> void:
	var g := _gfx_grid
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()
	_label(g, "Quality preset")
	var q := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		q.add_item(n)
	q.selected = Settings.quality
	q.tooltip_text = "Low: integrated graphics. Medium: older GPUs. High: most gaming PCs. Ultra: recent high-end GPUs."
	q.item_selected.connect(func(i):
		Settings.set_quality(i)
		Settings.apply()
		_fill_graphics.call_deferred())
	g.add_child(q)
	_check(g, "Fullscreen", Settings.fullscreen, func(x): Settings.fullscreen = x)
	_check(g, "V-Sync", Settings.vsync, func(x): Settings.vsync = x)
	_check(g, "Show FPS", Settings.show_fps, func(x): Settings.show_fps = x)
	_slider(g, "Field of view", 55, 110, 1, Settings.fov, "%d°", func(x): Settings.fov = x)
	_slider(g, "Resolution scale", 0.5, 1.0, 0.05, Settings.resolution_scale, "%.2f", func(x): Settings.resolution_scale = x)
	_option(g, "Upscaler", ["Bilinear", "FSR 1", "FSR 2"], Settings.upscaler, func(i): Settings.upscaler = i)
	_option(g, "Anti-aliasing", ["FXAA (fast)", "TAA", "TAA + MSAA 2x"], Settings.antialiasing, func(i): Settings.antialiasing = i)
	_slider(g, "View distance", 300, 3000, 50, Settings.view_distance, "%d m", func(x): Settings.view_distance = x)
	_check(g, "Shadows", Settings.shadows, func(x): Settings.shadows = x)
	_option(g, "Shadow quality", ["Low", "Medium", "High", "Ultra"], Settings.shadow_quality, func(i): Settings.shadow_quality = i)
	_option(g, "Global illumination", ["Off", "Screen-space", "Full (SDFGI)"], Settings.gi, func(i): Settings.gi = i)
	_check(g, "Ambient occlusion", Settings.ambient_occlusion, func(x): Settings.ambient_occlusion = x)
	_check(g, "Reflections", Settings.reflections, func(x): Settings.reflections = x)
	_check(g, "Volumetric fog and light shafts", Settings.volumetric_fog, func(x): Settings.volumetric_fog = x)
	_slider(g, "Grass density", 0.0, 1.0, 0.05, Settings.grass_density, "%.2f", func(x): Settings.grass_density = x)
	_slider(g, "Detailed tree distance", 100, 500, 10, Settings.foliage_distance, "%d m", func(x): Settings.foliage_distance = x)


func _option(g: GridContainer, t: String, items: Array, val: int, cb: Callable) -> void:
	_label(g, t)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = clampi(val, 0, items.size() - 1)
	o.item_selected.connect(func(i):
		cb.call(i)
		Settings.apply())
	g.add_child(o)


func _audio() -> Control:
	var g := _grid("Audio")
	for bus in Settings.AUDIO_BUSES:
		var b: String = bus
		_slider(g, b + " volume", 0, 100, 1, Settings.volumes[b] * 100.0, "%d%%", func(x): Settings.volumes[b] = x / 100.0)
	return g.get_parent()


func _controls() -> Control:
	var g := _grid("Controls")
	_slider(g, "Mouse sensitivity", 0.05, 1.0, 0.01, Settings.mouse_sensitivity, "%.2f", func(x): Settings.mouse_sensitivity = x)
	_check(g, "Invert mouse Y", Settings.invert_y, func(x): Settings.invert_y = x)
	for action in Settings.REBINDABLE:
		_label(g, Settings.REBINDABLE[action])
		var b := Button.new()
		b.text = Settings.key_name(Settings.keys.get(action, 0))
		var a: String = action
		b.pressed.connect(func():
			_waiting_action = a
			b.text = "Press a key...")
		_bind_buttons[action] = b
		g.add_child(b)
	_label(g, "")
	var reset := Button.new()
	reset.text = "Reset controls"
	reset.pressed.connect(func():
		Settings.reset_controls()
		for k in _bind_buttons:
			_bind_buttons[k].text = Settings.key_name(Settings.keys[k]))
	g.add_child(reset)
	return g.get_parent()


func _input(event: InputEvent) -> void:
	if _waiting_action != "" and event is InputEventKey and event.pressed:
		var kc: int = event.physical_keycode
		if kc != KEY_ESCAPE or _waiting_action == "pause":
			Settings.rebind(_waiting_action, kc)
		_bind_buttons[_waiting_action].text = Settings.key_name(Settings.keys[_waiting_action])
		_waiting_action = ""
		get_viewport().set_input_as_handled()
