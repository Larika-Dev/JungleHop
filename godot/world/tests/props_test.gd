extends SceneTree
## Headless checks for the street props / decals pass.
## godot --headless --path godot -s res://world/tests/props_test.gd

var failures := 0
var passes := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func _run() -> void:
	# loaded at run time: these scripts use autoloads, which -s mode registers after compiling this file
	var PropModels = load("res://world/props/prop_models.gd")
	var StreetProps = load("res://world/street_props.gd")
	var GroundDecals = load("res://world/ground_decals.gd")
	# every catalog model builds, has geometry, and sits on its base (no part far below the ground)
	for name in PropModels.NAMES:
		var info: Dictionary = PropModels.build(name)
		var mesh: ArrayMesh = info.mesh
		ok(mesh != null and mesh.get_surface_count() > 0, "%s builds a mesh" % name)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		ok(aabb.position.y > (-0.45 if name in ["leaf_pile", "rock", "pole", "shrub", "shrub_wild", "planter_big"] else -0.05), "%s base near y = 0 (got %.2f)" % [name, aabb.position.y])
		ok(aabb.size.length() > 0.05 and aabb.size.length() < 12.0, "%s plausible size %s" % [name, aabb.size])
	# real-world dimensions (CLAUDE.md §13): bench 183 cm long / 45 cm seat, hydrant < 1 m, cars to scale
	var bench: AABB = PropModels.build("bench").mesh.get_aabb()
	ok(absf(bench.size.x - 1.83) < 0.02, "bench is 183 cm long (%.3f)" % bench.size.x)
	var sedan: AABB = PropModels.build("car_sedan").mesh.get_aabb()
	ok(absf(sedan.size.z - 4.8) < 0.1 and absf(sedan.size.y - 1.48) < 0.08, "sedan 4.75 x 1.45 m (%s)" % sedan.size)
	var hydrant: AABB = PropModels.build("hydrant").mesh.get_aabb()
	ok(hydrant.size.y > 0.8 and hydrant.size.y < 0.95, "hydrant ~90 cm tall")
	# placement data
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/props.json"))
	ok(typeof(d) == TYPE_DICTIONARY, "props.json parses")
	var props: Dictionary = d.get("props", {})
	for m in props:
		ok(m in PropModels.NAMES, "placed model %s is in the catalog" % m)
	var cars := 0
	for m in props:
		if m.begins_with("car_"):
			cars += props[m].size()
	ok(cars > 400, "parked cars placed (%d)" % cars)
	ok(props.get("bench", []).size() > 100 and props.get("trash", []).size() > 100, "benches and trash cans placed")
	ok(d.get("lamps", []).size() > 500, "lamp posts placed")
	ok(d.get("furniture", []).size() > 100, "café furniture placed")
	for e in d.get("furniture", []):
		ok(not root.get_node("Furniture").model(int(e[0])).is_empty(), "café furniture id %d exists in the furniture catalog" % int(e[0]))
		break
	var nd := 0
	for k in d.get("decals", {}):
		ok(k in GroundDecals.KINDS, "decal kind %s known" % k)
		nd += d["decals"][k].size()
	ok(nd > 5000, "ground decals placed (%d)" % nd)
	# nothing placed inside a building footprint (sampled)
	var inside := 0
	var checked := 0
	for m in ["bench", "trash", "car_sedan", "hydrant", "planter", "mailbox_post"]:
		var list: Array = props.get(m, [])
		for i in range(0, list.size(), 7):
			var p := Vector3(list[i][0], list[i][1], list[i][2])
			checked += 1
			for id in root.get_node("CityData").buildings_near(p, 60.0):
				var fp: Array = root.get_node("CityData").building(id).get("footprintCm", [0, 0])
				var l: Vector3 = root.get_node("CityData").building_transform(id).affine_inverse() * p
				if l.x > 0.3 and l.z > 0.3 and l.x < fp[0] / 100.0 - 0.3 and l.z < fp[1] / 100.0 - 0.3:
					inside += 1
					break
	ok(inside == 0, "%d of %d sampled props inside buildings" % [inside, checked])
	# the nodes build their MultiMeshes at every preset
	for q in [0, 3]:
		root.get_node("Settings").quality = q
		var sp = StreetProps.new()
		root.add_child(sp)
		var n: int = sp.instance_count()
		ok(n > 10000, "quality %d: %d prop instances" % [q, n])
		var gd = GroundDecals.new()
		root.add_child(gd)
		ok(gd.decal_count() > 3000, "quality %d: %d decals" % [q, gd.decal_count()])
		sp.free()
		gd.free()
	print("props_test: %d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
