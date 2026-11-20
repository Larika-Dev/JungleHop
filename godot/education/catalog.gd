extends RefCounted
## The ONSU course catalog: 8 subjects, 100 courses, majors, minors, graduate
## degrees and short certificates. Pure data plus lookups, no state.
##
## Rules (from the design brief):
##   * 100 courses across 8 subjects.
##   * A bachelor's degree takes 20 passed courses.
##   * A minor takes 5 to 10 further courses, separate from the 20.
##   * Every course has 20 homework assignments of 10 to 20 multiple choice questions.

const HOMEWORK_PER_COURSE := 20
const QUESTIONS_MIN := 10
const QUESTIONS_MAX := 20
const PASS_PERCENT := 60.0
const DEGREE_COURSES := 20
const MAJOR_IN_SUBJECT := 8       # of the 20, at least this many in the major subject
const MAJOR_UPPER_LEVEL := 3      # of those, at least this many at 300 level or above
const MIN_GPA_TO_GRADUATE := 2.0
const MAX_ACTIVE_COURSES := 5
const TUITION_UNDERGRAD := 450
const TUITION_GRAD := 800

const REGISTRAR_BUILDING := "LM05_FOUNDERS_HALL"
const LIBRARIES := ["LM03_WILBERFORCE", "LM04_DAVIES_STACKS", "LM08_ASHGROVE"]
const STUDENT_UNION := "LM09_STUDENT_UNION"
const TUTORING_BUILDING := "HAM_N_016"   # Cram Fortress Tutoring

const SUBJECTS := {
	"math": {"name": "Mathematics", "code": "MATH", "degree": "bs_mathematics", "degree_name": "B.S. Mathematics",
		"minor_courses": 6, "building": "ONSU_0000", "skill": "logic", "color": "HEAVEN_BLUE"},
	"cs": {"name": "Computer Science", "code": "COMP", "degree": "bs_computer_science", "degree_name": "B.S. Computer Science",
		"minor_courses": 7, "building": "ONSU_0011", "skill": "logic", "color": "ONSU_NAVY"},
	"bio": {"name": "Biology", "code": "BIOL", "degree": "bs_biology", "degree_name": "B.S. Biology",
		"minor_courses": 6, "building": "ONSU_0002", "skill": "knowledge", "color": "WILLOW_OAK_LEAF"},
	"chem": {"name": "Chemistry", "code": "CHEM", "degree": "bs_chemistry", "degree_name": "B.S. Chemistry",
		"minor_courses": 5, "building": "ONSU_0020", "skill": "knowledge", "color": "COPPER_PATINA"},
	"nursing": {"name": "Nursing", "code": "NURS", "degree": "bs_nursing", "degree_name": "B.S. Nursing",
		"minor_courses": 8, "building": "LM13_MED_TOWER_B", "skill": "knowledge", "color": "PAINT_HOSPITAL_ACCENT"},
	"business": {"name": "Business & Economics", "code": "BUSI", "degree": "ba_business", "degree_name": "B.A. Business & Economics",
		"minor_courses": 6, "building": "ONSU_0013", "skill": "charm", "color": "BRASS"},
	"history": {"name": "History", "code": "HIST", "degree": "ba_history", "degree_name": "B.A. History",
		"minor_courses": 5, "building": "ONSU_0007", "skill": "knowledge", "color": "BRICK_CAMPUS_A"},
	"english": {"name": "English", "code": "ENGL", "degree": "ba_english", "degree_name": "B.A. English",
		"minor_courses": 5, "building": "ONSU_0008", "skill": "writing", "color": "WALNUT_DARK"},
}

