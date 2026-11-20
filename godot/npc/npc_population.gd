## Generates the 4,000 residents of Cathedral Mount from the city seed.
## Same seed, same people, same homes, jobs, friends and daily routines.
##
##   var pop := NpcPopulation.generate()            # 4,000 records
##   var pop := NpcPopulation.generate(250, 42)     # any count and seed
##   var one := NpcPopulation.make_record(rng, {"sex": "female", "height_cm": 170.2})
##
## A record is a plain Dictionary (easy to save, print and hand to other
## systems). Keys are documented in godot/npc/README.md.
class_name NpcPopulation
extends RefCounted

const BUILDINGS_PATH := "res://npc/data/npc_buildings.json"
const PERSONALITY_COUNT := 30


# Workplace categories: business or typology -> category.
const CATEGORY := {
	"cafe": "early_food", "bakery": "early_food", "breakfast": "early_food",
	"takeout": "food", "tacos": "food", "pizza": "food", "deli": "food", "diner": "food",
	"bar": "bar", "brewpub": "bar",
	"clothing": "shop", "retail": "shop", "bookstore": "shop", "records": "shop", "hardware": "shop",
	"florist": "shop", "optics": "shop", "gallery": "shop", "tattoo": "shop", "cinema": "shop",
	"salon": "salon", "bank": "office", "dental": "clinic", "tutoring": "office",
	"historic_academic": "academic", "modern_academic": "academic", "library": "library",
	"office_lab": "lab", "hospital": "hospital", "arena": "venue", "mill": "mill",
	"inn": "hotel", "parking": "venue", "residence_highrise": "residence", "residence_historic": "residence",
	"downtown_commercial": "office",
}
const JOBS := {
	"early_food": [["Barista", 14.5], ["Baker", 16.0], ["Shift Lead", 17.5]],
	"food": [["Line Cook", 16.0], ["Cashier", 13.5], ["Server", 12.0], ["Prep Cook", 14.5]],
	"bar": [["Bartender", 13.0], ["Server", 12.0], ["Bar Back", 12.5], ["Bouncer", 16.0]],
	"shop": [["Sales Associate", 14.0], ["Store Manager", 22.0], ["Stock Clerk", 13.5]],
	"salon": [["Hair Stylist", 18.0], ["Receptionist", 14.0]],
	"office": [["Office Clerk", 18.5], ["Accountant", 31.0], ["Bank Teller", 17.5], ["Paralegal", 24.0], ["Tutor", 20.0]],
	"clinic": [["Dental Hygienist", 38.0], ["Receptionist", 16.0]],
	"academic": [["Professor", 52.0], ["Lecturer", 34.0], ["Teaching Assistant", 18.0], ["Department Admin", 22.0], ["Custodian", 16.5]],
	"library": [["Librarian", 28.0], ["Library Assistant", 16.0]],
	"lab": [["Research Scientist", 41.0], ["Lab Technician", 23.0], ["Software Engineer", 48.0]],
	"hospital": [["Nurse", 39.0], ["Physician", 98.0], ["Orderly", 17.0], ["Medical Assistant", 19.5], ["Pharmacist", 62.0]],
	"venue": [["Groundskeeper", 17.0], ["Event Staff", 14.0], ["Parking Attendant", 13.0]],
	"mill": [["Woodworker", 21.0], ["Studio Artist", 18.0], ["Brewer", 19.0]],
	"hotel": [["Front Desk Agent", 15.0], ["Housekeeper", 14.0]],
	"residence": [["Resident Advisor", 13.0], ["Maintenance Tech", 21.0]],
}
const SHIFTS := {  # [start hours], length
	"early_food": [[5.5, 6.0, 7.0], 8.0], "food": [[10.0, 11.0, 15.0, 16.0], 7.5],
	"bar": [[16.0, 18.0], 8.0], "shop": [[9.0, 10.0, 12.0], 8.0], "salon": [[9.0, 10.0], 8.0],
	"office": [[8.0, 8.5, 9.0], 8.5], "clinic": [[8.0], 8.5], "academic": [[8.0, 9.0, 10.0], 8.0],
	"library": [[8.0, 12.0], 8.0], "lab": [[8.0, 9.0, 10.0], 8.5], "hospital": [[7.0, 15.0, 23.0], 8.0],
	"venue": [[7.0, 14.0], 8.0], "mill": [[8.0, 9.0], 8.0], "hotel": [[7.0, 15.0], 8.0], "residence": [[8.0, 16.0], 8.0],
}
const SEVEN_DAY := ["early_food", "food", "bar", "shop", "salon", "hospital", "venue", "hotel", "residence"]

