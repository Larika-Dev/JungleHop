class_name FurnitureInteractable
extends Interactable
## Interaction for a FurniturePiece. Child of the piece's StaticBody3D, so the player's look ray finds it.
##
## For the life systems (godot/life/): every instance is in group "furniture", carries `furniture_kind`,
## and emits action_started / action_finished(action_id, actor, furniture). Timed actions finish at once
## (Life applies the time skip and need effects); held poses (sit, lie_down) finish when the actor stands up.

signal action_started(action_id: String, actor: Node, furniture: Node)
signal action_finished(action_id: String, actor: Node, furniture: Node)

const POSES := ["sit", "lie_down"]

var piece: FurniturePiece
var furniture_kind: String = ""
## actor -> {"action": id, "slot": int}
var occupants: Dictionary = {}


func _ready() -> void:
	add_to_group("furniture")
	set_process(false)


func get_actions(actor: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if occupants.has(actor):
		out.append({"id": "stand_up", "label": "Stand up", "minutes": 0})
		var cur: String = occupants[actor]["action"]
		for id in piece.def.get("actions", []):
			if id != cur and id not in POSES and (_usable_while_posed(id) or (cur in LYING and id in ["sleep", "nap"])):
				out.append(_entry(id))
		return out
	var door_done := false
	for id in piece.def.get("actions", []):
		if id == "open" or id == "close":
			if piece.has_openables() and not door_done:
				_append_door_actions(out)
				door_done = true
			continue
		if _needs_free_slot(id) and _free_slot(id) < 0:
			continue
		out.append(_entry(id))
	if piece.has_openables() and not door_done:
		_append_door_actions(out)
	return out


func _append_door_actions(out: Array[Dictionary]) -> void:
	if piece.any_open():
		out.append(_entry("close"))
		if not _all_parts_open():
			out.append(_entry("open"))
	else:
		out.append(_entry("open"))


func _entry(id: String) -> Dictionary:
	var mgr := _manager()
	var a: Dictionary = mgr.action_def(id) if mgr else {}
	var label := String(a.get("label", id.capitalize()))
	if id == "toggle_light" and piece.light:
		label = "Turn off the light" if piece.light.visible else "Turn on the light"
	return {"id": id, "label": label, "minutes": int(a.get("minutes", 0))}


func perform(action_id: String, actor: Node) -> void:
	match action_id:
		"stand_up":
			_release(actor)
			super.perform(action_id, actor)
			return
		"sit", "lie_down", "sleep", "nap":
			if not _take_pose(action_id, actor):
				return
		"open":
			piece.set_part_open(true, _actor_pos(actor))
		"close":
			piece.set_part_open(false, _actor_pos(actor) if piece.parts.size() > 1 and _open_count() > 1 else Vector3.INF)
		"toggle_light":
			piece.toggle_light()
	action_started.emit(action_id, actor, self)
	super.perform(action_id, actor)
	if action_id in POSES:
		return # finishes on stand_up
	action_finished.emit(action_id, actor, self)
	# after sleep / nap the actor stays on the bed; "Stand up" is then the first action


# ------------------------------------------------------------------ poses

func _needs_free_slot(id: String) -> bool:
	return id in POSES or id in ["sleep", "nap"]


func _slots_for(id: String) -> Array[Transform3D]:
	if id == "sit":
		return piece.seat_transforms()
	var beds := piece.bed_transforms()
	return beds if not beds.is_empty() else piece.seat_transforms()


func _free_slot(id: String) -> int:
	var slots := _slots_for(id)
	var taken := {}
	for a in occupants:
		taken[occupants[a]["slot"]] = true
	for i in slots.size():
		if not taken.has(i):
			return i
	return -1


const LYING := ["lie_down", "sleep", "nap"]


func _take_pose(id: String, actor: Node) -> bool:
	if occupants.has(actor):
		# already on this piece: sleeping after lying down keeps the same spot
		if id in LYING and FurniturePose.is_lying(actor):
			occupants[actor]["action"] = id if id in POSES else occupants[actor]["action"]
			return true
		_release(actor)
	var slot := _free_slot(id)
	if slot < 0:
		var ui := get_node_or_null("/root/UI") if is_inside_tree() else null
		if ui and ui.has_method("notify"):
			ui.notify("No room on the %s." % furniture_kind.replace("_", " "))
		return false
	var xf: Transform3D = _slots_for(id)[slot]
	occupants[actor] = {"action": id, "slot": slot, "yaw": xf.basis.get_euler().y}
	if actor is PhysicsBody3D and piece:
		(actor as PhysicsBody3D).add_collision_exception_with(piece)
	if id in LYING and not piece.bed_transforms().is_empty():
		FurniturePose.lie(actor, xf)
	elif actor.has_method("sit_at"):
		actor.sit_at(xf)
	elif actor is Node3D:
		(actor as Node3D).global_transform = xf
	# the player can also get up with the movement keys; follow that
	if actor.has_signal("stood_up") and not actor.is_connected("stood_up", _on_actor_stood_up.bind(actor)):
		actor.connect("stood_up", _on_actor_stood_up.bind(actor), CONNECT_ONE_SHOT)
	set_process(true)
	return true


func _on_actor_stood_up(actor: Node) -> void:
	if occupants.has(actor):
		_release(actor, false)


func _process(_delta: float) -> void:
	# keep a lying body on the bed: mouse look turns the head only up/down
	var any := false
	for a in occupants:
		if is_instance_valid(a) and FurniturePose.is_lying(a):
			any = true
			if a.get("_yaw") != null:
				a.set("_yaw", float(occupants[a]["yaw"]))
	if not any:
		set_process(false)


## Where to stand after getting out of bed or off a seat: beside a bed, else in front of the piece.
func _stand_spot(actor: Node) -> Vector3:
	if not piece.bed_transforms().is_empty():
		var size: Array = piece.def.get("size_m", [1, 0.5, 2])
		var side := 1.0
		if actor is Node3D:
			side = 1.0 if piece.to_local((actor as Node3D).global_position).x >= 0.0 else -1.0
		return piece.to_global(Vector3(side * (float(size[0]) * 0.5 + 0.4), 0, 0))
	return piece.approach_transform().origin


func _release(actor: Node, stand := true) -> void:
	if not occupants.has(actor):
		return
	var held: String = occupants[actor]["action"]
	occupants.erase(actor)
	var lying := FurniturePose.is_lying(actor)
	var spot := _stand_spot(actor) if lying else Vector3.INF
	if stand:
		if actor.has_signal("stood_up") and actor.is_connected("stood_up", _on_actor_stood_up.bind(actor)):
			actor.disconnect("stood_up", _on_actor_stood_up.bind(actor))
		if actor.has_method("stand_up"):
			actor.stand_up()
		elif actor is Node3D and not lying:
			(actor as Node3D).global_transform = piece.approach_transform()
	if lying or actor.has_method("get_up"):
		FurniturePose.get_up(actor, spot if spot != Vector3.INF else _stand_spot(actor))
	if actor is PhysicsBody3D and piece:
		(actor as PhysicsBody3D).remove_collision_exception_with(piece)
	if held in POSES:
		action_finished.emit(held, actor, self)


## Called by the piece when it is unloaded, so nobody stays seated on a freed node.
func release_all() -> void:
	for a in occupants.keys():
		if is_instance_valid(a):
			_release(a)
	occupants.clear()


func _usable_while_posed(id: String) -> bool:
	return id in ["read", "watch_tv", "play_video_games", "eat", "drink_coffee", "chat", "study", "take_notes",
		"attend_lecture", "attend_class", "relax", "rock", "spin", "wait", "use_computer", "do_homework"]


func _all_parts_open() -> bool:
	for p in piece.parts:
		if not p["open"]:
			return false
	return true


func _open_count() -> int:
	var n := 0
	for p in piece.parts:
		if p["open"]:
			n += 1
	return n


func _actor_pos(actor: Node) -> Vector3:
	return (actor as Node3D).global_position if actor is Node3D else Vector3.INF


func _manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Furniture") if tree else null


func _exit_tree() -> void:
	release_all()
