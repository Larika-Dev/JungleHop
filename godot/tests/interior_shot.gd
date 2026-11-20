extends Node
## Quick interior render check: xvfb-run godot res://tests/interior_shot.tscn -- out.png

func _ready() -> void:
	Settings.fullscreen = false
	Settings.apply()
	get_window().size = Vector2i(960, 540)
	GameClock.set_time(1, 12, 0)
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child.call_deferred(city)
	for i in 10:
		await get_tree().process_frame
	var p = GameState.get_player()
	var r := CityData.room("CM_HAM_N_001_F0_R0")
	for room in CityData.rooms_for_building("HAM_N_001"):
		if room["areaM2"] > 30 and int(room["floor"]) == 0:
			r = room
			break
	var rc: Array = r["rect"]
	var bt := CityData.building_transform(r["buildingId"])
	var c := Vector3((rc[0] + rc[2]) * 0.5, r["y"] + 0.05, (rc[1] + rc[3]) * 0.5)
	print("room ", r["roomId"], " ", r["roomType"], " rect ", rc)
	p.teleport(bt * c, bt.basis.get_euler().y)
	p._pitch = 0.0
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("finishes ", r["floorFinish"], " ", r["wallFinish"], " ", CityData.color(r["wallFinish"]))
	var cam: Camera3D = p.camera
	for d in [Vector3(0,0,-1), Vector3(0,-1,-0.0001), Vector3(0,1,0.0001)]:
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + cam.global_basis * d * 40.0, 1)
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		print("ray ", d, " -> ", (hit.position.distance_to(cam.global_position) if hit else -1.0), " ", (hit.collider.get_path() if hit else ""))
	p._yaw += PI
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].replace(".png", "-b.png"))
	get_tree().quit()
