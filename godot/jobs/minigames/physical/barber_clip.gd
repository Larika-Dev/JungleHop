extends PhysicalMinigame
## Sweet Gum Barber Shop (view from above the client's head): run the
## clippers over the sides and back, keep them off the top.

const HEAD_R := 0.11
var keep_r := 0.06
var tufts: Array = []  # {pos, keep: bool, cut: bool, node}


func _setup() -> void:
	set_camera(Vector3(0, 0.55, 0.32), Vector3(0, 0, -0.01))
	add_box(Vector3(0.7, 0.02, 0.5), Color(0.17, 0.14, 0.13), Vector3(0, -0.03, 0))  # cape
	add_cylinder(HEAD_R + 0.01, 0.01, Color(0.78, 0.6, 0.48), Vector3(0, -0.01, 0))
	var c := Node3D.new()
	c.position = Vector3(0.24, 0, 0.14)
	world_root.add_child(c)
	add_box(Vector3(0.03, 0.025, 0.07), Color(0.56, 0.58, 0.59), Vector3.ZERO, c)
	add_item("clippers", c, true)
	add_box(Vector3(0.08, 0.004, 0.08), Color(0.31, 0.21, 0.14), Vector3(0.24, 0, 0.14))
	add_label("Done: set clippers here", Vector3(0.24, 0.04, 0.17), 0.013)
	add_zone("tray", Vector3(0.24, 0, 0.14), 0.045)


func _new_round() -> void:
	for t in tufts:
		t.node.queue_free()
	tufts.clear()
	keep_r = 0.065 - 0.015 * difficulty
	var col: Color = pick([Color(0.15, 0.1, 0.07), Color(0.35, 0.22, 0.12), Color(0.06, 0.05, 0.05), Color(0.6, 0.45, 0.25)])
	var step := 0.012
	var x := -HEAD_R
	while x <= HEAD_R:
		var z := -HEAD_R
		while z <= HEAD_R:
			var r := Vector2(x, z).length()
			if r <= HEAD_R:
				var keep := r < keep_r
				var n := add_box(Vector3(0.009, 0.018, 0.009), col.lightened(0.08) if keep else col, Vector3(x, 0, z))
				tufts.append({"pos": Vector3(x, 0, z), "keep": keep, "cut": false, "node": n})
			z += step
		x += step
	add_cylinder(keep_r, 0.0012, Color(1, 1, 1, 0.12), Vector3(0, 0.02, 0))
	items["clippers"].node.position = items["clippers"].home
	set_hint("Clip everything outside the light circle on top. Set the clippers down when done.")


func clip_at(p: Vector3) -> void:
	for t in tufts:
		if not t.cut and Vector2(p.x - t.pos.x, p.z - t.pos.z).length() < 0.016:
			t.cut = true
			t.node.scale.y = 0.15


func _phys_process(_d: float) -> void:
	if held == "clippers" and mouse_down and not _waiting_next:
		clip_at(items["clippers"].node.position)


func result() -> float:
	var ring := 0
	var ring_cut := 0
	var top := 0
	var top_cut := 0
	for t in tufts:
		if t.keep:
			top += 1
			top_cut += int(t.cut)
		else:
			ring += 1
			ring_cut += int(t.cut)
	return clampf(float(ring_cut) / maxf(1, ring) - 2.0 * float(top_cut) / maxf(1, top), 0.0, 1.0)


func _on_drop(id: String, zone: String) -> bool:
	if id == "clippers" and zone == "tray":
		finish_round(result() * time_factor(25.0))
	return false


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	for t in tufts:
		if perfect != t.keep:
			t.cut = true
	move_item_to_zone("clippers", "tray")
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
