extends Control
## Playable test bench for the life core: pick a target on the left, pick an
## action on the right. Time runs at 1 game hour per real minute (adjustable).

const ActionMenu := preload("res://life/ui/action_menu.gd")
const LifeHud := preload("res://life/ui/life_hud.gd")
const RelPanel := preload("res://life/ui/relationships_panel.gd")
const DemoNpc := preload("res://life/demo/demo_npc.gd")
const DemoFurniture := preload("res://life/demo/demo_furniture.gd")

const PLACES := [
	{"id": "HAM_N_004", "name": "Pamlico Coffee House", "business_type": "cafe", "category": "food", "room_type": "cafe", "room_id": "CM_HAM_N_004_F0_R1", "tags": ["social_hub"]},
	{"id": "HAM_N_000", "name": "Top of the Mount", "business_type": "brewpub", "category": "drink", "room_type": "bar", "room_id": "CM_HAM_N_000_F0_R2", "tags": ["social_hub"]},
	{"id": "BANK", "name": "Bluebird Savings Bank", "business_type": "bank", "category": "finance", "room_type": "banking_hall", "room_id": "CM_BANK_F0_R1"},
	{"id": "LIB", "name": "Wilberforce Library", "typology": "library", "room_type": "reading_room", "room_id": "CM_LIB_F0_R1"},
	{"id": "CINEMA", "name": "Junior Varsity Cinema", "business_type": "cinema", "room_type": "theater", "room_id": "CM_CIN_F0_R2"},
	{"id": "QUAD", "name": "Founders' Quad (outside)"},
]

var _life: Node
var _menu: PanelContainer
var _targets: VBoxContainer
var _rel: PanelContainer
var _place_label: Label


func _ready() -> void:
	_life = get_node("/root/Life")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.13, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(LifeHud.new())
	var cols := HBoxContainer.new()
	cols.position = Vector2(270, 16)
	cols.add_theme_constant_override("separation", 16)
	add_child(cols)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(270, 720)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left_scroll.add_child(left)
	_place_label = Label.new()
	left.add_child(_place_label)
	_targets = VBoxContainer.new()
	left.add_child(_targets)
	_menu = ActionMenu.new()
	_menu.custom_minimum_size = Vector2(400, 720)
	cols.add_child(_menu)
	_menu.closed.connect(func(): _menu.show())
	_rel = RelPanel.new()
	_rel.hide()
	cols.add_child(_rel)
	_build_world()
	_build_targets(left)
	_life.place_changed.connect(func(_p): _update_place_label())
	_life.auto_place = false
	_life.set_place(PLACES[0])
	_update_place_label()
	_menu.open_for(null)


func _build_world() -> void:
	var people := [
		["npc_0001", "Ava Pruitt", 20, {"outgoing": 0.8, "kind": 0.7, "wild": 0.4, "lawful": 0.7, "ambitious": 0.5}, ["music", "art"]],
		["npc_0002", "Marcus Hale", 22, {"outgoing": 0.4, "kind": 0.5, "wild": 0.7, "lawful": 0.3, "ambitious": 0.6}, ["sports", "partying"]],
		["npc_0003", "Priya Natarajan", 24, {"outgoing": 0.6, "kind": 0.9, "wild": 0.2, "lawful": 0.9, "ambitious": 0.9}, ["school", "gaming"]],
	]
	for p in people:
		var n := DemoNpc.new()
		n.npc_id = p[0]
		n.display_name = p[1]
		n.age = p[2]
		n.traits = p[3]
		n.interests = p[4]
		n.name = p[0]
		add_child(n)
	var furn := [
		["bed", "Bed", [{"id": "sleep", "label": "Sleep", "duration_game_minutes": 480}, {"id": "nap", "label": "Nap", "duration_game_minutes": 60}, {"id": "lie_down", "label": "Lie down"}]],
		["stove", "Stove", [{"id": "cook", "label": "Cook", "duration_game_minutes": 30}]],
		["shower", "Shower", []],
		["toilet", "Toilet", []],
		["sink", "Sink", [{"id": "wash_hands", "label": "Wash hands"}]],
		["fridge", "Fridge", [{"id": "open", "label": "Open"}]],
		["tv", "TV", []],
		["desk", "Desk", [{"id": "study", "label": "Study"}, {"id": "work_at_desk", "label": "Work"}]],
		["computer", "Computer", []],
		["piano", "Piano", []],
		["weights", "Weight bench", []],
		["pool_table", "Pool table", []],
		["arcade", "Arcade cabinet", [{"id": "jiggle_coin_slot", "label": "Jiggle the coin slot", "needs_effects": {"fun": 3}}]],
	]
	for f in furn:
		var node := DemoFurniture.new()
		node.furniture_kind = f[0]
		node.display_name = f[1]
		node.native = f[2]
		node.name = "F_" + f[0]
		add_child(node)


func _build_targets(left: VBoxContainer) -> void:
	_add_heading("You")
	_add_target("Yourself / this place", null)
	_add_heading("People")
	for n in get_tree().get_nodes_in_group("npc"):
		_add_target(n.display_name, n)
	_add_heading("Furniture")
	for n in get_tree().get_nodes_in_group("furniture"):
		_add_target(n.display_name, n)
	_add_heading("Go to")
	for p in PLACES:
		var b := Button.new()
		b.text = p.name
		b.pressed.connect(func(): _life.set_place(p); _menu.open_for(null))
		_targets.add_child(b)
	_add_heading("Time")
	var speed := HSlider.new()
	speed.min_value = 1
	speed.max_value = 60
	speed.value = 1
	speed.value_changed.connect(func(v): _life.clock.speed = v)
	_targets.add_child(speed)
	var row := HBoxContainer.new()
	for label in ["Skip 1 h", "People", "Save", "Load"]:
		var b := Button.new()
		b.text = label
		row.add_child(b)
		match label:
			"Skip 1 h": b.pressed.connect(func(): _life.clock.advance_minutes(60))
			"People": b.pressed.connect(func(): _rel.visible = not _rel.visible; _rel.refresh())
			"Save": b.pressed.connect(func(): _life.notify.emit("Saved." if _life.save_game() else "Save failed."))
			"Load": b.pressed.connect(func(): _life.notify.emit("Loaded." if _life.load_game() else "No save."))
	_targets.add_child(row)


func _add_heading(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.modulate = Color(1, 1, 1, 0.6)
	_targets.add_child(l)


func _add_target(label: String, t: Variant) -> void:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func(): _menu.open_for(t))
	_targets.add_child(b)


func _update_place_label() -> void:
	_place_label.text = "At: %s" % _life.place.get("name", "somewhere")
