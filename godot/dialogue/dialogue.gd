extends Node
## Dialogue autoload: 30 personalities and their lines.
##   [autoload] Dialogue="*res://dialogue/dialogue.gd"
## See res://dialogue/README.md for the full API.

signal line_spoken(npc_id: String, context: String, text: String, line_id: String)
signal personality_assigned(npc_id: String, personality_id: String)
## Fired whenever a conversation's state changes (start, after a choice, when a
## yes/no answer arrives from Life, at the end). state: see start_conversation().
signal conversation_updated(npc_id: String, state: Dictionary)
signal conversation_ended(npc_id: String)

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
var _convo_def := {}        # data/conversation.json
var _convos := {}           # npc_id -> {npc, extra, options, awaiting}


func _ready() -> void:
	_rng.randomize()
	var cf := FileAccess.open(DATA_DIR + "conversation.json", FileAccess.READ)
	if cf:
		var cd = JSON.parse_string(cf.get_as_text())
		if cd is Dictionary:
			_convo_def = cd
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
	if target == null or not (target is String or (target is Object and "npc_id" in target)):
		return
	var ok := true
	if result is Dictionary:
		ok = bool(result.get("success", result.get("ok", true)))
	var npc_id := _npc_id(target)
	if _convos.has(npc_id):
		# Inside a conversation the conversation speaks; only resolve a pending yes/no.
		var c: Dictionary = _convos[npc_id]
		if not c.awaiting.is_empty() and c.awaiting.get("action", "") == action_id:
			_answer_question(npc_id, c.awaiting, ok)
		return
	if action_contexts.has(action_id):
		say(target, action_contexts[action_id][0 if ok else 1])


# ---------------------------------------------------------------- conversations
# Talking is choice based: every turn the player picks one of 4 to 6 options
# (yes/no prompts have exactly 2) and the NPC answers in its personality's voice.
#
# state = {
#   "npc_id", "npc_line", "line_id", "context",
#   "npc_followup": "",          # e.g. the NPC asking a favor after its answer
#   "options": [{"id", "label", "kind"}],   # empty when ended or pending
#   "pending": false,            # waiting on Life for a yes/no answer
#   "ended": false,
# }

## Opens a conversation: the NPC greets the player and the first options are offered.
## extra: same keys as get_line_info, plus "has_gift" / "anniversary" (unlock options)
## and "npc_adult" (default true; NPC nodes with an `age` property are checked too).
func start_conversation(npc, extra: Dictionary = {}) -> Dictionary:
	var npc_id := _npc_id(npc)
	_convos[npc_id] = {"npc": npc, "extra": extra.duplicate(), "options": [], "awaiting": {}}
	var stage: String = extra.get("stage", _stage(npc_id))
	var ctx := "hostile" if stage in _convo_def.get("opening", {}).get("hostile_stages", []) else greeting_context(npc)
	var info := _speak(npc, ctx, extra)
	return _emit_state(npc_id, info, _offer_options(npc_id), false)

## Player picks option_id (one of the ids in the last state's options).
func choose(npc, option_id: String) -> Dictionary:
	var npc_id := _npc_id(npc)
	if not _convos.has(npc_id):
		return {}
	var c: Dictionary = _convos[npc_id]
	var opt := {}
	for o in c.options:
		if o.id == option_id:
			opt = o
			break
	if opt.is_empty():
		push_warning("Dialogue: option %s not offered" % option_id)
		return {}
	var kind: String = opt.get("kind", "talk")
	if kind == "question":
		return _ask_question(npc_id, opt)
	_run_life_action(c.npc, opt.get("action", ""))
	var info := _speak(c.npc, opt.reply, c.extra)
	if kind == "end" or opt.id == "favor_no":
		return _finish(npc_id, info)
	# Now and then the NPC asks the player a favor: a yes/no prompt, 2 options.
	var stage: String = c.extra.get("stage", _stage(npc_id))
	var fav: Dictionary = _convo_def.get("favor", {})
	if not fav.is_empty() and not opt.id.begins_with("favor") and not (stage in ["enemy", "dislike"]) \
			and _rng.randf() < float(_convo_def.get("npc_asks_favor_chance", 0.0)):
		var ask := get_line_info(c.npc, fav.ask_context, c.extra)
		if not ask.is_empty():
			var fav_opts: Array = []
			for o in fav.options:
				fav_opts.append(_option_view(o))
			c.options = fav.options
			return _emit_state(npc_id, info, fav_opts, false, ask.text)
	return _emit_state(npc_id, info, _offer_options(npc_id), false)

