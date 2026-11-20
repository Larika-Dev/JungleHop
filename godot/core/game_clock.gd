extends Node
## Global game clock. 1 in-game hour = 60 real seconds (1 game minute per real second).
## Autoload name: GameClock. See docs/INTERFACES.md.

signal minute_passed(total_minutes: int)
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)
signal time_set(total_minutes: float)

const REAL_SECONDS_PER_GAME_HOUR := 60.0
const GAME_MINUTES_PER_REAL_SECOND := 60.0 / REAL_SECONDS_PER_GAME_HOUR
const START_HOUR := 8
const WEEKDAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

## Minutes since Day 1 00:00.
var total_minutes: float = START_HOUR * 60.0
## Multiplier on top of the base rate (1.0 = 1 game hour per real minute).
var speed: float = 1.0
## When true the clock does not advance (menus, title screen).
var paused: bool = true

var day: int:
	get: return int(total_minutes / 1440.0) + 1
var hour: int:
	get: return int(fmod(total_minutes, 1440.0) / 60.0)
var minute: int:
	get: return int(fmod(total_minutes, 60.0))
## 0 = Monday. Day 1 is a Monday.
var weekday: int:
	get: return (day - 1) % 7
## Fractional hour of day, 0.0 to 24.0 (for lighting).
var hour_f: float:
	get: return fmod(total_minutes, 1440.0) / 60.0

var _last_minute: int = int(total_minutes)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if paused:
		return
	_step(delta * GAME_MINUTES_PER_REAL_SECOND * speed)


## Skip time forward (sleeping, a work shift, a class). Emits every intervening signal in order.
func advance_minutes(m: float) -> void:
	if m <= 0.0:
		return
	_step(m)


func _step(m: float) -> void:
	total_minutes += m
	var now := int(total_minutes)
	while _last_minute < now:
		_last_minute += 1
		minute_passed.emit(_last_minute)
		if _last_minute % 60 == 0:
			var d := _last_minute / 1440 + 1
			var h := (_last_minute % 1440) / 60
			hour_passed.emit(d, h)
			if h == 0:
				day_passed.emit(d)


func set_time(p_day: int, p_hour: int, p_minute: int = 0) -> void:
	total_minutes = (p_day - 1) * 1440.0 + p_hour * 60.0 + p_minute
	_last_minute = int(total_minutes)
	time_set.emit(total_minutes)


func time_string() -> String:
	return "%02d:%02d" % [hour, minute]


func date_string() -> String:
	return "Day %d, %s" % [day, WEEKDAY_NAMES[weekday]]


## True when the current hour is in [h_start, h_end). Handles ranges past midnight (22, 6).
func is_between(h_start: float, h_end: float) -> bool:
	var h := hour_f
	if h_start <= h_end:
		return h >= h_start and h < h_end
	return h >= h_start or h < h_end


func save_data() -> Dictionary:
	return {"total_minutes": total_minutes, "speed": speed}


func load_data(d: Dictionary) -> void:
	total_minutes = float(d.get("total_minutes", START_HOUR * 60.0))
	speed = float(d.get("speed", 1.0))
	_last_minute = int(total_minutes)
	time_set.emit(total_minutes)
