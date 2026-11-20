extends RefCounted
## Basic needs, 0 to 100 where 100 is satisfied. Decay every game minute.

signal need_changed(id: String, value: float)
signal need_critical(id: String)

var enabled: bool = true
var values: Dictionary = {}
var defs: Dictionary = {}
var critical_below: float = 10.0
## Needs that do not decay right now (while an action restores them).
var held: Dictionary = {}

var _critical_sent: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	defs = data.get("needs", {})
	if defs.is_empty():
		for id in ["hunger", "energy", "hygiene", "fun", "social", "bladder"]:
			defs[id] = {"label": id.capitalize(), "start": 75, "decay_per_hour": 3.0, "weight": 1.0}
	critical_below = float(data.get("critical_below", 10))
	for id in defs:
		values[id] = float(defs[id].get("start", 75))


func ids() -> Array:
	return defs.keys()


func label(id: String) -> String:
	return str(defs.get(id, {}).get("label", id.capitalize()))


func has_need(id: String) -> bool:
	return values.has(id)


func get_value(id: String) -> float:
	return float(values.get(id, 100.0))


func set_value(id: String, v: float) -> void:
	if not values.has(id):
		return
	v = clampf(v, 0.0, 100.0)
	if is_equal_approx(v, values[id]):
		return
	values[id] = v
	need_changed.emit(id, v)
	if v < critical_below:
		if not _critical_sent.get(id, false):
			_critical_sent[id] = true
			need_critical.emit(id)
	elif v > critical_below + 5.0:
		_critical_sent[id] = false


func change(id: String, delta: float) -> void:
	# "comfort" (furniture effects) restores energy at half weight.
	if id == "comfort":
		id = "energy"
		delta *= 0.5
	if not values.has(id):
		return
	set_value(id, values[id] + delta)


func apply(deltas: Dictionary, scale: float = 1.0) -> Dictionary:
	var applied := {}
	for id in deltas:
		var before := get_value(id if id != "comfort" else "energy")
		change(id, float(deltas[id]) * scale)
		var key: String = id if id != "comfort" else "energy"
		applied[key] = get_value(key) - before
	return applied


func tick_minute() -> void:
	if not enabled:
		return
	for id in defs:
		if held.has(id):
			continue
		var rate := float(defs[id].get("decay_per_hour", 3.0)) / 60.0
		set_value(id, values[id] - rate)


func hold(ids_to_hold: Array) -> void:
	for id in ids_to_hold:
		held[id] = true


func release_all() -> void:
	held.clear()


## Weighted average of all needs, 0 to 100.
func mood() -> float:
	if not enabled:
		return 75.0
	var total := 0.0
	var w := 0.0
	for id in defs:
		var weight := float(defs[id].get("weight", 1.0))
		total += values[id] * weight
		w += weight
	return total / w if w > 0.0 else 75.0


func mood_label() -> String:
	var m := mood()
	if m >= 80.0:
		return "Great"
	if m >= 60.0:
		return "Good"
	if m >= 40.0:
		return "Okay"
	if m >= 20.0:
		return "Low"
	return "Miserable"


## Scale for mini-game scores or pay: 0.6 (miserable) to 1.1 (great).
## Always 1.0 when needs are disabled.
func performance_multiplier() -> float:
	if not enabled:
		return 1.0
	return lerpf(0.6, 1.1, clampf(mood() / 100.0, 0.0, 1.0))


func lowest() -> String:
	var best := ""
	var v := 1000.0
	for id in values:
		if values[id] < v:
			v = values[id]
			best = id
	return best


func to_save() -> Dictionary:
	return {"values": values.duplicate(), "enabled": enabled}


func from_save(d: Dictionary) -> void:
	enabled = bool(d.get("enabled", true))
	var vs: Dictionary = d.get("values", {})
	for id in vs:
		if values.has(id):
			values[id] = float(vs[id])
