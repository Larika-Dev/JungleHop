extends RefCounted
## The player's body and looks. All values are internal (not shown in the HUD);
## other systems read them through this object.
##
## composite attractiveness (1..10) = base + style (0..+2) + self (-2..+2) - hygiene penalty
##   base:  rolled once at character creation, 1..10
##   style: outfit quality (clothes, lasts a game month) and grooming
##   self:  body: BMI (best at the median healthy BMI, 21.7) and muscle (best at 7)

signal attractiveness_changed(value: float)
signal weight_changed(kg: float)

const IDEAL_BMI := 21.7
const IDEAL_MUSCLE := 7.0
const KCAL_PER_KG := 7700.0
const KCAL_PER_HUNGER_POINT := 25.0
const MONTH_MINUTES := 30.0 * 1440.0
const MUSCLE_PRESETS := {"slim": 2.5, "lean": 4.0, "average": 4.5, "athletic": 6.5, "toned": 6.0,
	"muscular": 8.0, "bodybuilder": 9.5, "heavy": 4.0, "stocky": 5.5}

var sex: String = ""
var age: int = 18
var height_cm: float = 172.0
var weight_kg: float = 66.0
var muscle: float = 4.5
var base_attractiveness: float = 5.5
## Outfit quality 0..1 from the last clothes purchase; drops to OUTFIT_WORN after a month.
var outfit_quality: float = 0.3
var outfit_until: float = 0.0
## Salon-level grooming (haircut, color, manicure): points 0..4, last a month.
var salon_points: float = 0.0
var salon_until: float = 0.0
## Daily care (shave, makeup, fixing hair): points 0..2, last a day.
var daily_care_points: float = 0.0
var daily_care_until: float = 0.0

## Today's energy balance, settled at midnight.
var kcal_in_today: float = 0.0
var kcal_burned_today: float = 0.0
var days_since_workout: int = 0

const OUTFIT_WORN := 0.25

var _life: Node
var _rng := RandomNumberGenerator.new()


func _init(life: Node) -> void:
	_life = life
	_rng.randomize()
	base_attractiveness = roll_base()


func _now() -> float:
	return _life.clock.total_minutes if _life and _life.clock else 0.0


## Base looks: a bell curve around 5.5, clamped to 1..10, one decimal.
func roll_base() -> float:
	return snappedf(clampf(_rng.randfn(5.5, 1.5), 1.0, 10.0), 0.1)


# --- Character creation --------------------------------------------------------

## Seed the body from the character-creation screen. Accepts:
##   sex, age, height_cm, weight_kg, muscularity (0..10 or a preset name:
##   slim, lean, average, athletic, toned, muscular, bodybuilder, heavy, stocky),
##   base_attractiveness (1..10, else rolled), seed (int, optional).
## GameState.player_profile keys (height_cm, build) work as well.
func setup(p: Dictionary) -> void:
	if p.has("seed"):
		_rng.seed = int(p.seed)
	sex = str(p.get("sex", sex))
	age = clampi(int(p.get("age", age)), 18, 99)
	height_cm = clampf(float(p.get("height_cm", height_cm)), 120.0, 230.0)
	if p.has("weight_kg"):
		weight_kg = clampf(float(p.weight_kg), 35.0, 250.0)
	elif p.has("weight_lb"):
		weight_kg = clampf(float(p.weight_lb) * 0.45359237, 35.0, 250.0)
	else:
		weight_kg = snappedf(IDEAL_BMI * pow(height_cm / 100.0, 2), 0.1)
	# Foundation profile: "muscle" 1..10; "build" there is 0..1 from BMI, so only a
	# preset name in "build" counts.
	var m: Variant = p.get("muscle", p.get("muscularity", muscle))
	if p.get("build") is String and not p.has("muscle") and not p.has("muscularity"):
		m = p.build
	if m is String:
		muscle = float(MUSCLE_PRESETS.get(str(m).to_lower(), 4.5))
	else:
		muscle = clampf(float(m), 0.0, 10.0)
	base_attractiveness = clampf(float(p.base_attractiveness), 1.0, 10.0) if p.has("base_attractiveness") else roll_base()
	outfit_quality = 0.3
	outfit_until = 0.0
	salon_points = 0.0
	daily_care_points = 0.0
	kcal_in_today = 0.0
	kcal_burned_today = 0.0
	_emit()