const TOP_COLORS := ["#1f2a44", "#f2f2ee", "#7a1f2b", "#2f5d3a", "#c9a227", "#4b6584", "#202020", "#8e8e8a", "#c45c3b", "#6d4c8c", "#9fc5e8", "#e8b4b8", "#7BAFD4", "#e07a24"]
const BOTTOM_COLORS := ["#22324f", "#1b1b1b", "#5b4a3a", "#7d7d78", "#c8b996", "#3b4d2e", "#6b2737", "#a7b6c8"]
const SHOE_COLORS := ["#f4f4f0", "#151515", "#4a3020", "#7a7a7a", "#8b1e1e", "#2a3d66"]

static var _buildings_cache: Array = []


static func load_buildings() -> Array:
	if _buildings_cache.is_empty():
		var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
		assert(f != null, "missing " + BUILDINGS_PATH)
		_buildings_cache = JSON.parse_string(f.get_as_text()).buildings
	return _buildings_cache


## Builds one person. Anything in `overrides` wins over the random pick, so the
## NPC generator tool and player customization can set exactly what they want.
## Accepted override keys: name, first, last, sex, age, height_cm, weight_kg,
## muscle, complexion, hair_color, hair_style, eye_color, outfit, personality_id.
static func make_record(rng: RandomNumberGenerator, overrides: Dictionary = {}) -> Dictionary:
	var sex: String = overrides.get("sex", "male" if rng.randf() < 0.5 else "female")
	var ethnicity: String = overrides.get("ethnicity", _weighted(NpcDemographics.TOWN_ETHNICITY, rng))
	var nm := NpcNames.pick(sex, ethnicity, rng)
	var rec := {
		"id": -1,
		"npc_id": "",
		"first": nm[0],
		"last": nm[1],
		"sex": sex,
		"ethnicity": ethnicity,
		"age": rng.randi_range(19, 70),
		"height_cm": 0.0,
		"weight_kg": 0.0,
		"muscle": clampf(rng.randfn(0.35 if sex == "male" else 0.25, 0.15), 0.0, 1.0),
		"complexion": NpcDemographics.complexion_for(ethnicity, rng),
		"hair_color": 0, "hair_style": "", "eye_color": 0,
		"outfit": {},
		"personality_id": rng.randi() % PERSONALITY_COUNT,
		# Same trait names as Life (godot/life/INTERFACES.md), each 0..1.
		"traits": {"outgoing": snappedf(rng.randf(), 0.01), "kind": snappedf(rng.randf(), 0.01), "ambitious": snappedf(rng.randf(), 0.01), "wild": snappedf(rng.randf(), 0.01), "lawful": snappedf(rng.randf(), 0.01)},
		"interests": [],
		# 1..10, read by Life for dating odds.
		"attractiveness": snappedf(clampf(rng.randfn(5.5, 1.6), 1.0, 10.0), 0.1),
		"walk_speed": 0.0,
		"role": "worker", "occupation": "", "wage_per_hour": 0.0,
		"home": "", "workplace": "",
		"work_days": [false, false, false, false, false, false, false],
		"day_work": [], "day_off": [],
		"social": {"partner": -1, "partner_kind": "", "household": [], "coworkers": [], "classmates": [], "friends": []},
	}
	if overrides.has("height_cm"):
		rec.height_cm = snappedf(float(overrides.height_cm), 0.1)
	else:
		var h: Dictionary = NpcConfig.HEIGHT[sex]
		var z := clampf(rng.randfn(0.0, 1.0), -3.0, 3.0)
		rec.height_cm = snappedf(clampf(h.median + z * (h.high - h.low) / (2.0 * NpcHeights.Z90), h.min, h.max), 0.1)
	rec.age = int(overrides.get("age", rec.age))
	rec.weight_kg = snappedf(float(overrides.get("weight_kg", _random_weight(rng, sex, rec.height_cm, rec.age))), 0.1)
	var hair_c := _random_hair_color(rng, rec.age, rec.complexion)
	rec.hair_color = int(overrides.get("hair_color", hair_c))
	rec.hair_style = String(overrides.get("hair_style", _random_hair_style(rng, sex, rec.age)))
	rec.eye_color = int(overrides.get("eye_color", (rng.randi() % 3) if rec.complexion > 0.45 else rng.randi() % NpcAppearance.EYE_COLORS.size()))
	rec.outfit = overrides.get("outfit", _random_outfit(rng, sex))
	for k in ["muscle", "complexion", "personality_id", "first", "last"]:
		if overrides.has(k):
			rec[k] = overrides[k]
	if overrides.has("name"):
		var parts := String(overrides.name).split(" ", false, 1)
		rec.first = parts[0]
		rec.last = parts[1] if parts.size() > 1 else ""
	if overrides.has("traits"):
		rec.traits.merge(overrides.traits, true)
	rec.interests = overrides.get("interests", _random_interests(rng, rec))
	rec.walk_speed = snappedf(NpcConfig.WALK_SPEED * (rec.height_cm / 170.0) * (1.0 - maxf(0.0, rec.age - 60) * 0.008) * rng.randf_range(0.92, 1.08), 0.01)
	return rec


