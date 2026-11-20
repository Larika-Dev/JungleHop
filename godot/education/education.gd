extends Node
## Education autoload ("Education"): Old North State University.
##
## Enroll in courses at the registrar (or the ONSU portal on any computer),
## pay tuition, work through each course's 20 homework assignments (multiple
## choice), pass with 60%+, and graduate with a major (20 courses) and an
## optional minor (5 to 10 more). Short certifications are single exams.
##
## Other systems read credentials with has_credential(id) / has_tag(tag) and
## listen to credential_earned(id). See README.md for the full contract.

signal enrolled(course_id: String)
signal dropped(course_id: String)
signal homework_submitted(course_id: String, index: int, percent: float)
signal course_completed(course_id: String, passed: bool, percent: float)
signal credential_earned(credential_id: String)
signal hints_changed(count: int)
signal changed

const CATALOG := preload("res://education/catalog.gd")
const BANK := preload("res://education/questions/question_bank.gd")
const HOMEWORK_SCENE := "res://education/ui/homework_screen.tscn"
const REGISTRAR_SCENE := "res://education/ui/registrar_panel.tscn"

const MAX_HINTS := 10
const MAX_HOMEWORK_ATTEMPTS := 2
const LOAN_LIMIT := 40000.0
const LOAN_MONTHLY_RATE := 0.004      # about 5% a year
const LOAN_MIN_PAYMENT := 50.0

## course_id -> {status, homework: [best % or -1] x20, attempts: [int] x20, grade, terms}
var records: Dictionary = {}
var major: String = ""
var minor: String = ""
var credentials: Array = []
var used_courses: Array = []          # courses already counted toward an awarded degree or minor
var hints: int = 0
var cert_attempts: Dictionary = {}    # cert_id -> attempts so far
var loan_balance: float = 0.0
var loan_missed: int = 0
var days_since_payment: int = 0
var office_hours_day: Dictionary = {} # subject -> last day used

## When true, money and location checks are skipped (tests, debug).
var free_mode: bool = false
var _fallback_cash: float = 2000.0    # only used when no Life autoload exists

func _ready() -> void:
	call_deferred("_connect_systems")

func _connect_systems() -> void:
	var clock := _node("GameClock")
	if clock and clock.has_signal("day_passed"):
		clock.day_passed.connect(_on_day_passed)
	else:
		var life := _node("Life")
		if life and "clock" in life and life.clock and life.clock.has_signal("day_passed"):
			life.clock.day_passed.connect(_on_day_passed)
	var gs := _node("GameState")
	if gs and gs.has_method("register_saveable"):
		gs.register_saveable("education", self)
	else:
		var life2 := _node("Life")
		if life2 and life2.has_method("register_save_provider"):
			life2.register_save_provider("education", self)
	register_life_actions()
	if gs and gs.has_signal("action_performed"):
		gs.action_performed.connect(_on_world_action)

## Furniture actions (desks, lecterns, computers) from the furniture system.
const FURNITURE_HOMEWORK := ["do_homework", "write_essay", "take_online_course"]
const FURNITURE_STUDY := ["study", "attend_class", "attend_lecture", "lecture"]
const FURNITURE_HINTS_PER_DAY := 3
var _furniture_hint_day: int = -1
var _furniture_hints_today: int = 0

func _on_world_action(action_id: String, _target: Variant = null, actor: Variant = null) -> void:
	if actor is Node and not (actor as Node).is_in_group("player"):
		return
	if action_id in FURNITURE_HOMEWORK:
		if active_courses().is_empty():
			_notify("You are not enrolled in any course. Visit the registrar in Founders' Hall.")
		else:
			open_homework()
	elif action_id in FURNITURE_STUDY and not active_courses().is_empty():
		if _furniture_hint_day != _today():
			_furniture_hint_day = _today()
			_furniture_hints_today = 0
		if _furniture_hints_today < FURNITURE_HINTS_PER_DAY:
			_furniture_hints_today += 1
			add_hints(1)
			_notify("Studying paid off: +1 homework hint (%d)." % hints)

# =========================================================================
# Catalog queries
# =========================================================================

func course(id: String) -> Dictionary:
	return CATALOG.course(id)

func record(id: String) -> Dictionary:
	return records.get(id, {})

func status(id: String) -> String:
	return record(id).get("status", "none")

func active_courses() -> Array:
	return CATALOG.course_ids().filter(func(id): return status(id) == "enrolled")

func passed_courses() -> Array:
	return CATALOG.course_ids().filter(func(id): return status(id) == "passed")

func is_passed(id: String) -> bool:
	return status(id) == "passed"