# --- Derived values ------------------------------------------------------------

func bmi() -> float:
	var m := height_cm / 100.0
	return weight_kg / (m * m)


func bmi_category() -> String:
	var b := bmi()
	if b < 18.5:
		return "underweight"
	if b < 25.0:
		return "healthy"
	if b < 30.0:
		return "overweight"
	return "obese"


## -1..1: 1 at BMI 21.7, 0 about 4 BMI points away, -1 about 8 away.
func bmi_quality() -> float:
	return clampf(1.0 - absf(bmi() - IDEAL_BMI) / 4.0, -1.0, 1.0)


## -1..1: 1 at muscle 7, 0 at 3.5 (or 10.5), -1 at 0.
func muscle_quality() -> float:
	return clampf(1.0 - absf(muscle - IDEAL_MUSCLE) / 3.5, -1.0, 1.0)


func outfit_now() -> float:
	return outfit_quality if _now() < outfit_until else min(outfit_quality, OUTFIT_WORN)


## Internal grooming score 0..10: hygiene (0..4) + salon work (0..4, a month)
## + daily care (0..2, a day).
func grooming() -> float:
	var g: float = _life.needs.get_value("hygiene") / 100.0 * 4.0 if _life.needs.enabled else 3.0
	if _now() < salon_until:
		g += salon_points
	if _now() < daily_care_until:
		g += daily_care_points
	return clampf(g, 0.0, 10.0)


## 0..2 from clothes and grooming.
func style_bonus() -> float:
	return 2.0 * clampf(0.6 * outfit_now() + 0.4 * grooming() / 10.0, 0.0, 1.0)


## -2..2 from working on yourself: weight and muscle.
func self_bonus() -> float:
	return 2.0 * (0.55 * bmi_quality() + 0.45 * muscle_quality())


func hygiene_penalty() -> float:
	if not _life.needs.enabled:
		return 0.0
	var h: float = _life.needs.get_value("hygiene")
	return 1.0 if h < 15.0 else (0.5 if h < 30.0 else 0.0)


## Composite attractiveness, 1..10.
func attractiveness() -> float:
	return clampf(base_attractiveness + style_bonus() + self_bonus() - hygiene_penalty(), 1.0, 10.0)


## How someone would rate you: the composite within +-1, whole number 1..10.
func perceived_rating(rng: RandomNumberGenerator = _rng) -> int:
	return clampi(int(round(attractiveness() + rng.randf_range(-1.0, 1.0))), 1, 10)


## What the visible body and face need (NPC thread / player appearance).
## fat 0..1 (0 very lean, 0.5 healthy, 1 obese), muscle_norm 0..1, grooming_norm 0..1.
func visual_params() -> Dictionary:
	return {
		"height_cm": height_cm, "weight_kg": snappedf(weight_kg, 0.1), "bmi": snappedf(bmi(), 0.1),
		"fat": clampf((bmi() - 16.0) / 20.0, 0.0, 1.0), "muscle": snappedf(muscle, 0.01),
		"muscle_norm": clampf(muscle / 10.0, 0.0, 1.0), "grooming": snappedf(grooming(), 0.01),
		"grooming_norm": clampf(grooming() / 10.0, 0.0, 1.0), "outfit": snappedf(outfit_now(), 0.01),
		"hygiene": _life.needs.get_value("hygiene"), "attractiveness": snappedf(attractiveness(), 0.01),
	}


func summary() -> Dictionary:
	return {
		"sex": sex, "age": age, "height_cm": height_cm, "weight_kg": snappedf(weight_kg, 0.1),
		"bmi": snappedf(bmi(), 0.1), "bmi_category": bmi_category(), "muscle": snappedf(muscle, 0.01),
		"grooming": snappedf(grooming(), 0.01), "outfit": snappedf(outfit_now(), 0.01),
		"base": base_attractiveness, "style_bonus": snappedf(style_bonus(), 0.01),
		"self_bonus": snappedf(self_bonus(), 0.01), "attractiveness": snappedf(attractiveness(), 0.01),
	}


# --- Changes from actions ------------------------------------------------------

