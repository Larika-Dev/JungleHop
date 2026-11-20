extends Node
## Headless smoke test: godot --headless res://tests/smoke_test.tscn
## Loads the city, checks spawn, interiors, doors, floor travel, clock and save/load. Exit code 0 = pass.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	# clock
	var hours := [0]
	GameClock.hour_passed.connect(func(_d, _h): hours[0] += 1)
	GameClock.set_time(1, 8, 0)
	GameClock.advance_minutes(150)
	check(GameClock.hour == 10 and GameClock.minute == 30 and hours[0] == 2, "clock: advance 150 min -> 10:30, 2 hour signals (%s, %d)" % [GameClock.time_string(), hours[0]])
	check(is_equal_approx(GameClock.GAME_MINUTES_PER_REAL_SECOND, 1.0), "clock: 1 game hour per real minute")
	# city
	GameState.player_profile = GameState.default_profile()
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child(city)
	for i in 120:
		await get_tree().physics_frame
	var p: CharacterBody3D = GameState.get_player()
	check(p != null, "player spawned")
	check(p.is_on_floor(), "player standing on ground at %s" % p.global_position)
	var streamer: InteriorStreamer = city.get_node("Interiors")
	check(streamer.loaded.size() > 0, "interiors loaded near spawn: %d" % streamer.loaded.size())
	var doors := city.find_children("*", "Door", true, false)
	check(doors.size() > 0, "doors built: %d" % doors.size())
	if doors.size() > 0:
		var d: Door = doors[0]
		var it := Interactable.find_from(d._hinge)
		check(it != null, "door interactable found from collider")
		it.interact(p)
		check(d.is_open, "door opens on interact")
	var travels := city.find_children("Travel_*", "StaticBody3D", true, false)
	check(travels.size() > 0, "stair/elevator travel points: %d" % travels.size())
	var tested_travel := false
	for tb in travels:
		var ft := Interactable.find_from(tb) as FloorTravel
		var acts := ft.get_actions(p)
		if acts[0]["id"].begins_with("floor_"):
			var y0 := p.global_position.y
			ft.perform(acts[0]["id"], p)
			check(absf(p.global_position.y - y0) > 1.0, "floor travel moves the player (%s)" % acts[0]["label"])
			tested_travel = true
			break
	check(tested_travel, "found a multi-floor building")
	# walking: push forward for 2 s
	p.teleport(Vector3(-6, 0.2, 6), PI * 0.5)
	for i in 30:
		await get_tree().physics_frame
	var start := p.global_position
	Input.action_press("move_forward")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(start.distance_to(p.global_position) > 1.5, "walks forward %.2f m in 2 s" % start.distance_to(p.global_position))
	# save / load
	check(GameState.save_game(9), "save slot 9")
	var data := GameState.load_game(9)
	check(data.has("player_pos") and data["systems"].has("clock"), "load slot 9 has player_pos + clock")
	DirAccess.remove_absolute(GameState.save_path(9))
	print("SMOKE TEST: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails else 0)
