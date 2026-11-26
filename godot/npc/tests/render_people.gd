extends SceneTree
## Close-up people shots for visual QA (needs a display; run with xvfb-run).
##   godot --path <proj> --script res://npc/tests/render_people.gd -- <out_dir> [shot ...]
## Six people (three men, three women, slim to heavy, several outfits incl. a
## dress, a skirt and a jacket), full-body front/side/back, torso and hip
## close-ups, faces and hands.
var frames := 0
var bodies: Array = []
var cam: Camera3D
var out_dir := "user://"
var shots := []
var only := []

const PEOPLE := [
	{"sex": "female", "weight": 58.0, "muscle": 0.3, "eth": "white", "hair": "long", "wear": {"top": "tee_white", "bottom": "jeans_dark", "outer": "", "shoes": "sneaker_white"}},
	{"sex": "male", "weight": 74.0, "muscle": 0.5, "eth": "black", "hair": "short", "wear": {"top": "tee_heaven", "bottom": "chinos_khaki", "outer": "", "shoes": "sneaker_black"}},
	{"sex": "female", "weight": 84.0, "muscle": 0.2, "eth": "hispanic", "hair": "ponytail", "wear": {"top": "", "bottom": "sundress", "outer": "", "shoes": "flats"}},
	{"sex": "male", "weight": 98.0, "muscle": 0.3, "eth": "white", "hair": "medium", "wear": {"top": "flannel_red", "bottom": "jeans_light", "outer": "puffer", "shoes": "work_boot"}},
	{"sex": "female", "weight": 63.0, "muscle": 0.5, "eth": "asian", "hair": "bun", "wear": {"top": "blouse", "bottom": "skirt_pleated", "outer": "blazer", "shoes": "loafer"}},
	{"sex": "male", "weight": 66.0, "muscle": 0.8, "eth": "asian", "hair": "curly", "wear": {"top": "polo_green", "bottom": "athletic_shorts", "outer": "", "shoes": "runner"}},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		only.append(args[i])
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#b9c4cc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root3d.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 200, 0)
	fill.light_energy = 0.35
	root3d.add_child(fill)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#8a8a84")
	floor.material_override = fm
	root3d.add_child(floor)
	var rng := RandomNumberGenerator.new()
	for i in PEOPLE.size():
		var p: Dictionary = PEOPLE[i]
		rng.seed = 900 + i
		var h := 176.0 if p.sex == "male" else 162.5
		var rec := NpcPopulation.make_record(rng, {"sex": p.sex, "height_cm": h, "weight_kg": p.weight, "age": 21 + i * 3})
		rec.ethnicity = p.eth if OS.get_environment("ETH_%d" % i) == "" else OS.get_environment("ETH_%d" % i)
		if OS.get_environment("MUSCLE_%d" % i) != "":
			p = p.duplicate()
			p.muscle = float(OS.get_environment("MUSCLE_%d" % i))
		rec.muscle = p.muscle
		rec.hair_style = p.hair
		rec.complexion = [0.15, 0.85, 0.45, 0.2, 0.3, 0.35][i]
		rec.npc_id = "shot_%d" % i
		rec.wardrobe = p.wear.duplicate()
		var ov := OS.get_environment("WEAR_%d" % i)   # e.g. WEAR_4=outer:puffer,top:tee_white
		for kv in ov.split(",", false):
			rec.wardrobe[kv.get_slice(":", 0)] = kv.get_slice(":", 1)
		var b := NpcBody.new()
		root3d.add_child(b)
		b.apply_record(rec)
		b.set_lod(0)
		b.position = Vector3(-2.0 + i * 0.8, 0, 0)
		b.rotation_degrees.y = 180.0
		bodies.append(b)
		if OS.get_environment("NO_BODY") != "":
			b.mesh_instance.visible = false
		if OS.get_environment("STATIC") != "":
			# garments as plain meshes in the rest pose (debug)
			for g in b._garments:
				g.skeleton = NodePath("")
				g.skin = null
	cam = Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 35
	var H := func(i: int) -> float: return bodies[i]._height_m
	var X := func(i: int) -> float: return -2.0 + i * 0.8
	shots = [
		["lineup", Vector3(0, 0.95, 6.4), Vector3(0, 0.88, 0), 35.0],
		["lineup_side", Vector3(6.4, 0.95, 0.3), Vector3(0, 0.88, 0), 35.0],
		["lineup_back", Vector3(0, 0.95, -6.4), Vector3(0, 0.88, 0), 35.0],
	]
	for i in PEOPLE.size():
		var x: float = X.call(i)
		var h: float = H.call(i)
		shots.append(["full_%d" % i, Vector3(x + 0.35, h * 0.55, 2.3), Vector3(x, h * 0.5, 0), 35.0])
		shots.append(["torso_%d" % i, Vector3(x + 0.12, h * 0.7, 0.95), Vector3(x, h * 0.62, 0), 35.0])
		shots.append(["side_%d" % i, Vector3(x + 0.62, h * 0.62, 0.8), Vector3(x, h * 0.56, 0), 45.0])
		shots.append(["back_%d" % i, Vector3(x - 0.1, h * 0.52, -1.1), Vector3(x, h * 0.5, 0), 35.0])
		shots.append(["face_%d" % i, Vector3(x + 0.08, h * 0.935, 0.42), Vector3(x, h * 0.925, 0), 35.0])
	shots.append(["hands", Vector3(X.call(1) - 0.3, H.call(1) * 0.44, 0.6), Vector3(X.call(1) - 0.22, H.call(1) * 0.43, 0), 35.0])
	shots.append(["hands_f", Vector3(X.call(0) + 0.3, H.call(0) * 0.44, 0.6), Vector3(X.call(0) + 0.2, H.call(0) * 0.43, 0), 35.0])
	if not only.is_empty():
		shots = shots.filter(func(s): return s[0] in only)


func _process(_delta: float) -> bool:
	frames += 1
	for b in bodies:
		b._speed = 1.2
		b._phase = 0.3
		b.animate(0.001, 1.2)
	var shot_i := (frames - 5) / 4
	if frames >= 5 and (frames - 5) % 4 == 0 and shot_i < shots.size():
		var s: Array = shots[shot_i]
		cam.position = s[1]
		cam.fov = s[3]
		cam.look_at(s[2])
	if frames >= 5 and (frames - 5) % 4 == 3 and shot_i < shots.size():
		var img := get_root().get_texture().get_image()
		img.save_png(out_dir.path_join("%s.png" % shots[shot_i][0]))
	return frames > 5 + shots.size() * 4
