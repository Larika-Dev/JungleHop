extends PhysicalMinigame
## Pamlico Coffee House bar: pick the right cup, then carry it through the
## espresso machine (one drop per shot), the steam wand, ice and syrups,
## and set it on the hand-off counter.

const STATIONS := {
	"espresso": [Vector3(-0.28, 0, -0.18), Color(0.23, 0.23, 0.24), "Espresso\n(1 drop = 1 shot)"],
	"steam": [Vector3(-0.02, 0, -0.2), Color(0.56, 0.58, 0.59), "Steamed milk"],
	"ice": [Vector3(0.22, 0, -0.2), Color(0.8, 0.88, 0.92), "Ice"],
	"vanilla": [Vector3(0.42, 0, -0.08), Color(0.89, 0.8, 0.56), "Vanilla"],
	"caramel": [Vector3(0.42, 0, 0.08), Color(0.69, 0.43, 0.19), "Caramel"],
	"handoff": [Vector3(0.12, 0, 0.2), Color(0.64, 0.48, 0.31), "Hand-off"],
}
const SIZES := {"S": 0.028, "M": 0.034, "L": 0.04}

var order := {}
var cup_steps := {}       # cup id -> {espresso:int, steam:int, ...}
var ticket: Label3D


func _setup() -> void:
	set_camera(Vector3(0, 0.95, 0.75), Vector3(0, 0, -0.02))
	add_box(Vector3(1.3, 0.04, 0.7), Color(0.31, 0.21, 0.14), Vector3(0, -0.04, 0))  # WALNUT_DARK counter
	for id in STATIONS:
		var s: Array = STATIONS[id]
		if id == "handoff":
			add_box(Vector3(0.2, 0.01, 0.14), s[1], s[0])
		elif id == "espresso":
			add_box(Vector3(0.2, 0.2, 0.12), s[1], s[0] + Vector3(0, 0, -0.06))
		else:
			add_cylinder(0.035, 0.08 if id != "ice" else 0.05, s[1], s[0] + Vector3(0, 0, -0.05))
		add_label(s[2], s[0] + Vector3(0, 0.16, -0.02), 0.022)
		add_zone(id, s[0], 0.08)
	add_label("Cups", Vector3(-0.47, 0.13, 0.12), 0.022)
	ticket = add_label("", Vector3(-0.05, 0.3, -0.3), 0.03, null, Color(1, 0.95, 0.8))
	for sz in SIZES:
		_spawn_cup(sz)


func _spawn_cup(sz: String) -> void:
	var id := "cup_" + sz + str(Time.get_ticks_usec() % 100000) + str(rng.randi() % 1000)
	var root := Node3D.new()
	var x: float = {"S": -0.55, "M": -0.47, "L": -0.39}[sz]
	root.position = Vector3(x, 0, 0.18)
	world_root.add_child(root)
	var r: float = SIZES[sz]
	var h := r * 2.6
	add_cylinder(r * 0.82, h, Color(0.95, 0.94, 0.91), Vector3.ZERO, root, r)
	var fill := add_cylinder(r * 0.84, 0.002, Color(0.36, 0.22, 0.12), Vector3(0, h, 0), root, r * 0.98)
	fill.visible = false
	add_label(sz, Vector3(0, h + 0.03, 0), 0.02, root)
	add_item(id, root, true, {"size": sz, "fill": fill})
	cup_steps[id] = {}


func _new_round() -> void:
	var sz: String = pick(SIZES.keys())
	var milk: String = pick(["steam", "steam", "ice", "none"])
	var syrup: String = pick(["none", "vanilla", "caramel"]) if rng.randf() < 0.5 + 0.4 * difficulty else "none"
	var shots := rng.randi_range(1, 2 + int(difficulty))
	order = {"size": sz, "steps": {"espresso": shots}}
	if milk != "none":
		order.steps[milk] = 1
	if syrup != "none":
		order.steps[syrup] = 1
	var name_s: String = {"steam": "latte", "ice": "iced americano", "none": "americano"}[milk]
	ticket.text = "ORDER: %s %s%s\n%d shot%s%s" % [{"S": "Small", "M": "Medium", "L": "Large"}[sz],
		(syrup.capitalize() + " ") if syrup != "none" else "", name_s, shots, "s" if shots > 1 else "",
		"" if milk == "none" else (", steamed milk" if milk == "steam" else ", over ice")]
	set_hint("Drag the right cup through each station, then set it on the hand-off counter.")


func _on_drop(id: String, zone: String) -> bool:
	if zone == "" or not cup_steps.has(id):
		return false
	if zone == "handoff":
		_serve(id)
		return true
	var st: Dictionary = cup_steps[id]
	st[zone] = int(st.get(zone, 0)) + 1
	var fill: MeshInstance3D = items[id].data.fill
	fill.visible = true
	var total := 0
	for k in st:
		total += st[k]
	fill.position.y = minf(0.1, 0.02 + 0.012 * total)
	items[id].home = items[id].node.position
	return true


func _serve(id: String) -> void:
	var st: Dictionary = cup_steps[id]
	var size_ok: bool = items[id].data.size == order.size
	var want: Dictionary = order.steps
	var errors := 0
	var keys := {}
	for k in want:
		keys[k] = true
	for k in st:
		keys[k] = true
	for k in keys:
		errors += absi(int(want.get(k, 0)) - int(st.get(k, 0)))
	var steps_total := 0
	for k in want:
		steps_total += want[k]
	var score := (0.25 if size_ok else 0.0) + 0.75 * clampf(1.0 - float(errors) / steps_total, 0.0, 1.0)
	var sz: String = items[id].data.size
	cup_steps.erase(id)
	remove_item(id)
	_spawn_cup(sz)
	finish_round(score * time_factor(8.0 + 2.0 * steps_total), "" if size_ok else "wrong size")


func _cup_of(sz: String) -> String:
	for id in cup_steps:
		if items.has(id) and items[id].data.size == sz and cup_steps[id].is_empty():
			return id
	return ""


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	var cup := _cup_of(order.size if perfect else ("S" if order.size != "S" else "L"))
	for k in order.steps:
		var n: int = order.steps[k] if perfect else 0
		for i in n:
			move_item_to_zone(cup, k)
	if not perfect:
		move_item_to_zone(cup, "caramel" if not order.steps.has("caramel") else "ice")
	move_item_to_zone(cup, "handoff")
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
