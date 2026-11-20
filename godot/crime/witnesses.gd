## Who saw a crime, who reports it, and whether the player was identified.
##
## Witness dictionaries (built by Law from the scene tree, or passed in directly in tests):
##   id            NPC id (String), "" for cameras
##   kind          "civilian" | "police" | "camera"
##   distance      metres from the crime
##   can_see       bool, line of sight (Law raycasts; true when unknown)
##   alertness     0..1, default 1 (asleep or busy NPCs can be lower)
##   friendship    -100..100 with the player (from Life.relationships)
##   lawful        0..1 trait, default 0.5
##   wild          0..1 trait, default 0.3
##   knows_player  bool, they have met the player
##   is_victim     bool
##   sees, reports optional bools that override the dice (scripted scenes, tests)
extends RefCounted

## Chance a civilian who saw it calls the police, before traits.
const REPORT_BASE := {"infraction": 0.0, "misdemeanor": 0.45, "felony": 0.85}
const NIGHT_SIGHT := 0.6


static func sight_chance(crime: Dictionary, w: Dictionary, is_night: bool) -> float:
	if not bool(w.get("can_see", true)):
		return 0.0
	var radius: float = float(crime.get("radius", 20.0))
	var d: float = float(w.get("distance", 0.0))
	if d > radius:
		return 0.0
	var falloff := 1.0 - pow(d / radius, 2.0)
	var p: float = float(crime.get("notice", 0.5)) * float(w.get("alertness", 1.0)) * (0.35 + 0.65 * falloff)
	if is_night and String(w.get("kind", "civilian")) != "camera":
		p *= NIGHT_SIGHT
	if String(w.get("kind", "")) == "camera":
		p = 0.9 if d <= radius else 0.0
	if String(w.get("kind", "")) == "police":
		p = minf(1.0, p * 1.5)
	return clampf(p, 0.0, 1.0)


static func report_chance(crime: Dictionary, w: Dictionary) -> float:
	var kind := String(w.get("kind", "civilian"))
	var crime_class := String(crime.get("class", "misdemeanor"))
	if kind == "police":
		return 1.0
	if kind == "camera":
		return 0.0 if crime_class == "infraction" else 1.0
	var p: float = float(REPORT_BASE.get(crime_class, 0.5))
	if bool(w.get("is_victim", false)):
		p += 0.35
	if crime_class == "infraction":
		return 0.0
	var lawful: float = float(w.get("lawful", 0.5))
	var friendship: float = clampf(float(w.get("friendship", 0.0)), 0.0, 100.0)
	p *= (0.6 + 0.8 * lawful)
	p *= 1.0 - friendship / 125.0   # friends cover for you
	return clampf(p, 0.0, 1.0)


## Friendship change for a witness. Wild NPCs shrug off small crimes; lawful ones judge harder.
static func witness_friendship_delta(crime: Dictionary, w: Dictionary) -> float:
	var base: float = float(crime.get("victim_rel", -20)) if bool(w.get("is_victim", false)) else float(crime.get("witness_rel", -3))
	if base >= 0.0:
		return base
	var lawful: float = float(w.get("lawful", 0.5))
	var wild: float = float(w.get("wild", 0.3))
	var scale := 0.6 + 0.8 * lawful - 0.5 * wild
	var delta := base * clampf(scale, 0.2, 1.6)
	# A wild friend thinks a petty crime is funny.
	if not bool(w.get("is_victim", false)) and String(crime.get("class", "")) == "infraction" and wild > 0.7:
		delta = 1.0
	return delta


## Rolls sight and reporting for every witness.
## Returns {seen_by: Array, reporters: Array, reported: bool, police_saw: bool, identified: bool}
static func evaluate(crime: Dictionary, witnesses: Array, is_night: bool, rng: RandomNumberGenerator,
		victim_noticed: bool = true) -> Dictionary:
	var out := {"seen_by": [], "reporters": [], "reported": false, "police_saw": false, "identified": false}
	for w in witnesses:
		var p := sight_chance(crime, w, is_night)
		if bool(w.get("is_victim", false)):
			p = 1.0 if victim_noticed else 0.0
		if w.has("sees"):   # scripted witness (cutscenes, tests)
			p = 1.0 if bool(w.sees) else 0.0
		if p <= 0.0 or rng.randf() >= p:
			continue
		out.seen_by.append(w)
		var kind := String(w.get("kind", "civilian"))
		if kind == "police":
			out.police_saw = true
		if kind != "civilian" or bool(w.get("knows_player", false)) or bool(w.get("is_victim", false)):
			out.identified = true
		var rp := report_chance(crime, w)
		if w.has("reports"):
			rp = 1.0 if bool(w.reports) else 0.0
		if rng.randf() < rp:
			out.reporters.append(w)
			out.reported = true
	return out
