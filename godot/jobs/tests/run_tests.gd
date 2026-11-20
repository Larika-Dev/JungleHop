extends SceneTree
## Headless tests for the jobs system and every mini-game.
##   godot --headless --path godot --script res://jobs/tests/run_tests.gd
## Runs with or without the Life / GameClock / Education autoloads present.

var failures := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	await test_job_system()
	await test_minigames()
	if root.get_node_or_null("Life") and root.get_node_or_null("GameClock"):
		await test_life_integration()
	if root.get_node_or_null("CityData") and root.get_node_or_null("JobSystem"):
		await test_sites()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func fresh_jobs() -> Node:
	var js: Node = load("res://jobs/job_system.gd").new()
	js._test_mode = true
	js.isolated = true
	js.name = "JobsUnderTest"
	root.add_child(js)
	js._clock_source = null
	return js


func test_job_system() -> void:
	var js := fresh_jobs()
	await process_frame
	js._clock_source = null  # drive the internal clock only
	ok(js.jobs.size() == 17, "17 jobs defined (got %d)" % js.jobs.size())
	var games := {}
	for id in js.job_order:
		var j: Dictionary = js.jobs[id]
		games[j.minigame] = true
		ok(ResourceLoader.exists("res://jobs/scenes/%s.tscn" % j.minigame), "scene for " + id)
		ok(j.ranks.size() >= 3, id + " has 3+ ranks")
		ok(CityDataStub.known(j.building), id + " building exists in buildings.json: " + j.building)
		for r in j.ranks.size() - 1:
			ok(float(j.ranks[r + 1].wage) > float(j.ranks[r].wage), id + " wages rise with rank")
	ok(games.size() == 17, "every job has its own mini-game")

	# Monday 05:50
	js._own_minutes = 5 * 60 + 50
	var r: Dictionary = js.apply("barista")
	ok(r.ok and r.rank == 0, "hired as barista trainee")
	ok(js.can_apply("barista") != "", "can't apply twice")
	ok(js.can_apply("it_support").contains("cert_it_support") or js.can_apply("it_support").contains("cert it support"), "IT needs a cert: " + js.can_apply("it_support"))
	ok(js.can_apply("er_nurse") == "", "can apply as transporter without a degree")
	ok(js.apply("bank_teller").ok, "second job ok")
	ok(js.can_apply("librarian").contains("at most"), "third job blocked")

	# Shift: clock in 10 minutes early, work 2 hours.
	var cash0: float = js.fallback_cash
	var s: Dictionary = js.start_shift("barista", false)
	ok(s.ok, "clock in: " + str(s.get("reason", "")))
	ok(js.start_shift("bank_teller", false).ok == false, "one shift at a time")
	js.debug_advance(120)
	ok(absf(js.fallback_cash - cash0 - 25.0) < 0.02, "2 h at $12.50 = $25 (got %.2f)" % (js.fallback_cash - cash0))
	for i in 6:
		js.report_round(1.0)
	var st: Dictionary = js.shift_status()
	ok(st.rounds == 6 and st.performance > 0.95, "rounds counted")
	# Leave 30 minutes in: partial hour pays pro rata.
	js.debug_advance(30)
	var sum: Dictionary = js.end_shift()
	ok(absf(sum.hours - 2.5) < 0.02, "2.5 h worked")
	ok(absf(js.fallback_cash - cash0 - sum.tips - 31.25) < 0.02 and sum.tips > 0.0, "2.5 h pay = $31.25 plus tips (got %.2f + %.2f)" % [js.fallback_cash - cash0 - sum.tips, sum.tips])
	ok(js.active_job == "", "clocked out")

	# Auto clock-out at shift end (barista morning ends 14:00).
	js._own_minutes = 1440 + 6 * 60  # Tuesday 06:00
	js.start_shift("barista", false)
	js.debug_advance(8 * 60 + 5)
	ok(js.active_job == "", "auto clock-out at end of shift")
	ok(absf(js.employment.barista.hours_total - 10.5) < 0.1, "hours total 10.5 (got %.2f)" % js.employment.barista.hours_total)

	# Promotion needs hours and review; Shift Lead needs cert_barista.
	ok(js.promotion_gap("barista") != "", "not promotable yet: " + js.promotion_gap("barista"))
	js.employment.barista.hours_rank = 20.0
	js.employment.barista.perf = 0.8
	ok(js.ask_promotion("barista").ok, "promoted to Barista")
	ok(js.wage_of("barista") == 14.5, "barista wage 14.50")
	js.employment.barista.hours_rank = 60.0
	ok(js.promotion_gap("barista").contains("cert"), "shift lead needs certificate")

	# Raise
	js.employment.barista.shifts_worked = 5
	js.employment.barista.perf = 0.85
	ok(js.ask_raise("barista").ok, "raise approved")
	ok(absf(js.wage_of("barista") - 15.23) < 0.01, "5%% raise -> 15.23 (got %.2f)" % js.wage_of("barista"))
	ok(not js.ask_raise("barista").ok, "raise cooldown")

	# Save/load
	var saved: Dictionary = js.to_save()
	var js2 := fresh_jobs()
	await process_frame
	js2.from_save(JSON.parse_string(JSON.stringify(saved)))
	ok(js2.rank_of("barista") == 1 and absf(js2.wage_of("barista") - 15.23) < 0.01, "save/load keeps rank and raise")

	# No-shows: bank teller works weekdays 9-17. Skip Wed, Thu, Fri.
	var fired_ids := []
	js.fired.connect(func(id, _why): fired_ids.append(id))
	js.employment.barista.checked = {}
	js._own_minutes = 2 * 1440  # Wednesday 00:00
	js.employment.bank_teller.hired_day = 0
	js.debug_advance(3 * 1440)
	ok(fired_ids.has("bank_teller"), "fired after 3 missed shifts")
	js.queue_free()
	js2.queue_free()


