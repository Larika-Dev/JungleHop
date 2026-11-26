extends Node
## Environment before/after shots: xvfb-run godot --rendering-driver vulkan res://tests/env_shots.tscn -- <outdir> [name ...]
## Each view stands on the ground at (x, z) with the eye `eye` m above it, looking along yaw/pitch at `hour`.

const VIEWS := {
	"01-hamilton-summit": [-6.0, 7.5, 1.7, PI * 0.5, -0.06, 15.5],
	"02-hamilton-midblock": [-190.0, 8.2, 1.7, PI * 0.5 + 0.25, -0.08, 16.5],
	"03-hamilton-aerial": [-40.0, 14.0, 22.0, PI * 0.5 + 0.15, -0.45, 16.0],
	"04-rosemary-row": [-60.0, -103.5, 1.7, -PI * 0.5 + 0.2, -0.06, 15.0],
	"05-residential-street": [-60.0, -226.0, 1.7, PI * 0.5 + 0.2, -0.07, 16.0],
	"06-cameron-campus": [-120.0, 320.5, 1.7, PI * 0.5 + 0.15, -0.06, 15.5],
	"07-alley": [-230.0, -40.0, 1.7, 0.0, -0.05, 14.0],
	"08-hamilton-night": [-20.0, 7.5, 1.7, PI * 0.5 + 0.1, -0.05, 21.5],
	"09-residential-closeup": [-80.0, -233.0, 1.4, PI * 0.5 - 0.6, -0.3, 16.0],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var outdir: String = args[0] if args.size() > 0 else "user://env_shots"
	var names: Array = []
	for i in range(1, args.size()):
		if not args[i].begins_with("--"):
			names.append(args[i])
	if names.is_empty():
		names = VIEWS.keys()
	DirAccess.make_dir_recursive_absolute(outdir)
	Settings.fullscreen = false
	for a in args:
		if a.begins_with("--set="):
			var kv: PackedStringArray = a.substr(6).split(":")
			Settings.set(kv[0], str_to_var(kv[1]))
	Settings.apply()
	get_window().size = Vector2i(1600, 900)
	GameState.player_profile = GameState.default_profile()
	GameClock.set_time(1, 15, 0)
	GameClock.paused = true
	get_tree().set_meta("shown_controls_hint", true)   # no controls toast over the shots
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child.call_deferred(city)
	for i in 10:
		await get_tree().process_frame
	var p = GameState.get_player()
	p.flying = true
	for nm in names:
		var v: Array = VIEWS[nm]
		GameClock.set_time(1, int(v[5]), int(fmod(v[5], 1.0) * 60.0))
		GameClock.paused = true
		p.teleport(Vector3(v[0], 50.0, v[1]), v[3])
		for i in 3:
			await get_tree().physics_frame
		var gy: float = city.ground_height(Vector3(v[0], 0.0, v[1]))
		# the camera sits at the player's eye; place the player so the eye is v[2] above ground
		var eye: float = p.camera.global_position.y - p.global_position.y
		p.teleport(Vector3(v[0], gy + v[2] - eye, v[1]), v[3])
		p._pitch = v[4]
		for i in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := outdir.path_join(nm + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
