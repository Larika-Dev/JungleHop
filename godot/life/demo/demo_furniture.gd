extends Node
## Stand-in for the furniture thread's interactables, for the demo and tests.

signal action_started(action_id: String, actor: Node, furniture: Node)
signal action_finished(action_id: String, actor: Node, furniture: Node)

@export var furniture_kind: String = "bed"
@export var display_name: String = "Bed"
var native: Array = []
var _held: String = ""


func _ready() -> void:
	add_to_group("furniture")


func get_actions() -> Array:
	return native


## Mirrors the furniture thread: timed actions finish at once (Life skips the
## clock), held poses ("sit", "lie_down") finish on stand_up().
func perform(action_id: String, actor: Node = null) -> void:
	if action_id in ["sit", "lie_down"]:
		_held = action_id
		action_started.emit(action_id, actor, self)
		return
	action_started.emit(action_id, actor, self)
	action_finished.emit(action_id, actor, self)


func stand_up(actor: Node = null) -> void:
	if _held != "":
		var a := _held
		_held = ""
		action_finished.emit(a, actor, self)
