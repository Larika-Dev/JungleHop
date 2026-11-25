## Wanted stars, police status, and the booking screen after an arrest.
## Added by Law automatically (skipped in headless runs).
extends CanvasLayer

var _stars: Label
var _status: Label
var _toast: Label
var _toast_time := 0.0
var _booking: PanelContainer


func _ready() -> void:
	layer = 20
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -260
	box.offset_top = 64
	box.offset_right = -16
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_stars = Label.new()
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stars.add_theme_font_size_override("font_size", 30)
	_stars.add_theme_constant_override("outline_size", 6)
	box.add_child(_stars)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.add_theme_constant_override("outline_size", 4)
	box.add_child(_status)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_constant_override("outline_size", 4)
	box.add_child(_toast)
	var law := get_parent()
	law.wanted_changed.connect(_on_wanted)
	law.arrested.connect(_on_arrested)
	law.released.connect(func(_r): _close_booking())
	_on_wanted(0, "clear")


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.text = ""


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 4.0


func _on_wanted(stars: int, state: String) -> void:
	var law := get_parent()
	_stars.visible = stars > 0
	_stars.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	_stars.modulate = Color(1.0, 0.85, 0.2) if state != "pursuit" else Color(1.0, 0.35, 0.3)
	var s := ""
	match state:
		"responding": s = "Police on the way"
		"searching": s = "Police searching. Stay out of sight"
		"pursuit": s = "PURSUIT"
	if stars == 0 and law.warrant.size() > 0:
		s = "Warrant out for your arrest"
	if stars == 0 and law.unpaid_fines > 0.0:
		s += ("\n" if s != "" else "") + "Unpaid tickets: $%d" % int(law.unpaid_fines)
	_status.text = s


func _on_arrested(b: Dictionary) -> void:
	if int(b.jail_hours) <= 0:
		return
	var law := get_parent()
	_close_booking()
	_booking = PanelContainer.new()
	_booking.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_booking.custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_booking.add_child(v)
	var title := Label.new()
	title.text = "BOOKED"
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: Array[String] = ["Charges:"]
	for n in b.names:
		lines.append("  • " + String(n))
	lines.append("Fines: $%d%s" % [int(b.fine), "  (could not pay $%d, added as jail time)" % int(b.fine_unpaid) if float(b.fine_unpaid) > 0.0 else ""])
	lines.append("Sentence: %d in-game hours" % int(b.jail_hours))
	body.text = "\n".join(lines)
	v.add_child(body)
	var serve := Button.new()
	serve.text = "Serve the sentence (time skips)"
	serve.pressed.connect(func(): law.serve_sentence())
	v.add_child(serve)
	if bool(b.can_bail):
		var bail := Button.new()
		bail.text = "Post bail ($%d)" % int(b.bail)
		bail.pressed.connect(func(): law.post_bail())
		v.add_child(bail)
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("open_panel"):
		ui.open_panel(_booking)
	else:
		add_child(_booking)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_booking() -> void:
	if _booking == null or not is_instance_valid(_booking):
		_booking = null
		return
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("close_panel") and _booking.get_parent() != self:
		ui.close_panel()
	if is_instance_valid(_booking):
		_booking.queue_free()
	_booking = null
