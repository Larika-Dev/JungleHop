## Appearance math shared by the 4,000 generated NPCs, the NPC generator tool
## and (if the foundation wants it) player customization.
## Everything here is a pure function: same inputs, same look.
class_name NpcAppearance
extends RefCounted

# Complexion slider 0.0 (lightest) to 1.0 (deepest). Stops are linear-ish sRGB
# skin tones from very fair through olive and brown to very deep.
const COMPLEXION_STOPS := [
	Color("#f6e1d3"), Color("#ecc7ae"), Color("#e0ae8c"), Color("#c99473"),
	Color("#b07a56"), Color("#8f5d3d"), Color("#6e4329"), Color("#50301d"), Color("#3a2216"),
]
const HAIR_COLORS := [
	Color("#141110"), Color("#2b1e16"), Color("#4a3121"), Color("#6b4a2f"),
	Color("#8c6a44"), Color("#b8925f"), Color("#d8bd8a"), Color("#8e3b1f"),
	Color("#a8a29a"), Color("#e3e0da"),
]
const EYE_COLORS := [Color("#3b2414"), Color("#5a3a1e"), Color("#6f5a2e"), Color("#4d6b3a"), Color("#4a6a8a"), Color("#7a8fa3")]
const HAIR_STYLES := ["buzz", "short", "medium", "long", "bun", "ponytail", "curly", "bald"]
const BOTTOM_STYLES := {"pants": 0.055, "capris": 0.17, "shorts": 0.30, "skirt": 0.31}  # hem height / body height
const SLEEVE_STYLES := {"long": 0.47, "three_quarter": 0.58, "short": 0.71, "tank": 0.80}

const KG_PER_LB := 0.45359237
const CM_PER_IN := 2.54


static func complexion_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0) * float(COMPLEXION_STOPS.size() - 1)
	var i := mini(int(t), COMPLEXION_STOPS.size() - 2)
	return (COMPLEXION_STOPS[i] as Color).lerp(COMPLEXION_STOPS[i + 1], t - float(i))


static func ft_in_to_cm(feet: float, inches: float) -> float:
	return snappedf((feet * 12.0 + inches) * CM_PER_IN, 0.1)


static func cm_to_ft_in(cm: float) -> Vector2:
	var total := cm / CM_PER_IN
	var ft := floorf(total / 12.0)
	return Vector2(ft, snappedf(total - ft * 12.0, 0.1))


static func lb_to_kg(lb: float) -> float:
	return snappedf(lb * KG_PER_LB, 0.1)


static func kg_to_lb(kg: float) -> float:
	return snappedf(kg / KG_PER_LB, 0.1)


static func bmi(height_cm: float, weight_kg: float) -> float:
	var m := height_cm / 100.0
	return weight_kg / (m * m)


## Blend shape weights for the body mesh from height, weight and how muscular
## the person is (0..1). `fat` widens the waist, hips and limbs; `slim` is the
## opposite for very low BMI; `muscle` adds shoulder, arm, thigh and calf mass.
static func body_shape(height_cm: float, weight_kg: float, muscle: float) -> Dictionary:
	var b := bmi(height_cm, weight_kg)
	# Muscle carries weight too, so part of a high BMI is explained by it.
	var lean_bmi := b - muscle * 3.0
	return {
		"fat": clampf((lean_bmi - 22.0) / 16.0, 0.0, 1.0),
		"slim": clampf((20.5 - lean_bmi) / 4.0, 0.0, 1.0),
		"muscle": clampf(muscle, 0.0, 1.0),
	}


## Everything an NpcBody needs to look like this person. `rec` is an NPC record
## (see NpcPopulation) or any Dictionary with the same keys.
static func body_params(rec: Dictionary) -> Dictionary:
	var shape := body_shape(rec.height_cm, rec.weight_kg, rec.get("muscle", 0.3))
	return {
		"sex": rec.sex,
		"height_cm": rec.height_cm,
		"shape": shape,
		"skin": complexion_color(rec.complexion),
		"hair": HAIR_COLORS[rec.hair_color],
		"hair_style": rec.hair_style,
		"eyes": EYE_COLORS[rec.eye_color],
		"top": Color(rec.outfit.top),
		"bottom": Color(rec.outfit.bottom),
		"shoes": Color(rec.outfit.shoes),
		"bottom_cut": BOTTOM_STYLES[rec.outfit.bottom_style],
		"sleeve_cut": SLEEVE_STYLES[rec.outfit.sleeves],
	}


## Turns the foundation's GameState.player_profile into a record NpcBody can
## wear, so the player can use the same detailed body as NPCs:
##   body.apply_record(NpcAppearance.record_from_profile(GameState.player_profile))
static func record_from_profile(p: Dictionary) -> Dictionary:
	var h := float(p.get("height_cm", 175))
	var sex: String = p.get("sex", "male")
	var bmi_target := lerpf(19.5, 31.0, float(p.get("build", 0.5)))
	var skin_i := int(p.get("skin", 2))
	return {
		"id": -1, "npc_id": "player", "first": String(p.get("name", "Player")), "last": "", "sex": sex, "age": 20,
		"height_cm": h, "weight_kg": p.get("weight_kg", bmi_target * pow(h / 100.0, 2)), "muscle": float(p.get("muscle", 3)) / 10.0,
		"complexion": float(p.get("complexion", skin_i / 5.0)), "hair_color": clampi(int(p.get("hair_color", 1)), 0, HAIR_COLORS.size() - 1),
		"hair_style": ["bald", "short", "medium", "long", "ponytail", "buzz", "bun"][clampi(int(p.get("hair_style", 1)), 0, 6)],
		"eye_color": 0,
		"outfit": {"top": "#80B4D9", "bottom": "#2F3F33", "shoes": "#18191A", "bottom_style": "pants", "sleeves": "short"},
		"traits": {}, "interests": [], "personality_id": 0,
	}
