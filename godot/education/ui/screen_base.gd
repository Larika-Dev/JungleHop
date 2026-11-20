extends Control
## Shared look and plumbing for the education screens (built in code, no
## theme resources). Colors come from the project palette keys.

const CATALOG := preload("res://education/catalog.gd")

const PALETTE := {
	"ONSU_NAVY": Color("#142B4E"), "HEAVEN_BLUE": Color("#80B4D9"), "ONSU_WHITE": Color("#FFFFFF"),
	"TRIM_WHITE": Color("#F3F0E8"), "PLASTER_IVORY": Color("#F2EDE1"), "WALNUT_DARK": Color("#4F3524"),
	"WILLOW_OAK_LEAF": Color("#6B7A35"), "COPPER_PATINA": Color("#5E9C8C"), "PAINT_HOSPITAL_ACCENT": Color("#9CC7C2"),
	"BRASS": Color("#B08D57"), "BRICK_CAMPUS_A": Color("#8E3B2E"), "BIKE_LANE_GREEN": Color("#4F9A5A"),
	"CURB_PAINT_RED": Color("#A8322A"), "MARKING_YELLOW": Color("#E8B923"), "SHUTTER_BLACK": Color("#1E1F1F"),
}

var edu: Node
var opts: Dictionary = {}
var title_label: Label
var sub_label: Label
var body: VBoxContainer
var footer: HBoxContainer
var accent: Color = PALETTE.HEAVEN_BLUE

func setup(p_opts: Dictionary) -> void:
	opts = p_opts
	edu = opts.get("education", null)
	if edu == null and is_inside_tree():
		edu = get_tree().root.get_node_or_null("Education")
	_start()

func _start() -> void:
	pass

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(PALETTE.SHUTTER_BLACK, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.ONSU_NAVY
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", PALETTE.ONSU_WHITE)
	col.add_child(title_label)
	sub_label = Label.new()
	sub_label.add_theme_color_override("font_color", PALETTE.HEAVEN_BLUE)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)

func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for c in footer.get_children():
		footer.remove_child(c)
		c.queue_free()

func add_text(text: String, size: int = 18, color: Color = PALETTE.TRIM_WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
	return l

func make_button(text: String, cb: Callable, enabled: bool = true, tint: Color = Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint if tint.a > 0.0 else Color(PALETTE.ONSU_WHITE, 0.08)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	sb.border_color = accent
	sb.border_width_left = 4
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(accent, 0.35)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(cb)
	return b

func add_button(text: String, cb: Callable, enabled: bool = true, tint: Color = Color(0, 0, 0, 0)) -> Button:
	var b := make_button(text, cb, enabled, tint)
	body.add_child(b)
	return b

func add_footer(text: String, cb: Callable) -> Button:
	var b := make_button(text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(160, 44)
	footer.add_child(b)
	return b

func subject_accent(subject: String) -> Color:
	var key: String = CATALOG.SUBJECTS.get(subject, {}).get("color", "HEAVEN_BLUE")
	return PALETTE.get(key, PALETTE.HEAVEN_BLUE)

func close() -> void:
	if edu and edu.has_method("close_screen"):
		edu.close_screen(self)
	else:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
