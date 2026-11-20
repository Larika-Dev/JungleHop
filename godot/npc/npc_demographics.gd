## Who lives in Cathedral Mount. Shares come from public data for the real
## town and university it is modeled on; sources are listed in
## godot/npc/docs/DEMOGRAPHICS.md. The game is an invented town, so these are
## used as proportions for a 4,000-person stand-in population, not a census.
class_name NpcDemographics
extends RefCounted

# Undergraduates: UNC-Chapel Hill IPEDS Fall Enrollment 2023-24 (fall 2023),
# 20,681 undergraduates. "Unknown" (2.3%) is spread across the other groups.
const STUDENT_FEMALE_SHARE := 0.607   # 12,553 of 20,681
const STUDENT_ETHNICITY := {
	"white": 0.553, "asian": 0.152, "hispanic": 0.100, "black": 0.084,
	"multiracial": 0.053, "international": 0.054, "american_indian": 0.004,
}

# Town residents who are not undergraduates: Chapel Hill town, 2024 ACS figures
# as published by Data USA (population 61,607). Non-Hispanic White 38.7k,
# Asian 8.23k, Black 6.94k, Hispanic 4.66k; the remainder is two or more races
# and other groups.
const TOWN_FEMALE_SHARE := 0.53
const TOWN_ETHNICITY := {
	"white": 0.628, "asian": 0.134, "black": 0.113, "hispanic": 0.076,
	"multiracial": 0.045, "american_indian": 0.004,
}

# Share of the 4,000 NPCs in each role. Undergraduates are a large part of the
# real town; residents who are not students include workers, retirees and people
# between jobs. Everyone generated is an adult, so the adult height table applies.
const ROLE_SHARE := {"student": 0.30, "retired": 0.12, "unemployed": 0.04}  # rest are workers

# Complexion slider ranges per group: [mean, spread]. A group gets a range, not
# one color, and groups overlap, like real people.
const COMPLEXION := {
	"white": [[0.12, 0.07, 0.85], [0.26, 0.06, 0.15]],
	"black": [[0.70, 0.12, 1.0]],
	"asian": [[0.22, 0.07, 0.65], [0.45, 0.10, 0.35]],   # East/Southeast, South Asian
	"hispanic": [[0.30, 0.09, 1.0]],
	"multiracial": [[0.42, 0.16, 1.0]],
	"international": [[0.25, 0.10, 0.55], [0.48, 0.12, 0.30], [0.70, 0.12, 0.15]],
	"american_indian": [[0.40, 0.08, 1.0]],
}


static func complexion_for(ethnicity: String, rng: RandomNumberGenerator) -> float:
	var parts: Array = COMPLEXION.get(ethnicity, COMPLEXION.multiracial)
	var r := rng.randf()
	var acc := 0.0
	for p in parts:
		acc += p[2]
		if r <= acc:
			return clampf(rng.randfn(p[0], p[1]), 0.0, 1.0)
	return clampf(rng.randfn(parts[0][0], parts[0][1]), 0.0, 1.0)


## `count` labels with exactly the given shares (largest remainder), shuffled.
static func exact_mix(shares: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var rema: Array = []
	for k in shares:
		var exact: float = shares[k] * count
		for i in int(exact):
			out.append(k)
		rema.append([exact - floorf(exact), k])
	rema.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while out.size() < count:
		out.append(rema[i % rema.size()][1])
		i += 1
	NpcPopulation._shuffle(out, rng)
	return out