## "" if the player may enroll, otherwise the reason.
func can_enroll(id: String) -> String:
	var c := course(id)
	if c.is_empty():
		return "No such course."
	var st := status(id)
	if st == "enrolled":
		return "Already enrolled."
	if st == "passed":
		return "Already passed."
	if active_courses().size() >= CATALOG.MAX_ACTIVE_COURSES:
		return "You can take at most %d courses at once." % CATALOG.MAX_ACTIVE_COURSES
	if c.graduate:
		var prog := _grad_program_for(c.subject)
		if prog.is_empty() or not _meets_requires_any(prog.requires_any):
			return "Graduate course: needs a qualifying bachelor's degree."
	elif int(c.level) >= 2:
		var lower: int = int(c.level) - 1
		var ok := passed_courses().any(func(p): return course(p).subject == c.subject and int(course(p).level) >= lower)
		if not ok:
			return "Prerequisite: pass a %d-level %s course first." % [lower * 100, CATALOG.subject_name(c.subject)]
	if not free_mode and not _can_afford(c.tuition):
		return "Tuition is $%d. Take a student loan at the registrar." % c.tuition
	return ""

func enroll(id: String) -> Dictionary:
	var why := can_enroll(id)
	if why != "":
		return {"ok": false, "reason": why}
	var c := course(id)
	if not free_mode and not _spend(c.tuition, "Tuition: %s" % id):
		return {"ok": false, "reason": "Payment failed."}
	var terms: int = int(record(id).get("terms", 0)) + 1
	var hw := []
	var att := []
	for i in CATALOG.HOMEWORK_PER_COURSE:
		hw.append(-1.0)
		att.append(0)
	records[id] = {"status": "enrolled", "homework": hw, "attempts": att, "grade": -1.0, "terms": terms, "paid": c.tuition}
	_sync_flags()
	enrolled.emit(id)
	changed.emit()
	_notify("Enrolled in %s %s." % [id, c.title])
	return {"ok": true, "reason": ""}

## Drop an active course. Full refund if no homework was turned in, else none.
func drop(id: String) -> bool:
	if status(id) != "enrolled":
		return false
	var r: Dictionary = records[id]
	var started: bool = (r.homework as Array).any(func(v): return v >= 0.0)
	if not started and not free_mode:
		_earn(float(r.get("paid", 0)), "Tuition refund: %s" % id)
	r.status = "dropped"
	_sync_flags()
	dropped.emit(id)
	changed.emit()
	return true

# =========================================================================
# Homework
# =========================================================================

func homework_outline(id: String) -> Array:
	var outline := BANK.homework_outline(id)
	var r := record(id)
	for h in outline:
		var i: int = h.index
		h["best"] = (r.get("homework", []) as Array)[i] if r.has("homework") else -1.0
		h["attempts"] = (r.get("attempts", []) as Array)[i] if r.has("attempts") else 0
		h["available"] = can_start_homework(id, i) == ""
	return outline

func next_homework_index(id: String) -> int:
	var r := record(id)
	if r.is_empty():
		return -1
	var hw: Array = r.homework
	for i in hw.size():
		if hw[i] < 0.0:
			return i
	return -1

func can_start_homework(id: String, index: int) -> String:
	if status(id) != "enrolled":
		return "Not enrolled in %s." % id
	if index < 0 or index >= CATALOG.HOMEWORK_PER_COURSE:
		return "No such assignment."
	var r: Dictionary = records[id]
	var nxt := next_homework_index(id)
	if (r.homework as Array)[index] < 0.0:
		return "" if index == nxt else "Finish Homework %d first." % (nxt + 1)
	if int((r.attempts as Array)[index]) >= MAX_HOMEWORK_ATTEMPTS:
		return "No redos left."
	return ""

## Returns {ok, reason, course_id, index, attempt, title, questions:[...]}
func begin_homework(id: String, index: int = -1) -> Dictionary:
	if index < 0:
		index = next_homework_index(id)
	var why := can_start_homework(id, index)
	if why != "":
		return {"ok": false, "reason": why}
	var attempt: int = (records[id].attempts as Array)[index]
	var outline: Dictionary = BANK.homework_outline(id)[index]
	return {"ok": true, "reason": "", "course_id": id, "index": index, "attempt": attempt,
		"title": "%s · %s" % [id, outline.title], "questions": BANK.homework_questions(id, index, attempt)}

