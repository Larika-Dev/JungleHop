## Talk to an NPC. Lives under the NPC body's collider so the player's look ray
## finds it. Actions come from Life (godot/life) when it is installed: 62
## social and romance actions with relationship tiers. Without Life, NPCs still
## greet you and say a line.
extends Interactable

var body: Node3D


func setup(p_body: Node3D) -> void:
	body = p_body
	display_name = body.display_name
	default_action_id = "talk"
	default_action_label = "Talk"


func get_actions(actor: Node) -> Array[Dictionary]:
	var life := get_node_or_null("/root/Life")
	if life and "actions" in life and life.actions and life.actions.has_method("interactable_actions"):
		var acts: Array[Dictionary] = []
		acts.assign(life.actions.interactable_actions(body))
		return acts
	return [{"id": "talk", "label": "Talk", "minutes": 5}, {"id": "wave", "label": "Wave", "minutes": 0}]


func perform(action_id: String, actor: Node) -> void:
	var life := get_node_or_null("/root/Life")
	if life and "actions" in life and life.actions and life.actions.has_method("perform"):
		life.actions.perform(action_id, body)
	else:
		var line := NpcManagerApi.line_for(body, action_id)
		var ui := get_node_or_null("/root/UI")
		if ui and ui.has_method("notify") and line != "":
			ui.notify("%s: \"%s\"" % [body.display_name, line])
	if body and body.has_method("face_toward") and actor is Node3D:
		body.face_toward(actor.global_position)
	super.perform(action_id, actor)
