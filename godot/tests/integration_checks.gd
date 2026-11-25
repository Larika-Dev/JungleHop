extends SceneTree
## Cross-system wiring checks (headless):
##   godot --headless --path godot -s res://tests/integration_checks.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _walk(o, out: Array) -> void:
	if o is Dictionary:
		if o.has("action") and str(o.action) != "":
			out.append(str(o.action))
		for v in o.values():
			_walk(v, out)
	elif o is Array:
		for v in o:
			_walk(v, out)


func _run() -> void:
	await process_frame
	await process_frame
	var life = root.get_node("Life")
	var ids: Dictionary = life.actions.defs
	# Dialogue options run Life actions: every one must exist.
	var conv = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/data/conversation.json"))
	var acts: Array = []
	_walk(conv, acts)
	var missing := acts.filter(func(a): return not ids.has(a))
	check(missing.is_empty(), "every conversation option maps to a Life action %s" % [missing])
	# Every autoload the game relies on is registered.
	for n in ["Settings", "GameClock", "GameState", "CityData", "UI", "Life", "Furniture", "JobSystem",
			"Education", "Law", "NPCs", "Dialogue", "Home"]:
		check(root.get_node_or_null(n) != null, "autoload %s" % n)
	# Action counts against the spec
	check(ids.size() >= 339, "189 + 150 actions or more (%d)" % ids.size())
	var crimes := ids.keys().filter(func(i): return str(i).begins_with("crime_") and not (str(i) in ["crime_hide", "crime_surrender", "crime_pay_fines"]))
	check(crimes.size() >= 30 and crimes.size() <= 40, "30-40 crimes (%d)" % crimes.size())
	# Furniture-target actions all have tags (or they never show up)
	var untagged := ids.keys().filter(func(i): return ids[i].get("target", "") == "furniture" and ids[i].get("furniture", []).is_empty())
	check(untagged.is_empty(), "furniture actions tagged %s" % [untagged])
	var edu = root.get_node("Education")
	var cids: Array = edu.CATALOG.course_ids()
	var subs := {}
	for c in cids:
		subs[str(edu.CATALOG.course(c).get("subject", ""))] = true
	check(cids.size() >= 100 and subs.size() >= 8, "%d courses across %d subjects" % [cids.size(), subs.size()])
	var dlg = root.get_node("Dialogue")
	check(dlg.personality_ids().size() == 30, "30 personalities")
	print("INTEGRATION: ", "OK" if failures == 0 else "%d failures" % failures)
	quit(1 if failures else 0)
