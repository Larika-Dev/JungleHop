extends Node
## Life core autoload: `Life="*res://life/life.gd"` in project.godot.
## Owns the clock adapter, needs, skills, money, relationships and actions.
## Jobs, education, crime, furniture and NPC systems plug in; see INTERFACES.md.

signal flag_changed(key: String, value: Variant)
signal place_changed(place: Dictionary)
## Short player-facing text (toasts). The HUD shows these.
signal notify(text: String)
signal passed_out()

const LifeClock := preload("res://life/core/life_clock.gd")
const LifeNeeds := preload("res://life/core/life_needs.gd")
const LifeSkills := preload("res://life/core/life_skills.gd")
const LifeMoney := preload("res://life/core/life_money.gd")
const LifeRelationships := preload("res://life/core/life_relationships.gd")
const LifeActions := preload("res://life/core/life_actions.gd")

const SAVE_PATH := "user://life_save.json"
const SAVE_VERSION := 1

var clock: Node
var needs: RefCounted
var skills: RefCounted
var money: RefCounted
var relationships: RefCounted
var actions: RefCounted

## Free-form player state shared by all systems. Prefix your keys: job. edu. crime.
var flags: Dictionary = {}
## Where the player is: {id, building_id, room_id, room_type, typology, business_type, district, tags: []}
var place: Dictionary = {}
## Set false to stop Life from tracking the player's room through CityData.
var auto_place: bool = true

var _save_providers: Dictionary = {}
var _recent_external: Dictionary = {}
var _place_timer: float = 0.0
var _hooked_game_state: bool = false
var _business_by_building: Dictionary = {}
## "furniture_instance|action" -> game minute a held pose (sit, lie_down) started
var _pose_started: Dictionary = {}


func _init() -> void:
	var now := func() -> float: return clock.total_minutes if clock else 0.0
	clock = LifeClock.new()
	clock.name = "LifeClock"
	needs = LifeNeeds.new(_load_json("res://life/data/needs.json"))
	skills = LifeSkills.new()
	money = LifeMoney.new(now)
	relationships = LifeRelationships.new(now)
	actions = LifeActions.new(self)


func _ready() -> void:
	add_child(clock)
	clock.minute_passed.connect(_on_minute)
	clock.hour_passed.connect(_on_hour)
	clock.day_passed.connect(_on_day)
	needs.need_critical.connect(_on_need_critical)
	actions.action_finished.connect(_on_action_finished)
	actions.action_failed.connect(func(_id, _t, reason): notify.emit(reason))
	skills.skill_leveled.connect(func(id, lv): notify.emit("%s skill is now level %d" % [id.capitalize(), lv]))
	relationships.tier_changed.connect(_on_tier_changed)
	money.bill_missed.connect(func(id, amt): notify.emit("Missed payment: %s (%s)" % [money.bills.get(id, {}).get("reason", id), money.fmt(amt)]))
	var n: int = actions.load_dir()
	print_verbose("Life: %d actions loaded" % n)
	get_tree().node_added.connect(_on_node_added)
	_scan_existing(get_tree().root)
	_hook_foundation.call_deferred()
	_load_business_index()


func _hook_foundation() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and not _hooked_game_state:
		_hooked_game_state = true
		if gs.has_signal("action_performed"):
			gs.action_performed.connect(_on_game_state_action)
		if gs.has_method("register_saveable"):
			gs.register_saveable("life", self)
	# Pull actions other autoloads expose with get_life_actions() / get_actions().
	for n in ["Education", "JobSystem", "Crime", "CrimeSystem", "Law"]:
		var sys := get_node_or_null("/root/" + n)
		if sys == null:
			continue
		var list: Variant = null
		if sys.has_method("get_life_actions"):
			list = sys.get_life_actions()
		elif sys.has_method("get_actions") and sys.get_method_argument_count("get_actions") == 0:
			list = sys.get_actions()
		if list is Array:
			_adopt_system_actions(n, list)


