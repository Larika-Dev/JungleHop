## Every crime the player can commit: 39 of them, from jaywalking to murder.
##
## Fields of each entry:
##   id          unique id; the Life action id is "crime_" + id
##   name        menu label
##   category    traffic | public_order | property | theft | violent | drugs | fraud | police
##   class       infraction | misdemeanor | felony  (decides the criminal record and job checks)
##   stars       wanted stars when the crime is reported (0 = only a ticket if police see it)
##   fine        dollars charged on arrest or citation
##   jail_hours  in-game hours of jail on arrest (1 in-game hour = 1 real minute)
##   notice      0..1, how noticeable the crime is to someone standing nearby
##   radius      metres within which NPCs can witness it
##   target      self | npc | furniture | place  (what the action is performed on)
##   minutes     in-game minutes the action takes
##   menu        false = triggered by game systems (driving, police), not shown as an action
##   loot        [min, max] dollars gained on success
##   victim_rel  friendship change for the victim NPC
##   witness_rel friendship change for a witness NPC
##   place       place tags/categories the action needs (Life.place), when target is place
##   chance      success chance (failure means the victim notices)
##   skill       Life skill that raises the success chance and earns XP
##   harm        "" | "hurt" | "killed"  (for the NPC system, via Law.npc_harmed)
##   desc        one line for menus and the rap sheet
extends RefCounted

const CLASS_ORDER := {"infraction": 0, "misdemeanor": 1, "felony": 2}

