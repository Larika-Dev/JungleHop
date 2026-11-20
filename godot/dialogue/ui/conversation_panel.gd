extends Control
## Conversation window: the NPC's line on top, the player's choices below
## (click, or press 1-9). Opened by Dialogue.open_conversation(npc, extra).
## Closes itself when the conversation ends (and calls UI.close_panel if UI exists).

var npc
var npc_id := ""
var _name_label: Label
var _line_label: RichTextLabel
var _options_box: VBoxContainer
var _buttons: Array[Button] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.55
	panel.anchor_bottom = 0.95
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	v.add_child(_name_label)
	_line_label = RichTextLabel.new()
	_line_label.fit_content = true
	_line_label.bbcode_enabled = false
	_line_label.custom_minimum_size = Vector2(0, 60)
	v.add_child(_line_label)
	v.add_child(HSeparator.new())
	_options_box = VBoxContainer.new()
	v.add_child(_options_box)


func begin(target, extra: Dictionary = {}) -> void:
	npc = target
	npc_id = Dialogue._npc_id(target)
	var display := npc_id
	if target is Object and "display_name" in target:
		display = str(target.display_name)
	_name_label.text = display
	Dialogue.conversation_updated.connect(_on_updated)
	Dialogue.start_conversation(target, extra)


func _on_updated(id: String, state: Dictionary) -> void:
	if id != npc_id:
		return
	var text: String = state.npc_line
	if state.get("npc_followup", "") != "":
		text += "\n" + state.npc_followup
	_line_label.text = "\"%s\"" % text if text != "..." else "..."
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	if state.ended:
		var close := Button.new()
		close.text = "(Leave)"
		close.pressed.connect(_close)
		_options_box.add_child(close)
		_buttons.append(close)
		return
	var i := 1
	for o in state.options:
		var b := Button.new()
		b.text = "%d. %s" % [i, o.label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var oid: String = o.id
		b.pressed.connect(func(): Dialogue.choose(npc, oid))
		_options_box.add_child(b)
		_buttons.append(b)
		i += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < _buttons.size():
			_buttons[n].pressed.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()


func _close() -> void:
	if Dialogue.conversation_updated.is_connected(_on_updated):
		Dialogue.conversation_updated.disconnect(_on_updated)
	Dialogue.end_conversation(npc)
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("close_panel"):
		ui.close_panel()
	queue_free()