## answers: Array of chosen option indexes (-1 = skipped). Grades and records it.
func submit_homework(id: String, index: int, answers: Array) -> Dictionary:
	var why := can_start_homework(id, index)
	if why != "":
		return {"ok": false, "reason": why}
	var r: Dictionary = records[id]
	var attempt: int = (r.attempts as Array)[index]
	var qs := BANK.homework_questions(id, index, attempt)
	var right := 0
	for i in qs.size():
		if i < answers.size() and int(answers[i]) == int(qs[i].answer):
			right += 1
	var pct := 100.0 * right / float(qs.size())
	r.attempts[index] = attempt + 1
	r.homework[index] = maxf(float(r.homework[index]), pct)
	_reward_skill(course(id).subject, right)
	homework_submitted.emit(id, index, pct)
	var out := {"ok": true, "correct": right, "total": qs.size(), "percent": pct, "best": r.homework[index], "course_done": false}
	if next_homework_index(id) == -1:
		out.course_done = true
		out.merge(_finish_course(id))
	_sync_flags()
	changed.emit()
	return out

func _finish_course(id: String) -> Dictionary:
	var r: Dictionary = records[id]
	var total := 0.0
	for v in r.homework:
		total += float(v)
	var grade := total / float((r.homework as Array).size())
	r.grade = grade
	var passed := grade >= CATALOG.PASS_PERCENT
	r.status = "passed" if passed else "failed"
	course_completed.emit(id, passed, grade)
	_notify("%s finished: %s (%.0f%%)%s" % [id, CATALOG.letter(grade), grade, "" if passed else ". Re-enroll to try again."])
	_check_auto_credentials()
	return {"grade": grade, "letter": CATALOG.letter(grade), "passed": passed}

func course_average(id: String) -> float:
	var r := record(id)
	if r.is_empty():
		return -1.0
	var done := (r.homework as Array).filter(func(v): return v >= 0.0)
	if done.is_empty():
		return -1.0
	var s := 0.0
	for v in done:
		s += float(v)
	return s / done.size()

# =========================================================================
# Hints and studying
# =========================================================================

func add_hints(n: int) -> void:
	hints = clampi(hints + n, 0, MAX_HINTS)
	hints_changed.emit(hints)

## Removes two wrong options from a question. Returns the indexes to hide.
func use_hint(q: Dictionary) -> Array:
	if hints <= 0:
		return []
	hints -= 1
	hints_changed.emit(hints)
	var wrong := []
	for i in (q.options as Array).size():
		if i != int(q.answer):
			wrong.append(i)
	wrong.shuffle()
	return wrong.slice(0, 2)

# =========================================================================
# Degrees
# =========================================================================

func declare_major(subject: String) -> void:
	if CATALOG.SUBJECTS.has(subject) or subject == "":
		major = subject
		if minor == subject:
			minor = ""
		_sync_flags()
		changed.emit()

func declare_minor(subject: String) -> void:
	if (CATALOG.SUBJECTS.has(subject) and subject != major) or subject == "":
		minor = subject
		_sync_flags()
		changed.emit()

## Progress toward a bachelor's in `subject`, with an optional minor.
## The minor's courses are kept separate from the 20 degree courses.
func degree_progress(subject: String = "", minor_subject: String = "") -> Dictionary:
	if subject == "":
		subject = major
	if minor_subject == "":
		minor_subject = minor
	var pool := passed_courses().filter(func(id): return not course(id).graduate and id not in used_courses)
	var minor_need: int = CATALOG.SUBJECTS[minor_subject].minor_courses if CATALOG.SUBJECTS.has(minor_subject) else 0
	var minor_set := []
	if minor_need > 0:
		for id in pool:
			if course(id).subject == minor_subject and minor_set.size() < minor_need:
				minor_set.append(id)
	var degree_pool := pool.filter(func(id): return id not in minor_set)
	var in_subject := degree_pool.filter(func(id): return course(id).subject == subject)
	var upper := in_subject.filter(func(id): return int(course(id).level) >= 3)
	var cores := CATALOG.core_courses(subject) if subject != "" else []
	var missing_core := cores.filter(func(id): return id not in in_subject)
	var degree_count := mini(degree_pool.size(), CATALOG.DEGREE_COURSES)
	var reasons := []
	if subject == "":
		reasons.append("Declare a major.")
	if degree_pool.size() < CATALOG.DEGREE_COURSES:
		reasons.append("%d of %d degree courses passed." % [degree_pool.size(), CATALOG.DEGREE_COURSES])
	if in_subject.size() < CATALOG.MAJOR_IN_SUBJECT:
		reasons.append("%d of %d courses in the major." % [in_subject.size(), CATALOG.MAJOR_IN_SUBJECT])
	if upper.size() < CATALOG.MAJOR_UPPER_LEVEL:
		reasons.append("%d of %d upper-level (300+) major courses." % [upper.size(), CATALOG.MAJOR_UPPER_LEVEL])
	if not missing_core.is_empty():
		reasons.append("Core courses still needed: %s." % ", ".join(missing_core))
	if gpa() < CATALOG.MIN_GPA_TO_GRADUATE:
		reasons.append("GPA %.2f is below %.1f." % [gpa(), CATALOG.MIN_GPA_TO_GRADUATE])
	var degree_id: String = CATALOG.SUBJECTS[subject].degree if subject != "" else ""
	if degree_id != "" and degree_id in credentials:
		reasons = ["You already hold the %s." % CATALOG.SUBJECTS[subject].degree_name]
	return {
		"subject": subject, "degree_id": degree_id,
		"degree_courses": degree_count, "degree_needed": CATALOG.DEGREE_COURSES,
		"major_courses": in_subject.size(), "major_needed": CATALOG.MAJOR_IN_SUBJECT,
		"upper_courses": upper.size(), "upper_needed": CATALOG.MAJOR_UPPER_LEVEL,
		"missing_core": missing_core, "minor_subject": minor_subject,
		"minor_courses": minor_set.size(), "minor_needed": minor_need,
		"minor_done": minor_need > 0 and minor_set.size() >= minor_need,
		"can_graduate": reasons.is_empty(), "reasons": reasons,
		"degree_set": degree_pool.slice(0, CATALOG.DEGREE_COURSES), "minor_set": minor_set,
	}

