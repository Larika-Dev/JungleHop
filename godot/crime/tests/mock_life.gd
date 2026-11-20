## A stand-in for the `Life` autoload with only the calls Law uses (from godot/life/INTERFACES.md).
## Tests only; the real game uses res://life/life.gd.
extends Node


class Clock extends RefCounted:
	signal minute_passed(total: int)
	var total_minutes := 8 * 60.0   # Day 1, 08:00

	func advance_minutes(n: int) -> void:
		for i in n:
			total_minutes += 1.0
			minute_passed.emit(int(total_minutes))


class Money extends RefCounted:
	var cash := 100.0
	var ledger: Array = []

	func add(amount: float, reason: String) -> void:
		cash += amount
		ledger.append({"delta": amount, "reason": reason})

	func spend(amount: float, reason: String) -> bool:
		if amount > cash:
			return false
		cash -= amount
		ledger.append({"delta": -amount, "reason": reason})
		return true


class Rels extends RefCounted:
	var data := {}

	func _rec(id: String) -> Dictionary:
		if not data.has(id):
			data[id] = {"friendship": 0.0, "romance": 0.0, "flags": [], "memories": [], "traits": {"lawful": 0.5, "wild": 0.3}}
		return data[id]

	func get_rel(id: String) -> Dictionary:
		return _rec(id)

	func change(id: String, f: float, r: float, _reason: String) -> void:
		var d := _rec(id)
		d.friendship = clampf(float(d.friendship) + f, -100.0, 100.0)
		d.romance = clampf(float(d.romance) + r, 0.0, 100.0)

	func remember(id: String, ev: String, w: float) -> void:
		_rec(id).memories.append([ev, w])

	func add_flag(id: String, f: String) -> void:
		if not _rec(id).flags.has(f):
			_rec(id).flags.append(f)

	func has_flag(id: String, f: String) -> bool:
		return _rec(id).flags.has(f)


class Skills extends RefCounted:
	var levels := {}
	var xp := {}

	func level(id: String) -> int:
		return int(levels.get(id, 0))

	func add_xp(id: String, n: float) -> void:
		xp[id] = float(xp.get(id, 0.0)) + n


class Actions extends RefCounted:
	signal action_started(id, target)
	signal action_finished(id, target, result)
	var defs := {}
	var checks := {}
	var handlers := {}

	func register(def: Dictionary) -> void:
		defs[def.id] = def

	func set_check(id: String, c: Callable) -> void:
		checks[id] = c

	func set_handler(id: String, c: Callable) -> void:
		handlers[id] = c

	func perform(id: String, target) -> Dictionary:
		if not defs.has(id):
			return {"ok": false, "reason": "unknown"}
		if checks.has(id):
			var why: String = checks[id].call(defs[id], target)
			if why != "":
				return {"ok": false, "reason": why}
		action_started.emit(id, target)
		var result := {"ok": true, "success": true, "message": ""}
		if handlers.has(id):
			result = handlers[id].call(defs[id], target, result)
		action_finished.emit(id, target, result)
		return result


var clock := Clock.new()
var money := Money.new()
var relationships := Rels.new()
var skills := Skills.new()
var actions := Actions.new()
var flags := {}
var save_providers := {}


func set_flag(k: String, v) -> void:
	flags[k] = v


func get_flag(k: String, default = null):
	return flags.get(k, default)


func register_save_provider(key: String, obj: Object) -> void:
	save_providers[key] = obj
