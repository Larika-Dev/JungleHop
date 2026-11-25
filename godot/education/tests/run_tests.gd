extends SceneTree
## Headless tests for the education system.
##   godot --headless --path godot --script res://education/tests/run_tests.gd
## Exits with code 1 on any failure.

const CATALOG := preload("res://education/catalog.gd")
const BANK := preload("res://education/questions/question_bank.gd")
const EDU := preload("res://education/education.gd")

var failures := 0
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	test_catalog()
	test_questions()
	await process_frame
	await test_flow()
	await test_degree()
	await test_ui()
	print("education tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func test_catalog() -> void:
	var ids := CATALOG.course_ids()
	check(ids.size() == 100, "100 courses (got %d)" % ids.size())
	check(CATALOG.SUBJECTS.size() == 8, "8 subjects")
	var seen := {}
	for id in ids:
		check(not seen.has(id), "unique id " + id)
		seen[id] = true
		var c := CATALOG.course(id)
		for t in c.topics:
			check(BANK.topic_exists(t), "%s topic %s exists" % [id, t])
		check(BANK.homework_outline(id).size() == 20, id + " has 20 homework")
		for k in 20:
			var n := CATALOG.question_count(id, k)
			check(n >= 10 and n <= 20, "%s hw %d has 10-20 questions (%d)" % [id, k, n])
	for s in CATALOG.SUBJECTS:
		var m: int = CATALOG.SUBJECTS[s].minor_courses
		check(m >= 5 and m <= 10, s + " minor is 5-10 courses")
		check(CATALOG.core_courses(s).size() == 4, s + " has 4 core courses")
		var ug := CATALOG.courses_in(s).filter(func(id): return not CATALOG.course(id).graduate)
		check(ug.size() >= CATALOG.MAJOR_IN_SUBJECT, s + " has enough undergrad courses for a major")
		check(ug.filter(func(id): return CATALOG.course(id).level >= 3).size() >= CATALOG.MAJOR_UPPER_LEVEL, s + " has enough upper-level courses")
		check(CATALOG.courses_in(s).filter(func(id): return CATALOG.course(id).level == 1).size() > 0, s + " has entry courses")
	for cid in CATALOG.CERTIFICATES:
		for t in CATALOG.CERTIFICATES[cid].topics:
			check(BANK.topic_exists(t), "%s topic %s exists" % [cid, t])

func test_questions() -> void:
	var total := 0
	var padded := 0
	var bad := 0
	var t0 := Time.get_ticks_msec()
	for id in CATALOG.course_ids():
		var first: Array = []
		for k in 20:
			var qs := BANK.homework_questions(id, k, 0)
			if k == 0:
				first = qs
			check(qs.size() == CATALOG.question_count(id, k), "%s hw %d size" % [id, k])
			for q in qs:
				total += 1
				var ok: bool = q.q is String and q.q != "" and (q.options as Array).size() == 4 and int(q.answer) >= 0 and int(q.answer) < 4
				var uniq := {}
				for o in q.options:
					uniq[o] = true
				ok = ok and uniq.size() == 4
				for o in q.options:
					if str(o).begins_with("Cannot be determined") or o == "None of these" or o == "All of these":
						padded += 1
				if not ok:
					bad += 1
					if bad < 10:
						printerr("bad question: ", q)
		# determinism and retake variety
		var again := BANK.homework_questions(id, 0, 0)
		check(str(again) == str(first), id + " homework is deterministic")
		check(str(BANK.homework_questions(id, 0, 1)) != str(first), id + " redo gives new questions")
	for cid in CATALOG.CERTIFICATES:
		check(BANK.cert_questions(cid).size() == CATALOG.CERT_QUESTIONS, cid + " exam size")
	check(bad == 0, "all %d questions well formed (%d bad)" % [total, bad])
	print("generated %d questions in %d ms; %d padded options (%.2f%%)" % [total, Time.get_ticks_msec() - t0, padded, 100.0 * padded / maxf(total, 1)])
	check(float(padded) / total < 0.02, "fewer than 2% of questions need padded options")

func _new_edu() -> Node:
	var e: Node = EDU.new()
	e.name = "Education"
	e.free_mode = true
	root.add_child(e)
	return e

func _perfect(e: Node, id: String, index: int) -> Dictionary:
	var s: Dictionary = e.begin_homework(id, index)
	var ans := (s.questions as Array).map(func(q): return q.answer)
	return e.submit_homework(id, index, ans)

func _pass_course(e: Node, id: String) -> void:
	if e.status(id) != "enrolled":
		var r: Dictionary = e.enroll(id)
		check(r.ok, "enroll %s: %s" % [id, r.reason])
	for k in 20:
		_perfect(e, id, k)

func test_flow() -> void:
	var e := _new_edu()
	await process_frame
	check(e.can_enroll("MATH 201") != "", "MATH 201 needs a 100-level math course")
	check(e.enroll("MATH 101").ok, "enroll MATH 101")
	check(e.status("MATH 101") == "enrolled", "status enrolled")
	check(e.can_start_homework("MATH 101", 1) != "", "homework 2 locked before homework 1")
	var r := _perfect(e, "MATH 101", 0)
	check(r.ok and is_equal_approx(r.percent, 100.0), "perfect homework scores 100")
	check(e.can_start_homework("MATH 101", 0) == "", "one redo allowed")
	var s: Dictionary = e.begin_homework("MATH 101", 0)
	e.submit_homework("MATH 101", 0, [])
	check(is_equal_approx(e.record("MATH 101").homework[0], 100.0), "best score kept after a bad redo")
	check(e.can_start_homework("MATH 101", 0) != "", "no third attempt")
	for k in range(1, 20):
		_perfect(e, "MATH 101", k)
	check(e.status("MATH 101") == "passed", "MATH 101 passed")
	check(e.can_enroll("MATH 201") == "", "MATH 201 unlocked")
	# failing a course
	e.enroll("ENGL 101")
	for k in 20:
		var hs: Dictionary = e.begin_homework("ENGL 101", k)
		e.submit_homework("ENGL 101", k, [])
	check(e.status("ENGL 101") == "failed", "zero answers fails the course")
	check(e.gpa() < 4.0, "GPA reflects the F")
	check(e.enroll("ENGL 101").ok, "can retake a failed course")
	check(e.record("ENGL 101").terms == 2, "retake counted")
	# hints
	e.add_hints(3)
	var q: Dictionary = BANK.homework_questions("MATH 201", 0)[0]
	var hidden: Array = e.use_hint(q)
	check(hidden.size() == 2 and not (int(q.answer) in hidden), "hint hides two wrong options")
	check(e.hints == 2, "hint consumed")
	# certificates
	var c: Dictionary = e.begin_cert("cert_cpr")
	var ans := (c.questions as Array).map(func(x): return x.answer)
	check(e.submit_cert("cert_cpr", c.attempt, ans).passed, "cert passes with perfect answers")
	check(e.has_credential("cert_cpr") and e.has_tag("cert"), "cert credential")
	check(e.has_credential("high_school"), "high school alias")
	# money without Life: tuition charged from the fallback wallet
	e.free_mode = false
	var before: float = e.cash()
	check(e.enroll("CHEM 101").ok, "paid enroll")
	check(is_equal_approx(before - e.cash(), CATALOG.TUITION_UNDERGRAD), "tuition charged")
	check(e.drop("CHEM 101") and is_equal_approx(e.cash(), before), "full refund when dropped before homework")
	e._fallback_cash = 10.0
	var lf := root.get_node_or_null("Life")
	if lf and lf.get("money"):
		lf.money.cash = 10.0
		if "bank" in lf.money:
			lf.money.bank = 0.0
	check(e.can_enroll("CHEM 101") != "", "cannot enroll without tuition")
	check(e.take_loan(1000.0), "loan")
	check(e.enroll("CHEM 101").ok, "enroll with loan money")
	# save / load
	var saved: Dictionary = e.save_data()
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var e2 := _new_edu()
	e2.load_data(json)
	check(e2.status("MATH 101") == "passed" and e2.status("CHEM 101") == "enrolled", "save/load keeps records")
	check(e2.has_credential("cert_cpr") and is_equal_approx(e2.loan_balance, 1000.0), "save/load keeps credentials and loans")
	check(e2.can_start_homework("CHEM 101", 0) == "", "loaded record is usable")
	e.queue_free()
	e2.queue_free()
	await process_frame

func test_degree() -> void:
	var e := _new_edu()
	await process_frame
	e.declare_major("cs")
	e.declare_minor("math")
	# 10 CS undergrad courses, 6 math (minor), 10 others
	var cs := CATALOG.courses_in("cs").filter(func(id): return not CATALOG.course(id).graduate)
	for id in cs:
		_pass_course(e, id)
	var p: Dictionary = e.degree_progress()
	check(not p.can_graduate, "10 courses is not a degree")
	for id in CATALOG.courses_in("math").slice(0, 6):
		_pass_course(e, id)
	p = e.degree_progress()
	check(p.minor_done, "minor complete with 6 math courses")
	check(p.degree_courses == 10, "minor courses do not count toward the 20 (got %d)" % p.degree_courses)
	for id in CATALOG.courses_in("history").slice(0, 4) + CATALOG.courses_in("english").slice(0, 4) + CATALOG.courses_in("bio").slice(0, 2):
		_pass_course(e, id)
	p = e.degree_progress()
	check(p.can_graduate, "20 courses with a CS major can graduate: %s" % str(p.reasons))
	var got: Array = e.graduate()
	check("bs_computer_science" in got and "minor_math" in got, "degree and minor awarded: %s" % str(got))
	check(e.has_tag("degree:bachelor") and e.has_tag("field:cs") and e.has_credential("bachelor_any"), "degree tags")
	check(e.has_credential("aa_general"), "associate degree awarded on the way")
	# master's
	check(e.can_enroll("COMP 501") == "", "grad course open after the B.S.")
	for id in CATALOG.courses_in("cs").filter(func(id): return CATALOG.course(id).graduate):
		_pass_course(e, id)
	check(e.graduate_master("ms_computer_science"), "M.S. awarded")
	check(e.has_tag("degree:master"), "master tag")
	e.queue_free()
	await process_frame

func test_ui() -> void:
	var e := _new_edu()
	await process_frame
	e.enroll("BIOL 101")
	var scene: PackedScene = load("res://education/ui/homework_screen.tscn")
	var ui: Control = scene.instantiate()
	root.add_child(ui)
	ui.setup({"education": e})
	await process_frame
	ui.show_assignments("BIOL 101")
	ui._start_homework("BIOL 101", 0)
	var n: int = (ui.session.questions as Array).size()
	for i in n:
		var q: Dictionary = ui.session.questions[ui.q_index]
		ui._choose(int(q.answer))
		ui._next()
	await process_frame
	check(is_equal_approx(e.record("BIOL 101").homework[0], 100.0), "UI run records a perfect homework")
	ui.queue_free()
	var cert: Control = scene.instantiate()
	root.add_child(cert)
	cert.setup({"education": e, "mode": "cert"})
	await process_frame
	check(cert.body.get_child_count() == CATALOG.CERTIFICATES.size(), "cert list shows every certification")
	cert.queue_free()
	var reg: Control = load("res://education/ui/registrar_panel.tscn").instantiate()
	root.add_child(reg)
	reg.setup({"education": e})
	for t in ["catalog", "mine", "degrees", "transcript", "loans"]:
		reg._set_tab(t)
		await process_frame
		check(reg.body.get_child_count() > 1, "registrar tab %s renders" % t)
	reg._set_subject("nursing")
	reg.queue_free()
	e.queue_free()
	await process_frame
