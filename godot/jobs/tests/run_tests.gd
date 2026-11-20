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


## First posting for a role at a company with no experience bar and none of the given perks.
func pid(js: Node, role: String, avoid_perks := ["signing_bonus", "flex_shifts", "tip_pool"]) -> String:
	for id in js.postings_for_role(role):
		var j: Dictionary = js.jobs[id]
		if float(j.experience_required) == 0.0 and not avoid_perks.any(func(p): return j.perks.has(p)):
			return id
	for id in js.postings_for_role(role):
		if float(js.jobs[id].experience_required) == 0.0:
			return id
	return js.postings_for_role(role)[0]


func test_job_system() -> void:
	var js := fresh_jobs()
	await process_frame
	js._clock_source = null  # drive the internal clock only
	ok(js.roles.size() == 17, "17 roles (got %d)" % js.roles.size())
	ok(js.companies.size() >= 200, "200+ companies (got %d)" % js.companies.size())
	ok(js.jobs.size() >= 300, "300+ postings (got %d)" % js.jobs.size())
	var games := {}
	for rid in js.roles:
		games[js.roles[rid].minigame] = true
		ok(ResourceLoader.exists("res://jobs/scenes/%s.tscn" % js.roles[rid].minigame), "scene for " + rid)
		ok(js.roles[rid].ranks.size() >= 3, rid + " has 3+ ranks")
		ok(not js.postings_for_role(rid).is_empty(), rid + " is offered by at least one company")
	ok(games.size() == 17, "every role has its own mini-game")
	var bad_buildings := 0
	var bad_wages := 0
	for id in js.job_order:
		var j: Dictionary = js.jobs[id]
		for b in j.buildings:
			if not CityDataStub.known(b):
				bad_buildings += 1
		for r in j.ranks.size() - 1:
			if float(j.ranks[r + 1].wage) <= float(j.ranks[r].wage):
				bad_wages += 1
		var base: float = js.roles[j.role].ranks[0].wage
		if absf(float(j.ranks[0].wage) - snappedf(base * float(js.companies[j.company].pay_scale), 0.25)) > 0.001:
			bad_wages += 1
	ok(bad_buildings == 0, "every posting is in a real building (%d bad)" % bad_buildings)
	ok(bad_wages == 0, "wages scale with company pay and rise with rank (%d bad)" % bad_wages)
	var names := {}
	for c in js.company_order:
		names[js.companies[c].name] = true
	ok(names.size() == js.companies.size(), "company names are unique")
	ok(js.companies.has("onsu") and js.companies.has("onsu_health"), "ONSU and ONSU Health exist")
	var chains: Array = js.company_order.filter(func(c): return js.companies[c].get("chain", false))
	ok(chains.size() >= 5, "local chains exist (%d)" % chains.size())
	var ch: Dictionary = js.companies[chains[0]]
	for b in ch.buildings:
		ok(js.jobs_at_building(b).any(func(id): return js.jobs[id].company == ch.id), "%s hires at branch %s" % [ch.name, b])
	ok(js.place_name(js.jobs_at_building(ch.buildings[1]).filter(func(id): return js.jobs[id].company == ch.id)[0], ch.buildings[1]).contains(ch.name), "branch name shows the chain")
	ok(js.jobs_at_building("LM13_MED_TOWER_D").any(func(id): return js.jobs[id].role == "er_nurse"), "ER nursing at Tower D")
	ok(not js.jobs_at_building("LM13_MED_TOWER_D").any(func(id): return js.jobs[id].role == "lab_tech"), "lab only at Tower A")

	var barista := pid(js, "barista")
	var teller := pid(js, "bank_teller")
	var wage: float = js.jobs[barista].ranks[0].wage
	# Monday 05:50
	js._own_minutes = 5 * 60 + 50
	var r: Dictionary = js.apply(barista)
	ok(r.ok and r.rank == 0, "hired as barista trainee at " + js.jobs[barista].place)
	ok(js.can_apply(barista) != "", "can't apply twice")
	var it := pid(js, "it_support")
	ok(js.can_apply(it).contains("cert_it_support") or js.can_apply(it).contains("cert it support"), "IT needs a cert: " + js.can_apply(it))
	ok(js.can_apply(pid(js, "er_nurse")) == "", "can apply as transporter without a degree")
	ok(js.apply(teller).ok, "second job ok")
	ok(js.can_apply(pid(js, "librarian")).contains("at most"), "third job blocked")

	var cash0: float = js.fallback_cash
	var s: Dictionary = js.start_shift(barista, false)
	ok(s.ok, "clock in: " + str(s.get("reason", "")))
	ok(js.start_shift(teller, false).ok == false, "one shift at a time")
	js.debug_advance(120)
	ok(absf(js.fallback_cash - cash0 - 2.0 * wage) < 0.02, "2 h at $%.2f (got %.2f)" % [wage, js.fallback_cash - cash0])
	for i in 6:
		js.report_round(1.0)
	var st: Dictionary = js.shift_status()
	ok(st.rounds == 6 and st.performance > 0.95, "rounds counted")
	js.debug_advance(30)
	var sum: Dictionary = js.end_shift()
	ok(absf(sum.hours - 2.5) < 0.02, "2.5 h worked")
	ok(absf(js.fallback_cash - cash0 - sum.tips - 2.5 * wage) < 0.03 and sum.tips > 0.0, "2.5 h pay pro rata plus tips (got %.2f + %.2f)" % [js.fallback_cash - cash0 - sum.tips, sum.tips])
	ok(js.active_job == "", "clocked out")

	js._own_minutes = 1440 + 6 * 60  # Tuesday 06:00
	js.start_shift(barista, false)
	js.debug_advance(8 * 60 + 5)
	ok(js.active_job == "", "auto clock-out at end of shift")
	ok(absf(js.employment[barista].hours_total - 10.5) < 0.1, "hours total 10.5 (got %.2f)" % js.employment[barista].hours_total)
	ok(absf(float(js.experience.get("barista", 0.0)) - 10.5) < 0.1, "barista experience follows the player")

	ok(js.promotion_gap(barista) != "", "not promotable yet: " + js.promotion_gap(barista))
	js.employment[barista].hours_rank = 20.0
	js.employment[barista].perf = 0.9
	ok(js.ask_promotion(barista).ok, "promoted to Barista")
	ok(js.wage_of(barista) == js.jobs[barista].ranks[1].wage, "rank 1 wage")
	js.employment[barista].hours_rank = 60.0
	ok(js.promotion_gap(barista).contains("cert"), "shift lead needs certificate")

	js.employment[barista].shifts_worked = 5
	js.employment[barista].perf = 0.85
	var w1: float = js.wage_of(barista)
	ok(js.ask_raise(barista).ok, "raise approved")
	ok(absf(js.wage_of(barista) - snappedf(js.jobs[barista].ranks[1].wage * 1.05, 0.01)) < 0.011, "5%% raise (%.2f -> %.2f)" % [w1, js.wage_of(barista)])
	ok(not js.ask_raise(barista).ok, "raise cooldown")

	var saved: Dictionary = js.to_save()
	var js2 := fresh_jobs()
	await process_frame
	js2.from_save(JSON.parse_string(JSON.stringify(saved)))
	ok(js2.rank_of(barista) == 1 and absf(js2.wage_of(barista) - js.wage_of(barista)) < 0.01, "save/load keeps rank and raise")
	ok(absf(float(js2.experience.get("barista", 0)) - 10.5) < 0.1, "save/load keeps experience")

	# Experience carries over: quit and join another cafe at a higher starting rank.
	js2.experience["barista"] = 40.0
	js2.role_rating["barista"] = 0.8
	js2.quit(barista)
	var other := ""
	for id in js2.postings_for_role("barista"):
		if id != barista and js2.jobs[id].company != js2.jobs[barista].company and float(js2.jobs[id].experience_required) == 0.0:
			other = id
			break
	var h2: Dictionary = js2.apply(other)
	ok(h2.ok and h2.rank == 1, "experienced barista starts as %s at %s" % [h2.get("title", "?"), js2.jobs[other].place])
	# Picky employers want experience.
	js2.quit(teller)
	var picky := ""
	for id in js2.job_order:
		if float(js2.jobs[id].experience_required) > 0 and js2.jobs[id].role == "bartender":
			picky = id
	if picky == "":
		for id in js2.job_order:
			if float(js2.jobs[id].experience_required) > 0 and not js2.jobs[id].ranks[0].has("education_any"):
				picky = id
				break
	ok(picky != "", "some companies require experience")
	if picky != "":
		js2.experience.erase(js2.jobs[picky].role)
		ok(js2.can_apply(picky).contains("experience"), "picky employer: " + js2.can_apply(picky))
	# Signing bonus is paid once on hire.
	var bonus := ""
	for id in js2.job_order:
		if js2.jobs[id].perks.has("signing_bonus") and not js2.jobs[id].ranks[0].has("education_any") and float(js2.jobs[id].experience_required) == 0.0 and not js2.jobs[id].get("adult", false):
			bonus = id
			break
	if bonus != "":
		var c0: float = js2.fallback_cash
		js2.quit(other)
		js2.apply(bonus)
		ok(absf(js2.fallback_cash - c0 - 150.0) < 0.01, "signing bonus paid at " + js2.jobs[bonus].place)

	# POS stock follows the employer's industry.
	var pos_id := ""
	for id in js.postings_for_role("cashier"):
		if js.jobs[id].catalog == "Grocery":
			pos_id = id
	var pos: Node = load("res://jobs/scenes/pos_register.tscn").instantiate()
	root.add_child(pos)
	pos.begin(js, pos_id, 0.3, 5)
	ok(pos.catalog == pos.CATALOGS["Grocery"], "co-op register sells groceries")
	pos.queue_free()

	var fired_ids := []
	js.fired.connect(func(id, _why): fired_ids.append(id))
	js.employment[barista].checked = {}
	js._own_minutes = 2 * 1440
	js.employment[teller].hired_day = 0
	js.debug_advance(3 * 1440)
	ok(fired_ids.has(teller), "fired after 3 missed shifts")
	js.queue_free()
	js2.queue_free()


