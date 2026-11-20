extends "res://education/ui/screen_base.gd"
## The education mini-game. Pick a course, pick its next homework assignment
## (or a redo), answer 10-20 multiple choice questions, see your score.
## In "cert" mode it lists certification exams instead.

var session: Dictionary = {}     # from Education.begin_homework / begin_cert
var answers: Array = []
var q_index: int = 0
var answered: bool = false
var option_buttons: Array = []

func _start() -> void:
	if opts.get("mode", "homework") == "cert":
		show_certs()
	elif opts.has("course_id"):
		show_assignments(opts.course_id)
	else:
		show_courses()

# --- course picker -------------------------------------------------------

func show_courses() -> void:
	clear_body()
	accent = PALETTE.HEAVEN_BLUE
	title_label.text = "Homework"
	sub_label.text = "Pick a course to work on. Hints: %d (study at a library, office hours, tutoring or a study group to earn more)." % edu.hints
	var active: Array = edu.active_courses()
	if active.is_empty():
		add_text("You are not enrolled in any course. Visit the registrar in Founders' Hall or open the ONSU portal on a computer.")
	for id in active:
		var c: Dictionary = edu.course(id)
		var done := 20 - (edu.homework_outline(id) as Array).filter(func(h): return h.best < 0.0).size()
		var avg: float = edu.course_average(id)
		accent = subject_accent(c.subject)
		add_button("%s  %s\n%s · %d/20 homework done%s" % [id, c.title, CATALOG.subject_name(c.subject), done,
			"" if avg < 0.0 else " · average %.0f%%" % avg], show_assignments.bind(id))
	accent = PALETTE.HEAVEN_BLUE
	add_footer("Close", close)

func show_assignments(id: String) -> void:
	clear_body()
	var c: Dictionary = edu.course(id)
	accent = subject_accent(c.subject)
	title_label.text = "%s  %s" % [id, c.title]
	sub_label.text = "%s · pass the course with a 60%% homework average. Each assignment can be redone once (best score counts)." % CATALOG.subject_name(c.subject)
	for h in edu.homework_outline(id):
		var label: String = "%s  (%d questions)" % [h.title, h.questions]
		if h.best >= 0.0:
			label += "  ·  best %.0f%%" % h.best
			label += "  ·  redo" if h.available else ""
		add_button(label, _start_homework.bind(id, h.index), h.available)
	add_footer("Back", show_courses)
	add_footer("Close", close)

func _start_homework(id: String, index: int) -> void:
	var s: Dictionary = edu.begin_homework(id, index)
	if not s.ok:
		sub_label.text = s.reason
		return
	_begin(s, edu.course(id).subject)

# --- certifications ------------------------------------------------------

func show_certs() -> void:
	clear_body()
	accent = PALETTE.PAINT_HOSPITAL_ACCENT
	title_label.text = "Certification exams"
	sub_label.text = "One %d-question exam each. Pass with %d%%. The fee is charged per attempt." % [CATALOG.CERT_QUESTIONS, int(CATALOG.CERT_PASS_PERCENT)]
	for cid in CATALOG.CERTIFICATES:
		var cert: Dictionary = CATALOG.CERTIFICATES[cid]
		var why: String = edu.can_take_cert(cid)
		add_button("%s  ($%d)%s" % [cert.name, cert.fee, "" if why == "" else "  ·  " + why], _start_cert.bind(cid), why == "")
	add_footer("Close", close)

func _start_cert(cid: String) -> void:
	var s: Dictionary = edu.begin_cert(cid)
	if not s.ok:
		sub_label.text = s.reason
		return
	_begin(s, "nursing" if cid in ["cert_cpr", "cert_phlebotomy"] else ("cs" if cid == "cert_it_support" else "business"))

# --- questions -----------------------------------------------------------

func _begin(s: Dictionary, subject: String) -> void:
	session = s
	answers = []
	q_index = 0
	accent = subject_accent(subject)
	show_question()

