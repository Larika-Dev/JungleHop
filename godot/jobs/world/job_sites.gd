extends RefCounted
## Places a clock-in terminal in the main ground-floor room of every
## employer building once the city is ready (GameState.world_ready).

const SKIP := ["stair", "elevator_lobby", "restroom", "corridor", "hall", "kitchen", "mechanical", "storage", "stockroom", "parking"]


static func spawn_all(jobs: Node, world: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "JobSites"
	world.add_child(root)
	var city := jobs.get_tree().root.get_node_or_null("CityData")
	for b in jobs.employer_buildings():
		var pos = site_position(city, b)
		if pos == null:
			continue
		root.add_child(make_terminal(jobs, b, pos))
	return root


## World position for the terminal, or null when the building is unknown.
static func site_position(city: Node, building_id: String):
	if city == null:
		return null
	var best := {}
	for r in city.rooms_for_building(building_id):
		if int(r.floor) != 0 or SKIP.has(String(r.roomType)):
			continue
		if best.is_empty() or float(r.areaM2) > float(best.areaM2):
			best = r
	if best.is_empty():
		var rooms: Array = city.rooms_for_building(building_id)
		if rooms.is_empty():
			return null
		best = rooms[0]
	var rc: Array = best.rect
	# Against the room's back half, 60 cm in from the side wall.
	var local := Vector3(rc[0] + 0.6, float(best.y), lerpf(rc[1], rc[3], 0.7))
	return city.building_transform(building_id) * local


static func make_terminal(jobs: Node, building_id: String, pos: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "JobSite_" + building_id
	body.collision_layer = 1 << 2  # layer 3 "interact"
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 1.3, 0.35)
	shape.shape = box
	shape.position.y = 0.65
	body.add_child(shape)
	# Post + screen: a 120 cm clock-in kiosk.
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 1.05, 0.12)
	post.mesh = pm
	post.position.y = 0.525
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.23, 0.24, 0.24)  # ALUMINUM_STOREFRONT
	pmat.metallic = 0.6
	post.material_override = pmat
	body.add_child(post)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.36, 0.26, 0.05)
	screen.mesh = sm
	screen.position = Vector3(0, 1.15, 0)
	screen.rotation_degrees.x = -15
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.08, 0.17, 0.31)  # ONSU_NAVY
	smat.emission_enabled = true
	smat.emission = Color(0.5, 0.71, 0.85)  # HEAVEN_BLUE
	smat.emission_energy_multiplier = 0.6
	screen.material_override = smat
	body.add_child(screen)
	var label := Label3D.new()
	label.text = "STAFF"
	label.font_size = 48
	label.pixel_size = 0.002
	label.position = Vector3(0, 1.36, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(label)
	var site = load("res://jobs/world/job_site.gd").new()
	site.building_id = building_id
	site.jobs = jobs
	var names := []
	for id in jobs.jobs_at_building(building_id):
		names.append(jobs.get_job(id).place)
	site.display_name = "Staff terminal  -  " + (names[0] if not names.is_empty() else building_id)
	body.add_child(site)
	return body
