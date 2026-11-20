extends CanvasLayer
## Needs bars, money, clock, the running action, and toasts.
## Add with: add_child(preload("res://life/ui/life_hud.gd").new())
## The foundation HUD already shows the clock; set show_clock=false then.

var show_clock: bool = true
var show_money: bool = true

var _life: Node
var _clock_label: Label
var _money_label: Label
var _mood_label: Label
var _bars: Dictionary = {}
var _activity: VBoxContainer
var _activity_label: Label
var _activity_bar: ProgressBar
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 5
	_life = get_node_or_null("/root/Life")
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.modulate = Color(1, 1, 1, 0.92)
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(230, 0)
	panel.add_child(box)
	_clock_label = Label.new()
	_clock_label.visible = show_clock
	box.add_child(_clock_label)
	_money_label = Label.new()
	_money_label.visible = show_money
	box.add_child(_money_label)
	_mood_label = Label.new()
	box.add_child(_mood_label)
	if _life:
		for id in _life.needs.ids():
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = _life.needs.label(id)
			l.custom_minimum_size = Vector2(70, 0)
			row.add_child(l)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(150, 14)
			bar.show_percentage = false
			bar.max_value = 100
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			box.add_child(row)
			_bars[id] = bar
	_activity = VBoxContainer.new()
	_activity.anchor_left = 0.5
	_activity.anchor_right = 0.5
	_activity.anchor_top = 1.0
	_activity.anchor_bottom = 1.0
	_activity.offset_left = -170
	_activity.offset_right = 170
	_activity.offset_top = -110
	_activity.offset_bottom = -60
	add_child(_activity)
	_activity_label = Label.new()
	_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity.add_child(_activity_label)
	_activity_bar = ProgressBar.new()
	_activity_bar.max_value = 1.0
	_activity_bar.show_percentage = false
	_activity_bar.custom_minimum_size = Vector2(340, 12)
	_activity.add_child(_activity_bar)
	var cancel := Button.new()
	cancel.text = "Stop"
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func(): _life.actions.cancel())
	_activity.add_child(cancel)
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.anchor_top = 1.0
	_toasts.anchor_bottom = 1.0
	_toasts.offset_left = -380
	_toasts.offset_right = -16
	_toasts.offset_top = -16
	_toasts.offset_bottom = -16
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	add_child(_toasts)
	if _life:
		_life.notify.connect(toast)


func _process(_d: float) -> void:
	if _life == null:
		return
	_clock_label.text = _life.clock.time_string()
	_money_label.text = "Cash %s   Bank %s" % [_life.money.fmt(_life.money.cash), _life.money.fmt(_life.money.bank)]
	if _life.money.debt > 0.0:
		_money_label.text += "   Debt %s" % _life.money.fmt(_life.money.debt)
	_mood_label.text = "Mood: %s" % _life.needs.mood_label() if _life.needs.enabled else "Needs off"
	for id in _bars:
		var v: float = _life.needs.get_value(id)
		var bar: ProgressBar = _bars[id]
		bar.value = v
		bar.modulate = Color(1, 0.35, 0.3) if v < 20.0 else (Color(1, 0.85, 0.4) if v < 45.0 else Color(0.55, 0.95, 0.6))
	var busy: bool = _life.actions.busy()
	_activity.visible = busy
	if busy:
		var def: Dictionary = _life.actions.get_def(_life.actions.current.id)
		_activity_label.text = str(def.get("name", ""))
		_activity_bar.value = _life.actions.progress()


func toast(text: String) -> void:
	if text == "":
		return
	var p := PanelContainer.new()
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