static func _role_shares() -> Dictionary:
	var d := NpcDemographics.ROLE_SHARE.duplicate()
	var rest := 1.0
	for k in d: rest -= d[k]
	d["worker"] = rest
	return d


## Gives a hand-made NPC (from the generator tool) a home, a job if they are a
## worker, and daily schedules, using the same rules as the generated city.
static func place_new_resident(rec: Dictionary, buildings: Array, population: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rec.first, rec.last, rec.height_cm, population.size()])
	var homes: Array = []
	for i in buildings.size():
		var dorm: bool = buildings[i].typology.begins_with("residence")
		if buildings[i].homes > 0 and dorm == (rec.role == "student"):
			homes.append(i)
	var hi: int = rec.get("home_index", -1)
	if hi < 0:
		hi = homes[rng.randi() % homes.size()]
	rec._home_idx = hi
	rec.home = buildings[hi].id
	var places := _index_places(buildings)
	if rec.role == "worker":
		var jobs: Array = []
		for i in buildings.size():
			if _category_of(buildings[i]) != "" and buildings[i].jobs > 0: jobs.append(i)
		var wi: int = rec.get("work_index", -1)
		if wi < 0: wi = jobs[rng.randi() % jobs.size()]
		var cat := _category_of(buildings[wi])
		var job: Array = JOBS[cat][rng.randi() % JOBS[cat].size()]
		rec._work_idx = wi
		rec._category = cat
		rec.workplace = buildings[wi].id
		if rec.occupation == "": rec.occupation = job[0]
		if rec.wage_per_hour <= 0.0: rec.wage_per_hour = job[1]
		rec._shift_start = SHIFTS[cat][0][0]
		rec._shift_len = SHIFTS[cat][1]
		rec.work_days = [true, true, true, true, true, false, false]
	elif rec.role == "student":
		rec.occupation = "Student"
		rec.work_days = [true, true, true, true, true, false, false]
	_build_schedules(rec, buildings, places, rng)


## JSON turns ints into floats; put the types back on a loaded record.
static func normalize_record(r: Dictionary) -> Dictionary:
	for k in ["id", "age", "personality_id", "hair_color", "eye_color", "home_index", "work_index"]:
		if r.has(k): r[k] = int(r[k])
	for k in ["day_work", "day_off"]:
		for b in r.get(k, []):
			b[2] = int(b[2])
	var soc: Dictionary = r.get("social", {})
	soc.partner = int(soc.get("partner", -1))
	for k in ["household", "coworkers", "classmates", "friends"]:
		soc[k] = soc.get(k, []).map(func(x): return int(x))
	return r


static func full_name(rec: Dictionary) -> String:
	return "%s %s" % [rec.first, rec.last]


