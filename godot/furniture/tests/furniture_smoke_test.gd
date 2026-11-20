extends Node
## Headless smoke test for the furniture package:
##   godot --headless --path godot res://furniture/tests/furniture_smoke_test.tscn
## Exits 0 when every check passes.

const EXPECT_OPENABLE := [6, 9, 11, 12, 15, 20, 21, 23, 24, 25, 32, 33, 34, 35, 36, 38, 41, 45, 46, 48, 53, 57,
	61, 64, 67, 76, 78, 79, 81, 88, 94, 96, 97, 98, 100]

var failures: Array[String] = []
var started: Array = []
var finished: Array = []


class Dummy extends CharacterBody3D:
	var seated_at = null
	func sit_at(xf: Transform3D) -> void:
		seated_at = xf
		global_transform = xf
	func stand_up() -> void:
		seated_at = null


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _ready() -> void:
	await get_tree().process_frame
	var mgr: Node = get_tree().root.get_node_or_null("Furniture")
	check(mgr != null, "Furniture autoload missing")
	if mgr == null:
		_finish(); return
	check(mgr.models.size() == 100, "expected 100 models, got %d" % mgr.models.size())
	check(mgr.placement_count() > 50000, "expected >50k placements, got %d" % mgr.placement_count())

	var stage := Node3D.new()
	get_tree().root.add_child(stage)
	var actor := Dummy.new()
	actor.add_to_group("player")
	stage.add_child(actor)

	var action_ids := {}
	for id in mgr.models:
		var def: Dictionary = mgr.models[id]
		check(ResourceLoader.exists(def["model"]), "model %d: missing %s" % [id, def["model"]])
		for a in def["actions"]:
			action_ids[a] = true
			check(not mgr.action_def(a).is_empty(), "model %d: no definition for action %s" % [id, a])
		var piece: FurniturePiece = mgr.spawn_piece(id, Transform3D(Basis.IDENTITY, Vector3(id * 5.0, 0, 0)), stage)
		check(piece != null and piece.get_node_or_null("Model") and piece.get_node("Model").get_child_count() > 0, "model %d did not instantiate" % id)
		if id in EXPECT_OPENABLE:
			check(piece.has_openables(), "model %d (%s) should have opening parts" % [id, def["name"]])
		var fi := piece.interactable
		check(fi.is_in_group("furniture"), "model %d not in group furniture" % id)
		check(fi.furniture_kind != "", "model %d has no furniture_kind" % id)
		fi.action_started.connect(func(a, _ac, _f): started.append(a))
		fi.action_finished.connect(func(a, _ac, _f): finished.append(a))
		actor.global_position = piece.approach_transform().origin
		var acts := fi.get_actions(actor)
		check(not acts.is_empty(), "model %d offers no actions" % id)
		check(acts[0]["id"] == def["actions"][0] or (acts[0]["id"] == "close"), "model %d default action %s" % [id, acts[0]["id"]])
		# run every action once
		for a in acts.duplicate():
			var aid: String = a["id"]
			fi.perform(aid, actor)
			if fi.occupants.has(actor):
				check(fi.get_actions(actor)[0]["id"] == "stand_up", "model %d: stand_up not first while %s" % [id, aid])
				fi.perform("stand_up", actor)
				check(not fi.occupants.has(actor), "model %d: still occupied after stand_up" % id)
		if piece.has_openables():
			var p: Dictionary = piece.parts[0]
			var rest: Transform3D = p["rest"]
			piece.set_part_open(true)
			await get_tree().create_timer(0.5).timeout
			check(not (p["pivot"] as Node3D).transform.is_equal_approx(rest), "model %d: part %s did not move" % [id, p["key"]])
			piece.set_part_open(false)
		if not def["seats"].is_empty():
			check(fi.get_actions(actor).any(func(x): return x["id"] == "sit"), "model %d: seat but no sit action" % id)
		piece.queue_free()

	check(started.size() > 250 and finished.size() > 250, "signals: started %d finished %d" % [started.size(), finished.size()])
	check(action_ids.size() >= 100, "only %d distinct furniture actions" % action_ids.size())

	# streaming: stand on the first placement and let the streamer build
	var world := Node3D.new()
	get_tree().root.add_child(world)
	mgr._on_world_ready(world)
	var st: FurnitureStreamer = mgr.streamer
	var target: Vector3 = mgr.p_pos[mgr.placement_count() / 2]
	actor.global_position = target
	st.refresh(target)
	for k in 60:
		await get_tree().process_frame
	check(st.loaded.size() > 0, "streamer loaded nothing near %s" % target)
	print("streamer loaded %d pieces near %s" % [st.loaded.size(), target])
	actor.global_position = target + Vector3(5000, 0, 0)
	st.refresh(actor.global_position)
	await get_tree().process_frame
	check(st.loaded.size() == 0, "streamer did not unload (%d left)" % st.loaded.size())
	print("models 100, actions %d, placements %d" % [action_ids.size(), mgr.placement_count()])
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("FURNITURE SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		printerr("%d failures" % failures.size())
		get_tree().quit(1)