func test_minigames() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://jobs/data/jobs.json"))
	for j in data.jobs:
		var packed: PackedScene = load("res://jobs/scenes/%s.tscn" % j.minigame)
		ok(packed != null, "load " + j.minigame)
		if packed == null:
			continue
		var mg: Node = packed.instantiate()
		root.add_child(mg)
		mg.begin(null, "", 0.5, 1795)
		await process_frame
		var good := 0.0
		var bad := 0.0
		var n := 6
		for i in n:
			good += mg.simulate_round(true)
		for i in n:
			bad += mg.simulate_round(false)
		good /= n
		bad /= n
		ok(good >= 0.9, "%s: perfect play scores %.2f" % [j.minigame, good])
		ok(bad <= 0.65, "%s: bad play scores %.2f" % [j.minigame, bad])
		ok(good > bad + 0.3, "%s separates good from bad" % j.minigame)
		print("  %-16s %-8s perfect %.2f  bad %.2f" % [j.minigame, j.kind, good, bad])
		mg.queue_free()
		await process_frame


func test_life_integration() -> void:
	var life: Node = root.get_node("Life")
	var gc: Node = root.get_node("GameClock")
	var js: Node = root.get_node_or_null("JobSystem")
	ok(js != null, "JobSystem autoload registered")
	if js == null:
		return
	await create_timer(1.5).timeout  # Life.clock attaches to GameClock
	gc.set_time(1, 9, 50)  # Monday 09:50
	await process_frame
	await process_frame
	ok(js.apply("custodian").ok, "hired as custodian")  # day 06-14 weekdays
	var cash0: float = life.money.cash if life.money.get("cash") != null else 0.0
	var r: Dictionary = js.start_shift("custodian", false)
	ok(r.ok, "clock in with Life: " + str(r.get("reason", "")))
	ok(life.get_flag("job.on_shift", false) == true, "job.on_shift flag set")
	life.clock.advance_minutes(120)
	await process_frame
	ok(js.shift_status().get("minutes", 0.0) >= 119.0, "JobSystem saw 2 h pass (got %s)" % str(js.shift_status().get("minutes")))
	ok(absf(life.money.cash - cash0 - 15.75) < 0.05, "Life credits each in-game hour (10 + 60 min so far, got %.2f)" % (life.money.cash - cash0))
	var sum: Dictionary = js.end_shift()
	ok(absf(life.money.cash - cash0 - 27.0) < 0.05, "Life paid 2 h x $13.50 at clock-out (got %.2f)" % (life.money.cash - cash0))
	ok(absf(sum.earned - 27.0) < 0.05, "shift summary earned $27 (got %.2f)" % sum.earned)
	ok(life.get_flag("job.on_shift", true) == false, "job.on_shift cleared")
	ok(life.get_flag("job.custodian", false) == true, "job.custodian flag")
	var acts: Array = life.actions.available_for({"id": "LM09_STUDENT_UNION", "category": "campus"})
	var ids := acts.map(func(a): return a.def.id)
	ok(ids.has("job_start_shift"), "Clock in action listed: %s" % str(ids.filter(func(x): return String(x).begins_with("job_"))))
	js.quit("custodian")


func test_sites() -> void:
	var js: Node = root.get_node("JobSystem")
	await process_frame
	var city := root.get_node_or_null("CityData")
	if city:
		var sites = load("res://jobs/world/job_sites.gd")
		for b in js.employer_buildings():
			var p = sites.site_position(city, b)
			ok(p != null, "site position for " + b)
			if p != null:
				var room: Dictionary = city.room_at(p + Vector3(0, 0.2, 0))
				ok(not room.is_empty() and room.buildingId == b, "%s terminal stands inside its building (room %s)" % [b, room.get("roomId", "none")])
		var w := Node3D.new()
		root.add_child(w)
		var made: Node3D = sites.spawn_all(js, w)
		ok(made.get_child_count() == js.employer_buildings().size(), "one terminal per workplace")
		var term: Node = made.get_child(0).get_child(made.get_child(0).get_child_count() - 1)
		ok(term.has_method("get_prompt") and term.get_actions(null).size() >= 2, "terminal is an Interactable with actions")
		w.queue_free()
