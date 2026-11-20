extends Node
## Stand-in for the furniture thread's interactables, for the demo and tests.

signal action_started(action_id: String, actor: Node, furniture: Node)
signal action_finished(action_id: String, actor: Node, furniture: Node)

@export var furniture_kind: String = "bed"
@export var display_name: String = "Bed"
var native: Array = []


func _ready() -> void:
	add_to_group("furniture")


func get_actions() -> Array:
	return native


func perform(action_id: String, actor: Node = null) -> void:
	action_started.emit(action_id, actor, self)
	# Real furniture owns its own timing; the stand-in just skips the clock.
	for a in native:
		if a.get("id", "") == action_id and int(a.get("duration_game_minutes", 0)) > 0:
			get_node("/root/Life").clock.advance_minutes(int(a.duration_game_minutes))
	action_finished.emit(action_id, actor, self)
