extends PCMinigame
## Junior Varsity Cinema box office.

const FILMS := [["MQ", "Moonlit Quarry"], ["BR", "Billram Returns"], ["LS", "The Last Syllabus"], ["RR", "Ravine Runners"], ["CS", "Carillon Song"]]
const ADULT := 12.5
const CHILD := 8.0
const MATINEE_OFF := 3.0


func _app_name() -> String:
	return "%s  ·  Box Office" % company_name("JV Cinema")


func _make_task() -> Dictionary:
	var shows := {}
	var side := "[b]Today[/b]\n[code]"
	for f in FILMS:
		var times := []
		for i in 3:
			var hh := rng.randi_range(12, 22)
			var mm: int = pick([0, 15, 30, 40, 45])
			times.append("%d:%02d" % [hh, mm])
		times.sort()
		shows[f[0]] = times
		side += "%s  %-18s %s\n" % [f[0], f[1], "  ".join(PackedStringArray(times))]
	side += "[/code]\nAdult $%.2f  Child $%.2f\nShows before 17:00: $%.2f off each ticket" % [ADULT, CHILD, MATINEE_OFF]
	var film: Array = pick(FILMS)
	var t: String = pick(shows[film[0]])
	var adults := rng.randi_range(1, 3)
	var kids := rng.randi_range(0, 2 + int(difficulty * 2))
	var off := MATINEE_OFF if int(t.split(":")[0]) < 17 else 0.0
	var total := adults * (ADULT - off) + kids * (CHILD - off)
	par_seconds = 22.0
	return {"screen": "[b]At the window[/b]\n\n\"%d adult%s%s for %s at %s, please.\"" % [adults, "s" if adults > 1 else "",
		(" and %d kid%s" % [kids, "s" if kids > 1 else ""]) if kids > 0 else "", film[1], t], "side": side, "fields": [
		{"label": "Film code", "answer": film[0], "kind": "text"},
		{"label": "Showtime", "answer": t, "kind": "text"},
		{"label": "Tickets", "answer": adults + kids, "kind": "number"},
		{"label": "Total $", "answer": total, "kind": "money"},
	]}
