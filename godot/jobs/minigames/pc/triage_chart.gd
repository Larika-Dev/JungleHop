extends PCMinigame
## ER triage: chart the monitor's vitals into the EHR and assign an ESI level.

const CASES := [
	["chest pain spreading to the left arm", 2], ["not breathing, unresponsive", 1], ["broken wrist after a bike fall", 3],
	["sore throat for two days", 4], ["severe allergic reaction, lips swelling", 2], ["deep cut on hand, needs stitches and a tetanus shot", 3],
	["prescription refill request", 5], ["sudden slurred speech", 2], ["high fever and confusion", 2], ["ankle sprain", 4],
	["abdominal pain and vomiting, needs labs and a scan", 3], ["asthma attack, can still speak", 2], ["head bump, no loss of consciousness", 4],
	["massive bleeding from the thigh", 1],
]


func _app_name() -> String:
	return "ONSU Medical  ·  ED Track Board"


func _make_task() -> Dictionary:
	var c: Array = pick(CASES)
	var hr := rng.randi_range(64, 96)
	var sys := rng.randi_range(108, 132)
	var spo2 := rng.randi_range(96, 100)
	# Danger-zone vitals can bump the level up.
	if rng.randf() < 0.25 + 0.3 * difficulty:
		hr = rng.randi_range(121, 150)
	if rng.randf() < 0.15:
		spo2 = rng.randi_range(86, 91)
	var esi: int = c[1]
	if esi >= 3 and (hr > 120 or spo2 < 92):
		esi = 2
	var screen := "[b]New arrival[/b]  Bed %d\nComplaint: %s\n\n[font_size=26][color=#7fd88a]HR %d[/color]    [color=#f2c48d]BP %d/%d[/color]    [color=#4fc3ff]SpO2 %d%%[/color][/font_size]" % [
		rng.randi_range(1, 24), c[0], hr, sys, rng.randi_range(64, 88), spo2]
	var side := "[b]ESI guide[/b]\n1 needs life-saving care now\n2 high risk (chest pain, stroke signs,\n   severe allergy, bad asthma, sepsis)\n3 needs 2+ resources (x-ray, sutures)\n4 needs one simple resource\n5 needs nothing (refill)\n\n[b]Danger vitals[/b]: HR > 120 or\nSpO2 < 92 make an ESI 3-5 an ESI 2."
	par_seconds = 18.0
	return {"screen": screen, "side": side, "fields": [
		{"label": "Heart rate", "answer": hr, "kind": "number"},
		{"label": "SpO2 %", "answer": spo2, "kind": "number"},
		{"label": "ESI level 1-5", "answer": esi, "kind": "number"},
	]}
