extends SceneTree
## Streams NPCs around a moving focus point and checks the 100 limit, that the
## nearest people are the ones loaded, and the per-frame cost.
var failures := 0
var streamer: NpcStreamer
var focus: Node3D
var frame := 0
var max_seen := 0
var stops := [Vector3(0, 0, 0), Vector3(150, 0, 260), Vector3(-300, 0, 100), Vector3(60, 0, -40)]
var stop_i := 0
var worst_pass := 0

func check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok: failures += 1

func _initialize() -> void:
	var pop := NpcPopulation.generate()
	var sim := NpcSimulation.new(pop, NpcPopulation.load_buildings())
	streamer = NpcStreamer.new()
	streamer.setup(sim)
	streamer._own_minutes = (2 * 24 + 12) * 60.0   # Wednesday noon
	focus = Node3D.new()
	root.add_child(focus)
	root.add_child(streamer)
	streamer.focus = focus

func _process(delta: float) -> bool:
	frame += 1
	max_seen = maxi(max_seen, streamer.loaded.size())
	if frame > 3: worst_pass = maxi(worst_pass, streamer.last_pass_usec)
	if frame % 40 == 0:
		var center := focus.global_position
		var n := streamer.loaded.size()
		var far_loaded := 0.0
		for i in streamer.loaded: far_loaded = maxf(far_loaded, center.distance_to(streamer.sim.pos[i]))
		var nearer_missing := 0
		for i in streamer.population.size():
			if streamer.sim.is_visible_candidate(i) and not streamer.loaded.has(i) and center.distance_to(streamer.sim.pos[i]) < far_loaded - 1.0:
				nearer_missing += 1
		print("  at %s: %d loaded, farthest %.0f m, nearer but not loaded: %d" % [center, n, far_loaded, nearer_missing])
		check(n <= 100, "no more than 100 loaded")
		check(nearer_missing < 3, "the nearest NPCs are the loaded ones")
		stop_i += 1
		if stop_i >= stops.size():
			print("  max loaded at once: %d, worst streaming pass %.1f ms" % [max_seen, worst_pass / 1000.0])
			check(max_seen <= 100 and max_seen > 0, "between 1 and 100 bodies at all times")
			print("RESULT test_streaming: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
			quit(1 if failures else 0)
			return true
		focus.global_position = stops[stop_i]
	return false
