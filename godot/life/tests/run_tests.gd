extends SceneTree
## Headless tests for the life core.
## godot --headless --path godot -s res://life/tests/run_tests.gd

const DemoNpc := preload("res://life/demo/demo_npc.gd")
const DemoFurniture := preload("res://life/demo/demo_furniture.gd")

var life: Node
var failures: int = 0
var passes: int = 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func near(a: float, b: float, eps: float = 0.011) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	life = root.get_node_or_null("Life")
	if life == null:
		life = load("res://life/life.gd").new()
		life.name = "Life"
		root.add_child(life)
	await process_frame
	life.actions.rng.seed = 1795
	life.auto_place = false
	test_catalog()
	test_clock()
	test_needs()
	test_money_and_hourly_pay()
	test_bills()
	await test_relationships()
	await test_furniture()
	test_places()
	test_runtime_registration()
	test_save_load()
	test_external_clock()
	print("Life core tests: %d passed, %d failed, %d actions loaded" % [passes, failures, life.actions.count()])
	quit(1 if failures > 0 else 0)


func test_catalog() -> void:
	var a = life.actions
	ok(a.count() >= 100, "at least 100 actions (got %d)" % a.count())
	var need_ids: Array = life.needs.ids() + ["comfort"]
	var targets := ["self", "npc", "furniture", "place"]
	var names := {}
	for id in a.order:
		var d: Dictionary = a.defs[id]
		ok(d.target in targets, "%s: target %s" % [id, d.target])
		for n in d.get("needs", {}):
			ok(n in need_ids, "%s: unknown need %s" % [id, n])
		for n in d.get("fail", {}).get("needs", {}):
			ok(n in need_ids, "%s: unknown fail need %s" % [id, n])
		if d.target == "furniture":
			ok(not d.get("furniture", []).is_empty(), "%s: furniture tags" % id)
		if d.target == "place":
			ok(not d.get("place", []).is_empty(), "%s: place tags" % id)
		names[str(d.name)] = true
	ok(names.size() >= 100, "100+ distinct action names")
	var by_target := {}
	for id in a.order:
		by_target[a.defs[id].target] = by_target.get(a.defs[id].target, 0) + 1
	print("Actions by target: ", by_target, " categories: ", a.categories())


func test_clock() -> void:
	var c = life.clock
	c.set_time(1, 8, 0)
	ok(c.hour() == 8 and c.day() == 1 and c.weekday() == 0, "clock starts Mon day 1 08:00")
	var hours := [0]
	var cb := func(_d, _h): hours[0] += 1
	c.hour_passed.connect(cb)
	c.advance_minutes(150)
	c.hour_passed.disconnect(cb)
	ok(hours[0] == 2, "advance 150 min from 08:00 fires 2 hour ticks (got %d)" % hours[0])
	ok(c.hour() == 10 and c.minute() == 30, "clock 10:30 after skip")
	ok(c.is_between(22, 26) == false and c.is_between(9, 17), "is_between incl. wrap")
	c.set_time(1, 23, 30)
	ok(c.is_between(22, 26), "23:30 is inside 22..26")
	c.set_time(1, 8, 0)


func test_needs() -> void:
	var n = life.needs
	n.set_value("energy", 50)
	life.clock.advance_minutes(60)
	ok(near(n.get_value("energy"), 45.5, 0.05), "energy decays 4.5/h (got %.2f)" % n.get_value("energy"))
	n.enabled = false
	life.clock.advance_minutes(60)
	ok(near(n.get_value("energy"), 45.5, 0.05), "disabled needs don't decay")
	ok(n.performance_multiplier() == 1.0, "multiplier 1.0 when needs are off")
	n.enabled = true
	for id in n.ids():
		n.set_value(id, 100)
	ok(n.performance_multiplier() > 1.05, "full needs -> multiplier near 1.1")


func test_money_and_hourly_pay() -> void:
	var m = life.money
	life.clock.set_time(1, 9, 0)
	var start: float = m.cash
	ok(m.spend(10, "test") and near(m.cash, start - 10), "spend")
	ok(not m.spend(1e9, "too much"), "spend refuses when broke")
	var credits := []
	var cb := func(_id, amt): credits.append(amt)
	m.pay_credited.connect(cb)
	var before: float = m.cash
	m.start_paid_session("job:test", 15.0, {"reason": "Test shift"})
	life.clock.advance_minutes(120)
	ok(credits.size() == 2 and near(credits[0], 15.0) and near(credits[1], 15.0), "paid $15 at each of 2 hour marks %s" % [credits])
	m.set_session_multiplier("job:test", 1.2)
	life.clock.advance_minutes(30)
	var total: float = m.end_paid_session("job:test")
	ok(near(total, 39.0), "2h at $15 + 30min at $18 = $39 (got %.2f)" % total)
	ok(near(m.cash - before, 39.0), "cash rose by session total")
	m.pay_credited.disconnect(cb)
	m.start_paid_session("gig", 20.0, {"max_minutes": 90, "to_bank": true})
	var bank0: float = m.bank
	life.clock.advance_minutes(200)
	ok(not m.has_session("gig") and near(m.bank - bank0, 30.0), "max_minutes auto-ends and pays bank $30")
	ok(m.deposit(5) and m.withdraw(5), "deposit / withdraw")
	ok(str(m) == "$%.2f" % m.cash, "money prints as cash")


