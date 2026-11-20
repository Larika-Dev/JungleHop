extends PhysicalMinigame
## Student Union floor: drag the mop over spills. They spread the longer they sit.

const FLOOR := Vector2(1.5, 0.9)
var spills: Array = []  # {pos: Vector3, r: float, dirt: float, age: float, node}
var wave := 3
var spawned := 0
var cleaned_scores: Array[float] = []
var spawn_timer := 0.0


func _setup() -> void:
	set_camera(Vector3(0, 1.25, 0.75), Vector3(0, 0, -0.05))
	add_box(Vector3(FLOOR.x, 0.02, FLOOR.y), Color(0.85, 0.83, 0.78), Vector3(0, -0.02, 0))  # VCT_A
	var mop := Node3D.new()
	mop.position = Vector3(0.6, 0, 0.35)
	world_root.add_child(mop)
	add_box(Vector3(0.12, 0.03, 0.05), Color(0.9, 0.88, 0.8), Vector3.ZERO, mop)
	add_cylinder(0.008, 0.35, Color(0.13, 0.25, 0.48), Vector3(0, 0.03, 0), mop)
	add_item("mop", mop, true)


func _new_round() -> void:
	for s in spills:
		s.node.queue_free()
	spills.clear()
	cleaned_scores.clear()
	wave = 3 + int(difficulty * 3)
	spawned = 0
	spawn_timer = 0.0
	_spawn()
	set_hint("Grab the mop and scrub each spill until it's gone.")


func _spawn() -> void:
	spawned += 1
	var p := Vector3(rng.randf_range(-0.6, 0.6), 0.001, rng.randf_range(-0.35, 0.35))
	var n := add_cylinder(0.04, 0.002, pick([Color(0.42, 0.26, 0.12, 0.8), Color(0.6, 0.7, 0.2, 0.75), Color(0.5, 0.1, 0.15, 0.8)]), p)
	spills.append({"pos": p, "r": 0.04, "dirt": 1.0, "age": 0.0, "node": n})


func _on_drop(_id: String, _zone: String) -> bool:
	items["mop"].home = items["mop"].node.position
	return true


func scrub(p: Vector3, delta: float) -> void:
	for s in spills.duplicate():
		if Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < s.r + 0.05:
			s.dirt -= delta * 1.4 * (0.05 / s.r)
			if s.dirt <= 0.0:
				cleaned_scores.append(clampf(1.15 - s.age / (12.0 - 4.0 * difficulty), 0.0, 1.0))
				s.node.queue_free()
				spills.erase(s)


func _phys_process(delta: float) -> void:
	if _waiting_next:
		return
	for s in spills:
		s.age += delta
		s.r = minf(0.16, s.r + delta * 0.004 * (1.0 + difficulty))
		s.node.scale = Vector3(s.r / 0.04, 1, s.r / 0.04)
	if held == "mop":
		scrub(items["mop"].node.position, delta)
	spawn_timer += delta
	if spawned < wave and (spawn_timer > 3.0 or spills.is_empty()):
		spawn_timer = 0.0
		_spawn()
	if spawned >= wave and spills.is_empty():
		var t := 0.0
		for x in cleaned_scores:
			t += x
		finish_round(t / maxf(1, wave))
	elif round_time > 60.0:
		var t2 := 0.0
		for x in cleaned_scores:
			t2 += x
		finish_round(t2 / maxf(1, wave), "spills left behind")


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	var dt := 0.1
	var steps := 0
	while scores.size() == before and steps < 1000:
		steps += 1
		round_time += dt
		if perfect and not spills.is_empty():
			grab("mop")
			items["mop"].node.position = spills[0].pos
		elif not perfect:
			held = ""
		_phys_process(dt)
	held = ""
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
