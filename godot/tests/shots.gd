extends Node
## Renders review screenshots: xvfb-run godot res://tests/shots.tscn -- <outdir>
## (needs a real renderer; see tools/godot/README.md).

var out := "user://shots"


func snap(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.fullscreen = false
	Settings.apply()
	get_window().size = Vector2i(1600, 900)
	# 1. title screen
	var title: Node = load("res://ui/title_screen.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await snap("01-title", 90)
	# 2. character creator
	var cc = load("res://ui/character_creator.gd").new()
	UI.open_panel(cc)
	cc.profile["sex"] = "female"
	cc.profile["height_cm"] = 165
	cc.profile["hair_style"] = 4
	cc.profile["hair_color"] = 5
	cc.profile["shirt_color"] = 0
	cc.profile["pants_color"] = 1
	cc._refresh()
	await snap("02-character", 40)
	var prof: Dictionary = cc.profile.duplicate()
	UI.close_all()
	# 3. settings
	UI.open_panel(load("res://ui/settings_menu.gd").new())
	await snap("03-settings", 20)
	UI.close_all()
	title.queue_free()
	# 4. city
	GameState.player_profile = prof
	GameClock.set_time(1, 16, 30)
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child.call_deferred(city)
	await snap("04-hamilton-street", 120)
	var p = GameState.get_player()
	p._set_view(true)
	p._yaw = PI * 0.5 + 0.5
	await snap("05-third-person", 40)
	# 6. interior: travel into the first loaded building's ground-floor room
	var streamer: InteriorStreamer = city.get_node("Interiors")
	var best := ""
	for id in streamer.loaded:
		var rooms := CityData.rooms_for_building(id)
		for r in rooms:
			if int(r["floor"]) == 0 and r["areaM2"] > 30:
				best = r["roomId"]
				break
		if best != "":
			break
	if best != "":
		var r := CityData.room(best)
		var rc: Array = r["rect"]
		var bt := CityData.building_transform(r["buildingId"])
		p._set_view(false)
		p.teleport(bt * Vector3(rc[0] + 0.8, r["y"] + 0.05, rc[1] + 0.8), bt.basis.get_euler().y + PI * 0.75)
		p._pitch = -0.1
		await snap("06-interior-" + String(r["buildingId"]), 60)
	# 7. campus view from above Founders' Quad
	p.flying = true
	p.teleport(Vector3(190, 30, 520), 0.0)
	p._pitch = -0.35
	await snap("07-founders-quad", 90)
	# 8. night
	GameClock.set_time(1, 22, 0)
	p.teleport(Vector3(-6, 0.2, 6), PI * 0.5)
	p.flying = false
	p._pitch = 0.0
	await snap("08-night", 60)
	# 9. pause menu
	UI.open_pause_menu()
	await snap("09-pause", 20)
	get_tree().quit()
