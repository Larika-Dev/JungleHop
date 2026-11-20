extends RefCounted
## Hidden scores that change how NPCs treat the player. None are shown in the
## HUD. Read them with Life.standing.get_score(id) or Life.standing.summary().
##
## reputation: starts at 0, +1 for every 10 "connections" (each person you've
##   talked to counts once, and each person who became a friend counts again).
## Ten 0..100 scores (data/standing.json): charisma, trust, kindness,
##   intelligence, humor, confidence, notoriety, romance_rep, reliability, coolness.
## Two derived scores: wealth (clothes and money) and looks (Life.body.attractiveness).

signal reputation_changed(value: int)
signal score_changed(id: String, value: float)

var defs: Dictionary = {}
var scores: Dictionary = {}
var by_category: Dictionary = {}
var by_action: Dictionary = {}
## Extra reputation from other systems (crime can pass negatives).
var reputation_offset: int = 0

var _life: Node
var _talked: Dictionary = {}
var _befriended: Dictionary = {}


func _init(life: Node, data: Dictionary) -> void:
	_life = life
	defs = data.get("scores", {})
	by_category = data.get("categories", {})
	by_action = data.get("actions", {})
	reset()


func reset() -> void:
	scores.clear()
	for id in defs:
		scores[id] = float(defs[id].get("start", 50))
	_talked.clear()
	_befriended.clear()
	reputation_offset = 0


func ids() -> Array:
	return defs.keys() + ["wealth", "looks"]


func label(id: String) -> String:
	return {"wealth": "Perceived wealth", "looks": "Looks"}.get(id, str(defs.get(id, {}).get("label", id.capitalize())))


func get_score(id: String) -> float:
	match id:
		"wealth":
			return wealth()
		"looks":
			return _life.body.attractiveness() * 10.0
		"reputation":
			return float(reputation())
	return float(scores.get(id, 50.0))


func change(id: String, delta: float) -> void:
	if not scores.has(id) or delta == 0.0:
		return
	scores[id] = clampf(scores[id] + delta, 0.0, 100.0)
	score_changed.emit(id, scores[id])


func apply(deltas: Dictionary, scale: float = 1.0) -> void:
	for id in deltas:
		change(id, float(deltas[id]) * scale)


## 0..100 from clothes and money on hand.
func wealth() -> float:
	var outfit: float = _life.body.outfit_now()
	var money: float = _life.money.total()
	var m := clampf(log(max(money, 1.0)) / log(100000.0), 0.0, 1.0)
	return clampf(100.0 * (0.65 * outfit + 0.35 * m), 0.0, 100.0)


func connections() -> int:
	return _talked.size() + _befriended.size()


func reputation() -> int:
	return connections() / 10 + reputation_offset


func add_reputation(n: int) -> void:
	reputation_offset += n
	reputation_changed.emit(reputation())


## Called by Life after every NPC interaction.
func note_interaction(npc_id: String) -> void:
	if npc_id == "" or _talked.has(npc_id):
		return
	var before := reputation()
	_talked[npc_id] = true
	if reputation() != before:
		reputation_changed.emit(reputation())


func note_tier(npc_id: String, tier: String) -> void:
	if tier in ["friend", "close_friend", "best_friend"] and not _befriended.has(npc_id):
		var before := reputation()
		_befriended[npc_id] = true
		if reputation() != before:
			reputation_changed.emit(reputation())


func on_action(def: Dictionary, success: bool, scale: float = 1.0) -> void:
	var key := "success" if success else "fail"
	apply(by_category.get(str(def.get("category", "")), {}).get(key, {}), scale)
	apply(by_action.get(str(def.get("id", "")), {}).get(key, {}), scale)
	var extra: Dictionary = def.get("standing", {})
	if success and not extra.is_empty():
		apply(extra, scale)


## How the scores shift an NPC's response to a social or romance action, -0.3..+0.3.
## Traits: kind NPCs like kindness; lawful NPCs dislike notoriety, wild ones
## don't mind it; ambitious NPCs notice wealth and intelligence; outgoing ones
## respond to humor and charisma.
func chance_modifier(def: Dictionary, npc_id: String) -> float:
	var rel = _life.relationships
	var tr := func(t: String) -> float: return rel.trait_value(npc_id, t) if npc_id != "" else 0.5
	var n := func(id: String) -> float: return (get_score(id) - 50.0) / 50.0
	var p := 0.0
	p += 0.05 * n.call("charisma")
	p += 0.04 * n.call("confidence")
	p += 0.01 * clampf(float(reputation()), -10.0, 10.0)
	p += 0.05 * n.call("kindness") * tr.call("kind")
	p -= 0.08 * (get_score("notoriety") / 100.0) * (tr.call("lawful") - tr.call("wild") * 0.5)
	p += 0.04 * n.call("wealth") * tr.call("ambitious")
	p += 0.03 * n.call("intelligence") * tr.call("ambitious")
	p += 0.04 * n.call("humor") * tr.call("outgoing")
	p += 0.03 * n.call("coolness") * tr.call("wild")
	var id := str(def.get("id", ""))
	if id in ["tell_joke", "prank", "friendly_roast", "share_meme", "pickup_line", "tell_story"]:
		p += 0.1 * n.call("humor")
	if id in ["ask_for_money", "ask_favor", "borrow_item", "share_secret", "ask_roommate", "move_in_together"]:
		p += 0.12 * n.call("trust") + 0.05 * n.call("reliability")
	if id in ["debate", "teach_skill", "give_advice", "study_together"]:
		p += 0.1 * n.call("intelligence")
	if def.get("category", "") == "romance":
		p += 0.06 * n.call("romance_rep") + 0.04 * n.call("wealth")
	return clampf(p, -0.3, 0.3)


func summary() -> Dictionary:
	var out := {"reputation": reputation(), "connections": connections()}
	for id in ids():
		out[id] = snappedf(get_score(id), 0.1)
	return out


func to_save() -> Dictionary:
	return {"scores": scores.duplicate(), "talked": _talked.keys(), "befriended": _befriended.keys(),
		"offset": reputation_offset}


func from_save(d: Dictionary) -> void:
	for id in d.get("scores", {}):
		scores[id] = float(d.scores[id])
	_talked.clear()
	for id in d.get("talked", []):
		_talked[str(id)] = true
	_befriended.clear()
	for id in d.get("befriended", []):
		_befriended[str(id)] = true
	reputation_offset = int(d.get("offset", 0))