func end_conversation(npc) -> void:
	var npc_id := _npc_id(npc)
	if _convos.erase(npc_id):
		conversation_ended.emit(npc_id)

func in_conversation(npc) -> bool:
	return _convos.has(_npc_id(npc))

## Opens the built-in conversation panel (res://dialogue/ui/conversation_panel.gd).
func open_conversation(npc, extra: Dictionary = {}) -> Control:
	var panel: Control = load("res://dialogue/ui/conversation_panel.gd").new()
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("open_panel"):
		ui.open_panel(panel)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 50
		get_tree().root.add_child(layer)
		layer.add_child(panel)
		panel.tree_exited.connect(layer.queue_free)
	panel.begin(npc, extra)
	return panel

## Every option that fits the current relationship and time (for tools and tests).
func available_options(npc, extra: Dictionary = {}) -> Array:
	var st := _conv_state(npc, extra)
	var out: Array = []
	for o in _convo_def.get("options", []):
		if _option_ok(o, st, extra, npc):
			out.append(o)
	return out

func _conv_state(npc, extra: Dictionary) -> Dictionary:
	var npc_id := _npc_id(npc)
	return {
		"stage": extra.get("stage", _stage(npc_id)),
		"romance": extra.get("romance", _romance(npc_id, extra)),
		"time": extra.get("time", time_of_day(extra.get("hour", _hour()))),
	}

func _option_ok(o: Dictionary, st: Dictionary, extra: Dictionary, npc) -> bool:
	var w: Dictionary = o.get("when", {})
	if w.has("romance") and not (st.romance in w.romance):
		return false
	if w.has("not_romance") and st.romance in w.not_romance:
		return false
	if w.has("stage") and not (st.stage in w.stage):
		return false
	if w.has("time") and not (st.time in w.time):
		return false
	if w.has("flag_extra") and not extra.get(w.flag_extra, false):
		return false
	if w.get("adult", false):
		if not extra.get("npc_adult", true):
			return false
		if npc is Object and "age" in npc and int(npc.age) < 18:
			return false
	return true

func _offer_options(npc_id: String) -> Array:
	var c: Dictionary = _convos[npc_id]
	var all := available_options(c.npc, c.extra)
	var ends: Array = all.filter(func(o): return o.get("kind", "talk") == "end")
	var special: Array = all.filter(func(o): return o.get("kind", "talk") != "end" and o.get("when", {}).has("romance"))
	var general: Array = all.filter(func(o): return o.get("kind", "talk") != "end" and not o.get("when", {}).has("romance"))
	_shuffle(special)
	_shuffle(general)
	var max_n := int(_convo_def.get("max_options", 6))
	var min_n := int(_convo_def.get("min_options", 4))
	var picked: Array = []
	for o in special + general:
		if picked.size() >= max_n - 1:
			break
		picked.append(o)
	if not ends.is_empty():
		picked.append(ends[_rng.randi() % ends.size()])
	# Never fewer than min_options: borrow any remaining option.
	for o in all:
		if picked.size() >= min_n:
			break
		if not (o in picked):
			picked.append(o)
	c.options = picked
	var views: Array = []
	for o in picked:
		views.append(_option_view(o))
	return views