func test_bills() -> void:
	var m = life.money
	m.add(500, "seed")
	var c0: float = m.total()
	m.add_bill("rent", 100, 1, "Rent")
	life.clock.advance_minutes(1440)
	ok(near(c0 - m.total(), 100.0, 0.02), "daily bill charged once (delta %.2f)" % (c0 - m.total()))
	m.remove_bill("rent")


func test_relationships() -> void:
	var npc := DemoNpc.new()
	npc.npc_id = "npc_test"
	npc.display_name = "Test Person"
	npc.traits = {"outgoing": 0.9, "kind": 0.9}
	npc.interests = ["music"]
	root.add_child(npc)
	await process_frame
	var r = life.relationships
	ok(r.display_name("npc_test") == "Test Person", "npc node auto-registered")
	ok(r.tier("npc_test") == "stranger", "starts as stranger")
	ok(life.actions.check("ask_on_date", npc) != "", "can't ask a stranger out")
	ok(life.actions.check("hug", npc) != "", "can't hug a stranger")
	life.needs.enabled = false
	var res: Dictionary = life.actions.perform("introduce", npc)
	ok(res.ok, "introduce runs: %s" % res.reason)
	ok(r.knows("npc_test"), "met after introduce")
	ok(life.actions.busy(), "introduce takes 2 game minutes")
	life.clock.advance_minutes(3)
	for i in range(40):
		life.actions.cooldowns.clear()
		life.actions.perform("talk_music", npc)
		life.clock.advance_minutes(11)
	ok(r.friendship("npc_test") >= 30.0, "friendship grows with talks (%.1f)" % r.friendship("npc_test"))
	ok(r.tier_index(r.tier("npc_test")) >= r.tier_index("friend"), "reached friend tier")
	r.change("npc_test", 0, 30)
	ok(life.actions.check("ask_on_date", npc) == "", "ask_on_date unlocked: %s" % life.actions.check("ask_on_date", npc))
	var tries := 0
	while not r.has_flag("npc_test", "dating") and tries < 20:
		life.actions.cooldowns.clear()
		life.actions.perform("ask_on_date", npc)
		life.clock.advance_minutes(3)
		tries += 1
	ok(r.has_flag("npc_test", "dating") and r.romance_tier("npc_test") == "dating", "dating after a yes")
	ok(life.actions.check("kiss", npc) == "", "kiss allowed when dating")
	var minor := DemoNpc.new()
	minor.npc_id = "npc_minor"
	minor.age = 16
	root.add_child(minor)
	await process_frame
	r.change("npc_minor", 50, 50)
	ok(life.actions.check("flirt", minor) != "", "no romance with minors")
	# decay
	var f0: float = r.friendship("npc_test")
	life.clock.advance_minutes(1440 * 5)
	ok(r.friendship("npc_test") < f0, "friendship drifts without contact")
	r.remember("npc_test", "saw_you_steal", -10)
	ok(r.memories("npc_test").back().event == "saw_you_steal", "memories")
	var opts: Array = life.actions.interactable_actions(npc)
	ok(opts.size() > 10 and opts[0].has("label"), "Interactable-shaped list for NPCs (%d)" % opts.size())
	life.needs.enabled = true


