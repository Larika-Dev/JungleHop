extends PanelContainer
## People the player knows: tier, friendship, romance, flags.

var _life: Node
var _list: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(440, 420)
	var root := VBoxContainer.new()
	add_child(root)
	var t := Label.new()
	t.text = "People you know"
	t.add_theme_font_size_override("font_size", 20)
	root.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _ready() -> void:
	_life = get_node_or_null("/root/Life")
	if _life:
		_life.relationships.relationship_changed.connect(func(_a, _b, _c): refresh())
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _life == null:
		return
	var ids: Array = _life.relationships.people()
	ids.sort_custom(func(a, b): return _life.relationships.friendship(a) > _life.relationships.friendship(b))
	if ids.is_empty():
		var l := Label.new()
		l.text = "You haven't met anyone yet."
		_list.add_child(l)
	for id in ids:
		var r: Dictionary = _life.relationships.get_rel(id)
		var row := VBoxContainer.new()
		var name_l := Label.new()
		var rt := "" if r.romance_tier == "none" else "  |  " + str(r.romance_tier).capitalize()
		name_l.text = "%s  -  %s%s" % [r.name, _life.relationships.TIER_LABELS.get(r.tier, r.tier), rt]
		row.add_child(name_l)
		var bars := HBoxContainer.new()
		bars.add_child(_bar("Friendship", (r.friendship + 100.0) / 2.0, Color(0.5, 0.8, 1.0)))
		bars.add_child(_bar("Romance", r.romance, Color(1.0, 0.5, 0.7)))
		row.add_child(bars)
		var flags: Array = r.flags.filter(func(f): return f != "met")
		if not flags.is_empty():
			var fl := Label.new()
			fl.text = ", ".join(flags).replace("_", " ")
			fl.modulate = Color(1, 1, 1, 0.6)
			row.add_child(fl)
		_list.add_child(row)
		_list.add_child(HSeparator.new())


func _bar(label: String, v: float, c: Color) -> Control:
	var box := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(110, 12)
	b.show_percentage = false
	b.value = v
	b.modulate = c
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	return box