## Clothes: quality 0..1 (thrift 0.25 ... designer 1.0). A better outfit
## replaces a worse one; any purchase restarts the month.
func buy_outfit(quality: float) -> void:
	outfit_quality = max(clampf(quality, 0.0, 1.0), outfit_now())
	outfit_until = _now() + MONTH_MINUTES
	_emit()


## Salon grooming (haircut, color, manicure, piercing...): adds points up to 4, lasts a month.
func salon(points: float) -> void:
	var cur := salon_points if _now() < salon_until else 0.0
	salon_points = clampf(cur + points, 0.0, 4.0)
	salon_until = _now() + MONTH_MINUTES
	_emit()


## Daily care (shave, makeup, styling): up to 2 points, lasts a day.
func daily_care(points: float) -> void:
	var cur := daily_care_points if _now() < daily_care_until else 0.0
	daily_care_points = clampf(cur + points, 0.0, 2.0)
	daily_care_until = _now() + 1440.0
	_emit()


func ate(hunger_points: float) -> void:
	if hunger_points > 0.0:
		var k := hunger_points * KCAL_PER_HUNGER_POINT
		if _life.get_flag("body.dieting", false):
			k *= 0.7
		kcal_in_today += k


## Exercise from skill XP: fitness and athletics XP burn calories and build muscle.
func exercised(fitness_xp: float, athletics_xp: float = 0.0) -> void:
	var xp := fitness_xp + athletics_xp * 0.5
	if xp <= 0.0:
		return
	kcal_burned_today += xp * 9.0
	# Diminishing returns: easy gains early, slow near 10.
	muscle = clampf(muscle + fitness_xp / 260.0 * (1.0 - muscle / 11.0), 0.0, 10.0)
	days_since_workout = 0
	_emit()


func basal_kcal() -> float:
	# Mifflin-St Jeor with a light activity factor.
	var s := -78.0
	if sex.to_lower().begins_with("m"):
		s = 5.0
	elif sex.to_lower().begins_with("f"):
		s = -161.0
	return (10.0 * weight_kg + 6.25 * height_cm - 5.0 * age + s) * 1.35


## Settle the day's calories into weight; muscle fades without training.
func on_day(_day: int) -> void:
	var delta := kcal_in_today - basal_kcal() - kcal_burned_today
	# Starving days with no food still count as a deficit.
	weight_kg = clampf(weight_kg + delta / KCAL_PER_KG, 35.0, 250.0)
	kcal_in_today = 0.0
	kcal_burned_today = 0.0
	days_since_workout += 1
	_life.set_flag("body.dieting", null)
	if days_since_workout > 3:
		muscle = max(0.0, muscle - 0.02)
	weight_changed.emit(weight_kg)
	_emit()


func _emit() -> void:
	attractiveness_changed.emit(attractiveness())


func to_save() -> Dictionary:
	return {"sex": sex, "age": age, "height_cm": height_cm, "weight_kg": weight_kg, "muscle": muscle,
		"base": base_attractiveness, "outfit_quality": outfit_quality, "outfit_until": outfit_until,
		"salon_points": salon_points, "salon_until": salon_until, "daily_care_points": daily_care_points,
		"daily_care_until": daily_care_until, "kcal_in": kcal_in_today, "kcal_out": kcal_burned_today,
		"days_since_workout": days_since_workout}


func from_save(d: Dictionary) -> void:
	sex = str(d.get("sex", sex))
	age = int(d.get("age", age))
	height_cm = float(d.get("height_cm", height_cm))
	weight_kg = float(d.get("weight_kg", weight_kg))
	muscle = float(d.get("muscle", muscle))
	base_attractiveness = float(d.get("base", base_attractiveness))
	outfit_quality = float(d.get("outfit_quality", outfit_quality))
	outfit_until = float(d.get("outfit_until", outfit_until))
	salon_points = float(d.get("salon_points", 0.0))
	salon_until = float(d.get("salon_until", 0.0))
	daily_care_points = float(d.get("daily_care_points", 0.0))
	daily_care_until = float(d.get("daily_care_until", 0.0))
	kcal_in_today = float(d.get("kcal_in", 0.0))
	kcal_burned_today = float(d.get("kcal_out", 0.0))
	days_since_workout = int(d.get("days_since_workout", 0))