func test_minigames() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://jobs/data/roles.json"))
	for j in data.roles:
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
	var cust := "onsu:custodian"
	var cwage: float = js.wage_of(cust) if false else float(js.jobs[cust].ranks[0].wage)
	ok(js.apply(cust).ok, "hired as ONSU custodian")  # day 06-14 weekdays
	var cash0: float = life.money.cash if life.money.get("cash") != null else 0.0
	var r: Dictionary = js.start_shift(cust, false)
	ok(r.ok, "clock in with Life: " + str(r.get("reason", "")))
	ok(life.get_flag("job.on_shift", false) == true, "job.on_shift flag set")
	life.clock.advance_minutes(120)
	await process_frame
	ok(js.shift_status().get("minutes", 0.0) >= 119.0, "JobSystem saw 2 h pass (got %s)" % str(js.shift_status().get("minutes")))
	ok(absf(life.money.cash - cash0 - cwage * 70.0 / 60.0) < 0.05, "Life credits each in-game hour (10 + 60 min so far, got %.2f)" % (life.money.cash - cash0))
	var sum: Dictionary = js.end_shift()
	ok(absf(life.money.cash - cash0 - 2.0 * cwage) < 0.05, "Life paid 2 h x $%.2f at clock-out (got %.2f)" % [cwage, life.money.cash - cash0])
	ok(absf(sum.earned - 2.0 * cwage) < 0.05, "shift summary earned (got %.2f)" % sum.earned)
	ok(life.get_flag("job.on_shift", true) == false, "job.on_shift cleared")
	ok(life.get_flag("job.onsu:custodian", false) == true, "job.<posting> flag")
	ok(life.get_flag("job.health_plan", false) == true, "ONSU health plan flag")
	var acts: Array = life.actions.available_for({"id": "LM09_STUDENT_UNION", "category": "campus"})
	var ids := acts.map(func(a): return a.def.id)
	ok(ids.has("job_start_shift"), "Clock in action listed: %s" % str(ids.filter(func(x): return String(x).begins_with("job_"))))
	js.quit(cust)
	ok(life.get_flag("job.onsu:custodian", true) == false, "flag cleared on quit")


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
				var local: Vector3 = city.building_transform(b).affine_inverse() * p
				var inside := false
				for rm in city.rooms_for_building(b):
					var rc: Array = rm.rect
					if int(rm.floor) == 0 and local.x >= rc[0] and local.x <= rc[2] and local.z >= rc[1] and local.z <= rc[3]:
						inside = true
				ok(inside, "%s terminal stands in a ground-floor room" % b)
		var w := Node3D.new()
		root.add_child(w)
		var made: Node3D = sites.spawn_all(js, w)
		ok(made.get_child_count() == js.employer_buildings().size(), "one terminal per workplace")
		var term: Node = made.get_child(0).get_child(made.get_child(0).get_child_count() - 1)
		ok(term.has_method("get_prompt") and term.get_actions(null).size() >= 2, "terminal is an Interactable with actions")
		w.queue_free()