## Awards the bachelor's (and the minor when complete). Returns awarded ids.
func graduate() -> Array:
	var p := degree_progress()
	var awarded := []
	if p.can_graduate:
		_award(p.degree_id)
		awarded.append(p.degree_id)
		used_courses.append_array(p.degree_set)
		_notify("Congratulations! You earned the %s." % CATALOG.SUBJECTS[major].degree_name)
	if p.minor_done and _has_any_bachelor_or(awarded) and CATALOG.minor_id(minor) not in credentials:
		_award(CATALOG.minor_id(minor))
		awarded.append(CATALOG.minor_id(minor))
		used_courses.append_array(p.minor_set)
	_sync_flags()
	changed.emit()
	return awarded

func master_progress(program_id: String) -> Dictionary:
	var prog: Dictionary = CATALOG.GRAD_PROGRAMS.get(program_id, {})
	if prog.is_empty():
		return {}
	var all := CATALOG.courses_in(prog.subject).filter(func(id): return course(id).graduate)
	var done := all.filter(func(id): return is_passed(id))
	var eligible := _meets_requires_any(prog.requires_any)
	return {"id": program_id, "name": prog.name, "courses": done.size(), "needed": all.size(),
		"eligible": eligible, "can_graduate": eligible and done.size() >= all.size() and program_id not in credentials}

func graduate_master(program_id: String) -> bool:
	var p := master_progress(program_id)
	if p.is_empty() or not p.can_graduate:
		return false
	_award(program_id)
	_notify("Congratulations! You earned the %s." % p.name)
	return true

func associate_progress() -> Dictionary:
	var a: Dictionary = CATALOG.ASSOCIATE
	var lower := passed_courses().filter(func(id): return int(course(id).level) <= int(a.max_level))
	var subjects := {}
	for id in lower:
		subjects[course(id).subject] = true
	return {"courses": lower.size(), "needed": a.courses, "subjects": subjects.size(), "subjects_needed": a.subjects,
		"can_claim": lower.size() >= int(a.courses) and subjects.size() >= int(a.subjects) and a.id not in credentials}

func _check_auto_credentials() -> void:
	# The associate degree is awarded automatically once earned.
	if associate_progress().can_claim:
		_award(CATALOG.ASSOCIATE.id)
		_notify("You earned the %s." % CATALOG.ASSOCIATE.name)

func gpa() -> float:
	var pts := 0.0
	var n := 0
	for id in records:
		var r: Dictionary = records[id]
		if r.status in ["passed", "failed"]:
			pts += CATALOG.grade_points(float(r.grade))
			n += 1
	return pts / n if n > 0 else 4.0

func transcript() -> Array:
	var out := []
	for id in CATALOG.course_ids():
		var r := record(id)
		if r.is_empty():
			continue
		var c := course(id)
		out.append({"id": id, "title": c.title, "status": r.status, "grade": r.grade,
			"letter": CATALOG.letter(float(r.grade)) if float(r.grade) >= 0.0 else "", "average": course_average(id)})
	return out

# =========================================================================
# Certifications
# =========================================================================

func can_take_cert(cert_id: String) -> String:
	var c: Dictionary = CATALOG.CERTIFICATES.get(cert_id, {})
	if c.is_empty():
		return "No such certification."
	if cert_id in credentials:
		return "Already certified."
	if not free_mode and not _can_afford(c.fee):
		return "The exam fee is $%d." % c.fee
	return ""

