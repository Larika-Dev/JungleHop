extends "res://furniture/tests/room_preview.gd"
## Renders the player lying in a bed (needs a display; xvfb-run on a server):
##   godot --path godot res://furniture/tests/sleep_preview.tscn -- <out_dir> <roomId>


func _ready() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var rid := args[1]
	var mgr: Node = get_tree().root.get_node("Furniture")
	var room: Dictionary = {}
	for r in JSON.parse_string(FileAccess.get_file_as_string(ROOMS_PATH))["rooms"]:
		if r["roomId"] == rid: room = r
	var stage := _stage(room)
	get_tree().root.add_child(stage)
	var placements = JSON.parse_string(FileAccess.get_file_as_string(mgr.PLACEMENTS_PATH))
	var e: Dictionary = placements["buildings"][room["buildingId"]]
	var ri: int = (e["rooms"] as Array).find(rid)
	var bed: FurniturePiece
	for it in e["items"]:
		if int(it[5]) != ri: continue
		var p: FurniturePiece = mgr.spawn_piece(int(it[0]), Transform3D(Basis(Vector3.UP, float(it[4])), Vector3(float(it[1]), float(it[2]), float(it[3]))), stage, rid)
		if bed == null and p.interactable.furniture_kind == "bed": bed = p
	var player: Node3D = load("res://player/player.tscn").instantiate()
	stage.add_child(player)
	player.global_position = bed.approach_transform().origin
	for f in 5: await get_tree().process_frame
	bed.interactable.perform("sleep", player)
	for f in 5: await get_tree().process_frame
	player.appearance.set_first_person(false)  # show the whole body for the picture
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 55
	var bt: Transform3D = bed.bed_transforms()[0]
	var side := bt.basis.x * 2.2 + Vector3(0, 1.6, 0) + bt.basis.z * 0.6
	cam.global_transform = Transform3D(Basis.IDENTITY, bt.origin + side).looking_at(bt.origin, Vector3.UP)
	cam.make_current()
	for f in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s_sleep.png" % [out_dir, rid])
	print("lying=", FurniturePose.is_lying(player))
	get_tree().quit(0)
