extends RefCounted
## Nursing and health question generator. Dosage math is computed; clinical
## knowledge comes from banks. Game content only, not medical advice.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"vitals": "Vital signs", "dosage_weight": "Weight-based dosing", "dosage_volume": "Liquid doses",
	"iv_rate": "IV infusion rates", "drip_rate": "Drip rates", "conversions": "Unit conversions",
	"triage": "Triage", "abbreviations": "Medical abbreviations", "pharmacology": "Drug classes",
	"infection": "Infection control", "ethics": "Ethics and law", "bmi": "Body mass index",
	"intake_output": "Fluid balance", "cpr": "CPR and first aid", "phlebotomy": "Phlebotomy",
	"assessment": "Patient assessment",
}

const ABBREV := [
	["PRN", "As needed"], ["NPO", "Nothing by mouth"], ["BID", "Twice a day"], ["TID", "Three times a day"],
	["QID", "Four times a day"], ["PO", "By mouth"], ["STAT", "Immediately"], ["IM", "Intramuscular"],
	["IV", "Intravenous"], ["SubQ", "Subcutaneous"], ["q4h", "Every 4 hours"], ["HS", "At bedtime"],
	["AC", "Before meals"], ["PC", "After meals"], ["SL", "Under the tongue"], ["DNR", "Do not resuscitate"],
	["BP", "Blood pressure"], ["HR", "Heart rate"], ["SpO₂", "Oxygen saturation"], ["I&O", "Intake and output"],
]
const PHARM := [
	["Lisinopril", "ACE inhibitor"], ["Metoprolol", "Beta blocker"], ["Amoxicillin", "Penicillin antibiotic"],
	["Ibuprofen", "NSAID"], ["Acetaminophen", "Analgesic / antipyretic"], ["Furosemide", "Loop diuretic"],
	["Warfarin", "Anticoagulant"], ["Insulin glargine", "Long-acting insulin"], ["Metformin", "Biguanide (diabetes)"],
	["Atorvastatin", "Statin"], ["Albuterol", "Bronchodilator"], ["Omeprazole", "Proton pump inhibitor"],
	["Sertraline", "SSRI antidepressant"], ["Morphine", "Opioid analgesic"], ["Naloxone", "Opioid antagonist"],
	["Diphenhydramine", "Antihistamine"], ["Prednisone", "Corticosteroid"], ["Heparin", "Anticoagulant (injectable)"],
]
const INFECTION := [
	["Single most important way to stop infection spread", "Hand hygiene"], ["Precautions for TB", "Airborne (N95, negative-pressure room)"],
	["Precautions for influenza", "Droplet (surgical mask)"], ["Precautions for C. diff", "Contact, and wash with soap and water"],
	["Order to put on PPE", "Gown, mask, goggles, gloves"], ["First PPE item to take off", "Gloves"],
	["Hand rub does not kill this spore-former", "C. difficile"], ["Where used needles go", "Sharps container"],
	["Treat all blood and body fluids as infectious", "Standard precautions"], ["Infection caught in the hospital", "Healthcare-associated infection"],
]
const ETHICS := [
	["Patient's right to decide about their own care", "Autonomy"], ["Duty to do good", "Beneficence"],
	["Duty to do no harm", "Non-maleficence"], ["Fair distribution of care", "Justice"],
	["US law protecting health information privacy", "HIPAA"], ["Patient agrees after understanding risks", "Informed consent"],
	["Written wishes for future care", "Advance directive"], ["Failure to meet the standard of care that harms a patient", "Negligence"],
	["Duty to keep promises and be truthful", "Fidelity / veracity"],
]
const CPR := [
	["Adult chest compression rate", "100–120 per minute"], ["Adult compression depth", "At least 5 cm (2 in)"],
	["Compression-to-breath ratio, single rescuer adult", "30:2"], ["First step at an unresponsive person", "Check the scene is safe"],
	["Device that shocks a heart in VF", "AED"], ["Choking adult who can cough", "Encourage them to keep coughing"],
	["Choking adult who cannot speak", "Abdominal thrusts"], ["Heavy bleeding from a limb", "Firm direct pressure"],
	["Hand position for adult compressions", "Center of the chest, lower half of the sternum"],
	["Let the chest do this between compressions", "Fully recoil"],
]
const PHLEB := [
	["Most common vein for venipuncture", "Median cubital vein"], ["Tourniquet time limit", "About 1 minute"],
	["Tube for a CBC", "Lavender top (EDTA)"], ["Tube for coagulation tests", "Light blue top (citrate)"],
	["Tube that must be drawn before additive tubes", "Blood culture bottles"], ["Needle angle for venipuncture", "15–30 degrees"],
	["Patient faints during a draw", "Remove needle and tourniquet, lower their head"], ["Two identifiers before every draw", "Name and date of birth"],
	["Gray top tube additive", "Sodium fluoride (glucose)"], ["Hematoma prevention", "Apply pressure after removing the needle"],
]
const ASSESS := [
	["Listening with a stethoscope", "Auscultation"], ["Feeling with the hands", "Palpation"], ["Tapping to hear sounds", "Percussion"],
	["Looking carefully", "Inspection"], ["Bluish skin from low oxygen", "Cyanosis"], ["Yellow skin from high bilirubin", "Jaundice"],
	["Swelling from fluid in tissues", "Edema"], ["Difficulty breathing", "Dyspnea"], ["Pain scale range most used", "0 to 10"],
	["Glasgow Coma Scale best score", "15"], ["Glasgow Coma Scale worst score", "3"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"vitals":
			var kind := rng.randi_range(0, 3)
			if kind == 0:
				var hr := rng.randi_range(35, 150)
				var r := "Bradycardia" if hr < 60 else ("Tachycardia" if hr > 100 else "Normal")
				return MC.build(rng, "Adult resting heart rate %d bpm is:" % hr, r, ["Bradycardia", "Tachycardia", "Normal", "Arrhythmia"], "Normal adult: 60–100.")
			if kind == 1:
				var rr := rng.randi_range(6, 32)
				var r2 := "Bradypnea" if rr < 12 else ("Tachypnea" if rr > 20 else "Normal")
				return MC.build(rng, "Adult respiratory rate %d per minute is:" % rr, r2, ["Bradypnea", "Tachypnea", "Normal", "Apnea"], "Normal adult: 12–20.")
			if kind == 2:
				var t := snappedf(rng.randf_range(35.0, 40.5), 0.1)
				var r3 := "Hypothermia" if t < 36.0 else ("Fever" if t >= 38.0 else "Normal")
				return MC.build(rng, "Oral temperature %.1f °C is:" % t, r3, ["Hypothermia", "Fever", "Normal", "Hyperthermia crisis"], "Normal is about 36.1–37.2 °C; fever from 38 °C.")
			var s := rng.randi_range(90, 185); var d := rng.randi_range(55, 115)
			var cat := "Normal"
			if s >= 180 or d >= 120:
				cat = "Hypertensive crisis"
			elif s >= 140 or d >= 90:
				cat = "Stage 2 hypertension"
			elif s >= 130 or d >= 80:
				cat = "Stage 1 hypertension"
			elif s >= 120:
				cat = "Elevated"
			return MC.build(rng, "Blood pressure %d/%d mmHg is:" % [s, d], cat, ["Normal", "Elevated", "Stage 1 hypertension", "Stage 2 hypertension", "Hypertensive crisis"], "AHA categories.")
		"dosage_weight":
			var kg := rng.randi_range(4, 90); var mgkg := rng.randi_range(1, 15)
			var r := kg * mgkg
			return MC.build(rng, "Order: %d mg/kg. Patient weighs %d kg. Dose (mg)?" % [mgkg, kg], r, [r / 2, r * 2, kg + mgkg, int(r * 2.2)], "Dose = mg/kg × kg.")
		"dosage_volume":
			var conc: int = MC.pick(rng, [5, 10, 25, 50, 100, 125, 250])
			var ml := rng.randi_range(1, 8) * 0.5
			var dose := conc * ml
			return MC.build(rng, "Order: %s mg. Stock is %d mg per 5 mL. Give how many mL?" % [MC._fmt(dose * 5 / 5.0), conc], ml * 5, [ml, ml * 10, ml * 2.5, ml * 5 + 1], "Desired / have × volume.")
		"iv_rate":
			var vol := rng.randi_range(1, 10) * 100; var hrs: int = MC.pick(rng, [1, 2, 4, 5, 8, 10])
			var r := vol / float(hrs)
			return MC.build(rng, "Infuse %d mL over %d hours. Pump rate (mL/hr)?" % [vol, hrs], snappedf(r, 0.1), MC.near_floats(rng, r, 1), "mL ÷ hours.")
		"drip_rate":
			var vol := rng.randi_range(1, 10) * 100; var mins: int = MC.pick(rng, [60, 120, 240, 480]); var df: int = MC.pick(rng, [10, 15, 20, 60])
			var r := vol * df / float(mins)
			return MC.build(rng, "%d mL over %d min, drop factor %d gtt/mL. Drops per minute?" % [vol, mins, df], snappedf(r, 1), MC.near_floats(rng, roundf(r), 0), "(mL × drop factor) ÷ minutes.")
		"conversions":
			var kind := rng.randi_range(0, 2)
			if kind == 0:
				var lb := rng.randi_range(5, 60) * 11
				return MC.build(rng, "%d lb is how many kg?" % lb, lb / 11 * 5, [lb * 2, int(lb / 2.0), lb / 11 * 5 + 5, lb / 11 * 4], "1 kg = 2.2 lb.")
			if kind == 1:
				var g := snappedf(rng.randi_range(1, 20) * 0.25, 0.01)
				return MC.build(rng, "%s g is how many mg?" % MC._fmt(g), g * 1000, [g * 100, g * 10, g * 1000000, g * 10000])
			var tsp := rng.randi_range(1, 6)
			return MC.build(rng, "%d teaspoons is how many mL?" % tsp, tsp * 5, [tsp * 15, tsp * 30, tsp * 2, tsp * 10], "1 tsp = 5 mL.")
		"triage":
			var cases := [
				["Not breathing after the airway is opened", "Expectant / deceased (black)"],
				["Respiratory rate 34, conscious", "Immediate (red)"], ["Capillary refill 4 seconds", "Immediate (red)"],
				["Cannot follow simple commands", "Immediate (red)"], ["Walking, minor cuts", "Minor (green)"],
				["Broken leg, breathing 18, follows commands", "Delayed (yellow)"], ["Radial pulse absent", "Immediate (red)"],
				["Sprained ankle, walking with a limp", "Minor (green)"], ["Deep wound with bleeding controlled, alert", "Delayed (yellow)"],
			]
			return MC.from_bank(rng, cases, "START triage: %s. Tag?", 0, 1)
		"abbreviations":
			return MC.both_ways(rng, ABBREV, "What does %s mean?", "Which abbreviation means \"%s\"?")
		"pharmacology":
			return MC.from_bank(rng, PHARM, "Drug class of %s?", 0, 1)
		"infection":
			return MC.from_bank(rng, INFECTION, "%s?", 0, 1)
		"ethics":
			return MC.both_ways(rng, ETHICS, "Which principle or term: %s?", "Which describes \"%s\"?")
		"bmi":
			var h := rng.randi_range(150, 195) / 100.0; var w := rng.randi_range(45, 130)
			var b := w / (h * h)
			var cat := "Underweight" if b < 18.5 else ("Normal weight" if b < 25.0 else ("Overweight" if b < 30.0 else "Obese"))
			if rng.randf() < 0.5:
				return MC.build(rng, "BMI of a %d kg adult who is %.2f m tall?" % [w, h], snappedf(b, 0.1), MC.near_floats(rng, b, 1), "kg ÷ m².")
			return MC.build(rng, "%d kg, %.2f m tall (BMI %.1f). Category?" % [w, h, b], cat, ["Underweight", "Normal weight", "Overweight", "Obese"])
		"intake_output":
			var i1 := rng.randi_range(2, 10) * 100; var i2 := rng.randi_range(1, 8) * 50; var o1 := rng.randi_range(3, 12) * 100; var o2 := rng.randi_range(0, 4) * 50
			var bal := i1 + i2 - o1 - o2
			return MC.build(rng, "Intake: %d mL IV, %d mL oral. Output: %d mL urine, %d mL drain. Net balance (mL)?" % [i1, i2, o1, o2], bal, [-bal, i1 + i2, o1 + o2, bal + i2], "Intake − output.")
		"cpr":
			return MC.from_bank(rng, CPR, "%s?", 0, 1)
		"phlebotomy":
			return MC.from_bank(rng, PHLEB, "%s?", 0, 1)
		"assessment":
			return MC.from_bank(rng, ASSESS, "%s?", 0, 1)
	return MC.build(rng, "Normal adult heart rate?", "60–100 bpm", ["20–40 bpm", "120–160 bpm", "100–140 bpm"])