# [number, title, topics]. The first four rows of each subject are its core.
const COURSE_ROWS := {
	"math": [
		[101, "College Algebra", ["arithmetic", "fractions", "percent", "linear"]],
		[110, "Precalculus", ["exponents", "logs", "quadratic", "trig"]],
		[150, "Introduction to Statistics", ["statistics", "probability", "percent"]],
		[201, "Calculus I", ["limits", "derivative", "exponents"]],
		[202, "Calculus II", ["integral", "series", "derivative"]],
		[220, "Geometry and Trigonometry", ["geometry", "pythagoras", "trig"]],
		[240, "Discrete Mathematics", ["combinatorics", "number_theory", "sequences"]],
		[310, "Linear Algebra", ["matrices", "vectors", "systems"]],
		[330, "Probability Theory", ["probability", "combinatorics", "statistics"]],
		[350, "Number Theory", ["number_theory", "sequences", "exponents"]],
		[410, "Real Analysis", ["limits", "series", "sequences", "integral"]],
		[450, "Mathematical Modeling", ["systems", "derivative", "statistics", "logs"]],
	],
	"cs": [
		[101, "Introduction to Programming", ["loops", "arrays", "boolean"]],
		[110, "Computer Systems and Number Bases", ["binary", "hex", "bitwise", "hardware"]],
		[201, "Data Structures", ["data_structures", "arrays", "big_o"]],
		[210, "Algorithms", ["sorting", "big_o", "recursion"]],
		[220, "Logic and Computation", ["boolean", "bitwise", "recursion"]],
		[230, "IT Support Fundamentals", ["it_support", "hardware", "networking"]],
		[301, "Operating Systems", ["os", "hardware", "binary"]],
		[310, "Computer Networks", ["networking", "security", "hex"]],
		[320, "Databases", ["databases", "data_structures", "big_o"]],
		[401, "Software Engineering", ["software_eng", "loops", "databases"]],
		[501, "Advanced Algorithms", ["big_o", "recursion", "sorting", "data_structures"]],
		[510, "Machine Learning", ["ai", "math.statistics", "big_o"]],
		[520, "Computer Security", ["security", "networking", "bitwise"]],
		[530, "Distributed Systems", ["os", "networking", "databases"]],
		[590, "Graduate Seminar in Computing", ["software_eng", "ai", "security", "big_o"]],
	],
	"bio": [
		[101, "Principles of Biology", ["cells", "dna", "photosynthesis"]],
		[102, "Organismal Biology", ["taxonomy", "botany", "evolution"]],
		[201, "Genetics", ["punnett", "dna", "transcription"]],
		[202, "Cell Biology", ["cells", "division", "photosynthesis"]],
		[210, "Human Anatomy", ["anatomy", "physiology"]],
		[220, "Ecology", ["ecology", "taxonomy", "botany"]],
		[301, "Molecular Biology", ["transcription", "codons", "dna"]],
		[310, "Microbiology", ["microbio", "immunology", "cells"]],
		[320, "Human Physiology", ["physiology", "anatomy", "immunology"]],
		[330, "Evolutionary Biology", ["evolution", "punnett", "ecology"]],
		[410, "Immunology", ["immunology", "microbio", "physiology"]],
		[450, "Advanced Genetics", ["punnett", "codons", "division", "transcription"]],
	],
	"chem": [
		[101, "General Chemistry I", ["elements", "atomic", "periodic", "lab_safety"]],
		[102, "General Chemistry II", ["moles", "molar_mass", "stoichiometry"]],
		[201, "Chemical Reactions", ["balancing", "stoichiometry", "dilution"]],
		[202, "Chemical Bonding", ["bonding", "periodic", "atomic"]],
		[210, "Acids and Bases", ["ph", "titration", "dilution"]],
		[220, "Organic Chemistry I", ["organic", "bonding", "molar_mass"]],
		[301, "Physical Chemistry", ["gas_laws", "thermo", "moles"]],
		[310, "Analytical Chemistry", ["titration", "dilution", "ph", "molar_mass"]],
		[320, "Organic Chemistry II", ["organic", "stoichiometry", "balancing"]],
		[410, "Thermodynamics", ["thermo", "gas_laws", "stoichiometry"]],
		[450, "Advanced Laboratory Methods", ["lab_safety", "titration", "molar_mass", "dilution"]],
	],
	"nursing": [
		[101, "Foundations of Nursing", ["vitals", "abbreviations", "infection"]],
		[110, "Medical Terminology", ["abbreviations", "assessment", "conversions"]],
		[201, "Dosage Calculations", ["dosage_weight", "dosage_volume", "conversions"]],
		[202, "Health Assessment", ["assessment", "vitals", "bmi"]],
		[210, "Pharmacology I", ["pharmacology", "dosage_volume", "abbreviations"]],
		[220, "Infection Prevention", ["infection", "phlebotomy", "ethics"]],
		[301, "Medical-Surgical Nursing", ["iv_rate", "drip_rate", "intake_output"]],
		[310, "Emergency and Critical Care", ["triage", "cpr", "vitals"]],
		[320, "Pharmacology II", ["pharmacology", "dosage_weight", "iv_rate"]],
		[330, "Nursing Ethics and Law", ["ethics", "infection", "assessment"]],
		[410, "Community Health", ["bmi", "infection", "vitals", "ethics"]],
		[450, "Nursing Capstone", ["triage", "drip_rate", "pharmacology", "intake_output"]],
	],
	"business": [
		[101, "Principles of Microeconomics", ["equilibrium", "elasticity", "concepts"]],
		[102, "Principles of Macroeconomics", ["gdp", "inflation", "unemployment"]],
		[110, "Financial Accounting", ["accounting_eq", "accounts", "journal"]],
		[120, "Introduction to Business", ["management", "marketing", "profit"]],
		[201, "Managerial Accounting", ["break_even", "profit", "markup"]],
		[210, "Personal Finance", ["interest", "present_value", "markup"]],
		[220, "Marketing", ["marketing", "markup", "elasticity"]],
		[301, "Corporate Finance", ["present_value", "ratios", "interest"]],
		[310, "Intermediate Accounting", ["journal", "depreciation", "ratios"]],
		[410, "Business Strategy", ["management", "concepts", "break_even"]],
		[501, "Managerial Economics", ["equilibrium", "elasticity", "break_even", "concepts"]],
		[510, "Financial Management", ["present_value", "ratios", "interest", "depreciation"]],
		[520, "Marketing Management", ["marketing", "markup", "profit"]],
		[530, "Organizational Leadership", ["management", "concepts", "marketing"]],
		[590, "MBA Capstone", ["ratios", "break_even", "gdp", "management"]],
	],
	"history": [
		[101, "World Civilizations I", ["ancient", "medieval", "people"]],
		[102, "World Civilizations II", ["early_modern", "modern", "contemporary"]],
		[110, "American History to 1865", ["us_early", "people"]],
		[111, "American History since 1865", ["us_modern", "contemporary"]],
		[201, "Ancient Greece and Rome", ["ancient", "europe"]],
		[210, "Medieval Europe", ["medieval", "europe"]],
		[220, "History of Asia", ["asia", "people"]],
		[230, "Africa and the Americas", ["africa_americas", "early_modern"]],
		[301, "History of Science", ["science", "people"]],
		[310, "The Modern World", ["modern", "contemporary", "world"]],
		[330, "Cathedral Mount and the State of Pamlico", ["local", "us_early", "us_modern"]],
		[410, "Historiography Seminar", ["world", "people", "science"]],
	],
	"english": [
		[101, "College Writing", ["usage", "punctuation", "agreement"]],
		[102, "Vocabulary and Style", ["vocab", "synonyms", "antonyms"]],
		[110, "Introduction to Literature", ["authors", "devices", "genres"]],
		[120, "English Grammar", ["pos", "grammar_terms", "agreement"]],
		[201, "Argument and Rhetoric", ["rhetoric", "vocab", "punctuation"]],
		[210, "Poetry", ["poetry", "devices"]],
		[220, "British Literature", ["authors", "genres", "devices"]],
		[230, "American Literature", ["authors", "poetry", "rhetoric"]],
		[301, "Copyediting", ["spelling", "usage", "punctuation", "agreement"]],
		[310, "Advanced Composition", ["rhetoric", "grammar_terms", "synonyms"]],
		[410, "Senior Seminar in Literature", ["devices", "poetry", "authors", "genres"]],
	],
}

