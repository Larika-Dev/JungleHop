extends Node
## Stand-in NPC: the NPC thread's nodes expose the same properties.

@export var npc_id: String = ""
@export var display_name: String = ""
@export var age: int = 21
@export var sex: String = ""
var traits: Dictionary = {}
var interests: Array = []


func _ready() -> void:
	add_to_group("npc")
