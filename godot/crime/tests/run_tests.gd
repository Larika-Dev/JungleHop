## Headless tests for the crime system.
##   godot --headless --path godot --script res://crime/tests/run_tests.gd
extends SceneTree

const Catalog = preload("../crime_catalog.gd")
const Record = preload("../criminal_record.gd")
const Police = preload("../police_response.gd")
const Witnesses = preload("../witnesses.gd")
const LawScript = preload("../law.gd")
const MockLife = preload("mock_life.gd")

var failures := 0
var passes := 0
var life: Node
var law: Node


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func reset() -> void:
	for n in [law, life]:
		if n and is_instance_valid(n):
			root.remove_child(n)
			n.free()
	for n in get_nodes_in_group("police"):
		n.free()
	# The real Life autoload also lives at /root/Life; swap it out so Law binds to the mock.
	var real := root.get_node_or_null("Life")
	if real and real.get_script() != MockLife:
		root.remove_child(real)
		real.queue_free()
	life = MockLife.new()
	life.name = "Life"
	root.add_child(life)
	law = LawScript.new()
	law.name = "Law"
	root.add_child(law)
	law.rng.seed = 1795
	await process_frame


func civ(id: String, extra: Dictionary = {}) -> Dictionary:
	var w := {"id": id, "kind": "civilian", "distance": 3.0, "sees": true, "reports": true}
	w.merge(extra, true)
	return w


func cop() -> Dictionary:
	return {"id": "officer_1", "kind": "police", "distance": 5.0, "sees": true}


## Puts a dummy node in group "police" so the dice-rolled police simulation turns off
## and only scripted sightings happen.
func real_police_mode() -> void:
	var n := Node3D.new()
	n.add_to_group("police")
	root.add_child(n)


