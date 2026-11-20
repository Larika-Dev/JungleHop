extends RefCounted
## Data-driven action registry and runner. See INTERFACES.md for the schema.

signal action_registered(id: String)
signal action_started(id: String, target: Variant)
signal action_finished(id: String, target: Variant, result: Dictionary)
signal action_failed(id: String, target: Variant, reason: String)
signal action_cancelled(id: String, target: Variant)

const ACTIONS_DIR := "res://life/data/actions"

var life: Node
var defs: Dictionary = {}
var order: Array = []
var handlers: Dictionary = {}
var checks: Dictionary = {}
## "id|target_key" -> game minute when usable again
var cooldowns: Dictionary = {}
## The running timed action: {id, target, end_at, started_at}
var current: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init(owner_life: Node) -> void:
	life = owner_life
	rng.randomize()


# --- Registry -----------------------------------------------------------------

func register(def: Dictionary) -> bool:
	var id := str(def.get("id", ""))
	if id == "":
		push_warning("Life.actions.register: action without id")
		return false
	if not def.has("target"):
		def["target"] = "self"
	if not def.has("name"):
		def["name"] = id.capitalize()
	if not def.has("category"):
		def["category"] = "misc"
	if not defs.has(id):
		order.append(id)
	defs[id] = def
	action_registered.emit(id)
	return true


func register_many(list: Array) -> int:
	var n := 0
	for d in list:
		if d is Dictionary and register(d):
			n += 1
	return n


func unregister(id: String) -> void:
	defs.erase(id)
	order.erase(id)


func has_action(id: String) -> bool:
	return defs.has(id)


func get_def(id: String) -> Dictionary:
	return defs.get(id, {})


func count() -> int:
	return defs.size()


func categories() -> Array:
	var out: Array = []
	for id in order:
		var c: String = defs[id].category
		if c not in out:
			out.append(c)
	return out


func set_handler(id: String, fn: Callable) -> void:
	handlers[id] = fn


func set_check(id: String, fn: Callable) -> void:
	checks[id] = fn


func load_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Life: cannot open %s" % path)
		return 0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return register_many(parsed.get("actions", []))
	if parsed is Array:
		return register_many(parsed)
	push_warning("Life: bad action file %s" % path)
	return 0


func load_dir(dir_path: String = ACTIONS_DIR) -> int:
	var n := 0
	var files := DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		# Exported builds may list "x.json.remap"-style names; only plain .json is ours.
		if file.ends_with(".json"):
			n += load_file(dir_path.path_join(file))
	return n


# --- Targets ------------------------------------------------------------------

func target_kind(target: Variant) -> String:
	if target == null:
		return "self"
	if target is String:
		return "npc"
	if target is Dictionary:
		return "place"
	if target is Node:
		var node: Node = target
		if node.is_in_group("npc") or "npc_id" in node:
			return "npc"
		if node.is_in_group("furniture") or "furniture_kind" in node or node.has_method("get_actions"):
			return "furniture"
	return "self"


func npc_id(target: Variant) -> String:
	if target is String:
		return target
	if target is Node and "npc_id" in target:
		return str(target.npc_id)
	return ""


func target_key(target: Variant) -> String:
	match target_kind(target):
		"npc":
			return "npc:" + npc_id(target)
		"furniture":
			return "f:%d" % (target as Node).get_instance_id()
		"place":
			return "p:" + str(target.get("id", ""))
	return "self"


## The furniture's own action ids plus its kind, used to match defs.
func furniture_tags(target: Node) -> Array:
	var tags: Array = []
	if "furniture_kind" in target:
		tags.append(str(target.furniture_kind))
	if "furniture_tags" in target:
		for t in target.furniture_tags:
			tags.append(str(t))
	for a in native_furniture_actions(target):
		tags.append(str(a.get("id", "")))
	return tags


func native_furniture_actions(target: Node) -> Array:
	if not target.has_method("get_actions"):
		return []
	var actor: Node = life.get_player()
	var res: Variant
	# Foundation Interactables take an actor; the furniture thread's may not.
	if target.get_method_argument_count("get_actions") > 0:
		res = target.get_actions(actor)
	else:
		res = target.get_actions()
	return res if res is Array else []