# Short certifications: one 20-question exam each, pass at 70%.
const CERTIFICATES := {
	"cert_cpr": {"name": "CPR & First Aid", "fee": 60, "building": "LM13_MED_TOWER_D", "topics": ["nursing.cpr", "nursing.vitals", "nursing.triage"]},
	"cert_phlebotomy": {"name": "Phlebotomy Technician", "fee": 180, "building": "LM13_MED_TOWER_B", "topics": ["nursing.phlebotomy", "nursing.infection", "nursing.abbreviations"]},
	"cert_food_safety": {"name": "Food Handler Safety", "fee": 40, "building": "LM09_DINING_HALL", "topics": ["business.food_safety"]},
	"cert_barista": {"name": "Barista Skills", "fee": 75, "building": "LM09_DINING_HALL", "topics": ["business.coffee", "business.food_safety"]},
	"cert_bookkeeping": {"name": "Bookkeeping", "fee": 150, "building": "ONSU_0013", "topics": ["business.accounts", "business.journal", "business.accounting_eq"]},
	"cert_it_support": {"name": "IT Support Technician", "fee": 150, "building": "ONSU_0011", "topics": ["cs.it_support", "cs.networking", "cs.hardware", "cs.security"]},
}
const CERT_QUESTIONS := 20
const CERT_PASS_PERCENT := 70.0

