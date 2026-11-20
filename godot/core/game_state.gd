extends Node
## Player profile, save/load registry and the global action bus.
## Autoload name: GameState. See docs/INTERFACES.md.

signal game_started
## Emitted once the city scene is loaded and the player is spawned. Add your streamers / managers
## as children of `world` (a Node3D at the city origin). Also available later as GameState.world.
signal world_ready(world: Node3D)
signal game_saved(slot: int)
signal game_loaded(slot: int)
## Fired for EVERY interaction the player (or an NPC) performs through an Interactable.
## Life systems listen here to apply needs, skills, money and relationship effects.
signal action_performed(action_id: String, target: Node, actor: Node)
signal profile_changed

const SAVE_DIR := "user://saves"
## Every new life starts with this much cash. Life systems read it from player_profile.starting_cash.
const STARTING_CASH := 1000

var player_profile: Dictionary = default_profile()
var in_game: bool = false
var world: Node3D = null

var _saveables: Dictionary = {}  # id -> Node with save_data()/load_data()
var _pending: Dictionary = {}    # loaded data for ids that register later


func _ready() -> void:
	register_saveable("clock", GameClock)


static func bmi(p: Dictionary) -> float:
	var h: float = float(p.get("height_cm", 175)) / 100.0
	return float(p.get("weight_kg", 70.0)) / (h * h)


static func default_profile() -> Dictionary:
	return {
		"starting_cash": STARTING_CASH,
		"name": "Alex",
		"sex": "male",          # "male" | "female"
		"age": 20,              # 18..80
		"height_cm": 175,       # 150..200
		"weight_kg": 70.0,      # 40..150; BMI drives body shape (and attractiveness in Life)
		"muscle": 4,            # 1..10 starting muscularity preset (7 = best for attractiveness)
		"build": 0.5,           # derived 0 slim .. 1 heavy (from BMI), used by the body mesh
		"skin": 2,              # index into Appearance.SKIN_TONES
		"hair_style": 1,        # index into Appearance.HAIR_STYLES
		"hair_color": 1,        # index into Appearance.HAIR_COLORS
		"shirt_color": 0,       # index into Appearance.CLOTH_COLORS
		"pants_color": 3,
	}


func get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


## Register any node that should persist. It needs save_data() -> Dictionary and load_data(d).
func register_saveable(id: String, node: Object) -> void:
	_saveables[id] = node
	if _pending.has(id) and node.has_method("load_data"):
		node.load_data(_pending[id])
		_pending.erase(id)


func unregister_saveable(id: String) -> void:
	_saveables.erase(id)


func emit_action(action_id: String, target: Node, actor: Node) -> void:
	action_performed.emit(action_id, target, actor)


func save_path(slot: int) -> String:
	return "%s/slot%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(save_path(slot))


func save_game(slot: int = 1) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {"version": 1, "profile": player_profile, "systems": {}}
	var p := get_player()
	if p:
		data["player_pos"] = [p.global_position.x, p.global_position.y, p.global_position.z, p.rotation.y]
	for id in _saveables:
		var n = _saveables[id]
		if is_instance_valid(n) and n.has_method("save_data"):
			data["systems"][id] = n.save_data()
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	game_saved.emit(slot)
	return true


## Reads the save. Systems get load_data() immediately; the world applies player_pos after it spawns.
func load_game(slot: int = 1) -> Dictionary:
	if not has_save(slot):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	player_profile = default_profile()
	player_profile.merge(data.get("profile", {}), true)
	_pending.clear()
	var systems: Dictionary = data.get("systems", {})
	for id in systems:
		var n = _saveables.get(id)
		if is_instance_valid(n) and n.has_method("load_data"):
			n.load_data(systems[id])
		else:
			_pending[id] = systems[id]
	game_loaded.emit(slot)
	return data