func _run() -> void:
	await test_catalog()
	await test_citation()
	await test_unseen_and_quiet()
	await test_report_and_wanted()
	await test_escalation()
	await test_escape_with_warrant()
	await test_escape_clean()
	await test_arrest_and_jail()
	await test_unpaid_fines_become_jail()
	await test_bail()
	await test_surrender_discount()
	await test_bribery()
	await test_relationships()
	await test_record_and_jobs()
	await test_life_actions()
	await test_simulated_police()
	await test_witness_odds()
	await test_save_load()
	print("crime tests: %d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


func test_catalog() -> void:
	var all := Catalog.all()
	check(all.size() >= 30 and all.size() <= 40, "30 to 40 crimes (got %d)" % all.size())
	var seen := {}
	for c in all:
		var id := String(c.id)
		check(not seen.has(id), "unique id " + id)
		seen[id] = true
		for f in ["name", "category", "class", "stars", "fine", "jail_hours", "notice", "radius", "target", "desc"]:
			check(c.has(f), "%s has %s" % [id, f])
		check(String(c["class"]) in ["infraction", "misdemeanor", "felony"], id + " class")
		check(int(c.stars) >= 0 and int(c.stars) <= 5, id + " stars 0..5")
		check(String(c.target) in ["self", "npc", "furniture", "place"], id + " target")
		if String(c.target) == "place":
			check(c.has("place"), id + " place target lists place tags")
		if String(c["class"]) == "felony":
			check(int(c.jail_hours) >= 72, id + " felony has real jail time")
		if c.has("loot"):
			check(int(c.loot[0]) <= int(c.loot[1]), id + " loot range")
	for must in ["jaywalking", "shoplifting", "murder", "bank_robbery", "speeding"]:
		check(seen.has(must), "catalog has " + must)
	var classes := {}
	for c in all:
		classes[c["class"]] = int(classes.get(c["class"], 0)) + 1
	check(int(classes.get("infraction", 0)) >= 5 and int(classes.get("felony", 0)) >= 10, "spread of severities")


func test_citation() -> void:
	await reset()
	var out: Dictionary = law.commit("jaywalking", {"witnesses": [cop()]})
	check(out.ok, "jaywalk ok")
	check(law.wanted() == 0, "infraction gives no stars")
	check(is_equal_approx(out.fine, 25.0), "jaywalk ticket $25")
	check(is_equal_approx(life.money.cash, 75.0), "ticket paid from cash")
	check(law.record.count("infraction") == 1, "ticket on record")


func test_unseen_and_quiet() -> void:
	await reset()
	var out: Dictionary = law.commit("shoplifting", {"success": true, "witnesses": []})
	check(out.loot >= 5.0 and out.loot <= 60.0, "shoplifting loot in range")
	check(life.money.cash > 100.0, "loot credited")
	check(law.wanted() == 0, "unseen shoplift: no stars")
	out = law.commit("shoplifting", {"success": true, "witnesses": [civ("npc_a", {"reports": false})]})
	check(out.seen == 1 and not out.reported and law.wanted() == 0, "seen but not reported")


func test_report_and_wanted() -> void:
	await reset()
	var dispatched := []
	law.police_dispatched.connect(func(s, u, k, p, e): dispatched.append([s, u, k, e]))
	var out: Dictionary = law.commit("robbery", {"victim_id": "npc_v", "witnesses": [civ("npc_v", {"is_victim": true})]})
	check(out.reported, "mugging reported")
	check(law.wanted() == 3, "mugging = 3 stars (got %d)" % law.wanted())
	check(law.charges == ["robbery"], "charge recorded")
	check(dispatched.size() == 1 and dispatched[0][1] == 4 and dispatched[0][2] == "patrol_roadblock", "dispatch 4 units with roadblocks")
	check(law.police.state == "responding" and law.police.eta == Police.RESPONSE_MINUTES[3], "police responding with eta")
	check(life.flags.get("crime.wanted") == 3, "wanted flag published")


func test_escalation() -> void:
	await reset()
	law.commit("graffiti", {"witnesses": [civ("a")]})
	check(law.wanted() == 1, "graffiti 1 star")
	law.commit("vandalism", {"witnesses": [civ("b")]})
	check(law.wanted() == 2, "second crime while wanted escalates to 2")
	law.commit("bank_robbery", {"witnesses": [civ("c")]})
	check(law.wanted() == 5, "bank robbery 5 stars")
	law.commit("littering", {"witnesses": [civ("d")]})
	check(law.wanted() == 5, "capped at 5")


func test_escape_with_warrant() -> void:
	await reset()
	real_police_mode()
	law.commit("car_theft", {"witnesses": [civ("friend", {"knows_player": true})]})
	check(law.wanted() == 2 and law.identified, "car theft, identified by someone who knows you")
	var minutes := Police.RESPONSE_MINUTES[2] + Police.SEARCH_TIMEOUT[2] + Police.SEARCH_TIMEOUT[1] + 2
	for i in minutes:
		law.tick_minute()
	check(law.wanted() == 0, "stars decay to 0 when unseen")
	check(law.warrant == ["car_theft"], "warrant holds the charge")
	check(law.job_check("basic").ok == false, "warrant blocks job checks")
	law.police_saw_player()
	check(law.wanted() == 1 and law.police.state == "pursuit", "cop recognizes warrant: 1 star pursuit")
	law.police_contact()
	check(law.record.count("felony") == 1, "warrant charge convicted on arrest")


func test_escape_clean() -> void:
	await reset()
	real_police_mode()
	law.commit("shoplifting", {"success": false, "witnesses": [civ("stranger")]})
	check(law.wanted() == 1 and not law.identified, "strangers can't identify you")
	for i in 60:
		law.tick_minute()
	check(law.wanted() == 0 and law.warrant.is_empty() and law.charges.is_empty(), "unidentified escape clears charges")


func test_arrest_and_jail() -> void:
	await reset()
	life.money.cash = 10000.0
	law.commit("robbery", {"witnesses": [cop()]})
	check(law.police.state == "pursuit", "cop saw it: immediate pursuit")
	var cash_before: float = life.money.cash
	var booked := []
	law.arrested.connect(func(b): booked.append(b))
	law.police_contact()
	check(booked.size() == 1, "arrested")
	var b: Dictionary = booked[0]
	check("robbery" in b.charges and "evading_police" in b.charges, "charges include evading after a pursuit")
	check(int(b.jail_hours) == 336 + 24, "jail hours summed (got %d)" % int(b.jail_hours))
	check(is_equal_approx(life.money.cash, cash_before - 3000.0 - 750.0), "fines charged")
	check(law.wanted() == 0, "wanted cleared on arrest")
	check(life.flags.get("crime.booked") == true, "booked flag")
	var t0: float = life.clock.total_minutes
	law.serve_sentence()
	check(is_equal_approx(life.clock.total_minutes - t0, 360.0 * 60.0), "clock skipped by the sentence")
	check(not law.in_jail and life.flags.get("crime.in_jail") == false, "released after serving")
	check(law.record.has_felony(), "felony on record")
	check(life.flags.get("crime.record").felonies == 1, "record flag for jobs")


func test_unpaid_fines_become_jail() -> void:
	await reset()
	life.money.cash = 100.0
	law.commit("vandalism", {"witnesses": [civ("a")]})
	law.surrender()
	var b: Dictionary = law.booking
	# Fine 500, paid 100, 400 unpaid = 8 extra hours; surrender takes 25% off 24h = 18h.
	check(is_equal_approx(life.money.cash, 0.0), "paid what they had")
	check(int(b.jail_hours) == 18 + 8, "unpaid fine turned into jail (got %d)" % int(b.jail_hours))


func test_bail() -> void:
	await reset()
	life.money.cash = 5000.0
	law.commit("simple_assault", {"witnesses": [civ("a")]})
	law.surrender()
	check(law.booking.can_bail, "bail offered for a misdemeanor")
	var cost: float = law.booking.bail
	var t0: float = life.clock.total_minutes
	check(law.post_bail(), "bail posted")
	check(is_equal_approx(life.money.cash, 5000.0 - 500.0 - cost), "bail charged")
	check(is_equal_approx(life.clock.total_minutes, t0), "no time skipped on bail")
	await reset()
	law.commit("murder", {"witnesses": [civ("a")]})
	law.surrender()
	check(not law.booking.can_bail, "no bail for murder")
	check(int(law.booking.jail_hours) <= LawScript.MAX_JAIL_HOURS, "sentence capped")


func test_surrender_discount() -> void:
	await reset()
	life.money.cash = 10000.0
	law.commit("burglary", {"witnesses": [civ("a")]})
	law.surrender()
	check(int(law.booking.jail_hours) == 180, "surrender: 240h -> 180h (got %d)" % int(law.booking.jail_hours))


func test_bribery() -> void:
	await reset()
	law.commit("shoplifting", {"witnesses": [civ("a")]})
	var out: Dictionary = law.commit("bribery", {"success": true})
	check(law.wanted() == 0 and law.charges.is_empty(), "bribe clears wanted")
	law.commit("shoplifting", {"witnesses": [civ("a")]})
	out = law.commit("bribery", {"success": false})
	check(law.wanted() == 2 and "bribery" in law.charges, "failed bribe adds charge and star")


func test_relationships() -> void:
	await reset()
	life.relationships.get_rel("lawful_lou").traits = {"lawful": 1.0, "wild": 0.0}
	life.relationships.get_rel("wild_wendy").traits = {"lawful": 0.0, "wild": 1.0}
	law.commit("littering", {"witnesses": [civ("lawful_lou"), civ("wild_wendy")]})
	check(life.relationships.get_rel("lawful_lou").friendship < 0.0, "lawful witness dislikes littering")
	check(life.relationships.get_rel("wild_wendy").friendship > 0.0, "wild witness thinks it's funny")
	await reset()
	law.commit("murder", {"victim_id": "victim", "success": true,
		"witnesses": [civ("victim", {"is_victim": true}), civ("bystander")]})
	var v: Dictionary = life.relationships.get_rel("victim")
	check(v.friendship <= -60.0 and "enemy" in v.flags and "crime_victim" in v.flags, "victim becomes enemy")
	check(v.memories[0][0] == "victim_of_murder", "victim remembers")
	var by: Dictionary = life.relationships.get_rel("bystander")
	check("witnessed_crime" in by.flags and by.memories[0][0] == "saw_you_murder", "bystander remembers")
	var harmed := []
	law.npc_harmed.connect(func(id, h, c): harmed.append([id, h]))
	law.police.clear()
	law.charges.clear()
	law.commit("simple_assault", {"victim_id": "x", "witnesses": []})
	check(harmed == [["x", "hurt"]], "npc_harmed signal for the NPC system")
	# Friends cover for you.
	var friend := {"kind": "civilian", "is_victim": false, "lawful": 0.5, "friendship": 100.0}
	var stranger := {"kind": "civilian", "is_victim": false, "lawful": 0.5, "friendship": 0.0}
	var c := Catalog.find("burglary")
	check(Witnesses.report_chance(c, friend) < Witnesses.report_chance(c, stranger) * 0.3, "friends rarely report")


func test_record_and_jobs() -> void:
	var r := Record.new()
	check(r.job_check("trusted", 0).ok, "clean record passes trusted")
	r.add_conviction("speeding", 0)
	check(r.job_check("trusted", 0).ok, "a ticket doesn't block trusted")
	r.add_conviction("shoplifting", 0)
	check(not r.job_check("trusted", 0).ok, "theft blocks trusted")
	check(not r.job_check("standard", 0).ok, "recent theft blocks standard")
	check(r.job_check("standard", 15 * 1440).ok, "standard ok after 14 days")
	check(r.job_check("basic", 0).ok, "shoplifting ok for basic")
	r.expunge(8 * 1440)
	check(r.count("infraction") == 0, "ticket expunged after 7 days")
	r.expunge(31 * 1440)
	check(r.count("misdemeanor") == 0, "misdemeanor expunged after 30 clean days")
	check(not r.job_check("trusted", 31 * 1440).ok, "trusted still sees past theft")
	r.add_conviction("burglary", 40 * 1440)
	check(not r.job_check("standard", 400 * 1440).ok, "felony blocks standard forever")
	check(r.job_check("basic", 71 * 1440).ok, "non-violent felony ok for basic after 30 days")
	check(not r.job_check("basic", 50 * 1440).ok, "felony blocks basic within 30 days")
	r.add_conviction("aggravated_assault", 100 * 1440)
	check(not r.job_check("basic", 900 * 1440).ok, "violent felony blocks basic forever")
	check(r.job_check("none", 0).ok, "none tier always ok")
	r.expunge(9999 * 1440)
	check(r.count("felony") == 2, "felonies never expunge")


func test_life_actions() -> void:
	await reset()
	var acts = life.actions
	var n := 0
	for id in acts.defs:
		if String(id).begins_with("crime_") and acts.defs[id].category == "crime":
			n += 1
	check(n == Catalog.menu_crimes().size() + 2, "every menu crime + hide + surrender registered (got %d)" % n)
	check(acts.defs.has("crime_pay_fines"), "pay fines action")
	check(acts.defs["crime_shoplifting"].place.has("shop"), "shoplifting needs a shop place")
	check(acts.defs["crime_embezzlement"].requires.flags == ["job.on_shift"], "embezzlement needs a shift")
	check(acts.perform("crime_bribery", "npc_x").reason != "", "bribery needs a cop")
	check(acts.perform("crime_surrender", null).ok == false, "can't surrender when not wanted")
	var res: Dictionary = acts.perform("crime_jaywalking", null)
	check(res.ok and res.has("crime"), "action runs through Law")
	law.commit("graffiti", {"witnesses": [civ("a")]})
	law.surrender()
	check(acts.perform("crime_jaywalking", null).ok == false, "no crimes while in custody")
	check(life.save_providers.has("crime"), "save provider registered")


func test_simulated_police() -> void:
	# No officer nodes: the police are simulated. Hiding should beat open ground on average.
	var caught_open := 0
	var caught_hiding := 0
	for trial in 200:
		for hide in [false, true]:
			var p := Police.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = trial * 2 + (1 if hide else 0)
			p.raise(2, Vector3.ZERO, false)
			var caught := false
			for m in 300:
				var ev := p.tick(rng, 0.15 if hide else 1.0, 1.0)
				if "caught" in ev:
					caught = true
					break
				if p.stars == 0:
					break
			if caught:
				if hide:
					caught_hiding += 1
				else:
					caught_open += 1
	check(caught_open > caught_hiding * 2, "hiding helps (open %d, hiding %d)" % [caught_open, caught_hiding])
	check(caught_open < 200 and caught_hiding > 0, "neither always caught nor never caught")


func test_witness_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := Catalog.find("pickpocketing")
	var near := 0
	var far := 0
	var night := 0
	for i in 4000:
		var w := {"kind": "civilian", "distance": 1.0}
		if not Witnesses.evaluate(c, [w], false, rng).seen_by.is_empty():
			near += 1
		w.distance = 7.0
		if not Witnesses.evaluate(c, [w], false, rng).seen_by.is_empty():
			far += 1
		w.distance = 1.0
		if not Witnesses.evaluate(c, [w], true, rng).seen_by.is_empty():
			night += 1
	check(near > far * 1.5, "closer witnesses notice more (%d vs %d)" % [near, far])
	check(night < near, "night hides you")
	var wall := {"kind": "civilian", "distance": 1.0, "can_see": false}
	check(Witnesses.sight_chance(c, wall, false) == 0.0, "no line of sight, no witness")
	check(Witnesses.sight_chance(c, {"distance": 9.0}, false) == 0.0, "outside radius")


func test_save_load() -> void:
	await reset()
	law.commit("car_theft", {"witnesses": [civ("f", {"knows_player": true})]})
	law.record.add_conviction("speeding", 0)
	law.unpaid_fines = 42.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(law.to_save()))
	await reset()
	law.from_save(d)
	check(law.wanted() == 2 and law.charges == ["car_theft"] and law.identified, "wanted state restored")
	check(law.record.count("infraction") == 1, "record restored")
	check(is_equal_approx(law.unpaid_fines, 42.0), "unpaid fines restored")
