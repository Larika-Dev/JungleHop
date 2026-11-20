extends PanelContainer
## Lists the actions available for a target, grouped by category, and runs the
## picked one. Blocked actions are shown greyed out with their reason.
## Usage: var m = preload("res://life/ui/action_menu.gd").new(); add_child(m); m.open_for(npc_node)

signal closed()
signal action_chosen(action_id: String)

const CATEGORY_ORDER := ["social", "romance", "food", "hygiene", "rest", "fun", "fitness", "skill",
	"school", "work", "home", "shopping", "money", "crime", "self", "misc"]

var target: Variant = null
var show_blocked: bool = true

var _title: Label
var _filter: LineEdit
var _list: VBoxContainer
var _life: Node


func _init() -> void:
	custom_minimum_size = Vector2(420, 520)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	head.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_menu)
	head.add_child(close)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Search actions"
	_filter.text_changed.connect(func(_t): _rebuild())
	root.add_child(_filter)
	var blocked := CheckBox.new()
	blocked.text = "Show unavailable"
	blocked.button_pressed = show_blocked
	blocked.toggled.connect(func(on): show_blocked = on; _rebuild())
	root.add_child(blocked)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _ready() -> void:
	_life = get_node_or_null("/root/Life")
	hide()


func open_for(t: Variant, title: String = "") -> void:
	target = t
	if _life == null:
		_life = get_node_or_null("/root/Life")
	_title.text = title if title != "" else _target_title(t)
	_filter.text = ""
	_rebuild()
	show()
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("open_panel") and get_parent() == null:
		ui.open_panel(self)


func close_menu() -> void:
	hide()
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("close_panel") and ui.has_method("is_panel_open") and ui.is_panel_open():
		ui.close_panel()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _target_title(t: Variant) -> String:
	if t == null:
		var place_name := ""
		if _life and _life.place.has("name"):
			place_name = " at " + str(_life.place.name)
		return "What do you want to do%s?" % place_name
	if _life and _life.actions.target_kind(t) == "npc":
		var nid: String = _life.actions.npc_id(t)
		var rel: Dictionary = _life.relationships.get_rel(nid)
		return "%s (%s)" % [rel.name, _life.relationships.TIER_LABELS.get(rel.tier, rel.tier)]
	if t is Node and "display_name" in t:
		return str(t.display_name)
	if t is Node and "furniture_kind" in t:
		return str(t.furniture_kind).capitalize()
	if t is Dictionary:
		return str(t.get("name", t.get("id", "Here")))
	return "Actions"


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _life == null:
		return
	var opts: Array = _life.actions.available_for(target, show_blocked)
	var q := _filter.text.strip_edges().to_lower()
	var by_cat := {}
	for o in opts:
		if q != "" and q not in str(o.label).to_lower():
			continue
		var cat: String = str(o.def.get("category", "misc")) if not o.native else "furniture"
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(o)
	var cats: Array = by_cat.keys()
	cats.sort_custom(func(a, b): return _cat_rank(a) < _cat_rank(b))
	for cat in cats:
		var h := Label.new()
		h.text = str(cat).capitalize()
		h.add_theme_font_size_override("font_size", 15)
		h.modulate = Color(1, 1, 1, 0.7)
		_list.add_child(h)
		for o in by_cat[cat]:
			_list.add_child(_make_button(o))
	if opts.is_empty():
		var none := Label.new()
		none.text = "Nothing to do here."
		_list.add_child(none)


func _cat_rank(c: String) -> int:
	var i := CATEGORY_ORDER.find(c)
	return i if i >= 0 else 100


func _make_button(o: Dictionary) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var extra: Array = []
	var mins: int = o.minutes
	if mins > 0:
		extra.append(_dur(mins))
	var cost := float(o.def.get("cost", 0)) if not o.native else 0.0
	if cost > 0.0:
		extra.append(_life.money.fmt(cost))
	var suffix := ("  (" + ", ".join(extra) + ")") if not extra.is_empty() else ""
	b.text = str(o.label) + suffix
	if not o.ok:
		b.disabled = true
		b.text += "  - " + str(o.reason)
		b.tooltip_text = str(o.reason)
	b.pressed.connect(func():
		var id: String = o.id
		close_menu()
		action_chosen.emit(id)
		_life.actions.perform(id, target))
	return b


static func _dur(m: int) -> String:
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%d h" % (m / 60)
	return "%d h %d min" % [m / 60, m % 60]
