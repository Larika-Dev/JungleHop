extends Node
## End-to-end play test through the real game flow, with screenshots.
##   xvfb-run godot --path godot res://tests/playtest.tscn -- <outdir>
## Prints PASS/FAIL lines and "PLAYTEST: OK" or "PLAYTEST: N failures".

var out := "user://playtest"
var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func snap(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func wait_s(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep this node alive across change_scene: hand "current scene" to a placeholder.
	var ph := Node.new()
	get_tree().root.add_child.call_deferred(ph)
	await get_tree().process_frame
	get_tree().current_scene = ph
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.fullscreen = false
	Settings.apply()
	get_window().size = Vector2i(1600, 900)
	await _run()
	print("PLAYTEST: ", "OK" if failures == 0 else "%d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	# Title screen
	var title: Node = load("res://ui/title_screen.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await snap("01-title", 60)
	# Character creator through the title's New Game
	title._new_game()
	await snap("02-character-creator", 30)
	var cc: Node = null
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n.get_script() == load("res://ui/character_creator.gd"):
			cc = n
	check(cc != null, "character creator opens from New Game")
	var prof: Dictionary = cc.profile.duplicate() if cc else GameState.default_profile()
	prof["name"] = "Test Player"
	prof["age"] = 21
	check(prof.has("age") and prof.has("height_cm") and prof.has("weight_kg") and prof.has("muscle"), "creator has age, height, weight, muscularity")
	UI.close_all()
	var gen: Control = load("res://npc/generator/npc_generator.gd").new()
	UI.open_panel(gen)
	await snap("02b-npc-generator", 40)
	UI.close_all()
	title.queue_free()
	await get_tree().process_frame
	# Start the game the way the creator does (scene change to the city)
	TitleScreen.start_new(prof)
	await wait_s(4.0)
	var city := get_tree().current_scene
	check(city != null and city.name.to_lower().contains("city"), "city scene loaded (%s)" % (city.name if city else "none"))
	var p := GameState.get_player()
	check(p != null, "player spawned")
	var life := get_node_or_null("/root/Life")
	check(life != null and is_equal_approx(float(life.money.cash), 1000.0), "starts with $1,000 (%s)" % (str(life.money.cash) if life else "?"))
	check(life != null and life.needs.enabled, "needs are on")
	# Clock rate: 1 game hour = 1 real minute
	var t0: float = GameClock.total_minutes
	var r0 := Time.get_ticks_msec()
	await wait_s(3.0)
	var dm: float = GameClock.total_minutes - t0
	var dr: float = (Time.get_ticks_msec() - r0) / 1000.0
	# Software rendering runs at ~1 fps and frames over 1 s count as hitches, so only
	# check the rate strictly when the frame rate is real.
	if Engine.get_frames_per_second() < 5:
		check(is_equal_approx(GameClock.GAME_MINUTES_PER_REAL_SECOND, 1.0) and dm > 0.0, "clock runs at 1 game min per real s (low-fps run: %.2f in %.2f s)" % [dm, dr])
	else:
		check(abs(dm - dr) < 0.6, "clock: %.2f game min in %.2f real s" % [dm, dr])
	await snap("03-city-start", 30)
	# NPCs
	var npcs := get_node_or_null("/root/NPCs")
	check(npcs != null, "NPCs autoload")
	if npcs:
		for i in 60:
			if npcs.ready_state:
				break
			await wait_s(0.5)
		check(npcs.population.size() >= 4000, "4,000 residents (%d)" % npcs.population.size())
		await wait_s(3.0)
		var bodies: Array = npcs.loaded_bodies()
		check(bodies.size() > 0 and bodies.size() <= 100, "NPC bodies streamed near player: %d (max 100)" % bodies.size())
		if bodies.size() > 0:
			var near: Node3D = bodies[0]
			for b in bodies:
				if b.global_position.distance_to(p.global_position) < near.global_position.distance_to(p.global_position):
					near = b
			var inter: Interactable = null
			for c in near.find_children("*", "Node", true, false):
				if c is Interactable:
					inter = c
			check(inter != null, "nearest NPC has an interactable")
			var inf: Dictionary = life.relationships.npc_info(str(near.npc_id))
			check(str(inf.get("name", "")) != "" and inf.has("attractiveness"), "streamed NPC registered with Life (%s)" % inf.get("name", "?"))
			if inter:
				var acts: Array = inter.get_actions(p)
				check(acts.size() >= 4, "NPC offers %d actions" % acts.size())
				check(acts.size() > 0 and acts[0].id == "converse", "first NPC action is a conversation (%s)" % (acts[0].id if acts.size() else ""))
				# Put the NPC in front of the player for the shot
				near.global_position = p.global_position + (-p.global_transform.basis.z * 1.6)
				var dlg := get_node_or_null("/root/Dialogue")
				if dlg:
					var panel: Control = dlg.open_conversation(near)
					await snap("04-conversation", 30)
					var st: Dictionary = dlg.start_conversation(near)
					check(life.relationships.npc_info(str(near.npc_id)).has("first_impression"), "first impression formed")
					var opts: Array = st.get("options", [])
					check(opts.size() >= 4, "conversation has %d choices" % opts.size())
					UI.close_all()
					if is_instance_valid(panel):
						panel.queue_free()
	# Jobs
	var js := get_node_or_null("/root/JobSystem")
	check(js != null, "JobSystem autoload")
	if js:
		var b_ids: Array = js.employer_buildings()
		check(b_ids.size() > 0, "employers in the city: %d" % b_ids.size())
		var hired := ""
		for b in b_ids:
			for jid in js.jobs_at_building(b):
				if js.can_apply(jid) == "":
					var r: Dictionary = js.apply(jid)
					if r.get("ok", true):
						hired = jid
						break
			if hired != "":
				break
		check(hired != "", "got hired: %s" % hired)
		if hired != "":
			check(js.wage_of(hired) > 0.0, "hourly wage $%.2f" % js.wage_of(hired))
			var win: Dictionary = js.shift_window(hired, GameClock.day)
			if win.has("start"):
				GameClock.set_time(GameClock.day, int(win.start) / 60 if float(win.start) > 24 else int(win.start), 0)
			var cash0: float = life.money.cash + life.money.bank
			var why: String = js.can_start_shift(hired)
			if why == "":
				js.start_shift(hired, true)
				await snap("05-job-minigame", 40)
				for i in 6:
					js.report_round(1.0)
				GameClock.advance_minutes(120)
				var res: Dictionary = js.end_shift()
				UI.close_all()
				await get_tree().process_frame
				check(life.money.cash + life.money.bank > cash0, "paid for hours worked ($%.2f -> $%.2f)" % [cash0, life.money.cash + life.money.bank])
			else:
				print("NOTE  could not start shift now: ", why)
	# Education
	var edu := get_node_or_null("/root/Education")
	check(edu != null, "Education autoload")
	if edu:
		var cid := "CHEM 101"
		var why: String = edu.can_enroll(cid)
		var er: Dictionary = edu.enroll(cid) if why == "" else {"ok": false, "reason": why}
		check(er.ok, "enroll in %s (%s)" % [cid, er.get("reason", "")])
		var hw: Node = edu.open_homework()
		await snap("06-homework", 40)
		if hw:
			edu.close_screen(hw)
		UI.close_all()
	# Crime
	var law := get_node_or_null("/root/Law")
	check(law != null, "Law autoload")
	if law:
		var crimes: Array = life.actions.order.filter(func(id): return str(id).begins_with("crime_"))
		check(crimes.size() >= 30, "%d crime actions in the menu" % crimes.size())
	# Visible police: commit a felony in plain view, officers show up and run at you
	if law:
		law.commit("robbery", {"success": true, "witnesses": [{"id": "officer_test", "kind": "police", "distance": 5.0, "sees": true}]})
		check(law.wanted() > 0, "robbery in front of a cop makes you wanted (%d stars)" % law.wanted())
		var pu := get_tree().current_scene.get_node_or_null("PoliceUnits")
		check(pu != null, "police units in the world")
		if pu and law.wanted() > 0:
			law.police_dispatched.emit(law.wanted(), 2, "patrol", p.global_position, 0)
			await wait_s(3.0)
			check(pu.officers.size() > 0, "officers spawned (%d)" % pu.officers.size())
			if pu.officers.size() > 0:
				var o: Node3D = pu.officers[0]
				o.global_position = p.global_position + (-p.global_transform.basis.z * 3.0)
				await snap("06g-police", 10)
				o.global_position = p.global_position + Vector3(0.5, 0, 0)
				await wait_s(1.5)
				check(law.wanted() == 0, "caught by an officer = arrested (wanted %d)" % law.wanted())
				if law.has_method("serve_sentence"):
					law.serve_sentence()
	# Furniture
	var fm := get_node_or_null("/root/Furniture")
	check(fm != null, "Furniture autoload")
	# Body follows Life: gain weight, check the player's body shape moved
	var app = p.get("appearance")
	if app and app.get("_body"):
		var before: Dictionary = app._body._build.duplicate()
		life.body.weight_kg += 15.0
		app._sync_life_body()
		check(str(before) != str(app._body._build), "player body reshapes with weight gain")
	# You / this place menu and people panel
	UI.open_life_menu()
	await snap("06c-life-menu", 20)
	check(UI.is_panel_open(), "Q opens the you / this place action menu")
	UI.close_all()
	UI.open_people()
	await snap("06d-people", 20)
	UI.close_all()
	# Home
	var home := get_node_or_null("/root/Home")
	check(home != null and home.room_id != "", "player has a home (%s)" % (home.room_id if home else ""))
	if home and home.room_id != "":
		var t1: float = GameClock.total_minutes
		var r: Dictionary = life.actions.perform("go_home", null)
		await wait_s(2.0)
		check(p.global_position.distance_to(home.home_position()) < 3.0, "Go home moves you home (%.1f m away)" % p.global_position.distance_to(home.home_position()))
		check(GameClock.total_minutes > t1, "the walk home takes time")
		await snap("06f-home", 40)
	UI.open_map()
	await snap("06e-map", 30)
	check(UI.is_panel_open(), "M opens the map")
	UI.close_all()
	# Pause menu
	UI.open_panel(load("res://ui/pause_menu.gd").new(), true)
	await snap("06b-pause", 20)
	UI.close_all()
	# Pause + settings
	UI.open_panel(load("res://ui/settings_menu.gd").new())
	await snap("07-settings", 20)
	UI.close_all()
	# Save / load
	check(GameState.save_game(8), "save game")
	check(not GameState.load_game(8).is_empty(), "load game")
	await snap("08-city-end", 20)
