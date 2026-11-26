extends Node3D
## Prop catalog render: xvfb-run godot --rendering-driver vulkan res://tests/prop_gallery.tscn -- <out.png> [model ...]
## Lays the requested models (default: all) out on a grid under a sun and sky.

func _ready() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var out: String = args[0] if args.size() > 0 else "user://gallery.png"
	var lod := "--lod" in args
	args = args.filter(func(a): return a != "--lod")
	var names: Array = args.slice(1) if args.size() > 1 else PropModels.NAMES
	get_window().size = Vector2i(1600, 900)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.4
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.44, 0.42)
	ground.material_override = gm
	add_child(ground)
	var cols := int(ceil(sqrt(names.size() * 1.6)))
	var spacing := 5.5 if names.size() > 4 else 6.0
	var i := 0
	for n in names:
		var info := PropModels.build(n)
		if info.mesh == null:
			continue
		if lod:
			info.mesh = StreetProps._with_lods(info.mesh)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = info.mesh
		mm.instance_count = 1
		var x := (i % cols - cols * 0.5) * spacing
		var z := (i / cols) * spacing
		mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, 0.6), Vector3(x, 0, z)))
		var tint := Color(0.55, 0.06, 0.06) if n.begins_with("car_") else Color(0.25, 0.4, 0.2) if n.begins_with("shrub") else Color(0.2, 0.4, 0.75)
		mm.set_instance_custom_data(0, Color(tint.r, tint.g, tint.b, 0.5))
		mm.set_instance_color(0, Color(1, 1, 1) if not n.begins_with("shrub") else tint)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		i += 1
	var rows := int(ceil(float(i) / cols))
	var cam := Camera3D.new()
	add_child(cam)
	var span := maxf(cols, rows) * spacing
	cam.position = Vector3(0, span * 0.45 + 1.5, -span * 0.35 - 3.0)
	cam.look_at(Vector3(-spacing * 0.5, 0.6, rows * spacing * 0.45), Vector3.UP)
	cam.fov = 50
	for k in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