## Accepts dicts like {id, label, building_id, callable} from other systems.
func _adopt_system_actions(system: String, list: Array) -> void:
	for a in list:
		if not (a is Dictionary) or not a.has("id"):
			continue
		var id := str(a.id)
		if actions.has_action(id):
			continue
		var def: Dictionary = a.duplicate()
		def.erase("callable")
		if not def.has("name"):
			def["name"] = str(a.get("label", id.capitalize()))
		if not def.has("category"):
			def["category"] = {"Education": "school", "JobSystem": "work"}.get(system, "crime")
		if not def.has("target"):
			def["target"] = "place" if a.has("building_id") else "self"
		if a.has("building_id") and not def.has("place"):
			def["place"] = [str(a.building_id)]
		actions.register(def)
		var fn: Variant = a.get("callable")
		if fn is Callable:
			actions.set_handler(id, func(_d, _t, result):
				fn.call()
				return result)


func _process(delta: float) -> void:
	_place_timer += delta
	if _place_timer >= 0.5:
		_place_timer = 0.0
		if auto_place:
			_update_place_from_city()


# --- Ticks --------------------------------------------------------------------

func _on_minute(_total: int) -> void:
	needs.tick_minute()
	money.on_minute()
	actions.on_minute()


func _on_hour(_day: int, _hour: int) -> void:
	money.on_hour()


func _on_day(day: int) -> void:
	money.on_day(day)
	relationships.on_day(day)


func _on_need_critical(id: String) -> void:
	match id:
		"energy":
			if not actions.busy():
				notify.emit("You passed out from exhaustion.")
				passed_out.emit()
				needs.hold(["energy"])
				clock.advance_minutes(360)
				needs.release_all()
				needs.change("energy", 45.0)
		"bladder":
			notify.emit("You really need a bathroom.")
		"hunger":
			notify.emit("You're starving.")
		_:
			notify.emit("Your %s is very low." % needs.label(id).to_lower())


func _on_action_finished(_id: String, _target: Variant, result: Dictionary) -> void:
	if str(result.get("message", "")) != "":
		notify.emit(result.message)


func _on_tier_changed(npc_id: String, _old: String, new_tier: String) -> void:
	notify.emit("%s: %s" % [relationships.display_name(npc_id), relationships.TIER_LABELS.get(new_tier, new_tier)])


# --- Player, flags, place -----------------------------------------------------

func get_player() -> Node:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_player"):
		var p: Node = gs.get_player()
		if p:
			return p
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


func set_flag(key: String, value: Variant) -> void:
	if flags.get(key) == value:
		return
	if value == null:
		flags.erase(key)
	else:
		flags[key] = value
	flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_place(p: Dictionary) -> void:
	if p.get("id", "") == place.get("id", "") and p.get("room_id", "") == place.get("room_id", ""):
		return
	place = p
	place_changed.emit(place)


func place_tags(p: Dictionary = place) -> Array:
	var tags: Array = []
	for k in ["id", "building_id", "room_id", "room_type", "typology", "business_type", "category", "type", "district"]:
		if p.has(k) and str(p[k]) != "":
			tags.append(str(p[k]))
	for t in p.get("tags", []):
		tags.append(str(t))
	return tags


## True when any wanted tag is on the place ("any" matches everywhere,
## "outdoors" matches when not inside a building). Empty list matches.
func place_matches(wanted: Array, p: Dictionary = place) -> bool:
	if wanted.is_empty():
		return true
	var tags := place_tags(p)
	for w in wanted:
		if w == "any":
			return true
		if w == "outdoors" and str(p.get("room_id", "")) == "":
			return true
		if w == "indoors" and str(p.get("room_id", "")) != "":
			return true
		if w in tags:
			return true
	return false


func _load_business_index() -> void:
	for path in ["res://data/off-campus/businesses.json", "res://life/data/businesses.json"]:
		var d := _load_json(path)
		for b in d.get("businesses", []):
			_business_by_building[str(b.get("id", ""))] = b
		if not _business_by_building.is_empty():
			return


