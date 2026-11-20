class_name DoorInteractable
extends Interactable
## Open / close for Door.


func _door() -> Door:
	var n := get_parent()
	while n and not (n is Door):
		n = n.get_parent()
	return n as Door


func get_actions(_actor: Node) -> Array[Dictionary]:
	var d := _door()
	var open := d != null and d.is_open
	return [{"id": "close_door" if open else "open_door", "label": "Close" if open else "Open"}]


func perform(action_id: String, actor: Node) -> void:
	var d := _door()
	if d:
		d.toggle()
	super.perform(action_id, actor)
