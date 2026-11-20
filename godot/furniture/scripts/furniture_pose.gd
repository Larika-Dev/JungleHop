class_name FurniturePose
extends RefCounted
## Lying-down pose for beds (sleep, nap, lie_down) without changing the player's own code.
##
## Order of preference for an actor:
##   1. actor.lie_at(xform) / actor.get_up()  if the actor implements them (NPC bodies can);
##   2. the player / any body with `sit_at` + `appearance` (CharacterAppearance): the player is put in its
##      seated state (movement off), then the appearance is laid flat on the mattress and the camera head
##      moved to the pillow, looking up at the ceiling;
##   3. otherwise the actor's transform is set so its -Z points to the pillow.
## `xform` (from FurniturePiece.bed_transforms): origin on the mattress under the hips, -Z toward the head.

const BODY_LIFT := 0.11  # body half-thickness above the mattress


static func lie(actor: Node, xform: Transform3D) -> void:
	if actor.has_method("lie_at"):
		actor.lie_at(xform)
		return
	var app = actor.get("appearance")
	if actor.has_method("sit_at") and app is Node3D:
		var h := _height(actor)
		var hips_from_feet := 0.53 * h
		# feet end of the body, so the head lands on the pillow
		var feet := xform.origin + xform.basis.z * hips_from_feet
		actor.sit_at(Transform3D(xform.basis, feet))
		if app.has_method("set_pose"):
			app.set_pose("lie")  # straight legs; CharacterAppearance treats non-"sit" as standing
		actor.set_meta("furniture_lying", {"app_xf": Transform3D(Basis.IDENTITY, Vector3.ZERO)})
		(app as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, BODY_LIFT, 0))
		var head = actor.get("_head")
		if head is Node3D:
			actor.get_meta("furniture_lying")["head_pos"] = (head as Node3D).position
			actor.get_meta("furniture_lying")["head_rot"] = (head as Node3D).rotation
			(head as Node3D).position = Vector3(0, BODY_LIFT + 0.12, -(h - 0.12))
			if actor.get("_pitch") != null:
				actor.set("_pitch", deg_to_rad(80))  # look up at the ceiling
			(head as Node3D).rotation = Vector3(deg_to_rad(80), 0, 0)
		return
	if actor is Node3D:
		(actor as Node3D).global_transform = xform


static func is_lying(actor: Node) -> bool:
	return is_instance_valid(actor) and actor.has_meta("furniture_lying")


## Puts the body upright again (call after the actor stood up). `stand_at` = where to put the feet.
static func get_up(actor: Node, stand_at: Vector3 = Vector3.INF) -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("get_up") and not actor.has_meta("furniture_lying"):
		actor.get_up()
		return
	if not actor.has_meta("furniture_lying"):
		return
	var saved: Dictionary = actor.get_meta("furniture_lying")
	actor.remove_meta("furniture_lying")
	var app = actor.get("appearance")
	if app is Node3D:
		(app as Node3D).transform = saved["app_xf"]
		if app.has_method("set_pose"):
			app.set_pose("stand")
	var head = actor.get("_head")
	if head is Node3D and saved.has("head_pos"):
		(head as Node3D).position = saved["head_pos"]
		(head as Node3D).rotation = saved["head_rot"]
		if actor.get("_pitch") != null:
			actor.set("_pitch", 0.0)
	if stand_at != Vector3.INF and actor is Node3D and (actor as Node3D).is_inside_tree():
		(actor as Node3D).global_position = stand_at


static func _height(actor: Node) -> float:
	var app = actor.get("appearance")
	if app is Object and app.get("_height") != null:
		return float(app.get("_height"))
	var gs := actor.get_tree().root.get_node_or_null("GameState") if actor.is_inside_tree() else null
	if actor.is_in_group("player") and gs and gs.get("player_profile") is Dictionary:
		return clampf(float(gs.player_profile.get("height_cm", 175)) / 100.0, 1.4, 2.1)
	var h = actor.get("height_m")
	return float(h) if h != null else 1.75
