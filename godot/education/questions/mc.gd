extends RefCounted
## Helpers for building multiple choice questions.
##
## Every generator returns the same shape:
##   {"q": String, "options": [4 Strings], "answer": int (index), "explain": String, "topic": String}

static func build(rng: RandomNumberGenerator, question: String, correct: Variant, distractors: Array, explain: String = "") -> Dictionary:
	var right := _fmt(correct)
	var opts: Array[String] = [right]
	for d in distractors:
		var s := _fmt(d)
		if s != right and s not in opts:
			opts.append(s)
		if opts.size() == 4:
			break
	# Out of distinct wrong answers: numeric answers get nearby numbers
	# (keeping any "$" prefix or unit suffix), others get generic fillers.
	var num := _numeric_parts(right)
	if not num.is_empty():
		var step: float = 1.0 if num.is_int else maxf(absf(float(num.value)) * 0.1, 0.01)
		var k := 1
		while opts.size() < 4 and k < 40:
			for sgn in [1.0, -1.0]:
				var v: float = float(num.value) + sgn * step * k
				var txt: String = num.prefix + (str(int(v)) if num.is_int else String.num(snappedf(v, 0.01), 2)) + num.suffix
				if opts.size() < 4 and txt not in opts:
					opts.append(txt)
			k += 1
	var pad := 1
	while opts.size() < 4:
		var filler := "None of these" if pad == 1 else ("All of these" if pad == 2 else "Cannot be determined (%d)" % pad)
		if filler not in opts:
			opts.append(filler)
		pad += 1
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := opts[i]
		opts[i] = opts[j]
		opts[j] = t
	for w in ["hours", "years", "teaspoons", "minutes", "times"]:
		question = question.replace(" 1 %s" % w, " 1 %s" % w.trim_suffix("s"))
	return {"q": question, "options": opts, "answer": opts.find(right), "explain": explain}

## Pick the right answer from a bank row and three wrong ones from other rows.
## `rows` is an Array of Arrays; `qi` is the index holding the prompt text,
## `ai` the index holding the answer.
static func from_bank(rng: RandomNumberGenerator, rows: Array, template: String, qi: int, ai: int, explain_i: int = -1) -> Dictionary:
	var row: Array = rows[rng.randi_range(0, rows.size() - 1)]
	var similar := []
	var wrong := []
	var unlike := []
	var numeric := str(row[ai]).is_valid_float()
	var key := _prompt_key(str(row[qi]))
	for r in shuffle(rng, rows):
		if r[ai] != row[ai]:
			# Prefer wrong answers to similar prompts ("Shape of ..." with
			# "Shape of ..."), then answers of the same kind (numbers with numbers).
			if key != "" and _prompt_key(str(r[qi])) == key:
				similar.append(r[ai])
			elif str(r[ai]).is_valid_float() == numeric:
				wrong.append(r[ai])
			else:
				unlike.append(r[ai])
	wrong = similar + wrong + unlike
	var explain: String = row[explain_i] if explain_i >= 0 and explain_i < row.size() else ""
	return build(rng, template % row[qi], row[ai], wrong, explain)

## Nearby wrong numbers for numeric answers (off-by-one, sign errors, factor slips).
static func near_ints(rng: RandomNumberGenerator, x: int, spread: int = 5) -> Array:
	var out := [x + 1, x - 1, -x, x * 2, x + spread, x - spread]
	for i in 6:
		out.append(x + rng.randi_range(-spread * 2, spread * 2))
	return shuffle(rng, out)

static func near_floats(rng: RandomNumberGenerator, x: float, decimals: int = 2) -> Array:
	var out := []
	for f in [1.1, 0.9, 1.25, 0.8, 2.0, 0.5, 1.5]:
		out.append(snappedf(x * f, pow(10.0, -decimals)))
	out.append(snappedf(x + 1.0, pow(10.0, -decimals)))
	return shuffle(rng, out)

static func shuffle(rng: RandomNumberGenerator, arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out

static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]

static func _fmt(v: Variant) -> String:
	if v is float:
		var f: float = v
		if is_equal_approx(f, roundf(f)) and absf(f) < 1e12:
			return str(int(roundf(f)))
		return String.num(f, 2)
	return str(v)

## Ask a bank row either way round: "what is <description>?" -> term, or
## "which describes <term>?" -> description. Doubles the variety of every bank.
static func both_ways(rng: RandomNumberGenerator, rows: Array, fwd_template: String, rev_template: String) -> Dictionary:
	if rng.randf() < 0.6:
		return from_bank(rng, rows, fwd_template, 0, 1)
	return from_bank(rng, rows, rev_template, 1, 0)

## Splits "$12.50", "35%", "-4", "12 mL" into prefix / number / suffix, or {} if not numeric.
static func _numeric_parts(s: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^([^0-9-]*)(-?[0-9]+(?:\\.[0-9]+)?)(.*)$")
	var m := re.search(s)
	if m == null or m.get_string(1).length() > 2 or m.get_string(3).length() > 6:
		return {}
	var n := m.get_string(2)
	return {"prefix": m.get_string(1), "value": n.to_float(), "is_int": n.is_valid_int(), "suffix": m.get_string(3)}

static func money(v: float) -> String:
	return ("-$%.2f" % -v) if v < 0.0 else ("$%.2f" % v)

static func money_int(v: int) -> String:
	return ("-$%d" % -v) if v < 0 else ("$%d" % v)

static func _prompt_key(prompt: String) -> String:
	var words := prompt.split(" ", false)
	if words.size() < 3:
		return ""
	return (words[0] + " " + words[1]).to_lower()