func _update_place_from_city() -> void:
	var city := get_node_or_null("/root/CityData")
	var player := get_player()
	if city == null or player == null or not (player is Node3D) or not city.has_method("room_at"):
		return
	var room: Variant = city.room_at((player as Node3D).global_position)
	var p := {}
	if room is Dictionary and not room.is_empty():
		var bid := str(room.get("buildingId", ""))
		p = {"id": bid, "building_id": bid, "room_id": str(room.get("roomId", "")),
			"room_type": str(room.get("roomType", "")), "tags": []}
		var b: Variant = city.building(bid) if city.has_method("building") else null
		if b is Dictionary:
			p["typology"] = str(b.get("typology", ""))
			p["district"] = str(b.get("district", ""))
			var biz: Variant = b.get("business")
			if biz is Dictionary:
				p["business_type"] = str(biz.get("type", ""))
				p["name"] = str(biz.get("name", ""))
		var cat: Dictionary = _business_by_building.get(bid, {})
		if not cat.is_empty():
			p["category"] = str(cat.get("category", ""))
			if cat.get("socialHub", false):
				p.tags.append("social_hub")
	set_place(p)


# --- Furniture and Interactable hooks ----------------------------------------

func _scan_existing(node: Node) -> void:
	for c in node.get_children():
		_on_node_added(c)
		_scan_existing(c)


func _on_node_added(node: Node) -> void:
	if node.has_signal("action_finished") and (node.is_in_group("furniture") or "furniture_kind" in node):
		if not node.action_finished.is_connected(_on_furniture_action):
			node.action_finished.connect(_on_furniture_action)
		if node.has_signal("action_started") and not node.action_started.is_connected(_on_furniture_started):
			node.action_started.connect(_on_furniture_started)
	if "npc_id" in node and str(node.npc_id) != "":
		_register_npc_node(node)


func _register_npc_node(node: Node) -> void:
	var inf := {}
	for k in ["display_name", "name_full", "traits", "interests", "age", "sex"]:
		if k in node:
			inf[{"display_name": "name", "name_full": "name"}.get(k, k)] = node.get(k)
	relationships.register_npc(str(node.npc_id), inf)


func _on_furniture_started(action_id: String, actor: Variant, furniture: Variant) -> void:
	if _is_player_actor(actor) and furniture is Object:
		_pose_started["%d|%s" % [furniture.get_instance_id(), action_id]] = clock.total_minutes


func _on_furniture_action(action_id: String, actor: Variant, furniture: Variant) -> void:
	apply_external_action(action_id, furniture, actor)


func _on_game_state_action(action_id: String, target: Variant, actor: Variant) -> void:
	# NPC actions run through Life.actions.perform are already applied, and
	# furniture reports through its own action_finished (held poses end later).
	if target is Node and actions.target_kind(target) in ["npc", "furniture"]:
		if (target as Node).has_signal("action_finished"):
			return
	apply_external_action(action_id, target, actor)


func _is_player_actor(actor: Variant) -> bool:
	return not (actor is Node and actor != self and not (actor as Node).is_in_group("player"))


## The furniture side's definition of an action: Furniture.action_def(id) when
## the furniture manager exists, else the entry from the node's get_actions().
## Shape: {label, minutes, needs, perHour?}.
func _furniture_def(action_id: String, target: Variant) -> Dictionary:
	var mgr := get_node_or_null("/root/Furniture")
	if mgr and mgr.has_method("action_def"):
		var d: Variant = mgr.action_def(action_id)
		if d is Dictionary and not d.is_empty():
			return d
	if target is Node and target.has_method("get_actions"):
		for a in actions.native_furniture_actions(target):
			if str(a.get("id", "")) == action_id:
				var d2: Dictionary = a.duplicate()
				if not d2.has("needs"):
					d2["needs"] = a.get("needs_effects", {})
				if not d2.has("minutes"):
					d2["minutes"] = int(a.get("duration_game_minutes", 0))
				return d2
	return {}


