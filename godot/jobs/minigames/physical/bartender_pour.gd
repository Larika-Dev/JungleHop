extends PhysicalMinigame
## Top of the Mount bar: lift bottles over the glass to pour (it pours while
## you hold it there), stop at the right amount, slide the glass to the guest.

const POUR_ML_S := 30.0
const PART_ML := 15.0
const BOTTLES := {
	"vodka": Color(0.86, 0.9, 0.93), "gin": Color(0.62, 0.8, 0.74), "rum": Color(0.55, 0.33, 0.16),
	"bourbon": Color(0.69, 0.4, 0.15), "ginger beer": Color(0.85, 0.74, 0.45), "tonic": Color(0.88, 0.92, 0.95),
	"lime": Color(0.55, 0.75, 0.3), "cola": Color(0.25, 0.13, 0.08),
}
const RECIPES := [
	["Ridge Mule", {"vodka": 3, "ginger beer": 6, "lime": 1}],
	["Quad Tonic", {"gin": 3, "tonic": 7}],
	["Billram Punch", {"rum": 3, "cola": 6, "lime": 1}],
	["Hamilton Smash", {"bourbon": 4, "ginger beer": 4, "lime": 1}],
	["Carillon Cooler", {"gin": 2, "lime": 1, "tonic": 5}],
	["Night Owl", {"rum": 2, "bourbon": 2, "cola": 5}],
]

var recipe: Array = []
var poured := {}
var glass_fill: MeshInstance3D
var readout: Label3D


func _setup() -> void:
	set_camera(Vector3(0, 0.9, 0.7), Vector3(0, 0, -0.05))
	add_box(Vector3(1.4, 0.04, 0.7), Color(0.17, 0.14, 0.13), Vector3(0, -0.04, 0))  # PAINT_BAR_DARK bar top
	var names := BOTTLES.keys()
	for i in names.size():
		var b := Node3D.new()
		b.position = Vector3(-0.56 + i * 0.16, 0, -0.22)
		world_root.add_child(b)
		add_cylinder(0.028, 0.16, BOTTLES[names[i]], Vector3.ZERO, b)
		add_cylinder(0.01, 0.05, BOTTLES[names[i]].darkened(0.3), Vector3(0, 0.16, 0), b)
		add_label(names[i], Vector3(0, 0.25, 0), 0.02, b)
		add_item("b_" + names[i], b, true, {"liquor": names[i]})
	var g := Node3D.new()
	g.position = Vector3(0, 0, 0.08)
	world_root.add_child(g)
	add_cylinder(0.035, 0.11, Color(0.9, 0.95, 1.0, 0.35), Vector3.ZERO, g, 0.04)
	glass_fill = add_cylinder(0.033, 0.001, Color(0.7, 0.5, 0.2, 0.9), Vector3(0, 0.003, 0), g)
	add_item("glass", g, true)
	add_zone("glass", g.position, 0.07)
	add_box(Vector3(0.18, 0.005, 0.14), Color(0.42, 0.12, 0.1), Vector3(0.5, 0, 0.2))
	add_label("Guest", Vector3(0.5, 0.08, 0.2), 0.024)
	add_zone("guest", Vector3(0.5, 0, 0.2), 0.1)
	readout = add_label("", Vector3(-0.45, 0.12, 0.2), 0.024, null, Color(1, 0.86, 0.6))


func _new_round() -> void:
	recipe = pick(RECIPES)
	poured = {}
	items["glass"].node.position = items["glass"].home
	_update_glass()
	set_hint("Hold a bottle over the glass to pour. Drag the glass to the guest when it's right.")


func _on_hover(id: String, zone: String, delta: float) -> void:
	if zone == "glass" and id.begins_with("b_"):
		var l: String = items[id].data.liquor
		poured[l] = float(poured.get(l, 0.0)) + POUR_ML_S * delta
		items[id].node.rotation.z = -1.2
		_update_glass()


func _on_grab(id: String) -> void:
	if id == "glass":
		zones.erase("glass")


func _on_drop(id: String, zone: String) -> bool:
	if id.begins_with("b_"):
		items[id].node.rotation.z = 0.0
		return false
	if id == "glass":
		if zone == "guest":
			_serve()
			return false
		add_zone("glass", items["glass"].home, 0.07)
	return false


func _phys_process(_d: float) -> void:
	if held != "glass" and not zones.has("glass") and items.has("glass"):
		add_zone("glass", items["glass"].node.position, 0.07)


func _update_glass() -> void:
	var total := 0.0
	for k in poured:
		total += poured[k]
	var h := clampf(total / 220.0, 0.0, 1.0) * 0.1
	(glass_fill.mesh as CylinderMesh).height = maxf(0.001, h)
	glass_fill.position.y = h * 0.5 + 0.003
	var lines := "%s\n" % recipe[0]
	for k in recipe[1]:
		lines += "%s  %d / %d ml\n" % [k, roundi(poured.get(k, 0.0)), int(recipe[1][k] * PART_ML)]
	readout.text = lines


func pour_score() -> float:
	var target: Dictionary = recipe[1]
	var err := 0.0
	var want_total := 0.0
	for k in target:
		want_total += target[k] * PART_ML
		err += absf(float(poured.get(k, 0.0)) - target[k] * PART_ML)
	for k in poured:
		if not target.has(k):
			err += poured[k] * 1.5
	return clampf(1.0 - 1.6 * err / want_total, 0.0, 1.0)


func _serve() -> void:
	var s := pour_score()
	finish_round(s * time_factor(14.0), "")


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	for k in recipe[1]:
		poured[k] = recipe[1][k] * PART_ML * (1.0 if perfect else 1.9)
	if not perfect:
		poured["cola" if not recipe[1].has("cola") else "tonic"] = 40.0
	move_item_to_zone("glass", "guest")
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