const GRAD_PROGRAMS := {
	"ms_computer_science": {"name": "M.S. Computer Science", "subject": "cs", "requires_any": ["bs_computer_science", "bs_mathematics"]},
	"mba": {"name": "Master of Business Administration", "subject": "business", "requires_any": ["*bachelor"]},
}
const ASSOCIATE := {"id": "aa_general", "name": "A.A. General Studies", "courses": 10, "subjects": 3, "max_level": 2}

static var _courses: Dictionary = {}
static var _order: Array = []

static func _build() -> void:
	if not _courses.is_empty():
		return
	for subj in COURSE_ROWS:
		var info: Dictionary = SUBJECTS[subj]
		var rows: Array = COURSE_ROWS[subj]
		for i in rows.size():
			var r: Array = rows[i]
			var num: int = r[0]
			var id := "%s %d" % [info.code, num]
			var level := clampi(num / 100, 1, 5)
			var topics: Array = []
			for t in r[2]:
				topics.append(t if "." in t else "%s.%s" % [subj, t])
			_courses[id] = {
				"id": id, "subject": subj, "number": num, "title": r[1], "level": level,
				"graduate": level >= 5, "core": i < 4, "topics": topics,
				"building": info.building, "tuition": TUITION_GRAD if level >= 5 else TUITION_UNDERGRAD,
			}
			_order.append(id)

static func courses() -> Dictionary:
	_build()
	return _courses

static func course_ids() -> Array:
	_build()
	return _order.duplicate()

static func course(id: String) -> Dictionary:
	_build()
	return _courses.get(id, {})

static func courses_in(subject: String) -> Array:
	_build()
	return _order.filter(func(id): return _courses[id].subject == subject)

static func core_courses(subject: String) -> Array:
	return courses_in(subject).filter(func(id): return _courses[id].core)

static func subject_name(subject: String) -> String:
	return SUBJECTS.get(subject, {}).get("name", subject)

static func degree_subject(credential: String) -> String:
	for s in SUBJECTS:
		if SUBJECTS[s].degree == credential:
			return s
	return ""

static func minor_id(subject: String) -> String:
	return "minor_" + subject

## Number of homework questions for a given assignment (deterministic, 10-20).
static func question_count(course_id: String, homework_index: int) -> int:
	var h := absi(hash("%s#%d" % [course_id, homework_index]))
	return QUESTIONS_MIN + h % (QUESTIONS_MAX - QUESTIONS_MIN + 1)

static func letter(percent: float) -> String:
	if percent >= 93.0: return "A"
	if percent >= 90.0: return "A-"
	if percent >= 87.0: return "B+"
	if percent >= 83.0: return "B"
	if percent >= 80.0: return "B-"
	if percent >= 77.0: return "C+"
	if percent >= 73.0: return "C"
	if percent >= 70.0: return "C-"
	if percent >= 67.0: return "D+"
	if percent >= 60.0: return "D"
	return "F"

static func grade_points(percent: float) -> float:
	return {"A": 4.0, "A-": 3.7, "B+": 3.3, "B": 3.0, "B-": 2.7, "C+": 2.3, "C": 2.0, "C-": 1.7, "D+": 1.3, "D": 1.0, "F": 0.0}[letter(percent)]
