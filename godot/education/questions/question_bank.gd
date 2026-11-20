extends RefCounted
## Routes "subject.topic" ids to the subject generators and builds homework
## sets. Same course + homework + attempt always gives the same questions.

const CATALOG := preload("res://education/catalog.gd")
const GENERATORS := {
	"math": preload("res://education/questions/gen_math.gd"),
	"cs": preload("res://education/questions/gen_cs.gd"),
	"bio": preload("res://education/questions/gen_bio.gd"),
	"chem": preload("res://education/questions/gen_chem.gd"),
	"nursing": preload("res://education/questions/gen_nursing.gd"),
	"business": preload("res://education/questions/gen_business.gd"),
	"history": preload("res://education/questions/gen_history.gd"),
	"english": preload("res://education/questions/gen_english.gd"),
}

static var _instances: Dictionary = {}

static func generator(subject: String) -> RefCounted:
	if not _instances.has(subject):
		_instances[subject] = GENERATORS[subject].new()
	return _instances[subject]

static func topic_exists(topic_id: String) -> bool:
	var parts := topic_id.split(".")
	if parts.size() != 2 or not GENERATORS.has(parts[0]):
		return false
	return GENERATORS[parts[0]].TOPICS.has(parts[1])

static func topic_name(topic_id: String) -> String:
	var parts := topic_id.split(".")
	if parts.size() == 2 and GENERATORS.has(parts[0]):
		return GENERATORS[parts[0]].TOPICS.get(parts[1], parts[1])
	return topic_id

static func question(topic_id: String, rng: RandomNumberGenerator, level: int) -> Dictionary:
	var parts := topic_id.split(".")
	var q: Dictionary = generator(parts[0]).make(parts[1], rng, level)
	q["topic"] = topic_id
	return q

## Builds questions avoiding repeats inside one set (retries a few times).
static func question_set(topics: Array, count: int, seed_value: int, level: int, main_topic: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var seen := {}
	for i in count:
		var topic: String = main_topic
		# About 70% from the assignment's own topic, the rest reviews the course.
		if main_topic == "" or rng.randf() > 0.7:
			topic = topics[rng.randi_range(0, topics.size() - 1)]
		var q := {}
		for attempt in 6:
			q = question(topic, rng, level)
			if not seen.has(q.q + "|" + str(q.options)):
				break
		seen[q.q + "|" + str(q.options)] = true
		out.append(q)
	return out

## The 20 assignments of a course: titles, topic and size. Questions are
## generated only when an assignment is opened.
static func homework_outline(course_id: String) -> Array:
	var c := CATALOG.course(course_id)
	var out := []
	var topics: Array = c.topics
	for k in CATALOG.HOMEWORK_PER_COURSE:
		var topic: String = topics[k % topics.size()]
		out.append({
			"index": k, "title": "Homework %d: %s" % [k + 1, topic_name(topic)],
			"topic": topic, "questions": CATALOG.question_count(course_id, k),
		})
	return out

static func homework_questions(course_id: String, homework_index: int, attempt: int = 0) -> Array:
	var c := CATALOG.course(course_id)
	var outline: Dictionary = homework_outline(course_id)[homework_index]
	# Difficulty ramps through the term: the last third is one step harder.
	var level: int = mini(int(c.level) + (1 if homework_index >= 13 else 0), 6)
	var seed_value := hash("%s|%d|%d" % [course_id, homework_index, attempt])
	return question_set(c.topics, int(outline.questions), seed_value, level, outline.topic)

static func cert_questions(cert_id: String, attempt: int = 0) -> Array:
	var c: Dictionary = CATALOG.CERTIFICATES[cert_id]
	return question_set(c.topics, CATALOG.CERT_QUESTIONS, hash("%s|%d" % [cert_id, attempt]), 2)
