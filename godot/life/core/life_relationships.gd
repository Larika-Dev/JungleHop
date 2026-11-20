extends RefCounted
## Per-NPC relationship records. Sparse: a record exists only once the player
## has interacted with that NPC, so 4,000 NPCs cost nothing up front.

signal relationship_changed(npc_id: String, friendship: float, romance: float)
signal tier_changed(npc_id: String, old_tier: String, new_tier: String)
signal flag_added(npc_id: String, flag: String)
signal flag_removed(npc_id: String, flag: String)

const TIERS := ["enemy", "dislike", "stranger", "acquaintance", "friend", "close_friend", "best_friend"]
const TIER_LABELS := {
	"enemy": "Enemy", "dislike": "Dislike", "stranger": "Stranger", "acquaintance": "Acquaintance",
	"friend": "Friend", "close_friend": "Close friend", "best_friend": "Best friend",
}
const ROMANCE_TIERS := ["none", "crush", "dating", "partner", "engaged", "married"]
const MEMORY_MAX := 12

## npc_id -> {name, sex, age, traits: {}, interests: []}
var info: Dictionary = {}
## npc_id -> {friendship, romance, met, flags: [], last_contact, memories: []}
var records: Dictionary = {}

var _now: Callable = func() -> float: return 0.0


func _init(now_minutes: Callable = Callable()) -> void:
	if now_minutes.is_valid():
		_now = now_minutes


func register_npc(npc_id: String, npc_info: Dictionary) -> void:
	var cur: Dictionary = info.get(npc_id, {})
	for k in npc_info:
		cur[k] = npc_info[k]
	info[npc_id] = cur


func npc_info(npc_id: String) -> Dictionary:
	return info.get(npc_id, {})


func display_name(npc_id: String) -> String:
	return str(info.get(npc_id, {}).get("name", npc_id))


func trait_value(npc_id: String, trait_id: String) -> float:
	return float(info.get(npc_id, {}).get("traits", {}).get(trait_id, 0.5))


func has_interest(npc_id: String, interest: String) -> bool:
	return interest in info.get(npc_id, {}).get("interests", [])


func is_adult(npc_id: String) -> bool:
	# Unknown age counts as adult: the city's NPC generator only makes adults.
	return int(info.get(npc_id, {}).get("age", 18)) >= 18


func _ensure(npc_id: String) -> Dictionary:
	if not records.has(npc_id):
		records[npc_id] = {"friendship": 0.0, "romance": 0.0, "met": false, "flags": [],
			"last_contact": _now.call(), "memories": []}
	return records[npc_id]


func knows(npc_id: String) -> bool:
	return records.has(npc_id) and bool(records[npc_id].met)


## A copy of the record merged with the NPC info, safe to read.
func get_rel(npc_id: String) -> Dictionary:
	var r: Dictionary = records.get(npc_id, {"friendship": 0.0, "romance": 0.0, "met": false,
		"flags": [], "last_contact": 0.0, "memories": []}).duplicate(true)
	r["npc_id"] = npc_id
	r["name"] = display_name(npc_id)
	r["traits"] = info.get(npc_id, {}).get("traits", {})
	r["interests"] = info.get(npc_id, {}).get("interests", [])
	r["tier"] = tier(npc_id)
	r["romance_tier"] = romance_tier(npc_id)
	return r


func friendship(npc_id: String) -> float:
	return float(records.get(npc_id, {}).get("friendship", 0.0))


func romance(npc_id: String) -> float:
	return float(records.get(npc_id, {}).get("romance", 0.0))


static func tier_for(f: float, met: bool) -> String:
	if f <= -60.0:
		return "enemy"
	if f <= -20.0:
		return "dislike"
	if not met:
		return "stranger"
	if f >= 85.0:
		return "best_friend"
	if f >= 60.0:
		return "close_friend"
	if f >= 30.0:
		return "friend"
	return "acquaintance"


static func tier_index(t: String) -> int:
	return TIERS.find(t)


func tier(npc_id: String) -> String:
	if not records.has(npc_id):
		return "stranger"
	var r: Dictionary = records[npc_id]
	return tier_for(r.friendship, r.met)


func romance_tier(npc_id: String) -> String:
	for t in ["married", "engaged", "partner", "dating"]:
		if has_flag(npc_id, t):
			return t
	return "crush" if romance(npc_id) >= 20.0 else "none"


## Change friendship and romance. Marks the NPC as met and refreshes contact.
func change(npc_id: String, d_friendship: float, d_romance: float = 0.0, reason: String = "") -> void:
	var r := _ensure(npc_id)
	var old := tier(npc_id)
	r.met = true
	r.friendship = clampf(r.friendship + d_friendship, -100.0, 100.0)
	r.romance = clampf(r.romance + d_romance, 0.0, 100.0)
	r.last_contact = _now.call()
	if reason != "":
		remember(npc_id, reason, d_friendship)
	relationship_changed.emit(npc_id, r.friendship, r.romance)
	var now_tier := tier(npc_id)
	if now_tier != old:
		tier_changed.emit(npc_id, old, now_tier)


func meet(npc_id: String) -> void:
	if not knows(npc_id):
		change(npc_id, 0.0, 0.0)
		add_flag(npc_id, "met")


func has_flag(npc_id: String, flag: String) -> bool:
	return flag in records.get(npc_id, {}).get("flags", [])


func add_flag(npc_id: String, flag: String) -> void:
	var r := _ensure(npc_id)
	if flag not in r.flags:
		r.flags.append(flag)
		flag_added.emit(npc_id, flag)


func remove_flag(npc_id: String, flag: String) -> void:
	if records.has(npc_id) and flag in records[npc_id].flags:
		records[npc_id].flags.erase(flag)
		flag_removed.emit(npc_id, flag)


## Anyone with this flag, e.g. people("dating").
func people(flag: String = "") -> Array:
	var out: Array = []
	for id in records:
		if flag == "" and records[id].met:
			out.append(id)
		elif flag != "" and flag in records[id].flags:
			out.append(id)
	return out


func remember(npc_id: String, event: String, weight: float = 0.0) -> void:
	var r := _ensure(npc_id)
	r.memories.append({"t": _now.call(), "event": event, "weight": weight})
	if r.memories.size() > MEMORY_MAX:
		r.memories.pop_front()


func memories(npc_id: String) -> Array:
	return records.get(npc_id, {}).get("memories", []).duplicate(true)


## Daily drift toward 0 after 3 days without contact.
func on_day(_day: int) -> void:
	var now: float = _now.call()
	for id in records:
		var r: Dictionary = records[id]
		if not r.met:
			continue
		var days_since := (now - float(r.last_contact)) / 1440.0
		if days_since < 3.0:
			continue
		var step := 1.0
		if tier(id) == "best_friend" or has_flag(id, "partner") or has_flag(id, "married"):
			step = 0.25
		var old := tier(id)
		if r.friendship > 0.0:
			r.friendship = max(0.0, r.friendship - step)
		elif r.friendship < 0.0:
			r.friendship = min(0.0, r.friendship + step * 0.5)
		if r.romance > 0.0 and not has_flag(id, "married"):
			r.romance = max(0.0, r.romance - step * 0.5)
		relationship_changed.emit(id, r.friendship, r.romance)
		if tier(id) != old:
			tier_changed.emit(id, old, tier(id))


func to_save() -> Dictionary:
	return {"records": records.duplicate(true), "info": info.duplicate(true)}


func from_save(d: Dictionary) -> void:
	records = d.get("records", {})
	var saved_info: Dictionary = d.get("info", {})
	for id in saved_info:
		if not info.has(id):
			info[id] = saved_info[id]
