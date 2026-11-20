extends Interactable
## Clock-in terminal at a workplace. Lists apply / clock in / promotion /
## raise / shift change / quit for every job at this building.

var building_id := ""
var jobs: Node = null


func get_actions(_actor: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if jobs == null:
		return out
	for id in jobs.jobs_at_building(building_id):
		var j: Dictionary = jobs.get_job(id)
		if jobs.is_employed(id):
			if jobs.active_job == id:
				out.append({"id": "end|" + id, "label": "Clock out"})
				continue
			var why: String = jobs.can_start_shift(id)
			out.append({"id": "start|" + id, "label": "Clock in: %s, %s ($%.2f/hr)%s" % [jobs.title_of(id), j.place, jobs.wage_of(id),
				"" if why == "" else "  - " + why], "enabled": why == ""})
			var gap: String = jobs.promotion_gap(id)
			out.append({"id": "promo|" + id, "label": "Ask for a promotion" + ("" if gap == "" else "  - " + gap), "minutes": 15})
			out.append({"id": "raise|" + id, "label": "Ask for a raise", "minutes": 15})
			var shifts: Array = j.shifts
			for k in shifts.size():
				if k != int(jobs.employment[id].shift):
					out.append({"id": "shift%d|%s" % [k, id], "label": "Switch to %s shift (%02d:00-%02d:00)" % [shifts[k].name, int(shifts[k].start), int(shifts[k].end) % 24]})
			out.append({"id": "quit|" + id, "label": "Quit " + jobs.title_of(id)})
		else:
			var why2: String = jobs.can_apply(id)
			var r0: Dictionary = j.ranks[0]
			out.append({"id": "apply|" + id, "label": "Apply: %s at %s ($%.2f/hr)%s" % [r0.title, j.place, r0.wage, "" if why2 == "" else "  - " + why2],
				"minutes": 20, "enabled": why2 == ""})
	out.append({"id": "info|", "label": "Company info and openings"})
	return out


func perform(action_id: String, actor: Node) -> void:
	var parts := action_id.split("|")
	var verb := parts[0]
	var id := parts[1] if parts.size() > 1 else ""
	match verb:
		"apply":
			GameClock.advance_minutes(20)
			jobs.apply(id)
		"start":
			jobs.start_shift(id)
		"end":
			jobs.end_shift()
		"promo":
			jobs.ask_promotion(id)
		"raise":
			var r: Dictionary = jobs.ask_raise(id)
			if not r.ok:
				UI.notify(r.reason)
		"quit":
			jobs.quit(id)
		"info":
			UI.open_panel(load("res://jobs/ui/job_board.gd").new().with_building(building_id))
		_:
			if verb.begins_with("shift"):
				jobs.change_shift(id, int(verb.substr(5)))
				UI.notify("Shift changed. Next: " + jobs.next_shift_text(id))
	super.perform(action_id, actor)
