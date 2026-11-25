extends SceneTree
## Runs a simulated day for all 4,000 and checks people are where their
## routines say: asleep at night, at work and class in the day.
var failures := 0
func check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok: failures += 1

func _init() -> void:
	var pop := NpcPopulation.generate()
	var sim := NpcSimulation.new(pop, NpcPopulation.load_buildings())
	var day0 := 2 * 24.0  # Day 3, a Wednesday
	var worst := 0
	var counts_by_hour := {}
	for m in 24 * 12:   # every 5 game minutes
		var t := day0 + m / 12.0
		var t0 := Time.get_ticks_usec()
		sim.update_all(t)
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		var h := m / 12
		if m % 12 == 8 and h in [3, 11, 15, 21]:   # :40, away from block starts on the hour
			var c := {}
			for i in pop.size():
				var a := sim.activity_of(i)
				c[a] = c.get(a, 0) + 1
			counts_by_hour[h] = c
			print("  %02d:40  %s" % [h, c])
	print("  update of all 4,000 NPCs: worst %.1f ms" % (worst / 1000.0))
	check(worst < 60000, "a full update of 4,000 stays under 60 ms (runs 5 times a second)")
	check(counts_by_hour[3].get("sleep", 0) > 3000, "most people are asleep at 03:00")
	check(counts_by_hour[11].get("work", 0) > 900, "many people are at work at 11:40")
	check(counts_by_hour[11].get("class", 0) + counts_by_hour[11].get("study", 0) + counts_by_hour[11].get("eat", 0) > 300, "students are in class or out at 11:00")
	var walking := 0
	var riding := 0
	for i in pop.size():
		if sim.state[i] == NpcSimulation.WALKING: walking += 1
		if sim.state[i] == NpcSimulation.RIDING: riding += 1
	sim.update_all(day0 + 6.0)
	var moved := 0
	for m in 180:   # 06:00 to 09:00, one game minute at a time
		sim.update_all(day0 + 6.0 + m / 60.0)
		var c := 0
		for i in pop.size():
			if sim.state[i] != NpcSimulation.AT_PLACE: c += 1
		moved = maxi(moved, c)
	print("  most on the move at once between 06:00 and 09:00: %d" % moved)
	check(moved > 0, "people head out on their commute")
	print("RESULT test_simulation: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
