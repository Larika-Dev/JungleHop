extends "res://education/ui/screen_base.gd"
## Registrar / ONSU portal: browse the 100-course catalog, enroll and drop,
## declare a major and minor, check degree progress, graduate, see the
## transcript, and manage student loans.

var tab: String = "catalog"
var subject_filter: String = "math"

func _start() -> void:
	tab = opts.get("tab", "") if opts.get("tab", "") != "" else "catalog"
	if edu.major != "":
		subject_filter = edu.major
	refresh()

func refresh() -> void:
	clear_body()
	accent = PALETTE.HEAVEN_BLUE
	title_label.text = "Old North State University · Registrar"
	sub_label.text = "Cash $%.2f · GPA %.2f · %d courses passed · hints %d%s" % [edu.cash(), edu.gpa(), edu.passed_courses().size(), edu.hints,
		"" if edu.loan_balance <= 0.0 else " · loan $%.2f" % edu.loan_balance]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for t in [["catalog", "Course catalog"], ["mine", "My courses"], ["degrees", "Degrees"], ["transcript", "Transcript"], ["loans", "Loans"]]:
		var b := make_button(("● " if tab == t[0] else "") + t[1], _set_tab.bind(t[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tabs.add_child(b)
	match tab:
		"catalog": _catalog()
		"mine": _mine()
		"degrees": _degrees()
		"transcript": _transcript()
		"loans": _loans()
	add_footer("Do homework", func(): close(); edu.call_deferred("open_homework"))
	add_footer("Close", close)

func _set_tab(t: String) -> void:
	tab = t
	refresh()

func _catalog() -> void:
	var row := HFlowContainer.new()
	body.add_child(row)
	for s in CATALOG.SUBJECTS:
		var b := make_button(("● " if s == subject_filter else "") + CATALOG.subject_name(s), _set_subject.bind(s))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(b)
	accent = subject_accent(subject_filter)
	add_text("%d courses · tuition $%d (graduate $%d) · at most %d at once" % [CATALOG.courses_in(subject_filter).size(),
		CATALOG.TUITION_UNDERGRAD, CATALOG.TUITION_GRAD, CATALOG.MAX_ACTIVE_COURSES], 15, PALETTE.HEAVEN_BLUE)
	for id in CATALOG.courses_in(subject_filter):
		var c: Dictionary = edu.course(id)
		var st: String = edu.status(id)
		var why: String = edu.can_enroll(id)
		var tag := ""
		match st:
			"enrolled": tag = "enrolled"
			"passed": tag = "passed %s" % CATALOG.letter(float(edu.record(id).grade))
			"failed": tag = "failed, can retake"
		var topics: Array = (c.topics as Array).map(func(t): return preload("res://education/questions/question_bank.gd").topic_name(t))
		var line := "%s  %s%s%s\n%s%s" % [id, c.title, "  · core" if c.core else "", "  · graduate" if c.graduate else "",
			", ".join(topics), "" if tag == "" else "  ·  " + tag]
		if why != "" and st != "enrolled" and st != "passed":
			line += "\n" + why
		add_button(line, _enroll.bind(id), why == "")

func _set_subject(s: String) -> void:
	subject_filter = s
	refresh()

func _enroll(id: String) -> void:
	var r: Dictionary = edu.enroll(id)
	refresh()
	sub_label.text = ("Enrolled in %s." % id) if r.ok else r.reason

func _mine() -> void:
	var active: Array = edu.active_courses()
	if active.is_empty():
		add_text("No active courses. Pick some from the catalog.")
	for id in active:
		var c: Dictionary = edu.course(id)
		var done := (edu.homework_outline(id) as Array).filter(func(h): return h.best >= 0.0).size()
		accent = subject_accent(c.subject)
		add_text("%s  %s · %d/20 homework · average %s" % [id, c.title, done,
			"—" if edu.course_average(id) < 0.0 else "%.0f%%" % edu.course_average(id)], 18)
		add_button("Drop %s%s" % [id, " (full refund)" if done == 0 else " (no refund)"], _drop.bind(id))

func _drop(id: String) -> void:
	edu.drop(id)
	refresh()

func _degrees() -> void:
	add_text("Major: %s   ·   Minor: %s" % [CATALOG.subject_name(edu.major) if edu.major != "" else "undeclared",
		CATALOG.subject_name(edu.minor) if edu.minor != "" else "none"], 20)
	add_text("A bachelor's takes %d passed courses: at least %d in your major (its 4 core courses, and %d at 300-level or above), GPA %.1f+. A minor takes 5 to 10 more courses in another subject, kept separate from the %d." % [
		CATALOG.DEGREE_COURSES, CATALOG.MAJOR_IN_SUBJECT, CATALOG.MAJOR_UPPER_LEVEL, CATALOG.MIN_GPA_TO_GRADUATE, CATALOG.DEGREE_COURSES], 15, PALETTE.HEAVEN_BLUE)
	var majors := HFlowContainer.new()
	body.add_child(majors)
	for s in CATALOG.SUBJECTS:
		var b := make_button(("● " if s == edu.major else "") + "Major: " + CATALOG.SUBJECTS[s].degree_name, _major.bind(s))
		majors.add_child(b)
	var minors := HFlowContainer.new()
	body.add_child(minors)
	for s in CATALOG.SUBJECTS:
		if s == edu.major:
			continue
		var b := make_button(("● " if s == edu.minor else "") + "Minor: %s (%d courses)" % [CATALOG.subject_name(s), CATALOG.SUBJECTS[s].minor_courses], _minor.bind(s))
		minors.add_child(b)
	if edu.major != "":
		var p: Dictionary = edu.degree_progress()
		add_text("Degree courses %d/%d · major %d/%d · upper-level %d/%d%s" % [p.degree_courses, p.degree_needed, p.major_courses, p.major_needed,
			p.upper_courses, p.upper_needed, "" if p.minor_needed == 0 else " · minor %d/%d" % [p.minor_courses, p.minor_needed]], 18)
		for r in p.reasons:
			add_text("• " + r, 15, PALETTE.MARKING_YELLOW)
		add_button("Graduate", _graduate, p.can_graduate or (p.minor_done and edu.has_tag("degree:bachelor")))
	for pid in CATALOG.GRAD_PROGRAMS:
		var m: Dictionary = edu.master_progress(pid)
		add_button("%s · %d/%d graduate courses%s" % [m.name, m.courses, m.needed, "" if m.eligible else " · needs a qualifying bachelor's"],
			_graduate_master.bind(pid), m.can_graduate)
	var a: Dictionary = edu.associate_progress()
	add_text("%s: %d/%d lower-level courses in %d/%d subjects (awarded automatically)." % [CATALOG.ASSOCIATE.name, a.courses, a.needed, a.subjects, a.subjects_needed], 15)
	if not edu.credentials.is_empty():
		add_text("Credentials: " + ", ".join(edu.credentials.map(func(c): return edu.credential_name(c))), 18, PALETTE.MARKING_YELLOW)

func _major(s: String) -> void:
	edu.declare_major(s)
	refresh()

func _minor(s: String) -> void:
	edu.declare_minor("" if s == edu.minor else s)
	refresh()

func _graduate() -> void:
	var got: Array = edu.graduate()
	refresh()
	sub_label.text = "Awarded: " + ", ".join(got.map(func(c): return edu.credential_name(c))) if not got.is_empty() else "Not yet."

func _graduate_master(pid: String) -> void:
	edu.graduate_master(pid)
	refresh()

func _transcript() -> void:
	var rows: Array = edu.transcript()
	if rows.is_empty():
		add_text("No courses yet.")
	for r in rows:
		var g := ""
		if r.letter != "":
			g = "%s (%.0f%%)" % [r.letter, r.grade]
		elif r.average >= 0.0:
			g = "in progress, %.0f%%" % r.average
		add_text("%s  %s · %s · %s" % [r.id, r.title, r.status, g], 16)

func _loans() -> void:
	add_text("Student loans: up to $%d total, about 5%% interest a year, payments deferred while you are enrolled. Balance: $%.2f" % [int(edu.LOAN_LIMIT), edu.loan_balance], 18)
	for amt in [500, 1000, 2500, 5000]:
		add_button("Borrow $%d" % amt, _borrow.bind(amt), edu.loan_balance + amt <= edu.LOAN_LIMIT)
	for amt in [100, 500]:
		add_button("Pay $%d" % amt, _pay.bind(amt), edu.loan_balance > 0.0)

func _borrow(amt: int) -> void:
	edu.take_loan(amt)
	refresh()

func _pay(amt: int) -> void:
	edu.pay_loan(amt)
	refresh()