func _option_view(o: Dictionary) -> Dictionary:
	var labels: Array = o.get("labels", [o.id])
	return {"id": o.id, "label": labels[_rng.randi() % labels.size()], "kind": o.get("kind", "talk")}

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _ask_question(npc_id: String, opt: Dictionary) -> Dictionary:
	var c: Dictionary = _convos[npc_id]
	var action: String = opt.get("action", "")
	var life := _life()
	if action != "" and _life_action_available(c.npc, action):
		var res = life.actions.perform(action, c.npc)
		if res is Dictionary and res.get("ok", false):
			c.awaiting = opt
			c.options = []
			return _emit_state(npc_id, {"text": "...", "id": "", "context": ""}, [], true)
	# No Life action: decide from romance (or extra.accept / extra.romance_value).
	var accept: bool
	if c.extra.has("accept"):
		accept = bool(c.extra.accept)
	elif life == null:
		accept = _rng.randf() < 0.5
	else:
		accept = _romance_value(npc_id, c.extra) >= float(opt.get("accept_min_romance", 20))
	return _answer_question(npc_id, opt, accept)

func _answer_question(npc_id: String, opt: Dictionary, accepted: bool) -> Dictionary:
	var c: Dictionary = _convos[npc_id]
	c.awaiting = {}
	var ctx: String = opt.reply if accepted else opt.get("reply_no", "hostile")
	var info := _speak(c.npc, ctx, c.extra)
	if not accepted:
		return _finish(npc_id, info)
	# Accepted: the relationship moved on (Life sets the flags), offer the new options.
	c.extra.erase("romance")
	return _emit_state(npc_id, info, _offer_options(npc_id), false)

func _finish(npc_id: String, info: Dictionary) -> Dictionary:
	var state := _emit_state(npc_id, info, [], false)
	state.ended = true
	conversation_updated.emit(npc_id, state)
	_convos.erase(npc_id)
	conversation_ended.emit(npc_id)
	return state

func _emit_state(npc_id: String, info: Dictionary, options: Array, pending: bool, followup: String = "") -> Dictionary:
	var state := {
		"npc_id": npc_id, "npc_line": info.get("text", ""), "line_id": info.get("id", ""),
		"context": info.get("context", ""), "npc_followup": followup,
		"options": options, "pending": pending, "ended": false,
	}
	if options.size() > 0 or pending:
		conversation_updated.emit(npc_id, state)
	return state

func _speak(npc, ctx: String, extra: Dictionary) -> Dictionary:
	var info := get_line_info(npc, ctx, extra)
	if not info.is_empty():
		line_spoken.emit(_npc_id(npc), info.context, info.text, info.id)
	return info

func _run_life_action(npc, action: String) -> void:
	if action != "" and _life_action_available(npc, action):
		_life().actions.perform(action, npc)

func _life_action_available(npc, action: String) -> bool:
	var life := _life()
	if life == null or not ("actions" in life) or life.actions == null or not life.actions.has_method("available_for"):
		return false
	if life.actions.has_method("busy") and life.actions.busy():
		return false
	for entry in life.actions.available_for(npc):
		var d = entry.get("def", {})
		if d is Dictionary and d.get("id", "") == action:
			return bool(entry.get("ok", false))
	return false

func _romance_value(npc_id: String, extra: Dictionary) -> float:
	if extra.has("romance_value"):
		return float(extra.romance_value)
	var life := _life()
	if life and life.relationships and life.relationships.has_method("get_rel"):
		var r = life.relationships.get_rel(npc_id)
		if r is Dictionary:
			return float(r.get("romance", 0))
	return 0.0

# Life save provider
func to_save() -> Dictionary:
	return {"overrides": _overrides.duplicate()}

func from_save(d: Dictionary) -> void:
	_overrides = d.get("overrides", {}).duplicate()
	_assigned.clear()
	for k in _overrides:
		_assigned[k] = _overrides[k]