const CRIMES: Array[Dictionary] = [
	# ---- Public order: minor ----
	{"id": "jaywalking", "name": "Jaywalk", "category": "public_order", "class": "infraction",
		"stars": 0, "fine": 25, "jail_hours": 0, "notice": 0.6, "radius": 30.0, "target": "self",
		"minutes": 1, "witness_rel": 0, "desc": "Cross the street away from a crosswalk."},
	{"id": "littering", "name": "Litter", "category": "public_order", "class": "infraction",
		"stars": 0, "fine": 50, "jail_hours": 0, "notice": 0.5, "radius": 15.0, "target": "self",
		"minutes": 1, "witness_rel": -1, "desc": "Drop trash on the ground."},
	{"id": "public_urination", "name": "Pee in public", "category": "public_order", "class": "infraction",
		"stars": 0, "fine": 100, "jail_hours": 0, "notice": 0.7, "radius": 20.0, "target": "self",
		"minutes": 2, "witness_rel": -4, "desc": "Relieve yourself somewhere that is not a restroom."},
	{"id": "noise_disturbance", "name": "Make a racket", "category": "public_order", "class": "infraction",
		"stars": 0, "fine": 75, "jail_hours": 0, "notice": 0.9, "radius": 40.0, "target": "self",
		"minutes": 10, "witness_rel": -3, "desc": "Disturb the peace with shouting or loud music."},
	{"id": "fare_evasion", "name": "Skip the bus fare", "category": "public_order", "class": "infraction",
		"stars": 0, "fine": 60, "jail_hours": 0, "notice": 0.5, "radius": 10.0, "target": "place",
		"place": ["bus", "transit", "bus_stop"], "minutes": 1, "witness_rel": -1,
		"desc": "Ride without paying."},
	{"id": "public_intoxication", "name": "Get drunk in public", "category": "public_order", "class": "misdemeanor",
		"stars": 1, "fine": 150, "jail_hours": 8, "notice": 0.6, "radius": 20.0, "target": "self",
		"minutes": 30, "witness_rel": -3, "desc": "Stagger around the street visibly drunk."},
	{"id": "trespassing", "name": "Trespass", "category": "public_order", "class": "misdemeanor",
		"stars": 1, "fine": 200, "jail_hours": 12, "notice": 0.5, "radius": 20.0, "target": "place",
		"place": ["restricted", "private", "staff_only", "residential"], "minutes": 5, "witness_rel": -3,
		"desc": "Go where you are not allowed."},
	{"id": "indecent_exposure", "name": "Streak", "category": "public_order", "class": "misdemeanor",
		"stars": 1, "fine": 500, "jail_hours": 24, "notice": 1.0, "radius": 50.0, "target": "self",
		"minutes": 3, "witness_rel": -8, "desc": "Run through the streets without clothes."},
	{"id": "harassment", "name": "Harass", "category": "public_order", "class": "misdemeanor",
		"stars": 1, "fine": 300, "jail_hours": 12, "notice": 0.7, "radius": 15.0, "target": "npc",
		"minutes": 5, "victim_rel": -25, "witness_rel": -5, "desc": "Follow and threaten someone."},

	# ---- Property ----
	{"id": "graffiti", "name": "Tag a wall", "category": "property", "class": "misdemeanor",
		"stars": 1, "fine": 300, "jail_hours": 8, "notice": 0.5, "radius": 25.0, "target": "self",
		"minutes": 15, "witness_rel": -2, "skill": "creativity", "desc": "Spray paint your tag."},
	{"id": "vandalism", "name": "Smash it", "category": "property", "class": "misdemeanor",
		"stars": 1, "fine": 500, "jail_hours": 24, "notice": 0.9, "radius": 30.0, "target": "furniture",
		"minutes": 2, "witness_rel": -5, "desc": "Break someone else's property."},
	{"id": "breaking_and_entering", "name": "Break in", "category": "property", "class": "misdemeanor",
		"stars": 2, "fine": 800, "jail_hours": 72, "notice": 0.6, "radius": 25.0, "target": "place",
		"place": ["residential", "private", "shop", "office", "restricted"], "minutes": 5,
		"chance": 0.7, "skill": "stealth", "witness_rel": -8, "desc": "Force a locked door or window."},
	{"id": "arson", "name": "Set it on fire", "category": "property", "class": "felony",
		"stars": 4, "fine": 10000, "jail_hours": 1440, "notice": 1.0, "radius": 80.0, "target": "furniture",
		"minutes": 3, "witness_rel": -30, "desc": "Start a fire on purpose."},

	# ---- Theft ----
	{"id": "shoplifting", "name": "Shoplift", "category": "theft", "class": "misdemeanor",
		"stars": 1, "fine": 250, "jail_hours": 12, "notice": 0.45, "radius": 12.0, "target": "place",
		"place": ["shopping", "shop", "retail", "grocery", "pharmacy"], "minutes": 2, "loot": [5, 60],
		"chance": 0.75, "skill": "stealth", "witness_rel": -4, "desc": "Slip something into your pocket."},
	{"id": "dine_and_dash", "name": "Dine and dash", "category": "theft", "class": "misdemeanor",
		"stars": 1, "fine": 150, "jail_hours": 8, "notice": 0.6, "radius": 15.0, "target": "place",
		"place": ["food", "restaurant", "cafe", "diner", "bar"], "minutes": 1, "loot": [10, 45],
		"witness_rel": -4, "desc": "Eat, then leave without paying."},
	{"id": "pickpocketing", "name": "Pickpocket", "category": "theft", "class": "misdemeanor",
		"stars": 1, "fine": 300, "jail_hours": 24, "notice": 0.35, "radius": 8.0, "target": "npc",
		"minutes": 1, "loot": [5, 80], "chance": 0.6, "skill": "stealth", "victim_rel": -30,
		"witness_rel": -5, "desc": "Lift a wallet without them noticing."},
	{"id": "bike_theft", "name": "Steal a bike", "category": "theft", "class": "misdemeanor",
		"stars": 1, "fine": 400, "jail_hours": 24, "notice": 0.55, "radius": 20.0, "target": "self",
		"minutes": 4, "loot": [40, 150], "chance": 0.8, "skill": "mechanics", "witness_rel": -4,
		"desc": "Cut a lock and ride off."},
	{"id": "car_theft", "name": "Steal a car", "category": "theft", "class": "felony",
		"stars": 2, "fine": 2000, "jail_hours": 168, "notice": 0.8, "radius": 30.0, "target": "self",
		"minutes": 3, "chance": 0.65, "skill": "mechanics", "witness_rel": -8, "desc": "Hotwire a parked car."},
	{"id": "burglary", "name": "Burgle", "category": "theft", "class": "felony",
		"stars": 2, "fine": 2500, "jail_hours": 240, "notice": 0.5, "radius": 20.0, "target": "place",
		"place": ["residential", "home", "apartment", "office"], "minutes": 20, "loot": [50, 400],
		"chance": 0.7, "skill": "stealth", "witness_rel": -12, "desc": "Clear out a home while nobody is in."},
	{"id": "robbery", "name": "Mug", "category": "theft", "class": "felony",
		"stars": 3, "fine": 3000, "jail_hours": 336, "notice": 0.9, "radius": 30.0, "target": "npc",
		"minutes": 2, "loot": [20, 200], "victim_rel": -60, "witness_rel": -15, "harm": "",
		"desc": "Demand someone's wallet."},
	{"id": "armed_robbery", "name": "Hold up the store", "category": "theft", "class": "felony",
		"stars": 4, "fine": 7500, "jail_hours": 720, "notice": 1.0, "radius": 40.0, "target": "place",
		"place": ["shopping", "shop", "retail", "grocery", "pharmacy", "food"], "minutes": 3,
		"loot": [200, 1500], "witness_rel": -25, "desc": "Empty the register at gunpoint."},
	{"id": "bank_robbery", "name": "Rob the bank", "category": "theft", "class": "felony",
		"stars": 5, "fine": 20000, "jail_hours": 2160, "notice": 1.0, "radius": 60.0, "target": "place",
		"place": ["bank", "finance"], "minutes": 10, "loot": [2000, 20000], "witness_rel": -35,
		"desc": "Take the vault. Every cop in town will come."},

	# ---- Fraud ----
	{"id": "fake_id", "name": "Use a fake ID", "category": "fraud", "class": "misdemeanor",
		"stars": 1, "fine": 500, "jail_hours": 24, "notice": 0.3, "radius": 5.0, "target": "place",
		"place": ["bar", "nightlife", "liquor"], "minutes": 1, "chance": 0.7, "skill": "charm",
		"witness_rel": -3, "desc": "Get past the bouncer with a forged card."},
	{"id": "check_fraud", "name": "Write a bad check", "category": "fraud", "class": "felony",
		"stars": 1, "fine": 1500, "jail_hours": 168, "notice": 0.25, "radius": 5.0, "target": "place",
		"place": ["bank", "finance", "shopping", "shop"], "minutes": 5, "loot": [100, 900],
		"chance": 0.6, "skill": "writing", "witness_rel": -6, "desc": "Cash a check that will bounce."},
	{"id": "embezzlement", "name": "Skim from work", "category": "fraud", "class": "felony",
		"stars": 1, "fine": 5000, "jail_hours": 480, "notice": 0.2, "radius": 5.0, "target": "self",
		"minutes": 15, "loot": [200, 2000], "chance": 0.7, "skill": "logic", "requires_flag": "job.on_shift",
		"witness_rel": -20, "desc": "Move company money into your pocket during a shift."},

	# ---- Drugs ----
	{"id": "drug_possession", "name": "Buy weed", "category": "drugs", "class": "misdemeanor",
		"stars": 1, "fine": 600, "jail_hours": 24, "notice": 0.3, "radius": 10.0, "target": "npc",
		"minutes": 3, "cost": 40, "witness_rel": -3, "desc": "Buy a bag from a guy behind the bar."},
	{"id": "drug_dealing", "name": "Deal drugs", "category": "drugs", "class": "felony",
		"stars": 3, "fine": 5000, "jail_hours": 480, "notice": 0.4, "radius": 12.0, "target": "npc",
		"minutes": 5, "loot": [50, 500], "chance": 0.8, "skill": "charm", "witness_rel": -10,
		"desc": "Sell to someone on the street."},

	# ---- Violent ----
	{"id": "simple_assault", "name": "Punch", "category": "violent", "class": "misdemeanor",
		"stars": 2, "fine": 500, "jail_hours": 48, "notice": 1.0, "radius": 30.0, "target": "npc",
		"minutes": 1, "victim_rel": -50, "witness_rel": -10, "harm": "hurt", "skill": "fitness",
		"desc": "Start a fist fight."},
	{"id": "aggravated_assault", "name": "Beat up badly", "category": "violent", "class": "felony",
		"stars": 3, "fine": 5000, "jail_hours": 720, "notice": 1.0, "radius": 40.0, "target": "npc",
		"minutes": 2, "victim_rel": -90, "witness_rel": -25, "harm": "hurt", "desc": "Put someone in the hospital."},
	{"id": "murder", "name": "Kill", "category": "violent", "class": "felony",
		"stars": 5, "fine": 25000, "jail_hours": 2160, "notice": 1.0, "radius": 60.0, "target": "npc",
		"minutes": 1, "victim_rel": -100, "witness_rel": -60, "harm": "killed",
		"desc": "Take a life. The heaviest sentence in the game."},

	# ---- Crimes against police ----
	{"id": "bribery", "name": "Bribe the officer", "category": "police", "class": "felony",
		"stars": 1, "fine": 2000, "jail_hours": 72, "notice": 0.2, "radius": 6.0, "target": "npc",
		"minutes": 2, "cost": 300, "chance": 0.35, "skill": "charm", "police_only": true, "witness_rel": -8,
		"desc": "Slip a cop $300. If it works, your wanted level clears."},
	{"id": "resisting_arrest", "name": "Resist arrest", "category": "police", "class": "misdemeanor",
		"stars": 1, "fine": 750, "jail_hours": 48, "notice": 1.0, "radius": 20.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": -3, "desc": "Fight back when the cuffs come out."},
	{"id": "evading_police", "name": "Evade police", "category": "police", "class": "misdemeanor",
		"stars": 1, "fine": 750, "jail_hours": 24, "notice": 1.0, "radius": 20.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": 0, "desc": "Get away from a police pursuit."},
	{"id": "assault_on_officer", "name": "Attack the officer", "category": "police", "class": "felony",
		"stars": 4, "fine": 7500, "jail_hours": 720, "notice": 1.0, "radius": 40.0, "target": "npc",
		"minutes": 1, "police_only": true, "witness_rel": -20, "harm": "hurt", "desc": "Swing at a cop."},

	# ---- Traffic (reported by the driving code through Law.commit) ----
	{"id": "speeding", "name": "Speeding", "category": "traffic", "class": "infraction",
		"stars": 0, "fine": 150, "jail_hours": 0, "notice": 0.8, "radius": 40.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": 0, "desc": "Drive more than 15 km/h over the limit."},
	{"id": "running_red_light", "name": "Run a red light", "category": "traffic", "class": "infraction",
		"stars": 0, "fine": 200, "jail_hours": 0, "notice": 0.9, "radius": 40.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": -1, "desc": "Go through the intersection on red."},
	{"id": "reckless_driving", "name": "Reckless driving", "category": "traffic", "class": "misdemeanor",
		"stars": 1, "fine": 800, "jail_hours": 24, "notice": 1.0, "radius": 50.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": -5, "desc": "Drive on sidewalks or into oncoming traffic."},
	{"id": "dui", "name": "Drunk driving", "category": "traffic", "class": "misdemeanor",
		"stars": 2, "fine": 1500, "jail_hours": 48, "notice": 0.7, "radius": 40.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": -8, "desc": "Drive after drinking."},
	{"id": "hit_and_run", "name": "Hit and run", "category": "traffic", "class": "felony",
		"stars": 3, "fine": 3000, "jail_hours": 240, "notice": 1.0, "radius": 50.0, "target": "self",
		"minutes": 0, "menu": false, "witness_rel": -25, "harm": "hurt",
		"desc": "Hit someone with a car and drive off."},
]

static var _by_id: Dictionary = {}


static func all() -> Array[Dictionary]:
	return CRIMES


static func ids() -> Array[String]:
	var out: Array[String] = []
	for c in CRIMES:
		out.append(String(c.id))
	return out


static func find(id: String) -> Dictionary:
	if _by_id.is_empty():
		for c in CRIMES:
			_by_id[String(c.id)] = c
	return _by_id.get(id, {})


static func has(id: String) -> bool:
	return not find(id).is_empty()


static func menu_crimes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in CRIMES:
		if bool(c.get("menu", true)):
			out.append(c)
	return out


static func class_rank(crime_class: String) -> int:
	return int(CLASS_ORDER.get(crime_class, 0))
