extends PhysicalMinigame
## Late Night Lo Mein deliveries: ride the scooter (WASD / arrows) through a
## few blocks of Cathedral Mount and reach every drop-off.

const BLOCK := 0.34
const STREET := 0.1
const GRID := 4
const SPEED := 0.32
var drops: Array = []   # {pos, node, done}
var par := 20.0
var scooter: Node3D


func _setup() -> void:
	set_camera(Vector3(0, 1.75, 0.55), Vector3(0, 0, -0.02))
	var span := GRID * BLOCK
	add_box(Vector3(span + STREET, 0.01, span + STREET), Color(0.29, 0.29, 0.3), Vector3(0, -0.01, 0))  # ASPHALT_AGED
	for i in GRID:
		for j in GRID:
			var c := _cell_center(i, j)
			var hgt := 0.04 + rng.randf() * 0.1
			add_box(Vector3(BLOCK - STREET, hgt, BLOCK - STREET), pick([Color(0.61, 0.31, 0.22), Color(0.69, 0.38, 0.25), Color(0.91, 0.89, 0.85)]), c)
	scooter = Node3D.new()
	world_root.add_child(scooter)
	add_box(Vector3(0.035, 0.03, 0.06), Color(0.66, 0.2, 0.16), Vector3.ZERO, scooter)
	add_item("scooter", scooter, false)


func _cell_center(i: int, j: int) -> Vector3:
	var o := -GRID * BLOCK * 0.5 + BLOCK * 0.5
	return Vector3(o + i * BLOCK, 0, o + j * BLOCK)


func _street_coord(k: int) -> float:
	return -GRID * BLOCK * 0.5 + k * BLOCK


func on_street(p: Vector3) -> bool:
	var half := GRID * BLOCK * 0.5 + 0.001
	if absf(p.x) > half or absf(p.z) > half:
		return false
	var fx := fposmod(p.x + GRID * BLOCK * 0.5, BLOCK)
	var fz := fposmod(p.z + GRID * BLOCK * 0.5, BLOCK)
	var w := STREET * 0.5
	return fx < w or fx > BLOCK - w or fz < w or fz > BLOCK - w


func _new_round() -> void:
	for d in drops:
		d.node.queue_free()
	drops.clear()
	scooter.position = Vector3(_street_coord(0), 0, _street_coord(GRID))
	var n := 3 + int(difficulty * 2)
	var dist := 0.0
	var last := scooter.position
	for i in n:
		var p: Vector3
		if rng.randf() < 0.5:
			p = Vector3(_street_coord(rng.randi_range(0, GRID)), 0, _cell_center(0, rng.randi_range(0, GRID - 1)).z)
		else:
			p = Vector3(_cell_center(rng.randi_range(0, GRID - 1), 0).x, 0, _street_coord(rng.randi_range(0, GRID)))
		var node := add_cylinder(0.02, 0.06, Color(0.91, 0.73, 0.14), p)
		drops.append({"pos": p, "node": node, "done": false})
		dist += absf(p.x - last.x) + absf(p.z - last.z)
		last = p
	par = dist / SPEED * 1.4 + 4.0
	set_hint("Ride with WASD or the arrow keys. Hit every yellow drop-off. Par: %d s" % int(par))


func steer(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	var step := Vector3(dir.x, 0, dir.y).normalized() * SPEED * delta
	var tryp := scooter.position + step
	if on_street(tryp):
		scooter.position = tryp
	elif on_street(scooter.position + Vector3(step.x, 0, 0)):
		scooter.position += Vector3(step.x, 0, 0)
	elif on_street(scooter.position + Vector3(0, 0, step.z)):
		scooter.position += Vector3(0, 0, step.z)
	scooter.rotation.y = atan2(-dir.x, -dir.y)
	_check_drops()


func _check_drops() -> void:
	var left := 0
	for d in drops:
		if not d.done and scooter.position.distance_to(d.pos) < 0.05:
			d.done = true
			d.node.visible = false
		if not d.done:
			left += 1
	if left == 0 and not drops.is_empty() and not _waiting_next:
		finish_round(time_factor(par), "%.0f s (par %d)" % [round_time, int(par)])


func _phys_process(delta: float) -> void:
	if _waiting_next or not is_visible_in_tree():
		return
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): d.x += 1
	steer(d, delta)


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	round_time = par * (0.8 if perfect else 4.0)
	for d in drops:
		scooter.position = d.pos
		_check_drops()
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
