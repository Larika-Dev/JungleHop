## NPC generator tool. Open res://npc/generator/npc_generator.tscn (F6 in the
## editor) or show it in game with UI.open_panel(NpcGenerator.new()).
## Complexion slider, height and weight in ft/in + lb or cm + kg, live 3D
## preview, then "Add to city" puts the person into Cathedral Mount with a
## home, a job and a routine (saved in user://npc/custom_npcs.json).
class_name NpcGenerator
extends PanelContainer

var rec: Dictionary
var rng := RandomNumberGenerator.new()
var metric := false
var body: NpcBody
var _ui := {}
var _busy := false


func _ready() -> void:
	rng.randomize()
	custom_minimum_size = Vector2(980, 620)
	# Centered on screen when shown as an in-game panel.
	if get_parent() is Control or get_parent() is CanvasLayer:
		set_anchors_preset(Control.PRESET_CENTER)
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		grow_vertical = Control.GROW_DIRECTION_BOTH
	var h := HBoxContainer.new()
	add_child(h)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 420
	h.add_child(form)
	var title := Label.new()
	title.text = "NPC Generator"
	title.add_theme_font_size_override("font_size", 24)
	form.add_child(title)
	_ui.name = _line(form, "Name")
	_ui.sex = _option(form, "Sex", ["male", "female"])
	_ui.role = _option(form, "Role", ["worker", "student", "retired", "unemployed"])
	_ui.age = _spin(form, "Age", 18, 90, 1)
	_ui.complexion = _slider(form, "Complexion", 0.0, 1.0, 0.01)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(0, 14)
	form.add_child(swatch)
	_ui.swatch = swatch
	_ui.units = _option(form, "Units", ["ft / in / lb", "cm / kg"])
	var hrow := HBoxContainer.new()
	form.add_child(hrow)
	var hl := Label.new(); hl.text = "Height"; hl.custom_minimum_size.x = 110; hrow.add_child(hl)
	_ui.ft = _spin(hrow, "", 4, 7, 1)
	_ui.inch = _spin(hrow, "", 0, 11.9, 0.1)
	_ui.cm = _spin(hrow, "", 120, 230, 0.1)
	_ui.weight = _spin(form, "Weight", 30, 400, 0.1)
	_ui.muscle = _slider(form, "Muscle", 0.0, 1.0, 0.01)
	_ui.personality = _spin(form, "Personality (0-29)", 0, 29, 1)
	_ui.info = Label.new()
	form.add_child(_ui.info)
	var buttons := HBoxContainer.new()
	form.add_child(buttons)
	for b in [["Randomize", _randomize], ["Add to city", _add], ["Copy JSON", _copy], ["Close", _close]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		buttons.add_child(btn)
	# 3D preview.
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(520, 600)
	h.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.0)
	cam.fov = 40
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#c9d2d8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	vp.add_child(env)
	body = NpcBody.new()
	vp.add_child(body)
	_randomize()


func _process(delta: float) -> void:
	if body and body.lod >= 0:
		body.rotation.y += delta * 0.4
		body.animate(delta, 0.0)


## Builds a record from the form. Heights and weights are stored metric.
func current_record() -> Dictionary:
	var r := rec.duplicate(true)
	var parts := String(_ui.name.text).split(" ", false, 1)
	r.first = parts[0] if parts.size() > 0 else "New"
	r.last = parts[1] if parts.size() > 1 else ""
	r.sex = ["male", "female"][_ui.sex.selected]
	r.role = ["worker", "student", "retired", "unemployed"][_ui.role.selected]
	r.age = int(_ui.age.value)
	r.complexion = _ui.complexion.value
	r.muscle = _ui.muscle.value
	r.personality_id = int(_ui.personality.value)
	if metric:
		r.height_cm = snappedf(_ui.cm.value, 0.1)
		r.weight_kg = snappedf(_ui.weight.value, 0.1)
	else:
		r.height_cm = NpcAppearance.ft_in_to_cm(_ui.ft.value, _ui.inch.value)
		r.weight_kg = NpcAppearance.lb_to_kg(_ui.weight.value)
	return r


func _refresh(_x = null) -> void:
	if _busy: return
	var r := current_record()
	var new_metric: bool = _ui.units.selected == 1
	if new_metric != metric:  # convert the shown numbers, keep the person
		metric = new_metric
		_show_numbers(r)
	_ui.ft.visible = not metric
	_ui.inch.visible = not metric
	_ui.cm.visible = metric
	_ui.swatch.color = NpcAppearance.complexion_color(r.complexion)
	var fi := NpcAppearance.cm_to_ft_in(r.height_cm)
	_ui.info.text = "%.1f cm (%d ft %.1f in), %.1f kg (%.1f lb), BMI %.1f" % [r.height_cm, fi.x, fi.y, r.weight_kg, NpcAppearance.kg_to_lb(r.weight_kg), NpcAppearance.bmi(r.height_cm, r.weight_kg)]
	body.apply_record(r)
	body.set_lod(1)


func _show_numbers(r: Dictionary) -> void:
	_busy = true
	if metric:
		_ui.cm.value = r.height_cm
		_ui.weight.value = r.weight_kg
	else:
		var fi := NpcAppearance.cm_to_ft_in(r.height_cm)
		_ui.ft.value = fi.x
		_ui.inch.value = fi.y
		_ui.weight.value = NpcAppearance.kg_to_lb(r.weight_kg)
	_busy = false


func _randomize() -> void:
	rec = NpcPopulation.make_record(rng, {"sex": ["male", "female"][rng.randi() % 2]})
	_busy = true
	_ui.name.text = NpcPopulation.full_name(rec)
	_ui.sex.selected = 0 if rec.sex == "male" else 1
	_ui.age.value = rec.age
	_ui.complexion.value = rec.complexion
	_ui.muscle.value = rec.muscle
	_ui.personality.value = rec.personality_id
	_busy = false
	_show_numbers(rec)
	_refresh()


func _add() -> void:
	var mgr := get_node_or_null("/root/NPCs")
	var r := current_record()
	if mgr:
		mgr.ensure_ready()
		var i: int = mgr.add_npc(r)
		_ui.info.text = "Added %s to the city (index %d, lives at %s)." % [NpcPopulation.full_name(r), i, mgr.population[i].home]
	else:
		_ui.info.text = "NPCs autoload not running; use Copy JSON instead."


func _copy() -> void:
	DisplayServer.clipboard_set(JSON.stringify(current_record(), "  "))
	_ui.info.text = "Copied the record as JSON."


func _close() -> void:
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("close_panel") and ui.is_panel_open():
		ui.close_panel()
	else:
		queue_free()


# --- small form helpers ----------------------------------------------------------

func _row(parent: Node, label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	parent.add_child(r)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 110
	r.add_child(l)
	return r


func _line(parent: Node, label: String) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size.x = 260
	e.text_changed.connect(_refresh)
	_row(parent, label).add_child(e)
	return e


func _option(parent: Node, label: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	for it in items: o.add_item(it)
	o.item_selected.connect(_refresh)
	_row(parent, label).add_child(o)
	return o


func _spin(parent: Node, label: String, lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value_changed.connect(_refresh)
	if label == "": parent.add_child(s)
	else: _row(parent, label).add_child(s)
	return s


func _slider(parent: Node, label: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = 260
	s.value_changed.connect(_refresh)
	_row(parent, label).add_child(s)
	return s
