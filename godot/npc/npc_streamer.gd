## Keeps at most MAX_LOADED NPC bodies in the world: the nearest ones to the
## player that are not riding or gone. Bodies are pooled and reused.
## Added under GameState.world by the NPCs autoload; also usable standalone.
class_name NpcStreamer
extends Node3D

signal npc_loaded(index: int, body: NpcBody)
signal npc_unloaded(index: int)

var sim: NpcSimulation
var population: Array
## The node whose position decides who loads. Defaults to GameState.get_player(),
## then the active camera.
var focus: Node3D
var max_loaded: int = NpcConfig.MAX_LOADED
var load_radius: float = NpcConfig.LOAD_RADIUS

var loaded := {}          # index -> NpcBody
var _pool: Array = []
var _accum := 999.0
var _order: Array = []    # loaded indices, nearest first
var _own_minutes := 8.0 * 60.0
var last_pass_usec := 0


func setup(p_sim: NpcSimulation) -> void:
	sim = p_sim
	population = sim.population


func _process(delta: float) -> void:
	if sim == null:
		return
	_apply_settings()
	var t := game_hours(delta)
	_accum += delta
	if _accum >= NpcConfig.STREAM_INTERVAL:
		_accum = 0.0
		var t0 := Time.get_ticks_usec()
		sim.update_all(t)
		_select()
		last_pass_usec = Time.get_ticks_usec() - t0
	var center := _focus_pos()
	var lod0_left := NpcConfig.LOD0_BUDGET
	for i in _order:
		var body: NpcBody = loaded.get(i)
		if body == null:
			continue
		if body.has_meta("talking"):
			# Stand still and face the player while a conversation is open.
			body.animate(delta, 0.0)
			continue
		sim.update_one(i, t)
		var p := sim.pos[i]
		var moving := sim.state[i] == NpcSimulation.WALKING
		var before := body.global_position
		body.global_position = p
		if moving:
			body.rotation.y = lerp_angle(body.rotation.y, sim.heading[i], clampf(delta * 8.0, 0.0, 1.0))
		var d := center.distance_to(p)
		var l := 2
		if d < NpcConfig.LOD0_DISTANCE and lod0_left > 0:
			l = 0
			lod0_left -= 1
		elif d < NpcConfig.LOD1_DISTANCE:
			l = 1
		body.set_lod(l)
		var spd := 0.0
		if moving and delta > 0.0:
			spd = before.distance_to(p) / delta if before.distance_to(p) < 5.0 else float(population[i].walk_speed)
		if l < 2 or Engine.get_process_frames() % 3 == i % 3:
			body.animate(delta if l < 2 else delta * 3.0, spd)


## Game hours since Day 1 00:00 from GameClock, or an internal clock when the
## foundation's clock is not running (tests, tools).
func game_hours(delta: float) -> float:
	var clock := get_node_or_null("/root/GameClock")
	if clock:
		return float(clock.total_minutes) / 60.0
	_own_minutes += delta * 60.0 / NpcConfig.REAL_SECONDS_PER_GAME_HOUR
	return _own_minutes / 60.0


func _apply_settings() -> void:
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return
	if "quality" in s:
		max_loaded = [40, 70, 100, 100][clampi(int(s.quality), 0, 3)]
	if "view_distance" in s:
		load_radius = minf(NpcConfig.LOAD_RADIUS, maxf(40.0, float(s.view_distance)))


func _focus_pos() -> Vector3:
	if focus == null or not is_instance_valid(focus):
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("get_player"):
			focus = gs.get_player()
	if focus and is_instance_valid(focus):
		return focus.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.ZERO


func _select() -> void:
	var center := _focus_pos()
	var r_in := load_radius * load_radius
	var r_out := (load_radius + NpcConfig.UNLOAD_RADIUS - NpcConfig.LOAD_RADIUS)
	r_out *= r_out
	var cand: Array = []
	var n := population.size()
	for i in n:
		if not sim.is_visible_candidate(i):
			continue
		var d2 := center.distance_squared_to(sim.pos[i])
		if d2 < r_in or (d2 < r_out and loaded.has(i)):
			cand.append(Vector2(d2, i))
	cand.sort_custom(func(a, b): return a.x < b.x)
	if cand.size() > max_loaded:
		cand.resize(max_loaded)
	var keep := {}
	_order.clear()
	for c in cand:
		keep[int(c.y)] = true
		_order.append(int(c.y))
	for i in loaded.keys():
		if not keep.has(i):
			_unload(i)
	for i in _order:
		if not loaded.has(i):
			_load(i)


func _load(i: int) -> void:
	var body: NpcBody
	if _pool.is_empty():
		body = NpcBody.new()
		add_child(body)
	else:
		body = _pool.pop_back()
		body.visible = true
		body.process_mode = Node.PROCESS_MODE_INHERIT
		body.collider.collision_layer = (1 << 2) | (1 << 3)
		body.add_to_group("npc")
	body.apply_record(population[i])
	body.global_position = sim.pos[i]
	body.rotation.y = sim.heading[i]
	body.set_lod(2)
	loaded[i] = body
	npc_loaded.emit(i, body)


func _unload(i: int) -> void:
	var body: NpcBody = loaded[i]
	loaded.erase(i)
	body.visible = false
	body.collider.collision_layer = 0
	body.remove_from_group("npc")
	_pool.append(body)
	npc_unloaded.emit(i)


func body_of(i: int) -> NpcBody:
	return loaded.get(i)