## The whole city. About 1 to 2 seconds for 4,000 people.
static func generate(count: int = NpcConfig.POPULATION, seed_value: int = NpcConfig.SEED) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buildings := load_buildings()

	# Roles first; sex and background shares differ for students and townies.
	var roles: Array = NpcDemographics.exact_mix(_role_shares(), count, rng)
	var n_students := roles.count("student")
	var stu_sex := NpcDemographics.exact_mix({"female": NpcDemographics.STUDENT_FEMALE_SHARE, "male": 1.0 - NpcDemographics.STUDENT_FEMALE_SHARE}, n_students, rng)
	var town_sex := NpcDemographics.exact_mix({"female": NpcDemographics.TOWN_FEMALE_SHARE, "male": 1.0 - NpcDemographics.TOWN_FEMALE_SHARE}, count - n_students, rng)
	var stu_eth := NpcDemographics.exact_mix(NpcDemographics.STUDENT_ETHNICITY, n_students, rng)
	var town_eth := NpcDemographics.exact_mix(NpcDemographics.TOWN_ETHNICITY, count - n_students, rng)
	var sexes: Array = []
	var eths: Array = []
	var si := 0
	var ti := 0
	for r in roles:
		if r == "student":
			sexes.append(stu_sex[si]); eths.append(stu_eth[si]); si += 1
		else:
			sexes.append(town_sex[ti]); eths.append(town_eth[ti]); ti += 1
	# Heights by stratified quantiles per sex (exact 90% rule).
	var heights_m := NpcHeights.sample("male", sexes.count("male"), rng)
	var heights_f := NpcHeights.sample("female", sexes.count("female"), rng)
	# Personalities spread evenly: every one of the 30 gets count/30 people (+-1).
	var personalities: Array = []
	for i in count:
		personalities.append(i % PERSONALITY_COUNT)
	_shuffle(personalities, rng)

	var people: Array = []
	var hm := 0
	var hf := 0
	var used_names := {}
	for i in count:
		var sex: String = sexes[i]
		var h: float = heights_m[hm] if sex == "male" else heights_f[hf]
		if sex == "male": hm += 1
		else: hf += 1
		var age := _age_for_role(rng, roles[i])
		var rec := make_record(rng, {"sex": sex, "ethnicity": eths[i], "height_cm": h, "age": age, "personality_id": personalities[i]})
		rec.id = i
		rec.npc_id = "npc_%04d" % i
		rec.role = roles[i]
		var nm := full_name(rec)
		while used_names.has(nm):  # unique names: add a middle initial
			rec.first = "%s %s." % [rec.first.split(" ")[0], NpcNames.MIDDLE_INITIALS[rng.randi() % NpcNames.MIDDLE_INITIALS.length()]]
			nm = full_name(rec)
		used_names[nm] = true
		people.append(rec)

	var places := _index_places(buildings)
	_assign_jobs(people, buildings, places, rng)
	_assign_homes(people, buildings, rng)
	_assign_social(people, buildings, rng)
	# Spouses who took a partner's surname can collide with someone else.
	used_names.clear()
	for rec in people:
		var nm := full_name(rec)
		while used_names.has(nm):
			rec.first = "%s %s." % [rec.first.split(" ")[0], NpcNames.MIDDLE_INITIALS[rng.randi() % NpcNames.MIDDLE_INITIALS.length()]]
			nm = full_name(rec)
		used_names[nm] = true
	for rec in people:
		_build_schedules(rec, buildings, places, rng)
	return people


# --- appearance helpers -------------------------------------------------------

