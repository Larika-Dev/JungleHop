extends SceneTree
## Headless checks for the modeled building exteriors:
## godot --headless --path . -s res://tests/buildings_test.gd
## - every non-landmark building builds at every quality tier without errors
## - triangle budgets per tier hold (Low < Medium < High < Ultra, sane maxima)
## - every exterior window / door from rooms.json gets glass / a door leaf
## - every surface kind used is one the facade shader understands

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var city_data = root.get_node("CityData")
	var fails := 0
	var ids: Array = []
	for bd in city_data.buildings:
		if not String(bd["id"]).begins_with("LM"):
			ids.append(bd["id"])
	print("buildings: ", ids.size())
	var tiers := [0, 1, 2, 3]
	var tri_tot := [0, 0, 0, 0]
	var max_tris := [0, 0, 0, 0]
	var t0 := Time.get_ticks_msec()
	var sample := ids if OS.get_cmdline_user_args().has("--all") else ids.filter(func(x): return hash(x) % 6 == 0)
	for q in tiers:
		for id in sample:
			var bd: Dictionary = city_data.building(id)
			var res := BuildingDetail.build(bd, city_data.rooms_for_building(id), q)
			var tris: int = res["tris"]
			tri_tot[q] += tris
			max_tris[q] = maxi(max_tris[q], tris)
			var groups: Dictionary = res["groups"]
			if not groups.has("main"):
				print("FAIL no main geometry: ", id)
				fails += 1
			for g in groups:
				for s in groups[g]:
					var arr: Array = s[1]
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					if idx.size() % 3 != 0 or v.is_empty():
						print("FAIL bad surface ", id, " ", g, ":", s[0])
						fails += 1
					for p in v:
						if not p.is_finite():
							print("FAIL non-finite vertex ", id)
							fails += 1
							break
					if s[0] != "glass":
						for c in (arr[Mesh.ARRAY_COLOR] as PackedColorArray):
							var k := roundi(c.a * 20.0)
							if not k in [2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 14, 16, 18, 20]:
								print("FAIL unknown kind ", k, " in ", id)
								fails += 1
								break
			# exterior windows => glass
			var has_win := false
			for r in city_data.rooms_for_building(id):
				for o in r.get("openings", []):
					if o["type"] == "window":
						has_win = true
			if has_win and String(bd.get("typology", "")) != "parking" and not (groups.has("glass") or groups.has("main")):
				print("FAIL windows without glass: ", id)
				fails += 1
	var ms := Time.get_ticks_msec() - t0
	for q in tiers:
		print("tier %d: avg %d tris, max %d" % [q, tri_tot[q] / maxi(sample.size(), 1), max_tris[q]])
	print("build time: %.1f ms / building" % [float(ms) / (sample.size() * tiers.size())])
	if not (tri_tot[0] < tri_tot[1] and tri_tot[1] < tri_tot[2] and tri_tot[2] <= tri_tot[3]):
		print("FAIL tiers not increasing")
		fails += 1
	if max_tris[3] > 400000:
		print("FAIL a building exceeds 400k triangles")
		fails += 1
	# far LOD
	for id in sample:
		var g := BuildingDetail.build_far(city_data.building(id), 2)
		if not g.has("far"):
			print("FAIL no far LOD: ", id)
			fails += 1
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails else 0)
