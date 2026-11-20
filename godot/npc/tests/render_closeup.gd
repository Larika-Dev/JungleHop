extends SceneTree
## Renders NPC bodies to PNGs for a visual check (needs a display; run with
## xvfb-run). Usage: godot --path <proj> --script res://npc/tests/render_closeup.gd -- <out_dir>
var frames := 0
var bodies: Array = []
var cam: Camera3D
var out_dir := "user://"
var shots := []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#b9c4cc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.6)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root3d.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#8a8a84")
	floor.material_override = fm
	root3d.add_child(floor)
	var pop := NpcPopulation.generate(60)
	var picks := [pop[3], pop[11], pop[20], pop[33], pop[41]]
	picks[0].outfit.bottom_style = "shorts"
	picks[1].outfit.bottom_style = "skirt"
	for i in picks.size():
		var b := NpcBody.new()
		root3d.add_child(b)
		b.apply_record(picks[i])
		b.set_lod(0)
		b.position = Vector3(-1.6 + i * 0.8, 0, 0)
		b.rotation_degrees.y = 180.0 if i % 2 == 0 else 160.0
		bodies.append(b)
	cam = Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 40
	shots = [
		["lineup", Vector3(0, 1.0, 5.2), Vector3(0, 0.85, 0)],
		["calves_side", Vector3(-1.6 - 1.1, 0.35, 0.0), Vector3(-1.6, 0.3, 0)],
		["calves_back", Vector3(-1.6 + 0.2, 0.4, -1.0), Vector3(-1.6, 0.3, 0)],
		["hand", Vector3(-1.6 - 0.45, 0.78, -0.25), Vector3(-1.6 - 0.24, 0.74, 0.0)],
		["face", Vector3(-1.6 + 0.1, 1.62, 0.55), Vector3(-1.6, 1.6, 0)],
		["lineup_back", Vector3(0, 1.0, -5.2), Vector3(0, 0.85, 0)],
	]

func _process(delta: float) -> bool:
	frames += 1
	for b in bodies:
		b._speed = 1.35
		b._phase = 0.48 - 1.35 / (0.83 * b._height_m) * 0.001   # late stance: calf contracting for push-off
		b.animate(0.001, 1.35)
	var shot_i := (frames - 5) / 4
	if frames >= 5 and (frames - 5) % 4 == 0 and shot_i < shots.size():
		var s: Array = shots[shot_i]
		cam.position = s[1]
		cam.look_at(s[2])
	if frames >= 5 and (frames - 5) % 4 == 3 and shot_i < shots.size():
		var img := get_root().get_texture().get_image()
		img.save_png(out_dir.path_join("npc_%s.png" % shots[shot_i][0]))
	return frames > 5 + shots.size() * 4
