extends Node
## Dialogue autoload: 30 personalities and their lines.
##   [autoload] Dialogue="*res://dialogue/dialogue.gd"
## See res://dialogue/README.md for the full API.

signal line_spoken(npc_id: String, context: String, text: String, line_id: String)
signal personality_assigned(npc_id: String, personality_id: String)

const DATA_DIR := "res://dialogue/data/"
const FRIEND_TIERS := ["enemy", "dislike", "stranger", "acquaintance", "friend", "close_friend", "best_friend"]
const ROMANCE_TIERS := ["none", "crush", "dating", "partner", "engaged", "married"]
const RECENT_MEMORY := 12

## Context to try when a personality has no line for the asked one.
var fallbacks := {
	"home_greet": "date_greet", "date_greet": "greet", "goodbye_work": "farewell", "date_end": "farewell",
	"bedtime": "farewell", "affection": "flirt", "flirt": "flirt_reply", "compliment": "compliment_reply",
	"home_talk": "date_talk", "date_talk": "smalltalk", "tease": "joke", "work_return": "work_talk",
	"meal": "home_talk", "plans": "home_talk", "memories": "home_talk", "support": "home_talk",
	"chores": "home_talk", "money": "home_talk", "argue": "lovers_quarrel", "lovers_quarrel": "hostile",
	"makeup": "affection", "anniversary": "affection", "miss_you": "affection", "jealous": "lovers_quarrel",
	"kiss_reply": "flirt", "proposal_yes": "ask_out_yes",
}

## Life action id -> dialogue context. When Life.actions finishes one of these on an NPC,
## the NPC speaks a line (signal line_spoken; also a UI toast when show_toasts is true).
## [success_context, fail_context]. Other threads may add entries at runtime.
var action_contexts := {
	"chat": ["smalltalk", "hostile"], "talk": ["smalltalk", "hostile"], "greet": ["greet", "hostile"],
	"introduce": ["greet", "hostile"], "deep_talk": ["about_self", "hostile"],
	"compliment": ["compliment_reply", "hostile"], "insult": ["insult_reply", "insult_reply"],
	"give_gift": ["gift_reply", "hostile"], "gift": ["gift_reply", "hostile"], "joke": ["joke", "hostile"],
	"tell_joke": ["joke", "hostile"], "help": ["favor_reply", "favor_reply"], "flirt": ["flirt_reply", "flirt_reply"],
	"ask_on_date": ["ask_out_yes", "ask_out_no"], "ask_out": ["ask_out_yes", "ask_out_no"],
	"go_on_date": ["date_talk", "lovers_quarrel"], "date": ["date_talk", "lovers_quarrel"],
	"kiss": ["kiss_reply", "ask_out_no"], "hug": ["affection", "hostile"], "propose": ["proposal_yes", "lovers_quarrel"],
	"argue": ["argue", "argue"], "apologize": ["makeup", "hostile"], "cuddle": ["affection", "affection"],
}
var show_toasts := true

var _personalities: Array = []
var _by_id := {}
var _lines := {}            # personality id -> Array of line dicts (lazy)
var _assigned := {}         # npc_id -> personality id (cache of deterministic picks)
var _overrides := {}        # npc_id -> personality id set explicitly (saved)
var _names := {}            # npc_id -> display name
var _recent := {}           # npc_id -> Array of recent line ids
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open(DATA_DIR + "personalities.json", FileAccess.READ)
	if f == null:
		push_error("Dialogue: missing personalities.json")
		return
	var d = JSON.parse_string(f.get_as_text())
	_personalities = d.get("personalities", []) if d is Dictionary else []
	for p in _personalities:
		_by_id[p.id] = p
	var life := _life()
	if life:
		if life.has_method("register_save_provider"):
			life.register_save_provider("dialogue", self)
		if "actions" in life and life.actions and life.actions.has_signal("action_finished"):
			life.actions.action_finished.connect(_on_action_finished)


# ---------------------------------------------------------------- personalities

func personality_ids() -> Array:
	return _by_id.keys()

func personality(pid: String) -> Dictionary:
	return _by_id.get(pid, {})

