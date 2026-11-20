extends PhysicalMinigame
## Pitch Soles Tattoo: hold the machine and trace the stencil line. Ink that
## strays off the line costs you.

const ON_LINE := 0.012
const STRAY := 0.022
var path: PackedVector3Array = []
var samples: PackedVector3Array = []
var inked: PackedByteArray = []
var stray_count := 0
var ink_count := 0
var _dots: Array = []
var _last_ink := Vector3(INF, 0, 0)


func _setup() -> void:
	set_camera(Vector3(0, 0.62, 0.32), Vector3(0, 0, -0.02))
	add_box(Vector3(0.6, 0.02, 0.36), Color(0.78, 0.6, 0.48), Vector3(0, -0.02, 0))  # forearm skin
	var m := Node3D.new()
	m.position = Vector3(0.24, 0, 0.12)
	world_root.add_child(m)
	add_cylinder(0.008, 0.11, Color(0.1, 0.1, 0.1), Vector3.ZERO, m, 0.014)
	add_item("needle", m, true)
	add_box(Vector3(0.08, 0.005, 0.06), Color(0.56, 0.58, 0.59), Vector3(0.24, 0, 0.12))
	add_label("Done: set it here", Vector3(0.24, 0.04, 0.15), 0.014)
	add_zone("tray", Vector3(0.24, 0, 0.12), 0.04)


func _new_round() -> void:
	for d in _dots:
		d.queue_free()
	_dots.clear()
	path = PackedVector3Array()
	var n := 5 + int(difficulty * 4)
	var x := -0.18
	for i in n:
		path.append(Vector3(x, 0.001, rng.randf_range(-0.09, 0.09)))
		x += 0.33 / (n - 1)
	samples = PackedVector3Array()
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		var k := int(seg / 0.005)
		for j in k:
			samples.append(path[i].lerp(path[i + 1], float(j) / k))
	samples.append(path[path.size() - 1])
	inked = PackedByteArray()
	inked.resize(samples.size())
	inked.fill(0)
	stray_count = 0
	ink_count = 0
	for i in samples.size():
		if i % 3 == 0:
			_dots.append(add_cylinder(0.0018, 0.0006, Color(0.3, 0.45, 0.7), samples[i]))
	items["needle"].node.position = items["needle"].home
	set_hint("Pick up the machine and trace the blue stencil. Set it on the tray when finished.")


func _dist_to_path(p: Vector3) -> float:
	var best := INF
	for i in path.size() - 1:
		var a := Vector2(path[i].x, path[i].z)
		var b := Vector2(path[i + 1].x, path[i + 1].z)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
		best = minf(best, q.distance_to(Vector2(p.x, p.z)))
	return best


func ink_at(p: Vector3) -> void:
	ink_count += 1
	if _dist_to_path(p) > STRAY:
		stray_count += 1
	for i in samples.size():
		if inked[i] == 0 and Vector2(p.x - samples[i].x, p.z - samples[i].z).length() < ON_LINE:
			inked[i] = 1
	if p.distance_to(_last_ink) > 0.004 and _dots.size() < 900:
		_last_ink = p
		_dots.append(add_cylinder(0.0022, 0.0008, Color(0.05, 0.05, 0.06), Vector3(p.x, 0.0015, p.z)))


func coverage() -> float:
	var c := 0
	for v in inked:
		c += v
	return float(c) / maxf(1, inked.size())


func _phys_process(_d: float) -> void:
	if held == "needle" and mouse_down and not _waiting_next:
		var p: Vector3 = items["needle"].node.position
		if zone_at(p) != "tray":
			ink_at(p)


func _on_drop(id: String, zone: String) -> bool:
	if id == "needle" and zone == "tray" and ink_count > 0:
		_score()
	return false


func _score() -> void:
	var stray := float(stray_count) / maxf(1, ink_count)
	finish_round((coverage() * 0.75 + (1.0 - stray) * 0.25) * time_factor(8.0 + 2.0 * path.size()))


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	if perfect:
		for s in samples:
			ink_at(s)
	else:
		for i in 40:
			ink_at(Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.15, 0.15)))
	move_item_to_zone("needle", "tray")
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