## Apply life effects for an action another system ran (furniture, Interactable).
## De-duplicated, so both the furniture signal and GameState can report it.
func apply_external_action(action_id: String, target: Variant, actor: Variant) -> void:
	if not _is_player_actor(actor):
		return
	var tid := str(target.get_instance_id()) if target is Object else str(target)
	var key := "%s|%s" % [action_id, tid]
	# An echo of the same action arrives within moments and with the clock where
	# the first report left it; anything else is a new use.
	var now := Time.get_ticks_msec()
	var last: Dictionary = _recent_external.get(key, {})
	if not last.is_empty() and now - int(last.ms) < 400 and is_equal_approx(float(last.t), clock.total_minutes):
		return
	var fdef := _furniture_def(action_id, target)
	# Held poses (sit, lie_down): effects per game hour actually held.
	if fdef.get("perHour", false):
		var pk := "%s|%s" % [tid, action_id]
		var hours: float = (clock.total_minutes - float(_pose_started.get(pk, clock.total_minutes))) / 60.0
		_pose_started.erase(pk)
		if hours > 0.0:
			needs.apply(fdef.get("needs", {}), hours)
		_recent_external[key] = {"ms": now, "t": clock.total_minutes}
		return
	var def: Dictionary = actions.get_def(action_id)
	var own: bool = not def.is_empty() and def.get("target", "self") != "npc"
	var fx_needs: Dictionary = def.get("needs", {}) if own else fdef.get("needs", {})
	var minutes: float = actions.duration_for(def) if own else float(fdef.get("minutes", 0))
	if own and minutes <= 0.0:
		minutes = float(fdef.get("minutes", 0))
	if def.is_empty() and fdef.is_empty():
		return
	# Furniture finishes at once; Life spends the action's time by skipping the clock.
	var is_furniture: bool = target is Node and actions.target_kind(target) == "furniture"
	if is_furniture and minutes > 0.0 and not actions.busy():
		actions._hold_needs(def if own else {"needs": fx_needs})
		clock.advance_minutes(minutes)
		needs.release_all()
	needs.apply(fx_needs)
	if own and def.has("needs_per_hour"):
		needs.apply(def.needs_per_hour, minutes / 60.0)
	if own:
		for s in def.get("skills", {}):
			skills.add_xp(s, float(def.skills[s]))
		if float(def.get("earn", 0)) > 0.0:
			money.add(float(def.earn), str(def.name))
		var msg := str(def.get("message", ""))
		if msg != "":
			notify.emit(msg)
	_recent_external[key] = {"ms": Time.get_ticks_msec(), "t": clock.total_minutes}
	actions.action_finished.emit(action_id, target, {"ok": true, "success": true, "message": "",
		"external": true})


# --- Compatibility aliases (jobs / education threads asked for these) --------

func add_money(amount: float, reason: String = "") -> void:
	money.add(amount, reason)


func spend_money(amount: float, reason: String = "") -> bool:
	return money.spend(amount, reason)


func get_money() -> float:
	return money.cash


func apply_need_delta(need: String, delta: float) -> void:
	needs.change(need, delta)


# --- Save / load --------------------------------------------------------------

func register_save_provider(key: String, obj: Object) -> void:
	_save_providers[key] = obj


func to_save() -> Dictionary:
	var d := {
		"version": SAVE_VERSION,
		"clock": clock.to_save(),
		"needs": needs.to_save(),
		"skills": skills.to_save(),
		"money": money.to_save(),
		"relationships": relationships.to_save(),
		"actions": actions.to_save(),
		"flags": flags.duplicate(true),
		"providers": {},
	}
	for k in _save_providers:
		var o: Object = _save_providers[k]
		if is_instance_valid(o) and o.has_method("to_save"):
			d.providers[k] = o.to_save()
	return d


func from_save(d: Dictionary) -> void:
	clock.from_save(d.get("clock", {}))
	needs.from_save(d.get("needs", {}))
	skills.from_save(d.get("skills", {}))
	money.from_save(d.get("money", {}))
	relationships.from_save(d.get("relationships", {}))
	actions.from_save(d.get("actions", {}))
	flags = d.get("flags", {})
	var prov: Dictionary = d.get("providers", {})
	for k in prov:
		var o: Object = _save_providers.get(k)
		if is_instance_valid(o) and o.has_method("from_save"):
			o.from_save(prov[k])


## GameState.register_saveable contract.
func save_data() -> Dictionary:
	return to_save()


func load_data(d: Dictionary) -> void:
	from_save(d)


func save_game(path: String = SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_save(), "\t"))
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	var d := _load_json(path)
	if d.is_empty():
		return false
	from_save(d)
	return true


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
