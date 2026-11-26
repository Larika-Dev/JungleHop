extends Node
## Quick render check for the graphics pass: xvfb-run godot res://tests/gfx_quick.tscn -- <out.png> [hour] [x y z yaw pitch]
func _ready() -> void:
	var all := OS.get_cmdline_user_args()
	var args: Array = []
	for a in all:
		if not a.begins_with("--set="):
			args.append(a)
	var out: String = args[0] if args.size() > 0 else "user://gfx_quick.png"
	var hour: float = float(args[1]) if args.size() > 1 else 16.5
	Settings.fullscreen = false
	for a in all:
		if a.begins_with("--set="):
			var kv: PackedStringArray = a.substr(6).split(":")
			Settings.set(kv[0], str_to_var(kv[1]))
	Settings.apply()
	get_window().size = Vector2i(1600, 900)
	GameState.player_profile = GameState.default_profile()
	GameClock.set_time(1, int(hour), int(fmod(hour, 1.0) * 60.0))
	GameClock.paused = true
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child.call_deferred(city)
	for i in 10:
		await get_tree().process_frame
	GameClock.paused = true
	var p = GameState.get_player()
	if args.size() > 6:
		p.flying = true
		p.teleport(Vector3(float(args[2]), float(args[3]), float(args[4])), float(args[5]))
		p._pitch = float(args[6])
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