func begin_cert(cert_id: String) -> Dictionary:
	var why := can_take_cert(cert_id)
	if why != "":
		return {"ok": false, "reason": why}
	var c: Dictionary = CATALOG.CERTIFICATES[cert_id]
	if not free_mode and not _spend(c.fee, "Exam fee: %s" % c.name):
		return {"ok": false, "reason": "Payment failed."}
	var attempt: int = cert_attempts.get(cert_id, 0)
	cert_attempts[cert_id] = attempt + 1
	return {"ok": true, "reason": "", "cert_id": cert_id, "attempt": attempt, "title": "%s exam" % c.name,
		"questions": BANK.cert_questions(cert_id, attempt)}

func submit_cert(cert_id: String, attempt: int, answers: Array) -> Dictionary:
	var qs := BANK.cert_questions(cert_id, attempt)
	var right := 0
	for i in qs.size():
		if i < answers.size() and int(answers[i]) == int(qs[i].answer):
			right += 1
	var pct := 100.0 * right / qs.size()
	var passed := pct >= CATALOG.CERT_PASS_PERCENT
	if passed and cert_id not in credentials:
		_award(cert_id)
		_notify("Certified: %s." % CATALOG.CERTIFICATES[cert_id].name)
	_sync_flags()
	changed.emit()
	return {"ok": true, "correct": right, "total": qs.size(), "percent": pct, "passed": passed}

# =========================================================================
# Credentials (the contract jobs and others use)
# =========================================================================

const ALIASES := {
	"bachelor_nursing": "bs_nursing", "bachelor_finance": "ba_business", "bachelor_business": "ba_business",
	"bachelor_cs": "bs_computer_science", "ba_economics": "ba_business", "masters_cs": "ms_computer_science",
	"community_cert_culinary": "cert_food_safety",
}

func has_credential(id: String) -> bool:
	if id == "high_school" or id == "":
		return true
	if id == "bachelor_any":
		return has_tag("degree:bachelor")
	if id == "masters_any":
		return has_tag("degree:master")
	return ALIASES.get(id, id) in credentials

func get_credentials() -> Array:
	return credentials.duplicate()

func credential_tags(id: String) -> Array:
	if id.begins_with("cert_"):
		return ["cert"]
	if id.begins_with("minor_"):
		return ["minor", "field:" + id.trim_prefix("minor_")]
	if id == CATALOG.ASSOCIATE.id:
		return ["degree:associate"]
	if CATALOG.GRAD_PROGRAMS.has(id):
		return ["degree:master", "field:" + CATALOG.GRAD_PROGRAMS[id].subject]
	var subj := CATALOG.degree_subject(id)
	if subj != "":
		return ["degree:bachelor", "field:" + subj]
	return []

func has_tag(tag: String) -> bool:
	for c in credentials:
		if tag in credential_tags(c):
			return true
	return false

func credential_name(id: String) -> String:
	if CATALOG.CERTIFICATES.has(id):
		return CATALOG.CERTIFICATES[id].name + " certification"
	if id.begins_with("minor_"):
		return "Minor in " + CATALOG.subject_name(id.trim_prefix("minor_"))
	if CATALOG.GRAD_PROGRAMS.has(id):
		return CATALOG.GRAD_PROGRAMS[id].name
	if id == CATALOG.ASSOCIATE.id:
		return CATALOG.ASSOCIATE.name
	var s := CATALOG.degree_subject(id)
	return CATALOG.SUBJECTS[s].degree_name if s != "" else id

func _award(id: String) -> void:
	if id in credentials:
		return
	credentials.append(id)
	var life := _node("Life")
	if life and life.has_method("set_flag"):
		life.set_flag("edu." + id, true)
	credential_earned.emit(id)

func _has_any_bachelor_or(just_awarded: Array) -> bool:
	return has_tag("degree:bachelor") or not just_awarded.is_empty()

func _meets_requires_any(reqs: Array) -> bool:
	for r in reqs:
		if r == "*bachelor" and has_tag("degree:bachelor"):
			return true
		if has_credential(r):
			return true
	return false

func _grad_program_for(subject: String) -> Dictionary:
	for id in CATALOG.GRAD_PROGRAMS:
		if CATALOG.GRAD_PROGRAMS[id].subject == subject:
			return CATALOG.GRAD_PROGRAMS[id]
	return {}

# =========================================================================
# Student loans
# =========================================================================

func take_loan(amount: float) -> bool:
	amount = minf(amount, LOAN_LIMIT - loan_balance)
	if amount <= 0.0:
		return false
	loan_balance += amount
	_earn(amount, "Student loan")
	_sync_flags()
	changed.emit()
	return true

