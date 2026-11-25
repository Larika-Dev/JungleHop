## Talk to an NPC. Lives under the NPC body's collider so the player's look ray
## finds it. Actions come from Life (godot/life) when it is installed: 62
## social and romance actions with relationship tiers. Without Life, NPCs still
## greet you and say a line.
extends Interactable

var body: Node3D


func setup(p_body: Node3D) -> void:
	body = p_body
	display_name = body.display_name
	default_action_id = "converse"
	default_action_label = "Talk"


func get_actions(actor: Node) -> Array[Dictionary]:
	var life := get_node_or_null("/root/Life")
	if life and "actions" in life and life.actions and life.actions.has_method("interactable_actions"):
		var acts: Array[Dictionary] = []
		# A real conversation (Dialogue: 4+ choices per turn) comes first, so E starts talking.
		if get_node_or_null("/root/Dialogue"):
			acts.append({"id": "converse", "label": "Talk", "minutes": 0})
		acts.append_array(life.actions.interactable_actions(body))
		return acts
	return [{"id": "talk", "label": "Talk", "minutes": 5}, {"id": "wave", "label": "Wave", "minutes": 0}]


func perform(action_id: String, actor: Node) -> void:
	var dlg := get_node_or_null("/root/Dialogue")
	if action_id == "converse" and dlg:
		if body and body.has_method("face_toward") and actor is Node3D:
			body.face_toward(actor.global_position)
		if body:
			body.set_meta("talking", true)
			var b := body
			var done := func(_id = ""):
				if is_instance_valid(b) and b.has_meta("talking"):
					b.remove_meta("talking")
			if dlg.has_signal("conversation_ended"):
				dlg.conversation_ended.connect(done, CONNECT_ONE_SHOT)
			UI.panel_closed.connect(done, CONNECT_ONE_SHOT)
		dlg.open_conversation(body)
		super.perform(action_id, actor)
		return
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