func test_furniture() -> void:
	var bed := DemoFurniture.new()
	bed.furniture_kind = "bed"
	bed.native = [{"id": "sleep", "label": "Sleep", "duration_game_minutes": 480},
		{"id": "bounce", "label": "Bounce", "needs_effects": {"fun": 10}}]
	root.add_child(bed)
	var shower := DemoFurniture.new()
	shower.furniture_kind = "shower"
	root.add_child(shower)
	await process_frame
	var ids: Array = life.actions.available_for(bed).map(func(o): return o.id)
	ok("sleep" in ids and "nap" in ids and "make_bed" in ids and "bounce" in ids, "bed actions merge native + life: %s" % [ids])
	life.needs.set_value("energy", 10)
	var t0: float = life.clock.total_minutes
	life.actions.perform("sleep", bed)
	ok(life.needs.get_value("energy") > 80.0, "sleep restores energy once (%.1f)" % life.needs.get_value("energy"))
	ok(life.needs.get_value("energy") <= 100.0, "and not twice")
	ok(life.clock.total_minutes - t0 >= 479.0, "furniture skipped 8 h")
	life.needs.set_value("fun", 20)
	life.actions.perform("bounce", bed)
	ok(near(life.needs.get_value("fun"), 30.0, 0.2), "native-only action uses needs_effects")
	life.needs.set_value("hygiene", 10)
	var res: Dictionary = life.actions.perform("shower", shower)
	ok(res.ok and life.actions.busy(), "shower is timed")
	ok(not life.actions.perform("watch_tv").ok, "busy blocks other actions")
	life.clock.advance_minutes(16)
	ok(not life.actions.busy() and life.needs.get_value("hygiene") > 70.0, "shower done, hygiene up")


func test_places() -> void:
	life.set_place({"id": "HAM_N_004", "business_type": "cafe", "room_id": "R1"})
	ok(life.actions.check("buy_coffee", life.place) == "", "coffee at a cafe")
	var self_ids: Array = life.actions.available_for(null).map(func(o): return o.id)
	ok("buy_coffee" in self_ids, "place actions appear in the self menu")
	life.set_place({"id": "BANK", "business_type": "bank", "room_id": "R1"})
	ok(life.actions.check("buy_coffee", life.place) != "", "no coffee at the bank")
	life.clock.set_time(life.clock.day(), 10, 0)
	life.money.add(100, "t")
	var bank0: float = life.money.bank
	life.actions.perform("deposit_cash", life.place)
	life.clock.advance_minutes(6)
	ok(life.money.cash == 0.0 and life.money.bank > bank0, "deposit all at the bank")
	life.set_place({})
	ok(life.actions.check("go_jogging") == "" or life.needs.get_value("energy") < 20, "jogging outdoors")


func test_runtime_registration() -> void:
	var called := [false]
	life.actions.register({"id": "test_pickpocket", "name": "Pickpocket", "category": "crime", "target": "npc", "minutes": 0})
	life.actions.set_check("test_pickpocket", func(_d, _t): return "Too risky" if life.get_flag("crime.heat", 0) > 2 else "")
	life.actions.set_handler("test_pickpocket", func(_d, _t, result):
		called[0] = true
		result.message = "Got $5"
		return result)
	life.set_flag("crime.heat", 3)
	ok(life.actions.check("test_pickpocket", "npc_test") == "Too risky", "custom check blocks")
	life.set_flag("crime.heat", 0)
	ok(life.actions.perform("test_pickpocket", "npc_test").ok and called[0], "custom handler runs")
	life.set_flag("crime.in_jail", true)
	ok(life.actions.check("chat", "npc_test") == "You're in jail", "jail blocks actions")
	life.set_flag("crime.in_jail", null)
	life.add_money(5, "alias")
	ok(life.spend_money(5, "alias") and life.get_money() >= 0.0, "jobs/education aliases")


func test_save_load() -> void:
	var path := "user://life_test_save.json"
	life.money.cash = 123.45
	life.skills.add_xp("cooking", 250)
	life.set_flag("edu.enrolled", true)
	var f0: float = life.relationships.friendship("npc_test")
	ok(life.save_game(path), "save")
	life.money.cash = 0
	life.skills.xp_by_skill["cooking"] = 0.0
	life.flags.clear()
	life.relationships.records.clear()
	ok(life.load_game(path), "load")
	ok(near(life.money.cash, 123.45), "cash restored")
	ok(life.skills.level("cooking") == 2, "skill restored (lvl %d)" % life.skills.level("cooking"))
	ok(life.get_flag("edu.enrolled", false) == true, "flags restored")
	ok(near(life.relationships.friendship("npc_test"), f0), "relationships restored")


func test_external_clock() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar total_minutes: float = 0.0\nfunc advance_minutes(m): total_minutes += m\n"
	script.reload()
	var ext := Node.new()
	ext.set_script(script)
	ext.total_minutes = life.clock.total_minutes
	var c = life.clock
	c.external = ext
	var hours := [0]
	var cb := func(_d, _h): hours[0] += 1
	c.hour_passed.connect(cb)
	c.advance_minutes(60)
	ok(hours[0] == 1 and near(c.total_minutes, ext.total_minutes), "external clock: skip forwards and ticks")
	ext.total_minutes += 120
	c._process(0.016)
	ok(hours[0] == 3, "external clock: follows its time (%d)" % hours[0])
	c.hour_passed.disconnect(cb)
	c.external = null
	ext.free()
