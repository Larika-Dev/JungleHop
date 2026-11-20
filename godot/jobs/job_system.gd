extends Node
## JobSystem autoload: hiring, shifts, hourly pay, performance, promotions.
##
## Register in project.godot:  JobSystem="*res://jobs/job_system.gd"
##
## Soft dependencies (all optional, looked up at runtime so this runs alone):
##   GameClock  (foundation)  time and minute/hour signals
##   Life       (life core)   wallet, hourly pay sessions, needs, skills, actions, flags
##   Education  (education)   has_credential(id), has_tag(tag), credential_earned(id)
##   UI         (foundation)  show_minigame(packed), close_panel(), notify(text)
##   GameState  (foundation)  register_saveable(id, node)
## See godot/jobs/README.md for the full contract.

signal hired(job_id: String, rank: int)
signal quit_job(job_id: String)
signal fired(job_id: String, reason: String)
signal promoted(job_id: String, rank: int, title: String)
signal shift_started(job_id: String)
signal shift_ended(job_id: String, summary: Dictionary)
signal paid(job_id: String, amount: float)
signal round_scored(job_id: String, score: float)
signal strike_added(job_id: String, strikes: int)
signal notice(text: String)

const DATA_PATH := "res://jobs/data/jobs.json"
const MINIGAME_DIR := "res://jobs/scenes/"
const CLOCK_IN_EARLY_MIN := 30
const LATE_GRACE_MIN := 10
const MISSED_AFTER_MIN := 120
const STRIKE_WINDOW_DAYS := 14
const RAISE_COOLDOWN_DAYS := 7
const RAISE_STEP := 0.05
const RAISE_CAP := 0.20
const PERF_EMA := 0.25

var jobs: Dictionary = {}          # id -> definition
var job_order: Array = []
var max_concurrent_jobs := 2
var strikes_to_fire := 3

## Employment records: id -> {rank, shift, hours_total, hours_rank, perf, shifts_worked,
## strikes:[day...], raise, last_raise_day, hired_day, last_checked_shift_key}
var employment: Dictionary = {}
var history: Array = []            # past jobs {job_id, title, left_day, reason}

## Active shift (one at a time).
var active_job := ""
var _shift := {}                   # {start_min, scores:[], late_min, earned, tips, session_id, minigame}

## Fallback wallet / clock when Life / GameClock are absent.
var fallback_cash := 0.0
var _own_minutes := 8.0 * 60.0
var _last_minute_seen := -1
var _clock_source: Object = null
var _test_mode := false
## Tests: ignore every other autoload.
var isolated := false

## Optional extra hiring checks: Callable(job_id: String) -> String ("" = ok, else reason).
var _hiring_checks: Array[Callable] = []


func _ready() -> void:
	load_definitions(DATA_PATH)
	call_deferred("_connect_services")


