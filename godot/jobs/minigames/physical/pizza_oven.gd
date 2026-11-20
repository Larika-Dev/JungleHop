extends PhysicalMinigame
## Mount Pizza Co. deck oven: slide raw pies onto free decks, pull them at
## golden brown and set them on the cooling rack.

const RAW := Color(0.93, 0.86, 0.66)
const DONE := Color(0.78, 0.5, 0.2)
const BURNT := Color(0.15, 0.1, 0.07)

var cook_time := 14.0
var pies := {}           # id -> {cook: float, slot: String}
var _counter := 0


func _setup() -> void:
	set_camera(Vector3(0, 1.0, 0.8), Vector3(0, 0, -0.08))
	cook_time = 14.0 - 5.0 * difficulty
	add_box(Vector3(1.5, 0.04, 0.8), Color(0.62, 0.62, 0.6), Vector3(0, -0.04, 0.05))  # steel prep table
	add_box(Vector3(0.95, 0.3, 0.06), Color(0.56, 0.24, 0.17), Vector3(0, 0, -0.34))  # oven brick face
	add_label("DECK OVEN", Vector3(0, 0.36, -0.33), 0.03)
	for i in 3:
		var p := Vector3(-0.3 + i * 0.3, 0, -0.2)
		add_box(Vector3(0.26, 0.005, 0.2), Color(0.3, 0.27, 0.25), p)
		add_zone("oven%d" % i, p, 0.11, {"free": true})
	add_box(Vector3(0.24, 0.005, 0.2), Color(0.85, 0.85, 0.82), Vector3(-0.5, 0, 0.22))
	add_label("Prep", Vector3(-0.5, 0.06, 0.22), 0.022)
	add_zone("prep", Vector3(-0.5, 0, 0.22), 0.12)
	for i in 3:
		add_box(Vector3(0.24, 0.004, 0.012), Color(0.45, 0.47, 0.48), Vector3(0.5, 0.01, 0.15 + i * 0.05))
	add_label("Rack (done)", Vector3(0.5, 0.06, 0.22), 0.022)
	add_zone("rack", Vector3(0.5, 0, 0.22), 0.13)
	_spawn_pie()


func _spawn_pie() -> String:
	_counter += 1
	var id := "pie%d" % _counter
	var n := Node3D.new()
	n.position = Vector3(-0.5, 0, 0.22)
	world_root.add_child(n)
	var dough := add_cylinder(0.09, 0.015, RAW, Vector3.ZERO, n)
	dough.material_override = dough.material_override.duplicate()
	add_cylinder(0.075, 0.004, Color(0.7, 0.18, 0.12), Vector3(0, 0.015, 0), n)  # sauce
	add_item(id, n, true, {"dough": dough})
	pies[id] = {"cook": 0.0, "slot": ""}
	return id


func _new_round() -> void:
	set_hint("Drag a raw pie onto a free deck. Pull it out when it's golden and drop it on the rack.")


func _on_grab(id: String) -> void:
	if pies.has(id) and pies[id].slot != "":
		zones[pies[id].slot].data.free = true
		pies[id].slot = ""


func _on_drop(id: String, zone: String) -> bool:
	if not pies.has(id):
		return false
	if zone.begins_with("oven") and zones[zone].data.free:
		zones[zone].data.free = false
		pies[id].slot = zone
		items[id].node.position = zones[zone].pos
		items[id].home = zones[zone].pos
		if not _pie_on_prep():
			_spawn_pie()
		return true
	if zone == "rack" and pies[id].cook > 0.05:
		_deliver(id)
		return true
	return false


func _pie_on_prep() -> bool:
	for id in pies:
		if pies[id].slot == "" and pies[id].cook == 0.0:
			return true
	return false


func pie_score(cook: float) -> float:
	return clampf(1.0 - absf(cook - 1.0) * 2.5, 0.0, 1.0)


func _deliver(id: String) -> void:
	var c: float = pies[id].cook
	pies.erase(id)
	remove_item(id)
	if not _pie_on_prep():
		_spawn_pie()
	finish_round(pie_score(c), "burnt" if c > 1.3 else "underdone" if c < 0.7 else "")


func _phys_process(delta: float) -> void:
	for id in pies:
		var p: Dictionary = pies[id]
		if p.slot != "":
			p.cook += delta / cook_time
			var c: float = p.cook
			var col := RAW.lerp(DONE, clampf(c, 0, 1)) if c <= 1.0 else DONE.lerp(BURNT, clampf((c - 1.0) / 0.6, 0, 1))
			(items[id].data.dough.material_override as StandardMaterial3D).albedo_color = col


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	var id := ""
	for k in pies:
		if pies[k].slot == "" and pies[k].cook == 0.0:
			id = k
	if id == "":
		id = _spawn_pie()
	var slot := ""
	for z in zones:
		if z.begins_with("oven") and zones[z].data.free:
			slot = z
	if slot == "":
		return 0.0
	move_item_to_zone(id, slot)
	pies[id].cook = 1.0 if perfect else 1.6
	move_item_to_zone(id, "rack")
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
