extends RefCounted
## Skills rise with use. Level 0 to 10; level n -> n+1 costs 100 * 1.15^n XP.

signal skill_leveled(id: String, level: int)
signal xp_gained(id: String, amount: float)

const MAX_LEVEL := 10
const DEFAULT_SKILLS := ["charm", "fitness", "cooking", "logic", "creativity", "music",
	"mechanics", "athletics", "stealth", "writing", "gaming", "knowledge"]

var xp_by_skill: Dictionary = {}


func _init() -> void:
	for s in DEFAULT_SKILLS:
		xp_by_skill[s] = 0.0


func ids() -> Array:
	return xp_by_skill.keys()


static func xp_for_level(level: int) -> float:
	var total := 0.0
	for n in range(level):
		total += 100.0 * pow(1.15, n)
	return total


func xp(id: String) -> float:
	return float(xp_by_skill.get(id, 0.0))


func level(id: String) -> int:
	var x := xp(id)
	var lv := 0
	while lv < MAX_LEVEL and x >= xp_for_level(lv + 1):
		lv += 1
	return lv


## Progress 0..1 toward the next level.
func progress(id: String) -> float:
	var lv := level(id)
	if lv >= MAX_LEVEL:
		return 1.0
	var a := xp_for_level(lv)
	var b := xp_for_level(lv + 1)
	return (xp(id) - a) / (b - a)


func add_xp(id: String, amount: float) -> void:
	if amount == 0.0:
		return
	var before := level(id)
	xp_by_skill[id] = max(0.0, xp(id) + amount)
	xp_gained.emit(id, amount)
	var after := level(id)
	if after > before:
		skill_leveled.emit(id, after)


func to_save() -> Dictionary:
	return xp_by_skill.duplicate()


func from_save(d: Dictionary) -> void:
	for id in d:
		xp_by_skill[id] = float(d[id])
