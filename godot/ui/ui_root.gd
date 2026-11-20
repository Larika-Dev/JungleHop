extends CanvasLayer
## Global UI host. Autoload name: UI. See docs/INTERFACES.md.
## notify(text), open_panel(control), close_panel(), is_panel_open(), show_minigame(packed),
## open_action_menu(interactable, actor), open_pause_menu(). Also owns the shared Theme.

signal panel_opened(panel: Control)
signal panel_closed

const NAVY := Color("#142B4E")
const BLUE := Color("#80B4D9")
const BRICK := Color("#8E3B2E")
const CREAM := Color("#F3F0E8")
const INK := Color("#18191A")

var theme: Theme
var title_font: Font
var body_font: Font
var _toasts: VBoxContainer
var _panel_host: Control
var _panels: Array[Control] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_font = load("res://assets/fonts/bebas-neue-latin-400-normal.woff2")
	body_font = load("res://assets/fonts/oswald-latin-600-normal.woff2")
	theme = _make_theme()
	_panel_host = Control.new()
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_host.theme = theme
	add_child(_panel_host)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 90)
	_toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.theme = theme
	add_child(_toasts)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(NAVY, 0.94)
	panel.border_color = BLUE
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(24)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(10)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		match state:
			"normal": sb.bg_color = Color(CREAM, 0.08); sb.border_color = Color(BLUE, 0.5); sb.set_border_width_all(1)
			"hover": sb.bg_color = Color(BLUE, 0.35); sb.border_color = BLUE; sb.set_border_width_all(1)
			"pressed": sb.bg_color = Color(BLUE, 0.6)
			"focus": sb.bg_color = Color(0, 0, 0, 0); sb.border_color = CREAM; sb.set_border_width_all(2)
			"disabled": sb.bg_color = Color(0, 0, 0, 0.2)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.35))
	t.set_color("font_color", "Label", CREAM)
	t.set_font_size("font_size", "HeaderLarge", 96)
	t.set_font("font", "HeaderLarge", title_font)
	t.set_type_variation("HeaderLarge", "Label")
	t.set_font_size("font_size", "HeaderMedium", 48)
	t.set_font("font", "HeaderMedium", title_font)
	t.set_type_variation("HeaderMedium", "Label")
	t.set_font_size("font_size", "HeaderSmall", 30)
	t.set_font("font", "HeaderSmall", title_font)
	t.set_type_variation("HeaderSmall", "Label")
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(BLUE, 0.45)
	tab.set_content_margin_all(10)
	t.set_stylebox("tab_selected", "TabContainer", tab)
	var tab_u := tab.duplicate()
	tab_u.bg_color = Color(0, 0, 0, 0.25)
	t.set_stylebox("tab_unselected", "TabContainer", tab_u)
	t.set_stylebox("tab_hovered", "TabContainer", tab)
	var tp := StyleBoxFlat.new()
	tp.bg_color = Color(0, 0, 0, 0.2)
	tp.set_content_margin_all(16)
	t.set_stylebox("panel", "TabContainer", tp)
	return t


# ------------------------------------------------------------------------------------------ toasts
func notify(text: String, seconds: float = 3.0) -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.85)
	sb.border_color = BLUE
	sb.border_width_left = 4
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(l)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(pc)
	var tw := pc.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(pc, "modulate:a", 0.0, 0.4)
	tw.tween_callback(pc.queue_free)


# ------------------------------------------------------------------------------------------ panels
## Shows a full-screen or centered Control. Frees the mouse and disables player input until closed.
func open_panel(c: Control, pause_game: bool = false) -> void:
	_panels.append(c)
	c.set_meta("pauses", pause_game)
	_panel_host.add_child(c)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p := GameState.get_player()
	if p and p.has_method("set_input_enabled"):
		p.set_input_enabled(false)
	if pause_game:
		get_tree().paused = true
		GameClock.paused = true
	panel_opened.emit(c)


## Closes the top panel (or a specific one).
func close_panel(c: Control = null) -> void:
	if _panels.is_empty():
		return
	if c == null:
		c = _panels.back()
	_panels.erase(c)
	if c.get_meta("pauses", false):
		get_tree().paused = false
		GameClock.paused = not GameState.in_game
	if is_instance_valid(c):
		c.queue_free()
	if _panels.is_empty():
		panel_closed.emit()
		if GameState.in_game:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var p := GameState.get_player()
			if p and p.has_method("set_input_enabled"):
				p.set_input_enabled(true)


func is_panel_open() -> bool:
	return not _panels.is_empty()


func close_all() -> void:
	while not _panels.is_empty():
		close_panel()


## Full-screen mini game host (jobs, classes). The mini game calls UI.close_panel() when done.
func show_minigame(packed: PackedScene) -> Node:
	var inst := packed.instantiate()
	var c: Control
	if inst is Control:
		c = inst
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sv := SubViewport.new()
		sv.own_world_3d = true
		sv.add_child(inst)
		svc.add_child(sv)
		c = svc
	open_panel(c)
	return inst


# ------------------------------------------------------------------------------------------ menus
func open_action_menu(target: Interactable, actor: Node) -> void:
	if is_panel_open() or target == null:
		return
	var acts := target.get_actions(actor)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var title := Label.new()
	title.theme_type_variation = "HeaderSmall"
	title.text = target.display_name
	v.add_child(title)
	var first: Button
	for a in acts:
		var b := Button.new()
		var mins: float = a.get("minutes", 0.0)
		b.text = String(a.get("label", a["id"])) + ("   (%s)" % _dur(mins) if mins >= 1.0 else "")
		b.disabled = not a.get("enabled", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: String = a["id"]
		b.pressed.connect(func():
			close_panel(pc)
			if is_instance_valid(target):
				target.perform(id, actor))
		v.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): close_panel(pc))
	v.add_child(cancel)
	open_panel(pc)
	pc.reset_size()
	pc.position = -pc.size * 0.5
	(first if first else cancel).grab_focus()


static func _dur(m: float) -> String:
	if m < 60.0:
		return "%d min" % int(m)
	return "%.1f h" % (m / 60.0)


func open_pause_menu() -> void:
	if is_panel_open():
		return
	open_panel(load("res://ui/pause_menu.gd").new(), true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if is_panel_open():
			var top: Control = _panels.back()
			if top.has_method("on_back"):
				top.on_back()
			else:
				close_panel()
			get_viewport().set_input_as_handled()
		elif GameState.in_game:
			open_pause_menu()
			get_viewport().set_input_as_handled()
