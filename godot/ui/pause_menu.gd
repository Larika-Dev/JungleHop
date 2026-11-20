extends PanelContainer
## Pause menu: resume, save, load, settings, quit to title, quit to desktop.

var _status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var t := Label.new()
	t.text = "Paused"
	t.theme_type_variation = "HeaderMedium"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var clock := Label.new()
	clock.text = "%s  %s" % [GameClock.date_string(), GameClock.time_string()]
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(clock)
	var resume := _btn(v, "Resume", func(): UI.close_panel(self))
	_btn(v, "Save game", func():
		_status.text = "Saved." if GameState.save_game(1) else "Save failed.")
	var load_b := _btn(v, "Load last save", func():
		UI.close_all()
		TitleScreen.load_and_start(1))
	load_b.disabled = not GameState.has_save(1)
	_btn(v, "Settings", func(): UI.open_panel(load("res://ui/settings_menu.gd").new()))
	_btn(v, "Quit to title", func():
		UI.close_all()
		GameState.in_game = false
		GameClock.paused = true
		get_tree().change_scene_to_file("res://ui/title_screen.tscn"))
	_btn(v, "Quit to desktop", func(): get_tree().quit())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	await get_tree().process_frame
	UI.center(self)
	resume.grab_focus()


func _btn(v: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	v.add_child(b)
	return b