func _def_matches_target(def: Dictionary, kind: String, target: Variant, ftags: Array) -> bool:
	var t: String = def.get("target", "self")
	match kind:
		"self":
			if t == "self":
				return true
			return t == "place" and life.place_matches(def.get("place", []))
		"npc":
			return t == "npc"
		"furniture":
			if t != "furniture":
				return false
			for tag in def.get("furniture", []):
				if tag in ftags:
					return true
			return false
		"place":
			return t == "place" and life.place_matches(def.get("place", []), target)
	return false


## Everything that can be offered for this target: [{id, def, label, ok, reason, minutes, native}].
## Actions whose requirements fail are included with ok=false and a reason, so
## menus can grey them out. Set include_blocked=false to drop them.
func available_for(target: Variant = null, include_blocked: bool = true) -> Array:
	var kind := target_kind(target)
	var ftags: Array = furniture_tags(target) if kind == "furniture" else []
	var out: Array = []
	var seen := {}
	for id in order:
		var def: Dictionary = defs[id]
		if def.get("hidden", false):
			continue
		if not _def_matches_target(def, kind, target, ftags):
			continue
		var reason := check(id, target)
		if reason != "" and not include_blocked:
			continue
		seen[id] = true
		out.append({"id": id, "def": def, "label": str(def.name), "ok": reason == "",
			"reason": reason, "minutes": int(def.get("minutes", 0)), "native": false})
	if kind == "furniture":
		for a in native_furniture_actions(target):
			var aid := str(a.get("id", ""))
			if aid == "" or seen.has(aid):
				continue
			out.append({"id": aid, "def": a, "label": str(a.get("label", aid.capitalize())), "ok": true,
				"reason": "", "minutes": int(a.get("duration_game_minutes", a.get("minutes", 0))), "native": true})
	return out


