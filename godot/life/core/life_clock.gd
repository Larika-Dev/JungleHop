extends Node
## Game time for the life core. Mirrors the foundation's GameClock autoload when
## it exists; otherwise runs its own clock at 1 real second = 1 game minute
## (1 game hour = 1 real minute). Day 1 is a Monday; a new game starts 08:00.

signal minute_passed(total_minutes: int)
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)

const EXTERNAL_NAMES := ["GameClock", "Clock", "TimeManager"]

var total_minutes: float = 8.0 * 60.0
var speed: float = 1.0
var running: bool = true
var external: Node = null

var _last_whole: int = 0
var _search_timer: float = 0.0


func _ready() -> void:
	_find_external()
	if external:
		total_minutes = _read_external()
	_last_whole = int(floor(total_minutes))


func _find_external() -> void:
	for n in EXTERNAL_NAMES:
		var node := get_node_or_null("/root/" + n)
		if node and node != self and node != get_parent():
			external = node
			return


func _process(delta: float) -> void:
	if external == null:
		# Autoload order is not guaranteed: keep looking for GameClock briefly.
		_search_timer += delta
		if _search_timer >= 1.0:
			_search_timer = 0.0
			_find_external()
			if external:
				total_minutes = _read_external()
				_last_whole = int(floor(total_minutes))
				return
	if external == null:
		if running:
			total_minutes += delta * speed
	else:
		total_minutes = _read_external()
	_emit_up_to(total_minutes)


func _read_external() -> float:
	if "total_minutes" in external:
		return float(external.total_minutes)
	if external.has_method("get_total_minutes"):
		return float(external.get_total_minutes())
	if "day" in external and "hour" in external:
		var m: float = float(external.minute) if "minute" in external else 0.0
		return (float(external.day) - 1.0) * 1440.0 + float(external.hour) * 60.0 + m
	return total_minutes


func _emit_up_to(t: float) -> void:
	var whole := int(floor(t))
	if whole < _last_whole:
		# Clock went backwards (a load or set_time): resync without replaying.
		_last_whole = whole
		return
	while _last_whole < whole:
		_last_whole += 1
		minute_passed.emit(_last_whole)
		if _last_whole % 60 == 0:
			var d := _last_whole / 1440 + 1
			hour_passed.emit(d, (_last_whole % 1440) / 60)
			if _last_whole % 1440 == 0:
				day_passed.emit(d)


## Skip time. Every skipped minute still fires minute_passed and hour_passed,
## so pay, needs and bills stay correct.
func advance_minutes(m: float) -> void:
	if m <= 0.0:
		return
	if external:
		if external.has_method("advance_minutes"):
			external.advance_minutes(m)
		elif external.has_method("skip_minutes"):
			external.skip_minutes(m)
		total_minutes = max(_read_external(), total_minutes)
		# If the external clock could not skip, keep our own view moving.
		if total_minutes < float(_last_whole) + m - 0.5:
			total_minutes = float(_last_whole) + m
	else:
		total_minutes += m
	_emit_up_to(total_minutes)


func set_time(day: int, hour: int, minute: int = 0) -> void:
	if external and external.has_method("set_time"):
		external.set_time(day, hour, minute)
	total_minutes = float((day - 1) * 1440 + hour * 60 + minute)
	_last_whole = int(floor(total_minutes))


func day() -> int:
	return int(total_minutes) / 1440 + 1


func minute_of_day() -> int:
	return int(total_minutes) % 1440


func hour() -> int:
	return minute_of_day() / 60


func minute() -> int:
	return minute_of_day() % 60


func hour_f() -> float:
	return fmod(total_minutes, 1440.0) / 60.0


## 0 = Monday.
func weekday() -> int:
	return (day() - 1) % 7


func weekday_name() -> String:
	return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][weekday()]


## True when the current hour is inside [h0, h1), wrapping past midnight
## (for example [22, 2]). Hours above 24 are accepted (26 = 2 AM).
func is_between(h0: float, h1: float) -> bool:
	var h := hour_f()
	h0 = fmod(h0, 24.0)
	h1 = fmod(h1, 24.0)
	if is_equal_approx(h0, h1):
		return true
	if h0 < h1:
		return h >= h0 and h < h1
	return h >= h0 or h < h1


func time_string() -> String:
	var h := hour()
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s Day %d, %d:%02d %s" % [weekday_name(), day(), h12, minute(), ampm]


func to_save() -> Dictionary:
	return {"total_minutes": total_minutes}


func from_save(d: Dictionary) -> void:
	if external == null and d.has("total_minutes"):
		total_minutes = float(d.total_minutes)
	_last_whole = int(floor(total_minutes))