static func _weighted(shares: Dictionary, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var acc := 0.0
	for k in shares:
		acc += shares[k]
		if r <= acc: return k
	return shares.keys()[0]


static func _random_weight(rng: RandomNumberGenerator, sex: String, height_cm: float, age: int) -> float:
	var median_bmi := (25.6 if sex == "male" else 24.6) + clampf((age - 22) * 0.06, 0.0, 2.2)
	var b := clampf(median_bmi * exp(rng.randfn(0.0, 0.14)), 17.0, 45.0)
	var m := height_cm / 100.0
	return b * m * m


static func _random_hair_color(rng: RandomNumberGenerator, age: int, complexion: float) -> int:
	if age > 58 and rng.randf() < clampf((age - 55) / 25.0, 0.0, 0.9):
		return 8 if rng.randf() < 0.6 else 9
	if complexion > 0.45:
		return rng.randi() % 2
	return [0, 1, 2, 2, 3, 3, 4, 5, 6, 7][rng.randi() % 10]


static func _random_hair_style(rng: RandomNumberGenerator, sex: String, age: int) -> String:
	if sex == "male":
		if age > 45 and rng.randf() < 0.25: return "bald"
		return ["buzz", "short", "short", "short", "medium", "curly", "long"][rng.randi() % 7]
	return ["short", "medium", "long", "long", "bun", "ponytail", "curly"][rng.randi() % 7]


static func _random_outfit(rng: RandomNumberGenerator, sex: String) -> Dictionary:
	var bottoms := ["pants", "pants", "pants", "shorts", "shorts"]
	if sex == "female":
		bottoms += ["skirt", "skirt", "capris"]
	return {
		"top": TOP_COLORS[rng.randi() % TOP_COLORS.size()],
		"bottom": BOTTOM_COLORS[rng.randi() % BOTTOM_COLORS.size()],
		"shoes": SHOE_COLORS[rng.randi() % SHOE_COLORS.size()],
		"bottom_style": bottoms[rng.randi() % bottoms.size()],
		"sleeves": ["short", "short", "short", "long", "three_quarter", "tank"][rng.randi() % 6],
	}


const INTERESTS := ["music", "sports", "art", "gaming", "school", "partying", "reading", "cooking", "fitness", "film", "hiking", "fashion", "tech", "politics", "religion", "gardening", "basketball", "coffee"]

static func _random_interests(rng: RandomNumberGenerator, rec: Dictionary) -> Array:
	var out: Array = []
	var n := 2 + rng.randi() % 3
	var pool := INTERESTS.duplicate()
	if rec.age < 26: pool += ["partying", "gaming", "school", "basketball"]
	if rec.age > 55: pool += ["gardening", "reading", "religion"]
	while out.size() < n:
		var it: String = pool[rng.randi() % pool.size()]
		if not out.has(it): out.append(it)
	return out


static func _age_for_role(rng: RandomNumberGenerator, role: String) -> int:
	match role:
		"student": return 18 + int(absf(rng.randfn(0.0, 2.2))) % 9
		"retired": return rng.randi_range(65, 88)
		"unemployed": return rng.randi_range(19, 60)
	return clampi(int(rng.randfn(39.0, 11.0)), 22, 68)


# --- places, jobs, homes ------------------------------------------------------

static func _category_of(b: Dictionary) -> String:
	if b.business != null and CATEGORY.has(b.business):
		return CATEGORY[b.business]
	if b.typology == "bar": return "bar"
	if b.typology == "diner": return "food"
	return CATEGORY.get(b.typology, "")


## Lists of building indices that serve each kind of outing.
static func _index_places(buildings: Array) -> Dictionary:
	var p := {"food": [], "cafe": [], "shop": [], "bar": [], "academic": [], "library": [], "any": []}
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		var c := _category_of(b)
		p.any.append(i)
		if c in ["food", "early_food"]: p.food.append(i)
		if b.business in ["cafe", "bakery", "breakfast"]: p.cafe.append(i)
		if c in ["shop", "salon"]: p.shop.append(i)
		if c == "bar": p.bar.append(i)
		if c == "academic": p.academic.append(i)
		if c == "library": p.library.append(i)
	return p


static func _assign_jobs(people: Array, buildings: Array, places: Dictionary, rng: RandomNumberGenerator) -> void:
	var slots: Array = []  # one entry per job opening, building index
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if _category_of(b) == "" or b.jobs <= 0:
			continue
		for k in b.jobs:
			slots.append(i)
	# Every workplace keeps its first opening so no shop is unstaffed.
	var firsts := {}
	var primary: Array = []
	var rest: Array = []
	for s in slots:
		if firsts.has(s): rest.append(s)
		else:
			firsts[s] = true
			primary.append(s)
	_shuffle(rest, rng)
	slots = primary + rest
	var k := 0
	for rec in people:
		if rec.role != "worker" or k >= slots.size():
			if rec.role == "worker":
				rec.role = "unemployed"
			continue
		var bi: int = slots[k]
		k += 1
		var b: Dictionary = buildings[bi]
		var cat := _category_of(b)
		var job: Array = JOBS[cat][rng.randi() % JOBS[cat].size()]
		if cat == "academic" and rec.age < 28 and job[0] == "Professor":
			job = ["Teaching Assistant", 18.0]
		rec.workplace = b.id
		rec._work_idx = bi
		rec._category = cat
		rec.occupation = job[0]
		rec.wage_per_hour = snappedf(job[1] * rng.randf_range(0.92, 1.12), 0.25)
		var shift: Array = SHIFTS[cat]
		rec._shift_start = shift[0][rng.randi() % shift[0].size()]
		rec._shift_len = shift[1]
		var days := [true, true, true, true, true, false, false]
		if cat in SEVEN_DAY:  # five days on, rotating which two are off
			var off := rng.randi() % 7
			days = [true, true, true, true, true, true, true]
			days[off] = false
			days[(off + 1) % 7] = false
		rec.work_days = days
	for rec in people:
		match rec.role:
			"student":
				rec.occupation = "Student"
				rec.work_days = [true, true, true, true, true, false, false]
			"retired": rec.occupation = "Retired"
			"unemployed": rec.occupation = "Between jobs"


static func _assign_homes(people: Array, buildings: Array, rng: RandomNumberGenerator) -> void:
	var dorms: Array = []
	var homes: Array = []
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if b.homes <= 0: continue
		if b.typology.begins_with("residence"): dorms.append(i)
		else: homes.append(i)
	var students: Array = people.filter(func(p): return p.role == "student")
	var others: Array = people.filter(func(p): return p.role != "student")
	# Dorms first for students, overflow students rent in town.
	var dorm_slots: Array = []
	for i in dorms:
		for k in buildings[i].homes: dorm_slots.append(i)
	_shuffle(dorm_slots, rng)
	var renters: Array = []
	for s in students.size():
		if s < dorm_slots.size():
			_move_in(students[s], buildings, dorm_slots[s])
		else:
			renters.append(students[s])
	var townies: Array = others + renters
	_shuffle(townies, rng)
	var cap_total := 0
	for i in homes: cap_total += buildings[i].homes
	var scale := float(townies.size()) / float(cap_total)
	# Households: walk the home list, fill each with a group sized to its share.
	var hi := 0
	var p := 0
	var carry := 0.0
	while p < townies.size():
		var bi: int = homes[hi % homes.size()]
		carry += buildings[bi].homes * scale
		var size := maxi(1, int(carry))
		carry -= size
		var group: Array = []
		for k in size:
			if p >= townies.size(): break
			_move_in(townies[p], buildings, bi)
			group.append(townies[p])
			p += 1
		_link_household(group, rng)
		hi += 1
	# Dorm roommates: pairs in the same building.
	var by_dorm := {}
	for s in students:
		if s.has("_home_idx") and buildings[s._home_idx].typology.begins_with("residence"):
			by_dorm.get_or_add(s._home_idx, []).append(s)
	for d in by_dorm:
		var list: Array = by_dorm[d]
		for k in range(0, list.size() - 1, 2):
			list[k].social.household = [list[k + 1].id]
			list[k + 1].social.household = [list[k].id]


static func _move_in(rec: Dictionary, buildings: Array, bi: int) -> void:
	rec.home = buildings[bi].id
	rec._home_idx = bi


static func _link_household(group: Array, rng: RandomNumberGenerator) -> void:
	for a in group:
		for b in group:
			if a != b: a.social.household.append(b.id)
	if group.size() < 2: return
	var a: Dictionary = group[0]
	var b: Dictionary = group[1]
	if a.role != "student" and b.role != "student" and absi(a.age - b.age) <= 12 and rng.randf() < 0.6:
		var kind := "spouse" if rng.randf() < 0.55 else "partner"
		a.social.partner = b.id
		b.social.partner = a.id
		a.social.partner_kind = kind
		b.social.partner_kind = kind
		if kind == "spouse" and rng.randf() < 0.7:
			b.last = a.last


static func _assign_social(people: Array, buildings: Array, rng: RandomNumberGenerator) -> void:
	var by_work := {}
	for rec in people:
		if rec.workplace != "": by_work.get_or_add(rec.workplace, []).append(rec)
	for w in by_work:
		var list: Array = by_work[w]
		for rec in list:
			var picks := _pick(list, mini(4, list.size() - 1), rng, rec)
			rec.social.coworkers = picks.map(func(o): return o.id)
	var students: Array = people.filter(func(p): return p.role == "student")
	for rec in students:
		rec.social.classmates = _pick(students, 4, rng, rec).map(func(o): return o.id)
	# Friends: similar age, homes not too far apart. Symmetric, 2 to 4 each.
	var sorted_people := people.duplicate()
	sorted_people.sort_custom(func(a, b): return a.age < b.age)
	for idx in sorted_people.size():
		var rec: Dictionary = sorted_people[idx]
		var want := 2 + rng.randi() % 3
		var tries := 0
		while rec.social.friends.size() < want and tries < 12:
			tries += 1
			var j := clampi(idx + rng.randi_range(-40, 40), 0, sorted_people.size() - 1)
			var o: Dictionary = sorted_people[j]
			if o == rec or o.social.friends.has(rec.id) or o.social.friends.size() >= 5: continue
			var d: float = _door(buildings[rec._home_idx]).distance_to(_door(buildings[o._home_idx]))
			if d > 700.0 and rng.randf() < 0.7: continue
			rec.social.friends.append(o.id)
			o.social.friends.append(rec.id)


static func _pick(list: Array, n: int, rng: RandomNumberGenerator, exclude: Dictionary) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < n * 4:
		tries += 1
		var o: Dictionary = list[rng.randi() % list.size()]
		if o != exclude and not out.has(o): out.append(o)
	return out


# --- schedules ----------------------------------------------------------------

## A schedule is a list of blocks [start_hour, activity, building_index] sorted
## by hour, starting at 0.0. The block is in effect until the next one starts.
## Activities: sleep, home, work, class, study, eat, shop, leisure, stroll.
static func _build_schedules(rec: Dictionary, buildings: Array, places: Dictionary, rng: RandomNumberGenerator) -> void:
	var home: int = rec._home_idx
	var near_home := _near_lists(buildings, places, home)
	match rec.role:
		"worker":
			rec.day_work = _worker_day(rec, buildings, places, near_home, rng)
			rec.day_off = _free_day(rec, near_home, rng)
		"student":
			rec.day_work = _student_day(rec, places, near_home, rng)
			rec.day_off = _free_day(rec, near_home, rng)
		_:
			rec.day_off = _free_day(rec, near_home, rng)
			rec.day_work = rec.day_off
	for k in ["_home_idx", "_work_idx", "_category", "_shift_start", "_shift_len"]:
		if rec.has(k):
			rec["home_index" if k == "_home_idx" else ("work_index" if k == "_work_idx" else k)] = rec[k]
	for k in ["_home_idx", "_work_idx", "_category", "_shift_start", "_shift_len"]:
		rec.erase(k)
	if not rec.has("work_index"):
		rec.work_index = -1


static func _worker_day(rec: Dictionary, buildings: Array, places: Dictionary, nh: Dictionary, rng: RandomNumberGenerator) -> Array:
	var home: int = rec._home_idx
	var job: int = rec._work_idx
	var s: float = rec._shift_start
	var l: float = rec._shift_len
	var nw := _near_lists(buildings, places, job)
	var wake := s - rng.randf_range(1.0, 1.75)
	var ev: Array = [[wake, "home", home]]
	if rng.randf() < 0.3 and not nh.cafe.is_empty():
		ev.append([wake + 0.4, "eat", _choose(nh.cafe, rng)])
	ev.append([s, "work", job])
	if l >= 6.0 and not nw.food.is_empty():
		ev.append([s + l * 0.5, "eat", _choose(nw.food, rng)])
		ev.append([s + l * 0.5 + 0.5, "work", job])
	var t := s + l
	var bed := wake - rng.randf_range(7.0, 8.5) + 24.0
	if bed - t > 2.5:
		var soc: float = rec.traits.outgoing
		var r := rng.randf()
		if soc > 0.6 and r < 0.5 and not nh.bar.is_empty():
			ev.append([t, "leisure", _choose(nh.bar, rng)])
		elif r < 0.35:
			ev.append([t, "shop", _choose(nh.shop, rng)])
		elif r < 0.55:
			ev.append([t, "stroll", _choose(nh.any, rng)])
		else:
			ev.append([t, "eat", _choose(nh.food, rng)])
		t += rng.randf_range(0.75, 1.75)
	ev.append([t, "home", home])
	ev.append([bed, "sleep", home])
	return _normalize(ev)


static func _student_day(rec: Dictionary, places: Dictionary, nh: Dictionary, rng: RandomNumberGenerator) -> Array:
	var home: int = rec._home_idx
	var wake := rng.randf_range(7.25, 9.25)
	var ev: Array = [[wake, "home", home]]
	var t := ceilf(wake + 0.5)
	var classes := 2 + rng.randi() % 2
	for c in classes:
		ev.append([t, "class", _choose(places.academic, rng)])
		t += 1.25
		if t >= 12.0 and t < 13.5 and not nh.food.is_empty():
			ev.append([t, "eat", _choose(places.food, rng)])
			t += 0.75
		t = ceilf(t * 4.0) / 4.0 + 0.25
	if not places.library.is_empty() and rng.randf() < 0.4 + rec.traits.ambitious * 0.5:
		ev.append([t, "study", _choose(places.library, rng)])
		t += rng.randf_range(1.0, 2.5)
	ev.append([t, "home", home])
	ev.append([18.0 + rng.randf_range(0.0, 1.5), "eat", _choose(places.food, rng)])
	ev.append([19.5 + rng.randf_range(0.0, 0.5), "home", home])
	if rec.traits.outgoing > 0.55 and not nh.bar.is_empty():
		ev.append([21.5 + rng.randf_range(0.0, 1.0), "leisure", _choose(nh.bar, rng)])
		ev.append([23.5 + rng.randf_range(0.0, 0.75), "home", home])
	ev.append([24.0 + rng.randf_range(0.0, 1.75), "sleep", home])
	return _normalize(ev)


static func _free_day(rec: Dictionary, nh: Dictionary, rng: RandomNumberGenerator) -> Array:
	var home: int = rec._home_idx
	var early: bool = rec.role == "retired"
	var wake := rng.randf_range(6.0, 7.75) if early else rng.randf_range(7.5, 10.5)
	var ev: Array = [[wake, "home", home]]
	var t := wake + rng.randf_range(0.75, 2.0)
	var outings := 1 + rng.randi() % 3
	var kinds := ["shop", "eat", "stroll", "stroll", "study"]
	for o in outings:
		var kind: String = kinds[rng.randi() % kinds.size()]
		var list: Array = nh.get({"shop": "shop", "eat": "food", "stroll": "any", "study": "library"}[kind], nh.any)
		if list.is_empty(): list = nh.any
		ev.append([t, kind, _choose(list, rng)])
		t += rng.randf_range(0.75, 2.0)
		ev.append([t, "home", home])
		t += rng.randf_range(1.0, 3.0)
	var bed := rng.randf_range(21.0, 23.0) if early else rng.randf_range(22.5, 25.5)
	if not early and rec.traits.outgoing > 0.5 and not nh.bar.is_empty() and t < bed - 2.0:
		ev.append([maxf(t, 20.0), "leisure", _choose(nh.bar, rng)])
		ev.append([maxf(t, 20.0) + rng.randf_range(1.5, 3.0), "home", home])
	ev.append([bed, "sleep", home])
	return _normalize(ev)


## Wraps hours into 0..24, sorts, and adds the block that is running at midnight.
static func _normalize(ev: Array) -> Array:
	var out: Array = []
	for e in ev:
		out.append([snappedf(fposmod(e[0], 24.0), 0.05), e[1], e[2]])
	out.sort_custom(func(a, b): return a[0] < b[0])
	var midnight: Array = out[out.size() - 1]
	if out[0][0] > 0.0:
		out.push_front([0.0, midnight[1], midnight[2]])
	return out


static var _near_cache := {}

## For a building: the 6 nearest of each kind of place.
static func _near_lists(buildings: Array, places: Dictionary, bi: int) -> Dictionary:
	if _near_cache.has(bi): return _near_cache[bi]
	var origin := _door(buildings[bi])
	var res := {}
	for kind in places:
		var list: Array = places[kind]
		if kind == "any":
			list = list.filter(func(j): return _door(buildings[j]).distance_squared_to(origin) < 250.0 * 250.0)
		var scored: Array = list.map(func(j): return [_door(buildings[j]).distance_squared_to(origin), j])
		scored.sort_custom(func(a, b): return a[0] < b[0])
		res[kind] = scored.slice(0, 8 if kind == "any" else 6).map(func(x): return x[1])
	_near_cache[bi] = res
	return res


static func _door(b: Dictionary) -> Vector3:
	return Vector3(b.door[0], b.door[1], b.door[2])


static func _choose(list: Array, rng: RandomNumberGenerator) -> int:
	return list[rng.randi() % list.size()]


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
