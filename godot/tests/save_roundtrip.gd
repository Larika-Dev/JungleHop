extends SceneTree
## Saves a game with state in every system, scrambles it, loads, and checks it came back.
##   godot --headless --path godot -s res://tests/save_roundtrip.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	var r := root
	var gs = r.get_node("GameState")
	var life = r.get_node("Life")
	var edu = r.get_node("Education")
	var js = r.get_node("JobSystem")
	var law = r.get_node("Law")
	var dlg = r.get_node("Dialogue")
	var GameClock = r.get_node("GameClock")
	gs.player_profile = gs.default_profile()
	gs.game_started.emit()
	await process_frame
	await process_frame
	# State
	life.money.cash = 777.0
	for n in life.needs.ids():
		life.needs.set_value(n, 60.0)
	life.needs.set_value("hunger", 33.0)
	life.relationships.register_npc("npc_42", {"name": "Test Person"})
	life.relationships.change("npc_42", 25.0, 0.0) if life.relationships.has_method("change") else null
	var f0: float = float(life.relationships.get_rel("npc_42").get("friendship", 0.0))
	edu.free_mode = true
	edu.enroll("CHEM 101")
	var hired := ""
	for b in js.employer_buildings():
		for jid in js.jobs_at_building(b):
			if js.can_apply(jid) == "":
				js.apply(jid)
				hired = jid
				break
		if hired != "":
			break
	law.commit("littering", {"success": true})
	var rec0 := str(law.record.to_save()) if law.get("record") and law.record.has_method("to_save") else str(law.save_data())
	dlg.set_personality("npc_42", dlg.personality_ids()[3])
	GameClock.set_time(3, 14, 25)
	print("NOTE  energy at save ", life.needs.get_value("energy"))
	check(gs.save_game(7), "saved")
	# Scramble
	life.money.cash = 1.0
	life.needs.set_value("hunger", 90.0)
	edu.drop("CHEM 101")
	if hired != "":
		js.quit(hired)
	dlg.set_personality("npc_42", dlg.personality_ids()[5])
	GameClock.set_time(9, 1, 0)
	# Load
	life.passed_out.connect(func(): print("NOTE  passed out at ", GameClock.time_string()))
	GameClock.time_set.connect(func(t): print("NOTE  time_set ", t))
	var d: Dictionary = gs.load_game(7)
	print("NOTE  right after load ", GameClock.time_string(), " hunger ", life.needs.get_value("hunger"))
	await process_frame
	check(not d.is_empty(), "loaded")
	check(is_equal_approx(life.money.cash, 777.0), "cash restored (%.2f)" % life.money.cash)
	check(absf(life.needs.get_value("hunger") - 33.0) < 1.0, "hunger restored (%.1f)" % life.needs.get_value("hunger"))
	check(is_equal_approx(float(life.relationships.get_rel("npc_42").get("friendship", 0.0)), f0), "relationship restored")
	check(edu.status("CHEM 101") == "enrolled", "enrollment restored (%s)" % edu.status("CHEM 101"))
	check(hired == "" or js.is_employed(hired), "job restored (%s)" % hired)
	var rec1 := str(law.record.to_save()) if law.get("record") and law.record.has_method("to_save") else str(law.save_data())
	check(rec0 == rec1, "criminal record restored")
	check(dlg.get_personality_id("npc_42") == dlg.personality_ids()[3], "personality override restored")
	var home = r.get_node("Home")
	check(home.room_id != "", "home assigned on new game (%s)" % home.room_id)
	check(life.money.bills.has("rent"), "weekly rent bill")
	check(GameClock.day == 3 and GameClock.hour == 14, "clock restored (%s day %d)" % [GameClock.time_string(), GameClock.day])
	print("SAVE ROUNDTRIP: ", "OK" if failures == 0 else "%d failures" % failures)
	quit(1 if failures else 0)
