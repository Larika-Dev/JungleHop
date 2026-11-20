extends PhysicalMinigame
## Hospital lab centrifuge: load the tubes so the rotor is balanced, then
## press SPIN. An unbalanced rotor shakes and ruins samples.

const SLOTS := 12
const R := 0.16
var n_tubes := 2
var tube_slot := {}     # tube id -> slot index or -1
var slot_used := {}
var _n := 0


func _setup() -> void:
	set_camera(Vector3(0, 0.95, 0.55), Vector3(0, 0, -0.02))
	add_box(Vector3(1.2, 0.03, 0.8), Color(0.96, 0.96, 0.95), Vector3(0, -0.03, 0))  # PAINT_HOSPITAL bench
	add_cylinder(0.22, 0.04, Color(0.56, 0.58, 0.59), Vector3(0, -0.01, -0.05))
	for i in SLOTS:
		var a := TAU * i / SLOTS
		var p := Vector3(cos(a) * R, 0.03, -0.05 + sin(a) * R)
		add_cylinder(0.016, 0.004, Color(0.2, 0.2, 0.22), p)
		add_zone("slot%d" % i, p, 0.025, {"i": i, "angle": a})
	add_box(Vector3(0.12, 0.02, 0.07), Color(0.31, 0.71, 0.42), Vector3(0.42, 0, 0.2))
	add_label("SPIN", Vector3(0.42, 0.06, 0.2), 0.03)
	add_zone("spin", Vector3(0.42, 0, 0.2), 0.07)
	add_label("Tube rack", Vector3(-0.38, 0.12, 0.2), 0.022)


func _new_round() -> void:
	for id in tube_slot.keys():
		remove_item(id)
	tube_slot.clear()
	slot_used.clear()
	var choices := [2, 4] if difficulty < 0.3 else [2, 3, 4, 6] if difficulty < 0.7 else [3, 4, 6]
	n_tubes = pick(choices)
	for i in n_tubes:
		_n += 1
		var id := "tube%d" % _n
		var t := Node3D.new()
		t.position = Vector3(-0.5 + i * 0.05, 0, 0.2)
		world_root.add_child(t)
		add_cylinder(0.008, 0.09, Color(0.92, 0.95, 0.98, 0.7), Vector3.ZERO, t)
		add_cylinder(0.009, 0.015, pick([Color(0.6, 0.4, 0.8), Color(0.8, 0.2, 0.2), Color(0.3, 0.5, 0.85)]), Vector3(0, 0.09, 0), t)
		add_item(id, t, true)
		tube_slot[id] = -1
	set_hint("Load all %d tubes so the rotor balances, then click SPIN." % n_tubes)


func _on_grab(id: String) -> void:
	if tube_slot.get(id, -1) >= 0:
		slot_used.erase(tube_slot[id])
		tube_slot[id] = -1


func _on_drop(id: String, zone: String) -> bool:
	if zone.begins_with("slot") and not slot_used.has(zones[zone].data.i):
		var i: int = zones[zone].data.i
		slot_used[i] = id
		tube_slot[id] = i
		items[id].node.position = zones[zone].pos
		items[id].home = zones[zone].pos
		return true
	return false


func _on_click_ground(p: Vector3) -> void:
	if zone_at(p) == "spin":
		spin()


func imbalance() -> float:
	var v := Vector2.ZERO
	for id in tube_slot:
		var s: int = tube_slot[id]
		if s >= 0:
			var a := TAU * s / SLOTS
			v += Vector2(cos(a), sin(a))
	return v.length() / maxf(1, n_tubes)


func spin() -> void:
	for id in tube_slot:
		if tube_slot[id] < 0:
			set_hint("Load every tube first.")
			return
	var imb := imbalance()
	finish_round(clampf(1.0 - imb * 2.0, 0.0, 1.0) * time_factor(4.0 + 3.0 * n_tubes), "balanced" if imb < 0.01 else "rotor wobbling")


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	var ids := tube_slot.keys()
	for k in ids.size():
		var slot: int = (k * SLOTS / n_tubes) if perfect else k
		move_item_to_zone(ids[k], "slot%d" % slot)
	spin()
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
