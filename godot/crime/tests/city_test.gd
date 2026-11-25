extends Node
## In-city test with the real autoloads (GameClock, GameState, CityData, UI) and the Law autoload:
##   godot --headless --path godot res://crime/tests/city_test.tscn
## Loads the city, commits a robbery in front of a cop found by the real witness scan, then gets
## arrested and serves the sentence on GameClock. Exit code 0 = pass.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	var law: Node = get_node_or_null("/root/Law")
	check(law != null, "Law autoload present")
	GameState.player_profile = GameState.default_profile()
	var city: Node3D = load("res://world/city.tscn").instantiate()
	get_tree().root.add_child(city)
	for i in 120:
		await get_tree().physics_frame
	var p: Node3D = GameState.get_player()
	check(p != null, "player spawned")
	# A cop standing 2 m away, in the open.
	var cop := Node3D.new()
	cop.add_to_group("police")
	cop.set("name", "TestCop")
	get_tree().root.add_child(cop)
	cop.global_position = p.global_position + Vector3(2, 0, 0)
	await get_tree().physics_frame
	var out: Dictionary = law.commit("robbery", {"success": true})
	check(out.ok and out.reported, "robbery seen by the cop via the real scan")
	check(law.wanted() == 3 and law.police.state == "pursuit", "3 stars, pursuit (%d, %s)" % [law.wanted(), law.police.state])
	var t0: float = GameClock.total_minutes
	law.police_contact(cop)
	check(not law.booking.is_empty(), "booked after contact")
	var hours: int = int(law.booking.jail_hours)
	law.serve_sentence()
	check(is_equal_approx(GameClock.total_minutes - t0, hours * 60.0), "GameClock skipped %d jail hours (got %.1f min)" % [hours, GameClock.total_minutes - t0])
	check(law.record.has_felony() and not law.job_check("standard").ok, "felony blocks standard jobs")
	check(not law.in_jail and law.wanted() == 0, "released")
	get_tree().quit(1 if fails else 0)
