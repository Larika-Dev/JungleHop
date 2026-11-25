extends SceneTree
## Checks the population against what was asked: 4,000 people, the height
## rules per sex, weights, personalities 0..29, homes, jobs and schedules.

var failures := 0

func check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok: failures += 1

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var pop := NpcPopulation.generate()
	print("  generated %d NPCs in %d ms" % [pop.size(), Time.get_ticks_msec() - t0])
	check(pop.size() == 4000, "4,000 NPCs")
	for sex in ["male", "female"]:
		var h: Dictionary = NpcConfig.HEIGHT[sex]
		var list := pop.filter(func(p): return p.sex == sex)
		var inside := list.filter(func(p): return p.height_cm >= h.low and p.height_cm <= h.high).size()
		var hs: Array = list.map(func(p): return p.height_cm)
		hs.sort()
		var share := float(inside) / list.size()
		print("  %s: n=%d  median %.1f cm  min %.1f  max %.1f  in %.1f-%.1f: %.2f%%" % [sex, list.size(), hs[hs.size() / 2], hs[0], hs[-1], h.low, h.high, share * 100.0])
		check(absf(share - 0.90) < 0.005, "%s: 90%% between %.1f and %.1f cm" % [sex, h.low, h.high])
		check(hs[0] >= h.min and hs[-1] <= h.max, "%s: all between %.1f and %.1f cm" % [sex, h.min, h.max])
		check(absf(hs[hs.size() / 2] - h.median) < 0.3, "%s: median near %.1f cm" % [sex, h.median])
	var counts := {}
	for p in pop:
		counts[p.personality_id] = counts.get(p.personality_id, 0) + 1
	check(counts.size() == 30 and counts.values().min() >= 133 and counts.values().max() <= 134, "30 personalities, 133-134 NPCs each")
	check(pop.all(func(p): return p.home != "" and p.home_index >= 0), "everyone has a home")
	check(pop.all(func(p): return p.day_work.size() >= 3 and p.day_work[0][0] == 0.0 and p.day_off[0][0] == 0.0), "every schedule starts at 00:00")
	check(pop.all(func(p): return p.weight_kg > 35.0 and p.weight_kg < 160.0), "weights in a human range")
	var workers := pop.filter(func(p): return p.role == "worker")
	check(workers.all(func(p): return p.workplace != "" and p.wage_per_hour > 0.0), "every worker has a workplace and hourly wage (%d workers)" % workers.size())
	var names := {}
	for p in pop: names[NpcPopulation.full_name(p)] = true
	check(names.size() == pop.size(), "all names unique")
	var pop2 := NpcPopulation.generate()
	check(JSON.stringify(pop2[1234]) == JSON.stringify(pop[1234]), "same seed, same city")
	for group in [["student", NpcDemographics.STUDENT_ETHNICITY, NpcDemographics.STUDENT_FEMALE_SHARE], ["town", NpcDemographics.TOWN_ETHNICITY, NpcDemographics.TOWN_FEMALE_SHARE]]:
		var list := pop.filter(func(p): return (p.role == "student") == (group[0] == "student"))
		var fem := list.filter(func(p): return p.sex == "female").size() / float(list.size())
		check(absf(fem - group[2]) < 0.002, "%s: %.1f%% women (target %.1f%%)" % [group[0], fem * 100.0, group[2] * 100.0])
		var line := ""
		var ok := true
		for e in group[1]:
			var share := list.filter(func(p): return p.ethnicity == e).size() / float(list.size())
			line += "%s %.1f%%  " % [e, share * 100.0]
			ok = ok and absf(share - group[1][e]) < 0.002
		check(ok, "%s backgrounds match source shares: %s" % [group[0], line])
	var roles := {}
	for p in pop: roles[p.role] = roles.get(p.role, 0) + 1
	print("  roles: ", roles)
	print("  sample: ", JSON.stringify(pop[7]).substr(0, 900))
	print("RESULT test_population: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