func load_definitions(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JobSystem: cannot read %s" % path)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	max_concurrent_jobs = int(d.get("max_concurrent_jobs", 2))
	strikes_to_fire = int(d.get("strikes_to_fire", 3))
	jobs.clear()
	job_order.clear()
	for j in d.get("jobs", []):
		jobs[j.id] = j
		job_order.append(j.id)


# ---------------------------------------------------------------- services

func _svc(name: String) -> Node:
	if isolated:
		return null
	var root := get_tree().root if is_inside_tree() else null
	if root == null:
		return null
	return root.get_node_or_null(name)


func _life() -> Node:
	return _svc("Life")


func _connect_services() -> void:
	var gc := _svc("GameClock")
	var gs := _svc("GameState")
	var life := _life()
	if gc and gc.has_signal("minute_passed"):
		_clock_source = gc
	elif life and life.get("clock") != null and life.clock.has_signal("minute_passed"):
		_clock_source = life.clock
	if _clock_source:
		_clock_source.minute_passed.connect(_on_minute)
	var law := _svc("Law")
	if law and law.has_signal("convicted"):
		law.convicted.connect(_on_convicted)
	if gs and gs.has_signal("world_ready"):
		gs.world_ready.connect(func(w): load("res://jobs/world/job_sites.gd").spawn_all(self, w))
	var edu := _svc("Education")
	if edu and edu.has_signal("credential_earned"):
		edu.credential_earned.connect(_on_credential_earned)
	if gs and gs.has_method("register_saveable"):
		gs.register_saveable("jobs", self)
	elif life and life.has_method("register_save_provider"):
		life.register_save_provider("jobs", self)
	if life and life.get("money") != null and life.money.has_signal("pay_credited"):
		life.money.pay_credited.connect(_on_pay_credited)
	_register_life_actions()


func _process(delta: float) -> void:
	if _clock_source != null or _test_mode:
		return
	_own_minutes += delta  # 1 real second = 1 game minute
	var m := int(_own_minutes)
	if m != _last_minute_seen:
		_last_minute_seen = m
		_on_minute(m)


## Total game minutes since Day 1 00:00 (Day 1 is a Monday).
func now_minutes() -> float:
	if _clock_source != null:
		return float(_clock_source.total_minutes)
	return _own_minutes


func day_index() -> int:
	return int(now_minutes() / 1440.0)


func weekday() -> int:
	return day_index() % 7


func hour_f() -> float:
	return fmod(now_minutes(), 1440.0) / 60.0


## Test helper: drive the internal clock forward, firing every minute.
func debug_advance(minutes: int) -> void:
	for i in minutes:
		_own_minutes += 1.0
		_on_minute(int(_own_minutes))


# ---------------------------------------------------------------- queries

func get_job(job_id: String) -> Dictionary:
	return jobs.get(job_id, {})


func is_employed(job_id: String) -> bool:
	return employment.has(job_id)


func rank_of(job_id: String) -> int:
	return int(employment[job_id].rank) if employment.has(job_id) else -1


func title_of(job_id: String) -> String:
	if not employment.has(job_id):
		return ""
	return jobs[job_id].ranks[rank_of(job_id)].title


## Hourly wage for the player's current rank, including personal raises.
func wage_of(job_id: String) -> float:
	if not employment.has(job_id):
		return 0.0
	var e: Dictionary = employment[job_id]
	return snappedf(float(jobs[job_id].ranks[e.rank].wage) * (1.0 + float(e.raise)), 0.01)


func jobs_at_building(building_id: String) -> Array:
	var out := []
	for id in job_order:
		if jobs[id].building == building_id:
			out.append(id)
	return out


func employer_buildings() -> Array:
	var out := []
	for id in job_order:
		if not out.has(jobs[id].building):
			out.append(jobs[id].building)
	return out


## Shift window as absolute minutes for the given day index, or {} if not a work day.
func shift_window(job_id: String, day: int, shift_idx: int = -1) -> Dictionary:
	var j: Dictionary = jobs[job_id]
	if shift_idx < 0:
		shift_idx = int(employment[job_id].shift) if employment.has(job_id) else 0
	var s: Dictionary = j.shifts[clampi(shift_idx, 0, j.shifts.size() - 1)]
	if not s.days.has(float(day % 7)) and not s.days.has(day % 7):
		return {}
	return {"start": day * 1440 + int(s.start * 60), "end": day * 1440 + int(s.end * 60), "name": s.name}


## The shift the player could clock into right now (today's, or last night's overnight one).
func current_window(job_id: String) -> Dictionary:
	var now := now_minutes()
	for d in [day_index(), day_index() - 1]:
		var w := shift_window(job_id, d)
		if w.is_empty():
			continue
		if now >= w.start - CLOCK_IN_EARLY_MIN and now < w.end - 30:
			return w
	return {}


func next_shift_text(job_id: String) -> String:
	for i in 8:
		var w := shift_window(job_id, day_index() + i)
		if not w.is_empty() and w.end > now_minutes():
			var days := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
			var sh := int(w.start) % 1440
			var eh := int(w.end) % 1440
			return "%s %02d:%02d-%02d:%02d" % [days[(day_index() + i) % 7], sh / 60, sh % 60, eh / 60, eh % 60]
	return "none"


# ---------------------------------------------------------------- requirements

func has_credential(id: String) -> bool:
	var edu := _svc("Education")
	if edu and edu.has_method("has_credential"):
		return edu.has_credential(id)
	var life := _life()
	if life and life.has_method("get_flag"):
		return bool(life.get_flag("edu." + id, false))
	return false


func has_edu_tag(tag: String) -> bool:
	var edu := _svc("Education")
	if edu and edu.has_method("has_tag"):
		return edu.has_tag(tag)
	return false


func skill_level(id: String) -> int:
	var life := _life()
	if life and life.get("skills") != null:
		return int(life.skills.level(id))
	return 0


## Returns "" when the rank's requirements are met, else a readable reason.
func rank_requirement_gap(job_id: String, rank: int, check_hours := true) -> String:
	var r: Dictionary = jobs[job_id].ranks[rank]
	var missing := []
	if r.has("education_any"):
		var ok := false
		for c in r.education_any:
			if has_credential(c):
				ok = true
		if not ok:
			missing.append("needs " + " or ".join(PackedStringArray(r.education_any.map(_cred_name))))
	if r.has("education_tags"):
		for t in r.education_tags:
			if not has_edu_tag(t):
				missing.append("needs a " + String(t).replace("degree:", "") + "'s degree")
	if r.has("skills"):
		for s in r.skills:
			if skill_level(s) < int(r.skills[s]):
				missing.append("needs %s level %d" % [s, int(r.skills[s])])
	if check_hours and employment.has(job_id):
		var e: Dictionary = employment[job_id]
		if float(e.hours_rank) < float(r.min_hours):
			missing.append("%.0f more hours at this rank" % (float(r.min_hours) - float(e.hours_rank)))
		if float(e.perf) < float(r.min_performance):
			missing.append("performance %d%% (needs %d%%)" % [roundi(e.perf * 100), roundi(r.min_performance * 100)])
	return "; ".join(PackedStringArray(missing))


func _cred_name(id) -> String:
	return String(id).replace("_", " ")


func register_hiring_check(check: Callable) -> void:
	_hiring_checks.append(check)


## Highest rank whose education/skill requirements the applicant meets (hours are not needed to be hired).
func entry_rank_for(job_id: String) -> int:
	var best := -1
	var ranks: Array = jobs[job_id].ranks
	for i in ranks.size():
		# Experience-gated ranks (min_hours > 0) are only reachable by promotion,
		# except a rank that only needs credentials, which a qualified hire can start at.
		var r: Dictionary = ranks[i]
		var needs_exp := float(r.min_hours) > 0 and not (r.has("education_any") or r.has("education_tags"))
		if i > 0 and needs_exp:
			break
		if rank_requirement_gap(job_id, i, false) == "":
			best = i
		elif i == 0:
			return -1
	return best


func can_apply(job_id: String) -> String:
	if not jobs.has(job_id):
		return "No such job"
	if employment.has(job_id):
		return "You already work here"
	if employment.size() >= max_concurrent_jobs:
		return "You can hold at most %d jobs" % max_concurrent_jobs
	var j: Dictionary = jobs[job_id]
	var bg := background_check(job_id)
	if bg != "":
		return bg
	if entry_rank_for(job_id) < 0:
		return rank_requirement_gap(job_id, 0, false)
	for c in _hiring_checks:
		var why: String = c.call(job_id)
		if why != "":
			return why
	return ""


## Background check tier per job: "none", "basic", "standard", "trusted" (see crime/INTERFACES.md).
func check_tier(job_id: String) -> String:
	return String(jobs[job_id].get("check", "basic"))


func background_check(job_id: String) -> String:
	var law := _svc("Law")
	if law and law.has_method("job_check"):
		var r: Dictionary = law.job_check(check_tier(job_id))
		if not r.get("ok", true):
			return "Background check: " + String(r.get("reason", "failed"))
	return ""


func _on_convicted(_entry) -> void:
	for job_id in employment.keys():
		if check_tier(job_id) == "trusted" and background_check(job_id) != "":
			fire(job_id, "criminal conviction")


# ---------------------------------------------------------------- hiring

func apply(job_id: String, shift_idx := 0) -> Dictionary:
	var why := can_apply(job_id)
	if why != "":
		return {"ok": false, "reason": why}
	var rank := entry_rank_for(job_id)
	employment[job_id] = {
		"rank": rank, "shift": clampi(shift_idx, 0, jobs[job_id].shifts.size() - 1),
		"hours_total": 0.0, "hours_rank": 0.0, "perf": 0.6, "shifts_worked": 0,
		"strikes": [], "raise": 0.0, "last_raise_day": -999, "hired_day": day_index(),
		"checked": {},
	}
	_set_flags()
	var title: String = jobs[job_id].ranks[rank].title
	_say("Hired at %s as %s ($%.2f/hr). Next shift: %s" % [jobs[job_id].place, title, wage_of(job_id), next_shift_text(job_id)])
	hired.emit(job_id, rank)
	return {"ok": true, "rank": rank, "title": title}


func quit(job_id: String) -> bool:
	if not employment.has(job_id):
		return false
	if active_job == job_id:
		end_shift()
	_leave(job_id, "quit")
	_say("You quit your job at %s." % jobs[job_id].place)
	quit_job.emit(job_id)
	return true


func fire(job_id: String, reason: String) -> void:
	if not employment.has(job_id):
		return
	if active_job == job_id:
		end_shift()
	_leave(job_id, reason)
	_say("Fired from %s: %s" % [jobs[job_id].place, reason])
	fired.emit(job_id, reason)


func _leave(job_id: String, reason: String) -> void:
	history.append({"job_id": job_id, "title": title_of(job_id), "left_day": day_index(), "reason": reason})
	employment.erase(job_id)
	_set_flags()


func change_shift(job_id: String, shift_idx: int) -> bool:
	if not employment.has(job_id) or active_job == job_id:
		return false
	employment[job_id].shift = clampi(shift_idx, 0, jobs[job_id].shifts.size() - 1)
	return true


# ---------------------------------------------------------------- shifts

func can_start_shift(job_id: String) -> String:
	if not employment.has(job_id):
		return "You don't work here"
	if active_job != "":
		return "Already on shift"
	if current_window(job_id).is_empty():
		return "Not your shift. Next: " + next_shift_text(job_id)
	var life := _life()
	if life and life.get("needs") != null and life.needs.get_value("energy") < 5:
		return "Too exhausted to work"
	return ""


## Clocks in, starts paid time and opens the job's mini-game. Returns {ok, reason, minigame}.
func start_shift(job_id: String, open_minigame := true) -> Dictionary:
	var why := can_start_shift(job_id)
	if why != "":
		return {"ok": false, "reason": why}
	var w := current_window(job_id)
	var now := now_minutes()
	active_job = job_id
	_shift = {
		"start_min": now, "window": w, "scores": [], "late_min": maxf(0.0, now - w.start - LATE_GRACE_MIN),
		"earned": 0.0, "tips": 0.0, "session_id": "job:%s@%s" % [job_id, jobs[job_id].building],
		"minigame": null, "last_hour_min": now, "fallback_accrued": 0.0,
	}
	employment[job_id].checked[str(w.start)] = true
	var life := _life()
	if life and life.get("money") != null and life.money.has_method("start_paid_session"):
		life.money.start_paid_session(_shift.session_id, wage_of(job_id), {
			"reason": "%s shift (%s)" % [title_of(job_id), jobs[job_id].place],
			"max_minutes": int(w.end - now) + 1,
		})
	if life and life.has_method("set_flag"):
		life.set_flag("job.on_shift", true)
		life.set_flag("job.on_shift_id", job_id)
	if _shift.late_min > 0:
		_say("You're %d minutes late. Your manager noticed." % int(_shift.late_min))
	if open_minigame:
		_shift.minigame = _open_minigame(job_id)
	shift_started.emit(job_id)
	return {"ok": true, "minigame": _shift.minigame}


func _open_minigame(job_id: String) -> Node:
	var path: String = MINIGAME_DIR + String(jobs[job_id].minigame) + ".tscn"
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("JobSystem: missing mini-game " + path)
		return null
	var ui := _svc("UI")
	var mg: Node
	if ui and ui.has_method("show_minigame"):
		mg = ui.show_minigame(packed)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 50
		layer.name = "JobMinigameLayer"
		get_tree().root.add_child(layer)
		mg = packed.instantiate()
		layer.add_child(mg)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mg and mg.has_method("begin"):
		mg.begin(self, job_id, difficulty_for(job_id), randi())
	return mg


## 0..1, rises with rank so higher ranks get harder rounds.
func difficulty_for(job_id: String) -> float:
	var n: int = jobs[job_id].ranks.size()
	return clampf(float(rank_of(job_id)) / maxf(1.0, n - 1.0), 0.0, 1.0) if employment.has(job_id) else 0.0


## Mini-games report each finished task here (score 0..1).
func report_round(score: float) -> void:
	if active_job == "":
		return
	var mult := 1.0
	var life := _life()
	if life and life.get("needs") != null and life.needs.has_method("performance_multiplier"):
		mult = clampf(life.needs.performance_multiplier(), 0.6, 1.1)
	var s := clampf(score * mult, 0.0, 1.0)
	_shift.scores.append(s)
	var tip_rate := float(jobs[active_job].get("tips", 0.0))
	if tip_rate > 0.0 and s > 0.4:
		var tip := snappedf(tip_rate * (0.5 + s) * (1.0 + 0.25 * rank_of(active_job)), 0.01)
		_shift.tips += tip
		_credit(tip, "Tips (%s)" % jobs[active_job].place)
	if life and life.get("skills") != null:
		var sk: String = _job_skill(active_job)
		if sk != "":
			life.skills.add_xp(sk, 2.0 * s)
	round_scored.emit(active_job, s)


func _job_skill(job_id: String) -> String:
	return String(jobs[job_id].get("skill", {
		"barista": "cooking", "pizza_cook": "cooking", "bartender": "charm", "hardware_cashier": "logic",
		"bank_teller": "logic", "er_nurse": "knowledge", "lab_tech": "knowledge", "librarian": "knowledge",
		"tattoo_artist": "creativity", "barber": "creativity", "inn_front_desk": "charm",
		"university_grader": "logic", "delivery_rider": "fitness", "it_support": "mechanics",
		"custodian": "fitness", "cinema_usher": "charm", "bookstore_clerk": "writing",
	}.get(job_id, "")))


func shift_performance() -> float:
	if _shift.is_empty() or _shift.scores.is_empty():
		return 0.0
	var t := 0.0
	for s in _shift.scores:
		t += s
	return t / _shift.scores.size()


func shift_status() -> Dictionary:
	if active_job == "":
		return {}
	var mins := now_minutes() - float(_shift.start_min)
	return {
		"job_id": active_job, "title": title_of(active_job), "place": jobs[active_job].place,
		"wage": wage_of(active_job), "minutes": mins, "earned": _shift.earned, "tips": _shift.tips,
		"performance": shift_performance(), "rounds": _shift.scores.size(),
		"ends_in": float(_shift.window.end) - now_minutes(),
	}


## Clock out. Pays the partial hour, updates performance, checks promotions.
func end_shift() -> Dictionary:
	if active_job == "":
		return {}
	var job_id := active_job
	var e: Dictionary = employment[job_id]
	var minutes := now_minutes() - float(_shift.start_min)
	var life := _life()
	if life and life.get("money") != null and life.money.has_method("end_paid_session"):
		var total: float = life.money.end_paid_session(_shift.session_id)
		_shift.earned = maxf(_shift.earned, total)
	else:
		_fallback_pay_tick(true)
	var hours := minutes / 60.0
	var window_len := (float(_shift.window.end) - float(_shift.window.start)) / 60.0
	var perf := shift_performance()
	if _shift.scores.is_empty():
		perf = 0.3 if hours > 0.5 else e.perf
	# Lateness and leaving early pull the review down.
	var attendance := clampf(hours / maxf(1.0, window_len), 0.0, 1.0)
	perf = perf * (0.7 + 0.3 * attendance) - minf(0.2, float(_shift.late_min) / 300.0)
	perf = clampf(perf, 0.0, 1.0)
	if hours >= 0.5:
		e.perf = lerpf(float(e.perf), perf, PERF_EMA)
		e.shifts_worked = int(e.shifts_worked) + 1
	e.hours_total = float(e.hours_total) + hours
	e.hours_rank = float(e.hours_rank) + hours
	if life:
		if life.has_method("apply_need_delta"):
			life.apply_need_delta("energy", -4.0 * hours)
			life.apply_need_delta("fun", -1.5 * hours)
		if life.has_method("set_flag"):
			life.set_flag("job.on_shift", false)
			life.set_flag("job.on_shift_id", "")
	var summary := {
		"job_id": job_id, "hours": hours, "earned": _shift.earned, "tips": _shift.tips,
		"performance": perf, "rounds": _shift.scores.size(), "rating": e.perf,
	}
	var mg = _shift.minigame
	active_job = ""
	_shift = {}
	if is_instance_valid(mg):
		_close_minigame(mg)
	_say("Shift over: %.1f h, earned $%.2f%s. Review %d%%." % [hours, summary.earned,
		(" + $%.2f tips" % summary.tips) if summary.tips > 0 else "", roundi(perf * 100)])
	shift_ended.emit(job_id, summary)
	var next := promotion_gap(job_id)
	if employment.has(job_id) and next == "":
		_say("You're eligible for a promotion at %s. Ask your manager." % jobs[job_id].place)
	return summary


func _close_minigame(mg: Node) -> void:
	var ui := _svc("UI")
	if ui and ui.has_method("close_panel") and mg.get_parent() and mg.get_parent().name != "JobMinigameLayer":
		ui.close_panel(mg)
	else:
		var p := mg.get_parent()
		mg.queue_free()
		if p and p.name == "JobMinigameLayer":
			p.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pay_credited(session_id: String, amount: float) -> void:
	if not _shift.is_empty() and session_id == _shift.session_id:
		_shift.earned += amount
		paid.emit(active_job, amount)


## Without Life, pay accrues per minute and is credited each hour.
func _fallback_pay_tick(final := false) -> void:
	if _shift.is_empty():
		return
	var life := _life()
	if life and life.get("money") != null and life.money.has_method("start_paid_session"):
		return
	var now := now_minutes()
	var mins := now - float(_shift.last_hour_min)
	if mins >= 60.0 or (final and mins > 0.0):
		var amt := snappedf(wage_of(active_job) * mins / 60.0, 0.01)
		_shift.last_hour_min = now
		_shift.earned += amt
		_credit(amt, "%s shift" % title_of(active_job))
		paid.emit(active_job, amt)


func _credit(amount: float, reason: String) -> void:
	var life := _life()
	if life and life.has_method("add_money"):
		life.add_money(amount, reason)
	elif life and life.get("money") != null:
		life.money.add(amount, reason)
	else:
		fallback_cash += amount


# ---------------------------------------------------------------- clock hooks

func _on_minute(_total) -> void:
	if active_job != "":
		_fallback_pay_tick()
		if now_minutes() >= float(_shift.window.end):
			end_shift()
	if int(now_minutes()) % 10 == 0:
		_check_missed_shifts()


func _check_missed_shifts() -> void:
	var now := now_minutes()
	for job_id in employment.keys():
		var e: Dictionary = employment[job_id]
		for d in [day_index(), day_index() - 1]:
			var w := shift_window(job_id, d)
			if w.is_empty() or now < w.start + MISSED_AFTER_MIN:
				continue
			if d < int(e.hired_day) or (d == int(e.hired_day) and w.start < now - 1440):
				continue
			var key := str(w.start)
			if e.checked.has(key):
				continue
			if active_job == job_id:
				continue
			# A shift that began before the hire time cannot be missed.
			if float(w.start) < float(e.get("hired_min", -1.0)):
				e.checked[key] = true
				continue
			e.checked[key] = true
			_add_strike(job_id, "missed the %s shift" % w.name)


func _add_strike(job_id: String, why: String) -> void:
	var e: Dictionary = employment[job_id]
	var today := day_index()
	e.strikes = e.strikes.filter(func(d): return today - int(d) < STRIKE_WINDOW_DAYS)
	e.strikes.append(today)
	e.perf = maxf(0.0, float(e.perf) - 0.1)
	strike_added.emit(job_id, e.strikes.size())
	if e.strikes.size() >= strikes_to_fire:
		fire(job_id, "%d no-shows in %d days" % [e.strikes.size(), STRIKE_WINDOW_DAYS])
	else:
		_say("Warning from %s: you %s (strike %d of %d)." % [jobs[job_id].place, why, e.strikes.size(), strikes_to_fire])


func _on_credential_earned(_id: String) -> void:
	for job_id in employment:
		if promotion_gap(job_id) == "":
			_say("Your new credential qualifies you for a promotion at %s." % jobs[job_id].place)


# ---------------------------------------------------------------- promotions & raises

## "" when the next rank is reachable now; otherwise why not.
func promotion_gap(job_id: String) -> String:
	if not employment.has(job_id):
		return "Not employed"
	var r := rank_of(job_id)
	if r >= jobs[job_id].ranks.size() - 1:
		return "Already at the top rank"
	return rank_requirement_gap(job_id, r + 1)


func ask_promotion(job_id: String) -> Dictionary:
	var gap := promotion_gap(job_id)
	if gap != "":
		_say("Not yet: " + gap)
		return {"ok": false, "reason": gap}
	var e: Dictionary = employment[job_id]
	e.rank = int(e.rank) + 1
	e.hours_rank = 0.0
	e.raise = 0.0
	var title: String = jobs[job_id].ranks[e.rank].title
	_set_flags()
	_say("Promoted to %s! New wage $%.2f/hr." % [title, wage_of(job_id)])
	promoted.emit(job_id, e.rank, title)
	return {"ok": true, "rank": e.rank, "title": title}


func ask_raise(job_id: String) -> Dictionary:
	if not employment.has(job_id):
		return {"ok": false, "reason": "Not employed"}
	var e: Dictionary = employment[job_id]
	if day_index() - int(e.last_raise_day) < RAISE_COOLDOWN_DAYS:
		return {"ok": false, "reason": "You asked recently. Wait a week."}
	e.last_raise_day = day_index()
	if float(e.raise) >= RAISE_CAP:
		return {"ok": false, "reason": "You're at the top of the pay band. Go for a promotion."}
	if float(e.perf) < 0.75 or int(e.shifts_worked) < 3:
		_say("Your manager says to keep at it before asking again.")
		return {"ok": false, "reason": "Performance must be 75%+ over at least 3 shifts"}
	e.raise = minf(RAISE_CAP, float(e.raise) + RAISE_STEP)
	_say("Raise approved: now $%.2f/hr." % wage_of(job_id))
	return {"ok": true, "wage": wage_of(job_id)}


func _set_flags() -> void:
	var life := _life()
	if life == null or not life.has_method("set_flag"):
		return
	var ids := employment.keys()
	life.set_flag("job.employed", not ids.is_empty())
	life.set_flag("job.ids", ",".join(PackedStringArray(ids)))
	life.set_flag("job.primary", ids[0] if not ids.is_empty() else "")
	for id in job_order:
		life.set_flag("job." + id, employment.has(id))


func _say(text: String) -> void:
	notice.emit(text)
	var ui := _svc("UI")
	if ui and ui.has_method("notify"):
		ui.notify(text)
	elif not _test_mode:
		print("[Jobs] ", text)


# ---------------------------------------------------------------- Life actions

## Player-facing job actions in the shared action menu (category "work").
func _register_life_actions() -> void:
	var life := _life()
	if life == null or life.get("actions") == null:
		return
	var A = life.actions
	var defs := [
		{"id": "job_apply", "name": "Apply for a job here", "category": "work", "target": "place", "minutes": 20},
		{"id": "job_start_shift", "name": "Clock in", "category": "work", "target": "place", "minutes": 0},
		{"id": "job_end_shift", "name": "Clock out", "category": "work", "target": "self", "minutes": 0},
		{"id": "job_ask_promotion", "name": "Ask for a promotion", "category": "work", "target": "place", "minutes": 15},
		{"id": "job_ask_raise", "name": "Ask for a raise", "category": "work", "target": "place", "minutes": 15},
		{"id": "job_quit", "name": "Quit job", "category": "work", "target": "place", "minutes": 5},
		{"id": "job_check_schedule", "name": "Check work schedule", "category": "work", "target": "self", "minutes": 1},
		{"id": "job_browse_listings", "name": "Browse job listings", "category": "work", "target": "self", "minutes": 10},
		{"id": "job_chat_coworker", "name": "Chat with a coworker", "category": "work", "target": "npc", "minutes": 10,
			"needs": {"social": 8}, "rel": {"friendship": 3}, "sets_rel_flags": ["coworker"], "requires": {"flags": ["job.employed"]}},
		{"id": "job_take_break", "name": "Take a break", "category": "work", "target": "self", "minutes": 15,
			"needs": {"energy": 4, "fun": 3}, "requires": {"flags": ["job.on_shift"]}},
	]
	for d in defs:
		A.register(d)
	var here := func(target) -> Array:
		var b := _place_building(target)
		return jobs_at_building(b) if b != "" else []
	A.set_check("job_apply", func(_d, t):
		var ids: Array = here.call(t)
		if ids.is_empty(): return "No one is hiring here"
		for id in ids:
			if can_apply(id) == "": return ""
		return can_apply(ids[0]))
	A.set_handler("job_apply", func(_d, t, res):
		var ids: Array = here.call(t)
		for id in ids:
			if can_apply(id) == "":
				var r := apply(id)
				res.message = "Hired as %s." % r.title
				return res
		res.success = false
		return res)
	A.set_check("job_start_shift", func(_d, t):
		var ids: Array = here.call(t)
		for id in ids:
			if is_employed(id): return can_start_shift(id)
		return "You don't work here")
	A.set_handler("job_start_shift", func(_d, t, res):
		for id in here.call(t):
			if is_employed(id): start_shift(id)
		return res)
	A.set_check("job_end_shift", func(_d, _t): return "" if active_job != "" else "Not on shift")
	A.set_handler("job_end_shift", func(_d, _t, res): end_shift(); return res)
	for pair in [["job_ask_promotion", ask_promotion], ["job_ask_raise", ask_raise], ["job_quit", quit]]:
		var fn: Callable = pair[1]
		A.set_check(pair[0], func(_d, t):
			for id in here.call(t):
				if is_employed(id): return ""
			return "You don't work here")
		A.set_handler(pair[0], func(_d, t, res):
			for id in here.call(t):
				if is_employed(id):
					var out = fn.call(id)
					if out is Dictionary and not out.get("ok", true):
						res.message = String(out.get("reason", ""))
			return res)
	A.set_handler("job_check_schedule", func(_d, _t, res):
		var lines := []
		for id in employment:
			lines.append("%s at %s: next %s, $%.2f/hr" % [title_of(id), jobs[id].place, next_shift_text(id), wage_of(id)])
		res.message = "\n".join(PackedStringArray(lines)) if not lines.is_empty() else "You're unemployed."
		return res)
	A.set_handler("job_browse_listings", func(_d, _t, res):
		var ui := _svc("UI")
		if ui and ui.has_method("open_panel"):
			ui.open_panel(load("res://jobs/ui/job_board.gd").new())
		var lines := []
		for id in job_order:
			var why := can_apply(id)
			lines.append("%s - %s, $%.2f/hr%s" % [jobs[id].place, jobs[id].ranks[0].title, jobs[id].ranks[0].wage, "" if why == "" else " (" + why + ")"])
		res.message = "\n".join(PackedStringArray(lines))
		return res)


func _place_building(target) -> String:
	if target is Dictionary:
		return String(target.get("id", target.get("building_id", "")))
	if target is String:
		return target
	if target is Node:
		if target.get("building_id") != null:
			return String(target.building_id)
	var life := _life()
	if life and life.get("place") is Dictionary:
		return String(life.place.get("id", ""))
	return ""


# ---------------------------------------------------------------- save / load

func to_save() -> Dictionary:
	return {"employment": employment.duplicate(true), "history": history.duplicate(true), "cash": fallback_cash, "own_min": _own_minutes}


func from_save(d: Dictionary) -> void:
	if active_job != "":
		end_shift()
	employment = d.get("employment", {}).duplicate(true)
	for id in employment.keys():
		if not jobs.has(id):
			employment.erase(id)
			continue
		var e: Dictionary = employment[id]
		e.rank = int(e.rank)
		e.shift = int(e.shift)
		if not e.has("checked"):
			e.checked = {}
	history = d.get("history", []).duplicate(true)
	fallback_cash = float(d.get("cash", 0.0))
	_own_minutes = float(d.get("own_min", _own_minutes))
	_set_flags()


## GameState saveable interface.
func save_data() -> Dictionary:
	return to_save()


func load_data(d: Dictionary) -> void:
	from_save(d)