func pay_loan(amount: float) -> bool:
	amount = minf(amount, loan_balance)
	if amount <= 0.0 or not _spend(amount, "Student loan payment"):
		return false
	loan_balance -= amount
	_sync_flags()
	changed.emit()
	return true

func monthly_loan_payment() -> float:
	return minf(loan_balance, maxf(LOAN_MIN_PAYMENT, loan_balance * 0.01))

func _on_day_passed(_day: int = 0) -> void:
	if loan_balance <= 0.0:
		return
	days_since_payment += 1
	if days_since_payment < 30:
		return
	days_since_payment = 0
	loan_balance *= 1.0 + LOAN_MONTHLY_RATE
	# Payments are deferred while you are enrolled.
	if not active_courses().is_empty():
		return
	var due := monthly_loan_payment()
	if _spend(due, "Student loan payment"):
		loan_balance -= due
		loan_missed = 0
	else:
		loan_missed += 1
		_notify("Missed a student loan payment of $%.2f." % due)
	_sync_flags()

# =========================================================================
# Life actions (actions, flags, skills, money)
# =========================================================================

## Life pulls this first; Education registers its own actions (with checks
## and handlers) in register_life_actions(), so there is nothing to adopt.
func get_life_actions() -> Array:
	return []

## Plain list for systems that want simple entry points.
func get_actions() -> Array:
	return [
		{"id": "edu_registrar", "label": "Registrar: courses, degrees, loans", "building_id": CATALOG.REGISTRAR_BUILDING, "callable": open_registrar},
		{"id": "edu_homework", "label": "Do homework", "building_id": "", "callable": open_homework},
		{"id": "edu_cert_exam", "label": "Take a certification exam", "building_id": "", "callable": open_cert_exams},
	]

func register_life_actions() -> void:
	var life := _node("Life")
	if life == null or not ("actions" in life) or life.actions == null:
		return
	var A = life.actions
	var defs := [
		{"id": "edu_registrar", "name": "Registrar: courses, degrees, loans", "category": "school", "target": "self", "minutes": 0},
		{"id": "edu_portal", "name": "ONSU student portal", "category": "school", "target": "furniture", "furniture": ["computer", "laptop", "use_computer"], "minutes": 0},
		{"id": "edu_homework", "name": "Do homework", "category": "school", "target": "self", "minutes": 0},
		{"id": "edu_study_library", "name": "Study at the library", "category": "school", "target": "self", "minutes": 60,
			"needs": {"energy": -6, "fun": -4}, "skills": {"knowledge": 10}, "message": "You study in the stacks. (+1 hint)"},
		{"id": "edu_office_hours", "name": "Visit office hours", "category": "school", "target": "self", "minutes": 30,
			"needs": {"social": 4}, "skills": {"knowledge": 6}, "message": "The professor walks you through the hard part. (+2 hints)"},
		{"id": "edu_tutoring", "name": "Book a tutoring session ($40)", "category": "school", "target": "self", "minutes": 60, "cost": 40,
			"skills": {"knowledge": 12}, "message": "Cram Fortress drills you. (+3 hints)"},
		{"id": "edu_study_group", "name": "Join a study group", "category": "school", "target": "self", "minutes": 60,
			"needs": {"social": 12, "energy": -4}, "skills": {"knowledge": 6, "charm": 2}, "message": "You compare notes with classmates. (+1 hint)"},
		{"id": "edu_cert_exam", "name": "Take a certification exam", "category": "school", "target": "self", "minutes": 0},
		{"id": "edu_graduate", "name": "Apply to graduate", "category": "school", "target": "self", "minutes": 0},
		{"id": "edu_pay_loan", "name": "Pay toward student loan ($100)", "category": "money", "target": "self", "minutes": 5},
	]
	for d in defs:
		if A.has_method("register"):
			A.register(d)
	var at := func(ids: Array) -> Callable:
		return func(_def, _target): return "" if _at_any(ids) else "Go to %s." % _place_names(ids)
	_set_check(A, "edu_registrar", at.call([CATALOG.REGISTRAR_BUILDING]))
	_set_check(A, "edu_homework", func(_d, _t): return "" if _at_campus() else "Go to a campus building or use a desk.")
	_set_check(A, "edu_study_library", at.call(CATALOG.LIBRARIES))
	_set_check(A, "edu_office_hours", func(_d, _t): return _office_hours_check())
	_set_check(A, "edu_tutoring", at.call([CATALOG.TUTORING_BUILDING]))
	_set_check(A, "edu_study_group", at.call([CATALOG.STUDENT_UNION]))
	_set_check(A, "edu_cert_exam", func(_d, _t): return "" if _at_any(_cert_buildings()) else "Certification exams are at the Medical Center, Dining Hall, Swain Hall or Carroll Hall.")
	_set_check(A, "edu_graduate", at.call([CATALOG.REGISTRAR_BUILDING]))
	_set_check(A, "edu_pay_loan", func(_d, _t): return "" if loan_balance > 0.0 else "No student loan.")
	_set_handler(A, "edu_registrar", func(_d, _t, res): open_registrar(); return res)
	_set_handler(A, "edu_portal", func(_d, _t, res): open_registrar(); return res)
	_set_handler(A, "edu_homework", func(_d, _t, res): open_homework(); return res)
	_set_handler(A, "edu_study_library", func(_d, _t, res): add_hints(1); return res)
	_set_handler(A, "edu_office_hours", func(_d, _t, res): _use_office_hours(); add_hints(2); return res)
	_set_handler(A, "edu_tutoring", func(_d, _t, res): add_hints(3); return res)
	_set_handler(A, "edu_study_group", func(_d, _t, res): add_hints(1); return res)
	_set_handler(A, "edu_cert_exam", func(_d, _t, res): open_cert_exams(); return res)
	_set_handler(A, "edu_graduate", func(_d, _t, res): open_registrar("degrees"); return res)
	_set_handler(A, "edu_pay_loan", func(_d, _t, res): pay_loan(100.0); return res)

