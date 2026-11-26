extends Node
## Building before/after shots in one run:
## xvfb-run godot --path . --rendering-driver vulkan res://tests/building_shots.tscn -- <outdir> [prefix] [--set=key:value]
## Each pose: [name, hour, x, y, z, yaw, pitch].
const POSES := [
	["01-hamilton-street", 16.5, -6.0, 1.7, 6.0, PI * 0.5, 0.02],
	["02-storefronts", 15.0, -24.0, 1.7, 1.5, -0.75, 0.12],
	["03-storefront-closeup", 15.0, -12.0, 1.7, -4.5, -0.25, 0.18],
	["04-rooftops", 16.5, -60.0, 24.0, 22.0, -1.0, -0.42],
	["05-houses", 16.0, 14.0, -0.6, -233.0, PI - 0.35, 0.08],
	["06-house-closeup", 16.0, 12.0, -0.8, -226.5, PI - 0.6, 0.12],
	["07-campus-hall", 16.0, 50.0, 1.0, 80.0, -2.2, 0.15],
	["08-hamilton-night", 21.5, -6.0, 1.7, 6.0, PI * 0.5, 0.05],
	["09-houses-aerial", 16.0, 15.0, 14.0, -245.0, PI - 0.3, -0.5],
]

func _ready() -> void:
	var all := OS.get_cmdline_user_args()
	var args: Array = []
	for a in all:
		if not a.begins_with("--set="):
			args.append(a)
	var outdir: String = args[0] if args.size() > 0 else "user://"
	var prefix: String = args[1] if args.size() > 1 else ""
	var only: String = args[2] if args.size() > 2 else ""
	Settings.fullscreen = false
	for a in all:
		if a.begins_with("--set="):
			var kv: PackedStringArray = a.substr(6).split(":")
			Settings.set(kv[0], str_to_var(kv[1]))
	Settings.apply()
	get_window().size = Vector2i(1600, 900)
	GameState.player_profile = GameState.default_profile()
	GameClock.set_time(1, 16, 0)
	GameClock.paused = true
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child.call_deferred(city)
	for i in 10:
		await get_tree().process_frame
	var p = GameState.get_player()
	p.flying = true
	for pose in POSES:
		if only != "" and not String(pose[0]).contains(only):
			continue
		var hour: float = pose[1]
		GameClock.set_time(1, int(hour), int(fmod(hour, 1.0) * 60.0))
		GameClock.paused = true
		p.teleport(Vector3(pose[2], pose[3], pose[4]), pose[5])
		p._pitch = pose[6]
		for i in 5:
			await get_tree().process_frame
		var bs = GameState.world.get("buildings") if GameState.world else null
		var guard := 0
		while bs and not bs.is_idle() and guard < 1500:
			await get_tree().process_frame
			guard += 1
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var out: String = outdir.path_join(prefix + String(pose[0]) + ".png")
		get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
	get_tree().quit()
