extends SceneTree
## Headless checks for the Dialogue autoload.
##   godot --headless --path godot -s res://dialogue/tests/run_tests.gd
## Needs Dialogue registered as an autoload in project.godot.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	await process_frame
	var D = root.get_node_or_null("Dialogue")
	check(D != null, "Dialogue autoload present")
	if D == null:
		quit(1)
		return
	var ids: Array = D.personality_ids()
	check(ids.size() == 30, "30 personalities (got %d)" % ids.size())

	# Assignment is deterministic and covers every personality.
	var counts := {}
	for i in 4000:
		var pid: String = D.assign_personality("npc_%04d" % i)
		counts[pid] = counts.get(pid, 0) + 1
	check(D.assign_personality("npc_0042") == D.get_personality_id("npc_0042"), "assignment is stable")
	check(counts.size() == 30, "4,000 NPCs use all 30 personalities (used %d)" % counts.size())
	var wild: String = D.assign_personality("trait_test", {"outgoing": 1.0, "kind": 0.6, "ambitious": 0.3, "wild": 0.95, "lawful": 0.2})
	print("traits wild/outgoing -> ", wild)
	D.set_personality("forced", "dry_cynic")
	check(D.get_personality_id("forced") == "dry_cynic", "set_personality overrides")

	# Every personality answers every context in every relationship stage it should.
	var base_ctx := ["greet", "farewell", "smalltalk", "about_self", "opinion_place", "compliment_reply",
		"insult_reply", "gift_reply", "joke", "ask_favor", "favor_reply", "work_talk", "school_talk", "ask_out_yes", "ask_out_no"]
	var dating_ctx := ["date_greet", "flirt", "date_talk", "compliment", "kiss_reply", "miss_you", "jealous", "date_end", "lovers_quarrel", "proposal_yes"]
	var marriage_ctx := ["home_greet", "affection", "home_talk", "chores", "money", "meal", "argue", "makeup", "support",
		"plans", "memories", "anniversary", "tease", "work_return", "bedtime", "goodbye_work"]
	for pid in ids:
		for t in ["morning", "afternoon", "evening", "night"]:
			for c in base_ctx:
				var s: String = D.get_line("p_" + pid, c, {"personality": pid, "stage": "acquaintance", "romance": "none", "time": t, "player": "Sam"})
				check(s != "" and not ("{" in s), "%s %s %s -> '%s'" % [pid, c, t, s])
			for c in dating_ctx:
				var s2: String = D.get_line("p_" + pid, c, {"personality": pid, "stage": "friend", "romance": "dating", "time": t, "player": "Sam"})
				check(s2 != "", "%s dating %s %s" % [pid, c, t])
			for c in marriage_ctx:
				var s3: String = D.get_line("p_" + pid, c, {"personality": pid, "stage": "close_friend", "romance": "married", "time": t, "player": "Sam"})
				check(s3 != "", "%s married %s %s" % [pid, c, t])
		check(D.get_line("p_" + pid, "hostile", {"personality": pid, "stage": "enemy"}) != "", "%s hostile" % pid)
		var lines: Array = D.lines_for(pid, "")
		var b: int = D.lines_for(pid, "base").size()
		check(b >= 100 and b <= 200, "%s base count %d" % [pid, b])
		check(D.lines_for(pid, "dating").size() >= 50, "%s dating count" % pid)
		check(D.lines_for(pid, "marriage").size() >= 200, "%s marriage count" % pid)
		check(lines.size() == b + D.lines_for(pid, "dating").size() + D.lines_for(pid, "marriage").size(), "%s tiers" % pid)

	# No repeats in a row for the same NPC.
	var seen := {}
	for i in 10:
		var info: Dictionary = D.get_line_info("repeat_test", "smalltalk", {"personality": "sunny_optimist", "stage": "friend"})
		check(not seen.has(info.id), "no repeat within recent memory")
		seen[info.id] = true

	# Conversations: always 4+ options, except the 2-option favor prompt.
	var setups := [
		{"stage": "stranger", "romance": "none", "time": "morning"},
		{"stage": "acquaintance", "romance": "none", "time": "afternoon"},
		{"stage": "best_friend", "romance": "crush", "time": "evening"},
		{"stage": "enemy", "romance": "none", "time": "night"},
		{"stage": "friend", "romance": "dating", "time": "evening"},
		{"stage": "close_friend", "romance": "engaged", "time": "night"},
		{"stage": "close_friend", "romance": "married", "time": "morning"},
		{"stage": "close_friend", "romance": "married", "time": "afternoon"},
		{"stage": "close_friend", "romance": "married", "time": "evening"},
		{"stage": "close_friend", "romance": "married", "time": "night", "anniversary": true, "has_gift": true},
	]
	var turns := 0
	for pid in ids:
		for setup in setups:
			var extra: Dictionary = setup.duplicate()
			extra["personality"] = pid
			extra["accept"] = true
			var npc_id: String = "conv_%s_%s_%s" % [pid, setup.stage, setup.romance]
			var st: Dictionary = D.start_conversation(npc_id, extra)
			check(st.npc_line != "", "%s opening line %s" % [pid, setup])
			for step in 8:
				if st.is_empty() or st.ended:
					break
				var n: int = st.options.size()
				var is_favor: bool = n > 0 and str(st.options[0].id).begins_with("favor")
				check(n >= 4 or (is_favor and n == 2), "%s %s: %d options %s" % [pid, setup, n, st.options])
				check(n <= 6, "at most 6 options")
				# Pick a non-ending option until the last step.
				var pick: Dictionary = st.options[0]
				for o in st.options:
					if o.kind != "end" and step < 7:
						pick = o
						if _rand_bool():
							break
				st = D.choose(npc_id, pick.id)
				turns += 1
				check(not st.is_empty(), "choose returned a state")
				if not st.is_empty():
					check(st.npc_line != "", "%s reply for %s" % [pid, pick.id])
			D.end_conversation(npc_id)
	print("conversation turns simulated: ", turns)

	var sample: Dictionary = D.start_conversation("demo_npc", {"personality": "old_soul_storyteller", "stage": "friend", "romance": "none", "player": "Sam"})
	print("demo: ", sample.npc_line)
	for o in sample.options:
		print("   - ", o.label)
	D.end_conversation("demo_npc")

	if failures == 0:
		print("ALL DIALOGUE TESTS PASSED")
	else:
		printerr("%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _rand_bool() -> bool:
	return randf() < 0.5