func _set_check(A, id: String, c: Callable) -> void:
	if A.has_method("set_check"):
		A.set_check(id, c)

func _set_handler(A, id: String, c: Callable) -> void:
	if A.has_method("set_handler"):
		A.set_handler(id, c)

func _office_hours_check() -> String:
	var here := current_building()
	for id in active_courses():
		var c := course(id)
		if here == "" or here == c.building:
			if int(office_hours_day.get(c.subject, -1)) == _today():
				return "You already went to office hours today."
			return ""
	return "Go to the building of one of your courses."

func _use_office_hours() -> void:
	var here := current_building()
	for id in active_courses():
		var c := course(id)
		if here == "" or here == c.building:
			office_hours_day[c.subject] = _today()
			return

func _cert_buildings() -> Array:
	var out := []
	for k in CATALOG.CERTIFICATES:
		out.append(CATALOG.CERTIFICATES[k].building)
	out.append("LM13_MED_TOWER_D")
	return out

func _reward_skill(subject: String, correct: int) -> void:
	var life := _node("Life")
	if life == null or not ("skills" in life) or life.skills == null:
		return
	var mult := 1.0
	if "needs" in life and life.needs and life.needs.has_method("performance_multiplier"):
		mult = float(life.needs.performance_multiplier())
	var skill: String = CATALOG.SUBJECTS[subject].skill
	life.skills.add_xp(skill, int(round(correct * 2 * mult)))
	if skill != "knowledge":
		life.skills.add_xp("knowledge", int(round(correct * mult)))

func _sync_flags() -> void:
	var life := _node("Life")
	if life == null or not life.has_method("set_flag"):
		return
	life.set_flag("edu.enrolled", not active_courses().is_empty())
	life.set_flag("edu.student", not active_courses().is_empty())
	life.set_flag("edu.major", major)
	life.set_flag("edu.minor", minor)
	life.set_flag("edu.gpa", snappedf(gpa(), 0.01))
	life.set_flag("edu.courses_passed", passed_courses().size())
	life.set_flag("edu.credentials", credentials.duplicate())
	life.set_flag("edu.loan_balance", snappedf(loan_balance, 0.01))
	for c in credentials:
		life.set_flag("edu." + c, true)

# =========================================================================
# UI entry points
# =========================================================================

func open_homework() -> Node:
	return _show(HOMEWORK_SCENE, {"mode": "homework"})

func open_cert_exams() -> Node:
	return _show(HOMEWORK_SCENE, {"mode": "cert"})

func open_registrar(tab: String = "") -> Node:
	return _show(REGISTRAR_SCENE, {"tab": tab})

func _show(path: String, opts: Dictionary) -> Node:
	var scene: PackedScene = load(path)
	var ui := _node("UI")
	var node: Node = null
	if ui and ui.has_method("show_minigame"):
		node = ui.show_minigame(scene)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 50
		layer.name = "EducationLayer"
		get_tree().root.add_child(layer)
		node = scene.instantiate()
		layer.add_child(node)
	if node and node.has_method("setup"):
		node.setup(opts)
	return node

## Called by the screens when they are done.
func close_screen(node: Node) -> void:
	var ui := _node("UI")
	if ui and ui.has_method("close_panel"):
		ui.close_panel(node if node is Control else null)
	elif is_instance_valid(node):
		var parent := node.get_parent()
		node.queue_free()
		if parent and parent.name == "EducationLayer":
			parent.queue_free()

