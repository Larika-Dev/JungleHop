class_name PCMinigame
extends JobMinigame
## Work computer: a monitor with one work app. Each round is a task (a
## customer, a check, a patient...) with one or more fields the player types
## and confirms with Enter. Scored per field, with a speed factor.
##
## Subclasses override _app_name(), _make_task() and optionally _check_field().
## _make_task() returns {"screen": bbcode, "side": bbcode, "fields": [{label, answer, kind}]}
## where kind is "text" (case-insensitive, spaces ignored), "exact", "number" or "money".

var screen_text: RichTextLabel
var side_text: RichTextLabel
var field_label: Label
var input: LineEdit
var log_text: RichTextLabel
var app_label: Label

var task: Dictionary = {}
var field_index := 0
var field_scores: Array[float] = []
var par_seconds := 20.0

const C_SCREEN := Color(0.06, 0.12, 0.16)
const C_BEZEL := Color(0.13, 0.13, 0.14)
const C_ACCENT := Color(0.5, 0.71, 0.85)  # HEAVEN_BLUE


func _app_name() -> String:
	return "Work terminal"


func _make_task() -> Dictionary:
	return {"screen": "", "fields": []}


func _build_body(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var bezel := PanelContainer.new()
	bezel.custom_minimum_size = Vector2(1100, 640)
	var bs := StyleBoxFlat.new()
	bs.bg_color = C_BEZEL
	bs.set_corner_radius_all(14)
	bs.set_content_margin_all(22)
	bezel.add_theme_stylebox_override("panel", bs)
	center.add_child(bezel)
	var scr := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = C_SCREEN
	ss.set_content_margin_all(0)
	scr.add_theme_stylebox_override("panel", ss)
	bezel.add_child(scr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	scr.add_child(v)
	var bar := PanelContainer.new()
	var bars := StyleBoxFlat.new()
	bars.bg_color = Color(0.08, 0.17, 0.31)  # ONSU_NAVY-ish title bar
	bars.set_content_margin_all(6)
	bar.add_theme_stylebox_override("panel", bars)
	v.add_child(bar)
	app_label = Label.new()
	app_label.text = _app_name()
	app_label.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(app_label)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	screen_text = _rich(h, 0.62)
	side_text = _rich(h, 0.38)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	field_label = Label.new()
	field_label.custom_minimum_size.x = 300
	field_label.add_theme_color_override("font_color", C_ACCENT)
	field_label.add_theme_font_size_override("font_size", 20)
	row.add_child(field_label)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 22)
	input.placeholder_text = "type here, Enter to confirm"
	input.text_submitted.connect(_on_submit)
	row.add_child(input)
	log_text = RichTextLabel.new()
	log_text.custom_minimum_size.y = 70
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_color_override("default_color", Color(0.7, 0.75, 0.78))
	v.add_child(log_text)


func _rich(parent: Control, ratio: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_stretch_ratio = ratio
	r.add_theme_color_override("default_color", Color(0.86, 0.92, 0.9))
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("mono_font_size", 19)
	var m := StyleBoxEmpty.new()
	m.set_content_margin_all(14)
	r.add_theme_stylebox_override("normal", m)
	parent.add_child(r)
	return r


func _new_round() -> void:
	task = _make_task()
	field_index = 0
	field_scores.clear()
	if screen_text:
		screen_text.text = task.get("screen", "")
		side_text.text = task.get("side", "")
		_show_field()
		input.clear()
		if input.is_inside_tree():
			input.grab_focus()


func _show_field() -> void:
	if field_label and field_index < task.fields.size():
		field_label.text = "%s (%d/%d)" % [task.fields[field_index].label, field_index + 1, task.fields.size()]


func _on_submit(text: String) -> void:
	submit_text(text)
	input.clear()


## Types one field. Returns that field's score.
func submit_text(text: String) -> float:
	if _waiting_next or task.is_empty() or field_index >= task.fields.size():
		return 0.0
	var f: Dictionary = task.fields[field_index]
	var s := _check_field(f, text)
	field_scores.append(s)
	if log_text:
		log_text.append_text("[color=%s]%s: %s[/color]%s\n" % [
			"#7fd88a" if s >= 0.99 else "#f2a03d" if s > 0.0 else "#f26b5b", f.label, text,
			"" if s >= 0.99 else "   (expected %s)" % str(f.answer)])
	field_index += 1
	if field_index >= task.fields.size():
		var total := 0.0
		for x in field_scores:
			total += x
		finish_round(total / maxf(1, field_scores.size()) * time_factor(par_seconds))
	else:
		_show_field()
	return s


func _check_field(f: Dictionary, text: String) -> float:
	var kind: String = f.get("kind", "text")
	var want := str(f.answer)
	match kind:
		"number":
			return 1.0 if text.strip_edges().is_valid_float() and absf(text.to_float() - float(f.answer)) < 0.001 else 0.0
		"money":
			var t := text.strip_edges().replace("$", "").replace(",", "")
			return 1.0 if t.is_valid_float() and absf(t.to_float() - float(f.answer)) < 0.005 else 0.0
		"exact":
			return 1.0 if text.strip_edges() == want else 0.0
		_:
			var a := text.to_lower().replace(" ", "").replace("-", "")
			var b := want.to_lower().replace(" ", "").replace("-", "")
			if a == b:
				return 1.0
			# One typo allowed for long free text, at half credit.
			if b.length() >= 8 and _lev(a, b) <= 1:
				return 0.5
			return 0.0


func _lev(a: String, b: String) -> int:
	var prev := []
	for j in b.length() + 1:
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur := [i]
		for j in range(1, b.length() + 1):
			cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (0 if a[i - 1] == b[j - 1] else 1)))
		prev = cur
	return prev[b.length()]


func simulate_round(perfect: bool) -> float:
	_waiting_next = false
	var before := scores.size()
	for f in task.fields.duplicate():
		submit_text(str(f.answer) if perfect else _wrong(f))
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s


func _wrong(f: Dictionary) -> String:
	var k: String = f.get("kind", "text")
	if k == "number" or k == "money":
		return str(float(f.answer) + 7.0)
	return "zzz" + str(f.answer) + "q"


## Formats money without float noise.
func money(v: float) -> String:
	return "%.2f" % v