func show_question() -> void:
	clear_body()
	answered = false
	var qs: Array = session.questions
	var q: Dictionary = qs[q_index]
	title_label.text = session.title
	sub_label.text = "Question %d of %d  ·  %s  ·  hints left: %d" % [q_index + 1, qs.size(), _topic_name(q.get("topic", "")), edu.hints]
	add_text(q.q, 22)
	option_buttons = []
	for i in (q.options as Array).size():
		var b := add_button("%d)  %s" % [i + 1, q.options[i]], _choose.bind(i))
		option_buttons.append(b)
	var hint := add_footer("Hint (50/50)", _hint)
	hint.disabled = edu.hints <= 0
	add_footer("Quit (no credit)", _quit_session)

func _choose(i: int) -> void:
	if answered:
		return
	answered = true
	answers.append(i)
	var q: Dictionary = session.questions[q_index]
	for j in option_buttons.size():
		var b: Button = option_buttons[j]
		b.disabled = true
		if j == int(q.answer):
			b.add_theme_color_override("font_disabled_color", PALETTE.BIKE_LANE_GREEN.lightened(0.4))
			b.text = "✓ " + b.text
		elif j == i:
			b.add_theme_color_override("font_disabled_color", PALETTE.CURB_PAINT_RED.lightened(0.3))
			b.text = "✗ " + b.text
	var right := i == int(q.answer)
	add_text("Correct!" if right else "Not quite.", 20, PALETTE.BIKE_LANE_GREEN.lightened(0.3) if right else PALETTE.MARKING_YELLOW)
	if str(q.get("explain", "")) != "":
		add_text(q.explain, 16, PALETTE.HEAVEN_BLUE)
	for c in footer.get_children():
		c.queue_free()
	var last := q_index >= (session.questions as Array).size() - 1
	add_footer("Finish" if last else "Next", _next)

func _hint() -> void:
	if answered:
		return
	var q: Dictionary = session.questions[q_index]
	for j in edu.use_hint(q):
		(option_buttons[j] as Button).disabled = true
		(option_buttons[j] as Button).text = "—"
	sub_label.text = "Question %d of %d  ·  hints left: %d" % [q_index + 1, (session.questions as Array).size(), edu.hints]

func _next() -> void:
	q_index += 1
	if q_index < (session.questions as Array).size():
		show_question()
	else:
		_finish()

func _finish() -> void:
	var res: Dictionary
	if session.has("cert_id"):
		res = edu.submit_cert(session.cert_id, session.attempt, answers)
	else:
		res = edu.submit_homework(session.course_id, session.index, answers)
	clear_body()
	title_label.text = session.title
	sub_label.text = ""
	add_text("Score: %d / %d  (%.0f%%)" % [res.correct, res.total, res.percent], 28)
	if session.has("cert_id"):
		add_text("Passed! You are certified." if res.passed else "Not passed. You need %d%%." % int(CATALOG.CERT_PASS_PERCENT), 20)
		add_footer("Back", show_certs)
	else:
		if res.get("course_done", false):
			add_text("Course complete: %s (%.0f%%). %s" % [res.letter, res.grade,
				"Credit earned." if res.passed else "Below 60%: re-enroll to retake it."], 20)
		add_footer("Back to course", show_assignments.bind(session.course_id))
		add_footer("All courses", show_courses)
	add_footer("Close", close)
	session = {}

func _quit_session() -> void:
	# Quitting mid-assignment records nothing (the attempt is not used up).
	var was_cert: bool = session.has("cert_id")
	var cid: String = session.get("course_id", "")
	session = {}
	if was_cert:
		show_certs()
	elif cid != "":
		show_assignments(cid)
	else:
		show_courses()

func _topic_name(topic: String) -> String:
	return preload("res://education/questions/question_bank.gd").topic_name(topic)

func _unhandled_key_input(event: InputEvent) -> void:
	if session.is_empty() or not (event is InputEventKey) or not event.pressed:
		return
	var k: int = (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_4 and not answered:
		_choose(k - KEY_1)
		get_viewport().set_input_as_handled()
	elif (k == KEY_ENTER or k == KEY_SPACE) and answered:
		_next()
		get_viewport().set_input_as_handled()
