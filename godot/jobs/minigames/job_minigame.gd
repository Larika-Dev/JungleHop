class_name JobMinigame
extends Control
## Base for every job mini-game. A shift is a loop of rounds (one order, one
## patient, one delivery...). Each finished round reports a 0..1 score to
## JobSystem, which turns it into the performance review. Pay is by the hour
## and comes from JobSystem, not from here.
##
## Subclasses override _setup(), _new_round() and simulate_round(perfect).

signal round_done(score: float)

var jobs: Node = null
var job_id := ""
var difficulty := 0.0
var rng := RandomNumberGenerator.new()
var scores: Array[float] = []
var round_index := 0
var round_time := 0.0
var _begun := false
var _feedback_left := 0.0
var _waiting_next := false

var header: PanelContainer
var title_label: Label
var stats_label: Label
var feedback_label: Label
var body: Control
var clock_out_button: Button

const C_BG := Color(0.09, 0.1, 0.12, 0.96)
const C_TEXT := Color(0.93, 0.93, 0.9)
const C_GOOD := Color(0.45, 0.85, 0.5)
const C_BAD := Color(0.95, 0.42, 0.35)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	if not _begun:
		call_deferred("_auto_begin")


func _auto_begin() -> void:
	if not _begun:
		begin(null, job_id, difficulty, 1795)


## Called by JobSystem right after the scene is shown.
func begin(job_system: Node, p_job_id: String, p_difficulty: float, seed: int) -> void:
	jobs = job_system
	job_id = p_job_id
	difficulty = clampf(p_difficulty, 0.0, 1.0)
	rng.seed = seed
	_begun = true
	if title_label:
		title_label.text = _title_text()
	_setup()
	_start_round()


func _title_text() -> String:
	if jobs and job_id != "" and jobs.has_method("get_job"):
		var j: Dictionary = jobs.get_job(job_id)
		return "%s  ·  %s" % [jobs.title_of(job_id), j.get("place", "")]
	return name


func _build_frame() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	header = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", sb)
	v.add_child(header)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	header.add_child(h)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", C_TEXT)
	h.add_child(title_label)
	stats_label = Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.8))
	h.add_child(stats_label)
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 18)
	h.add_child(feedback_label)
	clock_out_button = Button.new()
	clock_out_button.text = "Clock out (Esc)"
	clock_out_button.focus_mode = Control.FOCUS_NONE
	clock_out_button.pressed.connect(clock_out)
	h.add_child(clock_out_button)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(body)
	_build_body(body)


## Subclass hook: build the play area inside `parent`.
func _build_body(_parent: Control) -> void:
	pass


func _setup() -> void:
	pass


func _new_round() -> void:
	pass


## Headless test hook: play one round automatically. perfect=true plays it
## correctly, false plays it badly. Returns the round score.
func simulate_round(_perfect: bool) -> float:
	return 0.0


func _start_round() -> void:
	round_index += 1
	round_time = 0.0
	_waiting_next = false
	_new_round()


## Subclasses call this when a round is over.
func finish_round(score: float, note := "") -> void:
	if _waiting_next:
		return
	score = clampf(score, 0.0, 1.0)
	scores.append(score)
	round_done.emit(score)
	if jobs and jobs.has_method("report_round"):
		jobs.report_round(score)
	if feedback_label:
		var word := "Perfect!" if score >= 0.95 else "Good" if score >= 0.75 else "OK" if score >= 0.5 else "Poor"
		feedback_label.text = "%s %d%%%s" % [word, roundi(score * 100), ("  " + note) if note != "" else ""]
		feedback_label.add_theme_color_override("font_color", C_GOOD if score >= 0.6 else C_BAD)
	_feedback_left = 1.6
	_waiting_next = true
	if is_inside_tree():
		var idx := round_index
		get_tree().create_timer(0.9).timeout.connect(func():
			if round_index == idx and _waiting_next and is_inside_tree():
				_start_round())


## Time factor: 1.0 within par seconds, falling to 0.6 at 3x par.
func time_factor(par: float) -> float:
	if round_time <= par:
		return 1.0
	return clampf(1.0 - 0.4 * (round_time - par) / (2.0 * par), 0.6, 1.0)


func clock_out() -> void:
	if jobs and jobs.has_method("end_shift") and jobs.active_job != "":
		jobs.end_shift()
	else:
		queue_free()


func _process(delta: float) -> void:
	if not _waiting_next:
		round_time += delta
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0 and feedback_label:
			feedback_label.text = ""
	if stats_label and Engine.get_process_frames() % 10 == 0:
		stats_label.text = _stats_text()
	_mg_process(delta)


func _mg_process(_delta: float) -> void:
	pass


func _stats_text() -> String:
	if jobs and jobs.has_method("shift_status"):
		var s: Dictionary = jobs.shift_status()
		if not s.is_empty():
			return "$%.2f/hr   on shift %d:%02d   earned $%.2f%s   review %d%%   ends in %d:%02d" % [
				s.wage, int(s.minutes) / 60, int(s.minutes) % 60, s.earned,
				("  tips $%.2f" % s.tips) if s.tips > 0 else "", roundi(s.performance * 100),
				maxi(0, int(s.ends_in)) / 60, maxi(0, int(s.ends_in)) % 60]
	var avg := 0.0
	for s in scores:
		avg += s
	return "round %d   avg %d%%" % [round_index, roundi(100 * avg / maxf(1, scores.size()))]


## UI autoload calls this on Esc / ui_cancel.
func on_back() -> void:
	clock_out()


func _unhandled_input(event: InputEvent) -> void:
	if get_node_or_null("/root/UI") != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		clock_out()


func pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]
