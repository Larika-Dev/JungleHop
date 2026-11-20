extends PCMinigame
## Pamlico Inn front desk: pick the vacant room that fits, quote the total.

const GUESTS := ["Hale", "Okafor", "Lindqvist", "Brandt", "Nakamura", "Ferreira", "Doyle", "Santos", "Whitaker", "Ivanova"]


func _app_name() -> String:
	return "Pamlico Inn  ·  Reservations"


func _make_task() -> Dictionary:
	var rooms := []
	for f in range(1, 5):
		for n in range(1, 5):
			var beds: String = pick(["King", "Queen", "2 Queens"])
			rooms.append({"no": f * 100 + n, "beds": beds, "acc": f == 1 and n <= 2, "vacant": rng.randf() < 0.55,
				"rate": {"King": 189, "Queen": 159, "2 Queens": 209}[beds] + (20 if f == 4 else 0)})
	var want_beds: String = pick(["King", "Queen", "2 Queens"])
	var want_acc := rng.randf() < 0.25
	var high := rng.randf() < 0.3 + 0.3 * difficulty
	var match_rooms := rooms.filter(func(r): return r.vacant and r.beds == want_beds and (not want_acc or r.acc) and (not high or r.no >= 300))
	if match_rooms.is_empty():
		var r: Dictionary = rooms[rng.randi_range(0, 3) if want_acc else rng.randi_range(8, 15)]
		r.beds = want_beds
		r.acc = r.acc or want_acc
		r.vacant = true
		match_rooms = [r]
	var target: Dictionary = match_rooms[0]
	var nights := rng.randi_range(1, 4)
	var guest: String = pick(GUESTS)
	var req := "%s bed%s%s%s" % [want_beds, ", accessible room" if want_acc else "", ", floor 3 or higher" if high else "", ""]
	var side := "[b]Room board[/b] (vacant only)\n[code]"
	for r in rooms:
		if r.vacant:
			side += "%d  %-8s %s $%d\n" % [r.no, r.beds, "ACC" if r.acc else "   ", r.rate]
	side += "[/code]"
	var accepted := []
	for r in match_rooms:
		accepted.append(str(r.no))
	par_seconds = 25.0
	return {"screen": "[b]Guest at the desk[/b]\n\n\"Hi, %s. I need %d night%s, %s, please.\"\n\nIf several rooms fit, any one works." % [guest, nights, "s" if nights > 1 else "", req],
		"side": side, "fields": [
			{"label": "Guest last name", "answer": guest, "kind": "text"},
			{"label": "Room number", "answer": accepted, "kind": "room", "rates": match_rooms, "nights": nights},
			{"label": "Total $ (rate x nights)", "answer": target.rate * nights, "kind": "total"},
		]}


var _chosen_rate := -1


func _check_field(f: Dictionary, text: String) -> float:
	if f.kind == "room":
		for r in f.rates:
			if str(r.no) == text.strip_edges():
				_chosen_rate = r.rate * f.nights
				return 1.0
		_chosen_rate = -1
		return 0.0
	if f.kind == "total":
		var want: float = _chosen_rate if _chosen_rate > 0 else float(f.answer)
		return 1.0 if text.strip_edges().replace("$", "").is_valid_float() and absf(text.replace("$", "").to_float() - want) < 0.01 else 0.0
	return super._check_field(f, text)


func simulate_round(perfect: bool) -> float:
	# The room field's answer is a list; type its first entry.
	if not task.is_empty():
		task.fields[1].answer = task.fields[1].answer[0] if task.fields[1].answer is Array else task.fields[1].answer
	return super.simulate_round(perfect)
