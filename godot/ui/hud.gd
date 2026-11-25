extends CanvasLayer
## In-game HUD: clock and date, money (from Life.money when that autoload exists), district,
## crosshair, interaction prompt, FPS. Other systems can add widgets with add_widget().

var _clock: Label
var _date: Label
var _money: Label
var _district: Label
var _prompt: Label
var _fps: Label
var _cross: Control
var _right: VBoxContainer
var _player: Node
var _bars := {}
var _mood: Label
var _activity: Label
var _activity_bar: ProgressBar


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme
	add_child(root)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UI.INK, 0.55)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(28, 24)
	root.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	_clock = Label.new()
	_clock.theme_type_variation = "HeaderMedium"
	v.add_child(_clock)
	_date = Label.new()
	v.add_child(_date)
	_money = Label.new()
	_money.add_theme_color_override("font_color", Color("#9BD08A"))
	v.add_child(_money)
	_district = Label.new()
	_district.add_theme_color_override("font_color", UI.BLUE)
	v.add_child(_district)
	_build_needs(v)
	_right = VBoxContainer.new()
	_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_right.position = Vector2(-360, 24)
	_right.custom_minimum_size.x = 330
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_right)
	_fps = Label.new()
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right.add_child(_fps)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.draw.connect(func(): _cross.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.8)))
	root.add_child(_cross)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-500, -170)
	_prompt.custom_minimum_size = Vector2(1000, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	root.add_child(_prompt)
	# Life's messages (action results, "You passed out", warnings) show as toasts.
	var life := get_node_or_null("/root/Life")
	if life and life.has_signal("notify") and not life.notify.is_connected(UI.notify):
		life.notify.connect(UI.notify)
	UI.panel_opened.connect(func(_p): root.visible = false)
	UI.panel_closed.connect(func(): root.visible = true)


## Add a Control to the right-hand HUD column (needs bars, job timer, objectives...).
func add_widget(c: Control) -> void:
	_right.add_child(c)


func _process(_d: float) -> void:
	_clock.text = GameClock.time_string()
	_date.text = GameClock.date_string()
	var life := get_node_or_null("/root/Life")
	if life and "money" in life:
		var m = life.money
		if m is Object and "cash" in m:
			m = m.cash
		_money.text = "$%s" % _commas(m) if (m is int or m is float) else str(m)
	else:
		_money.text = ""
	if _player == null:
		_player = GameState.get_player()
		if _player and _player.has_signal("focus_changed"):
			_player.focus_changed.connect(_on_focus)
	if _player:
		_district.text = _nearest_district(_player.global_position)
		if _player.get("sitting"):
			_prompt.text = "[E] Stand up"
		elif _player.get("focus") == null:
			_prompt.text = ""
	_update_needs(life)
	_fps.visible = Settings.show_fps
	_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _on_focus(it: Interactable) -> void:
	_prompt.text = it.get_prompt(_player) if it else ""


var _dist_cache := ""
var _dist_t := 0.0
func _nearest_district(p: Vector3) -> String:
	_dist_t -= get_process_delta_time()
	if _dist_t > 0.0:
		return _dist_cache
	_dist_t = 1.0
	var best := INF
	for d in CityData.labels.get("districts", []):
		var dd := Vector2(d["x"] - p.x, d["z"] - p.z).length()
		if dd < best:
			best = dd
			_dist_cache = d["name"]
	return _dist_cache


static func _commas(v) -> String:
	var s := str(int(v))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out


# --- Needs ------------------------------------------------------------------

func _build_needs(v: VBoxContainer) -> void:
	var life := get_node_or_null("/root/Life")
	if life == null or not ("needs" in life) or life.needs == null:
		return
	v.add_child(HSeparator.new())
	_mood = Label.new()
	v.add_child(_mood)
	for id in life.needs.ids():
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = life.needs.label(id)
		l.custom_minimum_size = Vector2(84, 0)
		l.add_theme_font_size_override("font_size", 15)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(130, 10)
		bar.show_percentage = false
		bar.max_value = 100
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		v.add_child(row)
		_bars[id] = bar
	_activity = Label.new()
	_activity.add_theme_color_override("font_color", UI.BLUE)
	_activity.visible = false
	v.add_child(_activity)
	_activity_bar = ProgressBar.new()
	_activity_bar.custom_minimum_size = Vector2(214, 8)
	_activity_bar.max_value = 1.0
	_activity_bar.show_percentage = false
	_activity_bar.visible = false
	v.add_child(_activity_bar)


func _update_needs(life: Node) -> void:
	if life == null or _bars.is_empty():
		return
	_mood.text = "Mood: %s" % life.needs.mood_label() if life.needs.enabled else "Needs off"
	for id in _bars:
		var val: float = life.needs.get_value(id)
		var bar: ProgressBar = _bars[id]
		bar.value = val
		bar.modulate = Color(1, 0.35, 0.3) if val < 20.0 else (Color(1, 0.85, 0.4) if val < 45.0 else Color(0.55, 0.95, 0.6))
	var busy: bool = life.actions.busy()
	_activity.visible = busy
	_activity_bar.visible = busy
	if busy:
		_activity.text = str(life.actions.get_def(life.actions.current.id).get("name", ""))
		_activity_bar.value = life.actions.progress()