## Shape the foundation's Interactable.get_actions() expects: [{id, label, minutes}].
## NPC Interactables can return this directly and call Life.actions.perform in perform().
func interactable_actions(target: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in available_for(target, false):
		out.append({"id": a.id, "label": a.label, "minutes": a.minutes})
	return out


# --- Requirements -------------------------------------------------------------

## "" when the action is allowed for this target, otherwise a short reason.
func check(id: String, target: Variant = null) -> String:
	var def: Dictionary = defs.get(id, {})
	if def.is_empty():
		return "Unknown action"
	if life.get_flag("crime.in_jail", false) and not def.get("allowed_in_jail", false):
		return "You're in jail"
	var req: Dictionary = def.get("requires", {})
	var kind := target_kind(target)
	var cd_until: float = cooldowns.get(id + "|" + target_key(target), -1.0)
	if cd_until > life.clock.total_minutes:
		return "Try again later"
	var cost := float(def.get("cost", 0))
	if cost > 0.0 and not life.money.can_afford(cost):
		return "Costs %s" % life.money.fmt(cost)
	if req.has("cash") and not life.money.can_afford(float(req.cash)):
		return "Need %s" % life.money.fmt(float(req.cash))
	if req.has("cash_on_hand") and life.money.cash < float(req.cash_on_hand):
		return "Need %s in cash" % life.money.fmt(float(req.cash_on_hand))
	if req.has("bank") and life.money.bank < float(req.bank):
		return "Need %s in the bank" % life.money.fmt(float(req.bank))
	if req.has("debt") and life.money.debt <= 0.0:
		return "No debt to pay"
	if req.has("hours"):
		var hrs: Array = req.hours
		if not life.clock.is_between(float(hrs[0]), float(hrs[1])):
			return "Only %s" % _hours_text(hrs)
	if req.has("weekdays"):
		if life.clock.weekday() not in req.weekdays:
			return "Not today"
	for n in req.get("needs_min", {}):
		if life.needs.enabled and life.needs.get_value(n) < float(req.needs_min[n]):
			return "Too low on %s" % life.needs.label(n).to_lower()
	for n in req.get("needs_max", {}):
		if life.needs.enabled and life.needs.get_value(n) > float(req.needs_max[n]):
			return "Not %s enough" % _need_word(n)
	for s in req.get("skills", {}):
		if life.skills.level(s) < int(req.skills[s]):
			return "Needs %s %d" % [s.capitalize(), int(req.skills[s])]
	for f in req.get("flags", []):
		if not life.get_flag(f, false):
			return "Requires %s" % str(f).get_slice(".", str(f).get_slice_count(".") - 1).replace("_", " ")
	for f in req.get("not_flags", []):
		if life.get_flag(f, false):
			return "Not while %s" % str(f).get_slice(".", str(f).get_slice_count(".") - 1).replace("_", " ")
	if req.get("player_adult_21", false) and int(life.get_flag("age", 21)) < 21:
		return "Must be 21+"
	# A place requirement on a non-place action (e.g. "dance with" only at a bar).
	if def.has("place"):
		var where: Dictionary = target if (kind == "place" and target is Dictionary) else life.place
		if not life.place_matches(def.place, where):
			return "Not here"
	if kind == "npc":
		var r := _check_npc(def, req, npc_id(target))
		if r != "":
			return r
	if checks.has(id) and checks[id].is_valid():
		var custom: Variant = checks[id].call(def, target)
		if custom is String and custom != "":
			return custom
	return ""


func _check_npc(def: Dictionary, req: Dictionary, nid: String) -> String:
	var rel = life.relationships
	if nid == "":
		return "No one there"
	if req.get("met", false) and not rel.knows(nid):
		return "You haven't met"
	if req.get("not_met", false) and rel.knows(nid):
		return "Already met"
	var t: String = rel.tier(nid)
	if req.has("min_tier") and rel.tier_index(t) < rel.tier_index(req.min_tier):
		return "Must be %s" % rel.TIER_LABELS.get(req.min_tier, req.min_tier).to_lower()
	if req.has("max_tier") and rel.tier_index(t) > rel.tier_index(req.max_tier):
		return "Too close for that"
	if req.has("min_friendship") and rel.friendship(nid) < float(req.min_friendship):
		return "Not close enough"
	if req.has("max_friendship") and rel.friendship(nid) > float(req.max_friendship):
		return "Not now"
	if req.has("min_romance") and rel.romance(nid) < float(req.min_romance):
		return "Not enough chemistry"
	for f in req.get("rel_flags", []):
		if not rel.has_flag(nid, f):
			return "Must be %s" % str(f).replace("_", " ")
	for f in req.get("not_rel_flags", []):
		if rel.has_flag(nid, f):
			return "Already %s" % str(f).replace("_", " ")
	if (req.get("adult", false) or def.get("category", "") == "romance") and not rel.is_adult(nid):
		return "Not appropriate"
	if req.get("one_partner", false):
		for other in rel.people("dating") + rel.people("partner") + rel.people("married"):
			if other != nid:
				return "You're already with someone"
	return ""


func _hours_text(hrs: Array) -> String:
	return "%s to %s" % [_h(int(hrs[0])), _h(int(hrs[1]))]


func _h(h: int) -> String:
	h = h % 24
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	return "%d %s" % [12 if h12 == 0 else h12, ampm]


func _need_word(n: String) -> String:
	return {"hunger": "hungry", "energy": "tired", "hygiene": "dirty", "fun": "bored",
		"social": "lonely", "bladder": "desperate"}.get(n, n)


# --- Running ------------------------------------------------------------------

func busy() -> bool:
	return not current.is_empty()


## 0..1 progress of the running timed action.
func progress() -> float:
	if current.is_empty():
		return 0.0
	var span: float = max(current.end_at - current.started_at, 1.0)
	return clampf((life.clock.total_minutes - current.started_at) / span, 0.0, 1.0)


## Start an action. Returns {ok, reason}. Timed actions finish later and emit
## action_finished; instant and time-skip actions finish before this returns.
func perform(id: String, target: Variant = null, opts: Dictionary = {}) -> Dictionary:
	if target is String and target == "":
		target = null
	# A furniture node's own action with no life definition: let it run itself.
	if not defs.has(id) and target_kind(target) == "furniture":
		return _perform_native_furniture(id, target)
	if busy() and not opts.get("force", false):
		return _fail(id, target, "Busy: %s" % defs.get(current.id, {}).get("name", current.id))
	var reason := check(id, target)
	if reason != "":
		return _fail(id, target, reason)
	var def: Dictionary = defs[id]
	# Furniture that has this action natively runs its own animation/time; we
	# apply the life effects when it reports back.
	if target_kind(target) == "furniture" and _is_native_on(id, target):
		return _perform_native_furniture(id, target)
	var cost := float(def.get("cost", 0))
	if cost > 0.0 and not life.money.spend(cost, str(def.name)):
		return _fail(id, target, "Can't afford it")
	if target_kind(target) == "npc":
		life.relationships.meet(npc_id(target))
	var minutes := float(def.get("minutes", 0))
	action_started.emit(id, target)
	if minutes <= 0.0:
		_complete(id, target)
	elif def.get("time_skip", false) or opts.get("instant", false):
		_hold_needs(def)
		current = {"id": id, "target": target, "started_at": life.clock.total_minutes,
			"end_at": life.clock.total_minutes + minutes, "skipping": true}
		life.clock.advance_minutes(minutes)
		_complete(id, target)
	else:
		_hold_needs(def)
		current = {"id": id, "target": target, "started_at": life.clock.total_minutes,
			"end_at": life.clock.total_minutes + minutes}
	return {"ok": true, "reason": ""}


func _is_native_on(id: String, target: Node) -> bool:
	for a in native_furniture_actions(target):
		if str(a.get("id", "")) == id:
			return true
	return false


func _perform_native_furniture(id: String, target: Node) -> Dictionary:
	if not target.has_method("perform"):
		return _fail(id, target, "Can't do that here")
	var actor: Node = life.get_player()
	if target.get_method_argument_count("perform") >= 2:
		target.perform(id, actor)
	else:
		target.perform(id)
	# If no signal reported it back (no GameState, plain test furniture), apply now.
	life.apply_external_action(id, target, actor if actor else life)
	return {"ok": true, "reason": ""}


func _fail(id: String, target: Variant, reason: String) -> Dictionary:
	action_failed.emit(id, target, reason)
	return {"ok": false, "reason": reason}


func _hold_needs(def: Dictionary) -> void:
	var hold: Array = []
	for n in def.get("needs", {}):
		if float(def.needs[n]) > 0.0:
			hold.append(n if n != "comfort" else "energy")
	life.needs.hold(hold)


func cancel() -> void:
	if current.is_empty():
		return
	var c := current
	current = {}
	life.needs.release_all()
	# Partial credit for what was done.
	var span: float = max(c.end_at - c.started_at, 1.0)
	var frac := clampf((life.clock.total_minutes - c.started_at) / span, 0.0, 1.0)
	if frac >= 0.25:
		_complete(c.id, c.target, frac)
	action_cancelled.emit(c.id, c.target)


func on_minute() -> void:
	if current.is_empty() or current.get("skipping", false):
		return
	if life.clock.total_minutes + 0.001 >= current.end_at:
		var c := current
		_complete(c.id, c.target)


## Success roll for chance-based actions (mostly social).
func success_chance(def: Dictionary, target: Variant) -> float:
	if not def.has("chance"):
		return 1.0
	var p := float(def.chance)
	if def.has("chance_skill"):
		p += 0.03 * life.skills.level(def.chance_skill)
	var nid := npc_id(target)
	if nid != "":
		var rel = life.relationships
		var t: String = rel.tier(nid)
		p += {"enemy": -0.3, "dislike": -0.15, "stranger": 0.0, "acquaintance": 0.02,
			"friend": 0.06, "close_friend": 0.1, "best_friend": 0.14}.get(t, 0.0)
		for tr in def.get("likes", {}):
			p += (rel.trait_value(nid, tr) - 0.5) * 0.4 * float(def.likes[tr])
		if def.has("topic") and rel.has_interest(nid, def.topic):
			p += 0.15
		if def.get("category", "") == "romance":
			p += rel.romance(nid) / 400.0
	if life.needs.enabled:
		p += (life.needs.mood() - 60.0) / 400.0
	return clampf(p, 0.05, 0.97)


func _complete(id: String, target: Variant, scale: float = 1.0) -> void:
	current = {}
	life.needs.release_all()
	var def: Dictionary = defs.get(id, {})
	var nid := npc_id(target)
	var success := rng.randf() < success_chance(def, target)
	var fx: Dictionary = def if success else def.get("fail", {})
	var result := {"ok": true, "success": success, "message": "", "money": 0.0,
		"needs": {}, "skills": {}, "rel": {}}
	result.needs = life.needs.apply(fx.get("needs", {}), scale)
	var skill_scale := scale * (1.0 if success else 0.5)
	for s in def.get("skills", {}):
		var amt := float(def.skills[s]) * skill_scale
		life.skills.add_xp(s, amt)
		result.skills[s] = amt
	if nid != "":
		var rel: Dictionary = fx.get("rel", {})
		var df := float(rel.get("friendship", 0)) * scale
		var dr := float(rel.get("romance", 0)) * scale
		if def.has("topic") and life.relationships.has_interest(nid, def.topic) and df > 0.0:
			df *= 1.5
		life.relationships.change(nid, df, dr, id if success else id + "_failed")
		result.rel = {"friendship": df, "romance": dr}
		if success:
			for f in def.get("sets_rel_flags", []):
				life.relationships.add_flag(nid, f)
			for f in def.get("clears_rel_flags", []):
				life.relationships.remove_flag(nid, f)
	var earn := float(fx.get("earn", 0)) * scale
	if def.has("earn_range") and success:
		earn += rng.randf_range(float(def.earn_range[0]), float(def.earn_range[1])) * scale
	if def.has("earn_skill") and success:
		earn *= 1.0 + 0.15 * life.skills.level(def.earn_skill)
	if earn > 0.0:
		life.money.add(earn, str(def.get("name", id)))
		result.money = earn
	if success:
		var sf: Dictionary = def.get("sets_flags", {})
		for f in sf:
			life.set_flag(f, sf[f])
		if def.has("special"):
			_special(str(def.special), result)
	var cd := float(def.get("cooldown_minutes", 0))
	if cd > 0.0:
		cooldowns[id + "|" + target_key(target)] = life.clock.total_minutes + cd
	var msg := str(def.get("message", "")) if success else str(def.get("fail_message", ""))
	if msg == "" and not success:
		msg = "That didn't go well."
	result.message = msg.replace("{npc}", life.relationships.display_name(nid) if nid != "" else "them")
	if handlers.has(id) and handlers[id].is_valid():
		var r: Variant = handlers[id].call(def, target, result)
		if r is Dictionary:
			result = r
	action_finished.emit(id, target, result)


func _special(kind: String, result: Dictionary) -> void:
	var m = life.money
	match kind:
		"deposit_all":
			var amt: float = m.cash
			m.deposit(amt)
			result.message = "Deposited %s." % m.fmt(amt)
		"withdraw_50":
			result.message = "Withdrew %s." % m.fmt(50.0) if m.withdraw(50.0) else "Not enough in the bank."
		"withdraw_200":
			result.message = "Withdrew %s." % m.fmt(200.0) if m.withdraw(200.0) else "Not enough in the bank."
		"repay_100":
			var paid: float = m.repay(100.0)
			result.message = "Paid %s toward your debt." % m.fmt(paid)
		"lottery":
			var roll := rng.randf()
			var win := 0.0
			if roll < 0.0005:
				win = 10000.0
			elif roll < 0.01:
				win = 100.0
			elif roll < 0.12:
				win = 5.0
			if win > 0.0:
				m.add(win, "Lottery win")
				result.money = win
				result.message = "You won %s!" % m.fmt(win)
			else:
				result.message = "No luck this time."
		"check_balance":
			result.message = "Cash %s, bank %s, debt %s." % [m.fmt(m.cash), m.fmt(m.bank), m.fmt(m.debt)]


func to_save() -> Dictionary:
	return {"cooldowns": cooldowns.duplicate()}


func from_save(d: Dictionary) -> void:
	cooldowns = d.get("cooldowns", {})
