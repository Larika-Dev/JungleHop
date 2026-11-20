extends PanelContainer
## Light character customization: name, sex, height, build, skin, hair, clothes.
## Emits confirmed(profile) with a GameState.player_profile-shaped Dictionary.

signal confirmed(profile: Dictionary)

var profile: Dictionary = GameState.default_profile()
var _preview: CharacterAppearance
var _pivot: Node3D
var _height_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	add_child(h)
	# preview
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(620, 0)
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#0B1424")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	sv.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_color = Color("#FFC98A")
	key.light_energy = 1.6
	sv.add_child(key)
	var floor := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.8
	pm.bottom_radius = 0.8
	pm.height = 0.04
	floor.mesh = pm
	floor.position.y = -0.02
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#142B4E")
	floor.material_override = fm
	sv.add_child(floor)
	_pivot = Node3D.new()
	sv.add_child(_pivot)
	_preview = CharacterAppearance.new()
	_pivot.add_child(_preview)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.3)
	cam.rotation_degrees.x = -6
	cam.fov = 40
	sv.add_child(cam)
	# options
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 0)
	h.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	var t := Label.new()
	t.text = "Create your character"
	t.theme_type_variation = "HeaderMedium"
	v.add_child(t)
	var name_edit := LineEdit.new()
	name_edit.text = profile["name"]
	name_edit.placeholder_text = "Name"
	name_edit.max_length = 24
	name_edit.text_changed.connect(func(s): profile["name"] = s)
	_row(v, "Name", name_edit)
	_choice(v, "Body", ["Male", "Female"], 0, func(i):
		profile["sex"] = ["male", "female"][i]
		profile["height_cm"] = 176 if i == 0 else 163
		_height_slider.value = profile["height_cm"])
	_height_slider = HSlider.new()
	_height_slider.min_value = 150
	_height_slider.max_value = 200
	_height_slider.step = 1
	_height_slider.value = profile["height_cm"]
	_height_slider.custom_minimum_size.x = 300
	_height_label = Label.new()
	_height_slider.value_changed.connect(func(x):
		profile["height_cm"] = int(x)
		_height_label.text = _fmt_height(int(x))
		_refresh())
	_height_label.text = _fmt_height(profile["height_cm"])
	var hh := HBoxContainer.new()
	hh.add_child(_height_slider)
	hh.add_child(_height_label)
	_row(v, "Height", hh)
	var build := HSlider.new()
	build.min_value = 0
	build.max_value = 1
	build.step = 0.05
	build.value = profile["build"]
	build.custom_minimum_size.x = 300
	build.value_changed.connect(func(x):
		profile["build"] = x
		_refresh())
	_row(v, "Build", build)
	_swatches(v, "Skin tone", CharacterAppearance.SKIN_TONES, "skin")
	_choice(v, "Hair style", CharacterAppearance.HAIR_STYLES, profile["hair_style"], func(i): profile["hair_style"] = i)
	_swatches(v, "Hair color", CharacterAppearance.HAIR_COLORS, "hair_color")
	_swatches(v, "Shirt", CharacterAppearance.CLOTH_COLORS, "shirt_color")
	_swatches(v, "Pants", CharacterAppearance.CLOTH_COLORS, "pants_color")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(on_back)
	row.add_child(back)
	var go := Button.new()
	go.text = "Start life in Cathedral Mount"
	go.pressed.connect(func():
		if String(profile["name"]).strip_edges() == "":
			profile["name"] = "Alex"
		confirmed.emit(profile))
	row.add_child(go)
	_refresh()
	go.grab_focus()


var _height_slider: HSlider


func on_back() -> void:
	UI.close_panel(self)


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += delta * 0.5


static func _fmt_height(cm: int) -> String:
	var inches := cm / 2.54
	return "%d cm  (%d'%d\")" % [cm, int(inches / 12), int(round(fmod(inches, 12.0)))]


func _refresh() -> void:
	_preview.build(profile)
	_preview.set_first_person(false)


func _row(v: VBoxContainer, label: String, c: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 150
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	v.add_child(h)


func _choice(v: VBoxContainer, label: String, names: Array, sel: int, cb: Callable) -> void:
	var o := OptionButton.new()
	for n in names:
		o.add_item(n)
	o.selected = sel
	o.item_selected.connect(func(i):
		cb.call(i)
		_refresh())
	_row(v, label, o)


func _swatches(v: VBoxContainer, label: String, colors: Array, key: String) -> void:
	var h := HFlowContainer.new()
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.set_corner_radius_all(20)
		b.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate()
		sbh.border_color = Color.WHITE
		sbh.set_border_width_all(3)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("focus", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var idx := i
		b.pressed.connect(func():
			profile[key] = idx
			_refresh())
		h.add_child(b)
	_row(v, label, h)