# =========================================================================
# Save / load (GameState.register_saveable and Life.register_save_provider)
# =========================================================================

func save_data() -> Dictionary:
	return {
		"version": 1, "records": records.duplicate(true), "major": major, "minor": minor,
		"credentials": credentials.duplicate(), "used_courses": used_courses.duplicate(), "hints": hints,
		"cert_attempts": cert_attempts.duplicate(), "loan_balance": loan_balance, "loan_missed": loan_missed,
		"days_since_payment": days_since_payment, "office_hours_day": office_hours_day.duplicate(),
	}

func load_data(d: Dictionary) -> void:
	records = (d.get("records", {}) as Dictionary).duplicate(true)
	for id in records:   # JSON turns ints into floats; normalize
		var r: Dictionary = records[id]
		r.attempts = (r.get("attempts", []) as Array).map(func(v): return int(v))
		r.homework = (r.get("homework", []) as Array).map(func(v): return float(v))
	major = d.get("major", "")
	minor = d.get("minor", "")
	credentials = (d.get("credentials", []) as Array).duplicate()
	used_courses = (d.get("used_courses", []) as Array).duplicate()
	hints = int(d.get("hints", 0))
	cert_attempts = {}
	for k in d.get("cert_attempts", {}):
		cert_attempts[k] = int(d.cert_attempts[k])
	loan_balance = float(d.get("loan_balance", 0.0))
	loan_missed = int(d.get("loan_missed", 0))
	days_since_payment = int(d.get("days_since_payment", 0))
	office_hours_day = (d.get("office_hours_day", {}) as Dictionary).duplicate()
	_sync_flags()
	changed.emit()

func to_save() -> Dictionary:
	return save_data()

func from_save(d: Dictionary) -> void:
	load_data(d)

func reset() -> void:
	load_data({})

# =========================================================================
# Bridges to other systems (every assumption about them lives here)
# =========================================================================

func _node(n: String) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null(n)

## The building id the player is in, or "" when unknown.
func current_building() -> String:
	var life := _node("Life")
	if life and "place" in life and life.place is Dictionary:
		var pid := str((life.place as Dictionary).get("id", ""))
		if pid != "":
			return pid
	var city := _node("CityData")
	var gs := _node("GameState")
	if city and gs and city.has_method("room_at") and gs.has_method("get_player"):
		var p = gs.get_player()
		if p is Node3D:
			var room = city.room_at((p as Node3D).global_position)
			if room is Dictionary and not (room as Dictionary).is_empty():
				return str(room.get("buildingId", ""))
	return ""

func _at_any(ids: Array) -> bool:
	if free_mode:
		return true
	var here := current_building()
	return here == "" or here in ids    # unknown location never blocks

func _at_campus() -> bool:
	var here := current_building()
	if free_mode or here == "":
		return true
	return here.begins_with("ONSU_") or here.begins_with("LM") or here == CATALOG.TUTORING_BUILDING

func _place_names(ids: Array) -> String:
	var city := _node("CityData")
	var names := []
	for id in ids:
		var n: String = id
		if city and city.has_method("building"):
			var b = city.building(id)
			if b is Dictionary and b.get("name"):
				n = b.name
		names.append(n)
	return " or ".join(names)

func _today() -> int:
	var clock := _node("GameClock")
	if clock and "day" in clock:
		return int(clock.day)
	var life := _node("Life")
	if life and "clock" in life and life.clock and life.clock.has_method("day"):
		return int(life.clock.day())
	return 0

func cash() -> float:
	var life := _node("Life")
	if life and "money" in life and life.money:
		return float(life.money.cash)
	return _fallback_cash

func _can_afford(amount: float) -> bool:
	var life := _node("Life")
	if life and "money" in life and life.money and life.money.has_method("can_afford"):
		return life.money.can_afford(amount)
	return _fallback_cash >= amount

func _spend(amount: float, reason: String) -> bool:
	var life := _node("Life")
	if life and "money" in life and life.money and life.money.has_method("spend"):
		return life.money.spend(amount, reason)
	if _fallback_cash < amount:
		return false
	_fallback_cash -= amount
	return true

func _earn(amount: float, reason: String) -> void:
	var life := _node("Life")
	if life and "money" in life and life.money and life.money.has_method("add"):
		life.money.add(amount, reason)
	else:
		_fallback_cash += amount

func _notify(text: String) -> void:
	var ui := _node("UI")
	if ui and ui.has_method("notify"):
		ui.notify(text)
	else:
		print("[Education] ", text)
