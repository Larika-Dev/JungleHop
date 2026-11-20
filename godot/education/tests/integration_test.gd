extends Node
## Runs inside the full project, with the real autoloads (GameClock, GameState,
## UI and, when present, Life):
##   godot --headless --path godot res://education/tests/integration_test.tscn
## Exit code 0 = pass.

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1

func _ready() -> void:
	for i in 3:
		await get_tree().process_frame
	var edu: Node = get_node_or_null("/root/Education")
	check(edu != null, "Education autoload is present")
	if edu == null:
		get_tree().quit(1)
		return
	edu.reset()
	var life: Node = get_node_or_null("/root/Life")
	var gs: Node = get_node_or_null("/root/GameState")
	if life:
		check(life.actions.has_action("edu_registrar") and life.actions.has_action("edu_study_library"), "education actions registered with Life")
		var cash_before: float = life.money.cash
		if cash_before < 1000.0:
			life.money.add(1000.0, "test")
			cash_before = life.money.cash
		var r: Dictionary = edu.enroll("HIST 101")
		check(r.ok, "enroll charges Life.money: %s" % r.reason)
		check(is_equal_approx(cash_before - life.money.cash, 450.0), "tuition $450 taken from cash")
		check(life.get_flag("edu.enrolled", false) == true, "edu.enrolled flag set")
		var res: Dictionary = life.actions.perform("edu_study_library", null)
		check(res.get("ok", false), "study action runs: %s" % str(res))
		if life.clock.has_method("advance_minutes"):
			life.clock.advance_minutes(61)
		for i in 3:
			await get_tree().process_frame
		check(edu.hints >= 1, "studying gives a hint (%d)" % edu.hints)
	else:
		edu.free_mode = true
		check(edu.enroll("HIST 101").ok, "enroll (no Life autoload)")
	# Furniture desk action routes to the homework screen
	var ui: Node = get_node_or_null("/root/UI")
	if gs and ui:
		gs.action_performed.emit("do_homework", null, null)
		await get_tree().process_frame
		check(ui.is_panel_open(), "furniture do_homework opens the homework screen")
		ui.close_all()
		await get_tree().process_frame
		var scr: Node = edu.open_registrar()
		await get_tree().process_frame
		check(ui.is_panel_open() and scr != null, "registrar opens through UI.show_minigame")
		edu.close_screen(scr)
		await get_tree().process_frame
		check(not ui.is_panel_open(), "close_screen closes the panel")
	# Homework through the API, then save/load through GameState
	var s: Dictionary = edu.begin_homework("HIST 101", 0)
	edu.submit_homework("HIST 101", 0, (s.questions as Array).map(func(q): return q.answer))
	if gs:
		check(gs.save_game(9), "GameState.save_game")
		edu.reset()
		check(edu.status("HIST 101") == "none", "reset clears records")
		gs.load_game(9)
		check(edu.status("HIST 101") == "enrolled" and is_equal_approx(edu.record("HIST 101").homework[0], 100.0), "GameState.load_game restores education")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path(9)))
	# Loans tick with GameClock days
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		edu.drop("HIST 101")
		edu.take_loan(1000.0)
		var cash0: float = edu.cash()
		clock.advance_minutes(31 * 24 * 60)
		check(edu.loan_balance < 1004.0 and edu.cash() < cash0, "loan payment taken after a month (balance %.2f)" % edu.loan_balance)
	print("integration: %d failures" % fails)
	get_tree().quit(1 if fails > 0 else 0)
