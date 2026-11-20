extends Node
## Renders furnished rooms to PNGs for review (needs a display; use xvfb-run on a server):
##   godot --path godot res://furniture/tests/room_preview.tscn -- <out_dir> <roomId> [<roomId> ...]
## Builds a plain floor + walls from res://data/rooms.json, spawns that room's furniture, and saves an
## overhead view and a perspective view per room.

const ROOMS_PATH := "res://data/rooms.json"


func _ready() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://previews"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mgr: Node = get_tree().root.get_node("Furniture")
	var rooms_by_id := {}
	for r in JSON.parse_string(FileAccess.get_file_as_string(ROOMS_PATH))["rooms"]:
		rooms_by_id[r["roomId"]] = r
	var placements = JSON.parse_string(FileAccess.get_file_as_string(mgr.PLACEMENTS_PATH))
	for k in range(1, args.size()):
		var rid: String = args[k]
		var room: Dictionary = rooms_by_id.get(rid, {})
		if room.is_empty():
			printerr("no room ", rid); continue
		var stage := _stage(room)
		get_tree().root.add_child(stage)
		var e: Dictionary = placements["buildings"][room["buildingId"]]
		var ri: int = (e["rooms"] as Array).find(rid)
		var n := 0
		for it in e["items"]:
			if int(it[5]) != ri:
				continue
			var p: FurniturePiece = mgr.spawn_piece(int(it[0]), Transform3D(Basis(Vector3.UP, float(it[4])), Vector3(float(it[1]), float(it[2]), float(it[3]))), stage, rid)
			# open one drawer/door per piece so the moving parts show
			if p.has_openables():
				p.set_part_open(true, p.to_global(Vector3(0, 0, 1)))
			n += 1
		var rect: Array = room["rect"]
		var c := Vector3((rect[0] + rect[2]) * 0.5, float(room["y"]), (rect[1] + rect[3]) * 0.5)
		var span := maxf(rect[2] - rect[0], rect[3] - rect[1])
		var cam := Camera3D.new()
		stage.add_child(cam)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = span * 1.08
		cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), c + Vector3(0, 30, 0))
		cam.make_current()
		for f in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_top.png" % [out_dir, rid])
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 70
		var eye := Vector3(rect[0] + 0.4, float(room["y"]) + 1.65, rect[3] - 0.4)
		cam.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(c + Vector3(0, 0.6, 0), Vector3.UP)
		for f in 10: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_view.png" % [out_dir, rid])
		print("%s: %d pieces" % [rid, n])
		stage.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _stage(room: Dictionary) -> Node3D:
	var s := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.96, 0.9)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	s.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	s.add_child(sun)
	var rect: Array = room["rect"]
	var y := float(room["y"])
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.64, 0.48, 0.31) # OAK_FLOOR
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.94, 0.91, 0.85)
	var w := float(rect[2]) - float(rect[0]); var d := float(rect[3]) - float(rect[1])
	var cx := (float(rect[0]) + float(rect[2])) * 0.5; var cz := (float(rect[1]) + float(rect[3])) * 0.5
	_box(s, Vector3(cx, y - 0.05, cz), Vector3(w, 0.1, d), floor_mat)
	var h := 1.0 # low walls so the perspective view sees in
	for wall in room["anchorWalls"]:
		var a := Vector3(wall["start"][0], y, wall["start"][2]); var b := Vector3(wall["end"][0], y, wall["end"][2])
		var n := Vector3(wall["normal"][0], 0, wall["normal"][2])
		var mid := (a + b) * 0.5 - n * 0.06
		var len := a.distance_to(b)
		var sz := Vector3(len, h, 0.12) if absf(n.z) > 0.5 else Vector3(0.12, h, len)
		_box(s, mid + Vector3(0, h * 0.5, 0), sz, wall_mat)
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.85, 0.2, 0.2)
	for o in room["openings"]:
		if o["type"] == "door":
			_box(s, Vector3(o["position"][0], y + 0.01, o["position"][2]), Vector3(0.5, 0.02, 0.5), door_mat)
	return s


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