## Deterministic pick for an NPC: the same npc_id always gets the same personality.
## With traits ({outgoing, kind, ambitious, wild, lawful}, 0..1) it favours personalities
## whose trait profile is close; without traits it uses the population weights.
func assign_personality(npc_id: String, traits: Dictionary = {}) -> String:
	if _overrides.has(npc_id):
		return _overrides[npc_id]
	if _assigned.has(npc_id):
		return _assigned[npc_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dialogue:" + npc_id)
	var weights: Array[float] = []
	var total := 0.0
	for p in _personalities:
		var w: float = float(p.get("weight", 1.0))
		if not traits.is_empty():
			var d2 := 0.0
			for k in p.traits:
				if traits.has(k):
					d2 += pow(float(traits[k]) - float(p.traits[k]), 2)
			w *= exp(-d2 / 0.12)
		weights.append(w)
		total += w
	var r := rng.randf() * total
	var pid: String = _personalities[-1].id
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			pid = _personalities[i].id
			break
	_assigned[npc_id] = pid
	personality_assigned.emit(npc_id, pid)
	return pid

## Force a personality (e.g. from the NPC generator tool). Saved with the game.
func set_personality(npc_id: String, pid: String) -> void:
	if not _by_id.has(pid):
		push_warning("Dialogue: unknown personality %s" % pid)
		return
	_overrides[npc_id] = pid
	_assigned[npc_id] = pid
	personality_assigned.emit(npc_id, pid)

func get_personality_id(npc_id: String) -> String:
	return _overrides.get(npc_id, _assigned.get(npc_id, assign_personality(npc_id)))

## Info to pass to Life.relationships.register_npc (traits and interests of the personality).
func npc_info(npc_id: String) -> Dictionary:
	var p := personality(get_personality_id(npc_id))
	return {"personality": p.get("id", ""), "traits": p.get("traits", {}).duplicate(), "interests": p.get("interests", []).duplicate()}

func set_npc_name(npc_id: String, display_name: String) -> void:
	_names[npc_id] = display_name


# ---------------------------------------------------------------- lines

## The greeting context that fits the relationship: home_greet (married),
## date_greet (dating/partner/engaged) or greet.
func greeting_context(npc) -> String:
	var r := _romance(_npc_id(npc), {})
	if r == "married":
		return "home_greet"
	if r in ["dating", "partner", "engaged"]:
		return "date_greet"
	return "greet"

## Returns {id, text, context, personality} or {} when nothing fits.
## npc: NPC node (with npc_id) or an npc_id string.
## extra may override: stage, romance, time, hour, weekend, place (Array of tags),
## player (name), npc (name), personality.
func get_line_info(npc, context: String, extra: Dictionary = {}) -> Dictionary:
	var npc_id := _npc_id(npc)
	if npc is Node and "display_name" in npc and not _names.has(npc_id):
		_names[npc_id] = str(npc.display_name)
	var pid: String = extra.get("personality", get_personality_id(npc_id))
	var state := {
		"stage": extra.get("stage", _stage(npc_id)),
		"romance": extra.get("romance", _romance(npc_id, extra)),
		"time": extra.get("time", time_of_day(extra.get("hour", _hour()))),
		"weekend": extra.get("weekend", _weekend()),
		"place": extra.get("place", _place_tags()),
	}
	var ctx := context
	var tried := {}
	while ctx != "" and not tried.has(ctx):
		tried[ctx] = true
		var line := _pick(pid, npc_id, ctx, state)
		if not line.is_empty():
			return {"id": line.id, "context": ctx, "personality": pid, "text": _fill(line.text, npc_id, state, extra)}
		ctx = fallbacks.get(ctx, "")
	return {}

func get_line(npc, context: String, extra: Dictionary = {}) -> String:
	return get_line_info(npc, context, extra).get("text", "")

## get_line + emits line_spoken (+ toast). Use this when the NPC actually talks.
func say(npc, context: String, extra: Dictionary = {}) -> String:
	var info := get_line_info(npc, context, extra)
	if info.is_empty():
		return ""
	var npc_id := _npc_id(npc)
	line_spoken.emit(npc_id, info.context, info.text, info.id)
	if show_toasts:
		var ui := get_node_or_null("/root/UI")
		if ui and ui.has_method("notify"):
			ui.notify("%s: \"%s\"" % [_names.get(npc_id, "Someone"), info.text])
	return info.text

## All lines of a personality, optionally one tier (base, dating, marriage).
func lines_for(pid: String, tier: String = "") -> Array:
	var all := _load_lines(pid)
	return all if tier == "" else all.filter(func(l): return l.tier == tier)

func contexts_for(pid: String) -> Array:
	var seen := {}
	for l in _load_lines(pid):
		seen[l.context] = true
	return seen.keys()

static func time_of_day(hour: int) -> String:
	if hour >= 5 and hour < 12:
		return "morning"
	if hour >= 12 and hour < 17:
		return "afternoon"
	if hour >= 17 and hour < 22:
		return "evening"
	return "night"


# ---------------------------------------------------------------- internals

func _load_lines(pid: String) -> Array:
	if _lines.has(pid):
		return _lines[pid]
	var arr: Array = []
	var f := FileAccess.open(DATA_DIR + "lines/%s.json" % pid, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			arr = d.get("lines", [])
	_lines[pid] = arr
	return arr

func _matches(cond: Dictionary, state: Dictionary) -> bool:
	if cond.has("stage") and not (state.stage in cond.stage):
		return false
	if cond.has("romance") and not (state.romance in cond.romance):
		return false
	if cond.has("time") and not (state.time in cond.time):
		return false
	if cond.has("weekend") and bool(cond.weekend) != bool(state.weekend):
		return false
	if cond.has("place"):
		var ok := false
		for t in cond.place:
			if t in state.place:
				ok = true
				break
		if not ok:
			return false
	return true

func _pick(pid: String, npc_id: String, ctx: String, state: Dictionary) -> Dictionary:
	var recent: Array = _recent.get(npc_id, [])
	var fresh: Array = []
	var stale: Array = []
	for l in _load_lines(pid):
		if l.context != ctx or not _matches(l.cond, state):
			continue
		(stale if l.id in recent else fresh).append(l)
	var pool := fresh if not fresh.is_empty() else stale
	if pool.is_empty():
		return {}
	# More specific lines (more conditions) are more likely, so a morning greeting
	# shows up in the morning instead of drowning among generic ones.
	var total := 0.0
	for l in pool:
		total += 1.0 + 2.0 * l.cond.size()
	var r := _rng.randf() * total
	var chosen: Dictionary = pool[-1]
	for l in pool:
		r -= 1.0 + 2.0 * l.cond.size()
		if r <= 0.0:
			chosen = l
			break
	recent.append(chosen.id)
	if recent.size() > RECENT_MEMORY:
		recent.pop_front()
	_recent[npc_id] = recent
	return chosen

func _fill(text: String, npc_id: String, state: Dictionary, extra: Dictionary) -> String:
	var player_name := str(extra.get("player", ""))
	if player_name == "":
		var gs := get_node_or_null("/root/GameState")
		if gs and "player_profile" in gs:
			player_name = str(gs.player_profile.get("name", ""))
	if player_name == "":
		player_name = "friend"
	var place_name := str(extra.get("place_name", ""))
	if place_name == "":
		var life := _life()
		if life and "place" in life and life.place is Dictionary:
			place_name = str(life.place.get("name", life.place.get("type", "")))
	if place_name == "":
		place_name = "this place"
	var days := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	return text.format({
		"player": player_name,
		"npc": str(extra.get("npc", _names.get(npc_id, "me"))),
		"place": place_name,
		"weekday": days[_weekday() % 7],
		"timeofday": state.time,
	})

func _life() -> Node:
	return get_node_or_null("/root/Life")

func _npc_id(npc) -> String:
	if npc is String:
		return npc
	if npc is Object and "npc_id" in npc:
		return str(npc.npc_id)
	return str(npc)

func _stage(npc_id: String) -> String:
	var life := _life()
	if life and life.relationships and life.relationships.has_method("tier"):
		var t := str(life.relationships.tier(npc_id))
		if t in FRIEND_TIERS:
			return t
	return "stranger"

func _romance(npc_id: String, extra: Dictionary) -> String:
	if extra.has("romance"):
		return extra.romance
	var life := _life()
	if life and life.relationships and life.relationships.has_method("romance_tier"):
		var t := str(life.relationships.romance_tier(npc_id))
		if t in ROMANCE_TIERS:
			return t
	return "none"

func _hour() -> int:
	var life := _life()
	if life and life.clock and life.clock.has_method("hour"):
		return int(life.clock.hour())
	var gc := get_node_or_null("/root/GameClock")
	return int(gc.hour) if gc else 12

func _weekday() -> int:
	var life := _life()
	if life and life.clock and life.clock.has_method("weekday"):
		return int(life.clock.weekday())
	var gc := get_node_or_null("/root/GameClock")
	return int(gc.weekday) if gc else 0

func _weekend() -> bool:
	return _weekday() >= 5

func _place_tags() -> Array:
	var life := _life()
	if life and "place" in life and life.place is Dictionary and not life.place.is_empty():
		var tags: Array = life.place.get("tags", []).duplicate()
		for k in ["category", "type", "id"]:
			if life.place.has(k):
				tags.append(str(life.place[k]))
		return tags
	return []

func _on_action_finished(action_id: String, target, result) -> void:
	if not action_contexts.has(action_id) or target == null:
		return
	if not (target is String or (target is Object and "npc_id" in target)):
		return
	var ok := true
	if result is Dictionary:
		ok = bool(result.get("success", result.get("ok", true)))
	say(target, action_contexts[action_id][0 if ok else 1])

# Life save provider
func to_save() -> Dictionary:
	return {"overrides": _overrides.duplicate()}

func from_save(d: Dictionary) -> void:
	_overrides = d.get("overrides", {}).duplicate()
	_assigned.clear()
	for k in _overrides:
		_assigned[k] = _overrides[k]
