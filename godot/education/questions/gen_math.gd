extends RefCounted
## Mathematics question generator. Every question is computed, so the pool
## never runs out. `lvl` is 1 (100-level, easy) to 5 (graduate, hard).

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"arithmetic": "Arithmetic", "fractions": "Fractions", "percent": "Percentages",
	"linear": "Linear equations", "systems": "Systems of equations", "quadratic": "Quadratics",
	"exponents": "Exponents", "logs": "Logarithms", "geometry": "Area and perimeter",
	"pythagoras": "Right triangles", "trig": "Trigonometry", "sequences": "Sequences",
	"derivative": "Derivatives", "integral": "Integrals", "probability": "Probability",
	"statistics": "Statistics", "combinatorics": "Counting", "number_theory": "Number theory",
	"matrices": "Matrices", "vectors": "Vectors", "limits": "Limits", "series": "Series",
}

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	var big := 10 * lvl
	match topic:
		"arithmetic":
			var a := rng.randi_range(2, 20 + big * 3)
			var b := rng.randi_range(2, 12 + big)
			var op: String = MC.pick(rng, ["+", "-", "×"])
			var r := a + b if op == "+" else (a - b if op == "-" else a * b)
			return MC.build(rng, "What is %d %s %d?" % [a, op, b], r, MC.near_ints(rng, r, 3))
		"fractions":
			var a := rng.randi_range(1, 9); var b := rng.randi_range(2, 9)
			var c := rng.randi_range(1, 9); var d := rng.randi_range(2, 9)
			var num := a * d + c * b; var den := b * d
			var g := _gcd(num, den)
			var right := _frac(num / g, den / g)
			return MC.build(rng, "Simplify %d/%d + %d/%d." % [a, b, c, d], right,
				[_frac(a + c, b + d), _frac(num, den + 1), _frac(a * c, b * d), _frac(num / g + 1, den / g), _frac(a + c, den)],
				"Common denominator %d." % den)
		"percent":
			var p: int = MC.pick(rng, [5, 10, 12, 15, 20, 25, 30, 40, 75])
			var base := rng.randi_range(2, 40) * 10
			var r := base * p / 100.0
			return MC.build(rng, "What is %d%% of %d?" % [p, base], r, MC.near_floats(rng, r, 1))
		"linear":
			var x := rng.randi_range(-12, 15)
			var a := rng.randi_range(2, 9) * (1 if rng.randf() < 0.7 else -1)
			var b := rng.randi_range(-25, 25)
			return MC.build(rng, "Solve for x: %dx %s %d = %d" % [a, "+" if b >= 0 else "-", absi(b), a * x + b],
				x, MC.near_ints(rng, x, 3), "Subtract %d, then divide by %d." % [b, a])
		"systems":
			var x := rng.randi_range(-6, 9); var y := rng.randi_range(-6, 9)
			var a := rng.randi_range(1, 4); var b := rng.randi_range(1, 4)
			return MC.build(rng, "x + y = %d and %dx − %dy = %d. What is x?" % [x + y, a, b, a * x - b * y],
				x, [y, x + 1, x - 1, -x, x + y], "Substitute y = %d − x." % (x + y))
		"quadratic":
			var r1 := rng.randi_range(-9, 9); var r2 := rng.randi_range(-9, 9)
			var bb := -(r1 + r2); var cc := r1 * r2
			var hi := maxi(r1, r2)
			return MC.build(rng, "What is the larger root of x² %s %dx %s %d = 0?" % [_sgn(bb), absi(bb), _sgn(cc), absi(cc)],
				hi, [-hi, mini(r1, r2) - 1, hi + 1, bb, cc, -mini(r1, r2)], "It factors as (x %s %d)(x %s %d)." % [_sgn(-r1), absi(r1), _sgn(-r2), absi(r2)])
		"exponents":
			var b := rng.randi_range(2, 5); var m := rng.randi_range(1, 4); var n := rng.randi_range(1, 4)
			return MC.build(rng, "Simplify %d^%d × %d^%d as a power of %d." % [b, m, b, n, b],
				"%d^%d" % [b, m + n], ["%d^%d" % [b, m * n], "%d^%d" % [b * b, m + n], "%d^%d" % [b, m + n + 1], "%d^%d" % [b, absi(m - n)]],
				"Add exponents with the same base.")
		"logs":
			var b: int = MC.pick(rng, [2, 3, 5, 10])
			var e := rng.randi_range(1, 4 if b > 3 else 6)
			return MC.build(rng, "What is log base %d of %d?" % [b, int(pow(b, e))], e, MC.near_ints(rng, e, 2))
		"geometry":
			var shape: String = MC.pick(rng, ["rectangle", "triangle", "circle"])
			if shape == "rectangle":
				var w := rng.randi_range(2, 20); var h := rng.randi_range(2, 20)
				return MC.build(rng, "Area of a %d × %d rectangle?" % [w, h], w * h, [2 * (w + h), w + h, w * h + w, w * h - h])
			if shape == "triangle":
				var bs := rng.randi_range(2, 20) * 2; var h := rng.randi_range(2, 20)
				return MC.build(rng, "Area of a triangle with base %d and height %d?" % [bs, h], bs * h / 2, [bs * h, bs + h, bs * h / 4, bs * h / 2 + h])
			var r := rng.randi_range(1, 12)
			return MC.build(rng, "Area of a circle with radius %d (in terms of π)?" % r, "%dπ" % (r * r), ["%dπ" % (2 * r), "%dπ" % (r * r * 2), "%dπ" % r, "%dπ" % (r * r + 1)])
		"pythagoras":
			var t: Array = MC.pick(rng, [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [20, 21, 29], [9, 40, 41]])
			var k := rng.randi_range(1, 3)
			return MC.build(rng, "Legs %d and %d. Hypotenuse?" % [t[0] * k, t[1] * k], t[2] * k,
				[(t[0] + t[1]) * k, t[2] * k + 1, t[1] * k + 1, t[2] * k - 2], "a² + b² = c².")
		"trig":
			var rows := [["sin 30°", "1/2"], ["cos 60°", "1/2"], ["sin 90°", "1"], ["cos 0°", "1"], ["tan 45°", "1"],
				["sin 0°", "0"], ["cos 90°", "0"], ["sin 45°", "√2/2"], ["cos 30°", "√3/2"], ["tan 60°", "√3"],
				["tan 30°", "√3/3"], ["sin 60°", "√3/2"], ["cos 45°", "√2/2"], ["cos 180°", "-1"], ["sin 270°", "-1"]]
			return MC.from_bank(rng, rows, "What is %s?", 0, 1)
		"sequences":
			if rng.randf() < 0.5:
				var a := rng.randi_range(-5, 20); var d := rng.randi_range(2, 9); var n := rng.randi_range(5, 20)
				var r := a + (n - 1) * d
				return MC.build(rng, "Arithmetic sequence %d, %d, %d, … What is term %d?" % [a, a + d, a + 2 * d, n], r, [a + n * d, r - d, r + 1, a * n], "aₙ = a₁ + (n−1)d.")
			var a2 := rng.randi_range(1, 5); var q := rng.randi_range(2, 3); var n2 := rng.randi_range(4, 8)
			var r2 := a2 * int(pow(q, n2 - 1))
			return MC.build(rng, "Geometric sequence %d, %d, %d, … What is term %d?" % [a2, a2 * q, a2 * q * q, n2], r2, [a2 * int(pow(q, n2)), r2 / q, r2 + q, a2 * q * n2])
		"derivative":
			var a := rng.randi_range(1, 6); var n := rng.randi_range(2, 4 + lvl / 2); var c := rng.randi_range(-9, 9); var x := rng.randi_range(-3, 3)
			var r := a * n * int(pow(x, n - 1)) + c
			return MC.build(rng, "f(x) = %dx^%d %s %dx. What is f′(%d)?" % [a, n, _sgn(c), absi(c), x], r,
				[a * int(pow(x, n)) + c * x, a * n * int(pow(x, n)), r + a, a * (n - 1) * int(pow(x, n - 1)) + c], "Power rule: d/dx xⁿ = n·xⁿ⁻¹.")
		"integral":
			var a := rng.randi_range(1, 4) * 3; var b := rng.randi_range(1, 4)
			# ∫0..b of a x² dx = a b³ / 3 (a is a multiple of 3, so this is an integer)
			var r := a * b * b * b / 3
			return MC.build(rng, "Evaluate ∫ from 0 to %d of %dx² dx." % [b, a], r, [a * b * b, a * b * b * b, r + a, 2 * a * b], "Antiderivative %dx³/3." % a)
		"probability":
			var kind := rng.randi_range(0, 2)
			if kind == 0:
				var s := rng.randi_range(2, 12)
				var ways := 6 - absi(7 - s)
				return MC.build(rng, "Two fair dice are rolled. Probability the sum is %d?" % s, _frac(ways, 36), [_frac(ways, 12), _frac(1, 6), _frac(ways + 1, 36), _frac(1, s), _frac(ways, 6)])
			if kind == 1:
				var n := rng.randi_range(2, 5)
				return MC.build(rng, "A fair coin is flipped %d times. Probability of all heads?" % n, _frac(1, 1 << n), [_frac(1, 2 * n), _frac(1, n), _frac(n, 1 << n), _frac(1, (1 << n) - 1)])
			var red := rng.randi_range(2, 9); var blue := rng.randi_range(2, 9)
			var t := red + blue; var g := _gcd(red, t)
			return MC.build(rng, "A bag has %d red and %d blue marbles. P(red)?" % [red, blue], _frac(red / g, t / g), [_frac(red, blue), _frac(blue, t), _frac(1, 2), _frac(red, t + 1)])
		"statistics":
			var vals := []
			for i in 5 + (lvl % 2) * 2:
				vals.append(rng.randi_range(1, 30))
			var sorted := vals.duplicate(); sorted.sort()
			if rng.randf() < 0.5:
				var med: int = sorted[sorted.size() / 2]
				return MC.build(rng, "Median of %s?" % _list(vals), med, [vals[vals.size() / 2], sorted[0], sorted[-1], med + 1, _sum(vals) / vals.size()], "Sort the values and take the middle one.")
			var s := _sum(vals) + (vals.size() - _sum(vals) % vals.size()) % vals.size()
			vals[0] += s - _sum(vals)   # make the mean a whole number
			var mean := _sum(vals) / vals.size()
			return MC.build(rng, "Mean of %s?" % _list(vals), mean, MC.near_ints(rng, mean, 2))
		"combinatorics":
			var n := rng.randi_range(4, 10); var k := rng.randi_range(2, mini(4, n - 1))
			var c := _ncr(n, k)
			if rng.randf() < 0.5:
				return MC.build(rng, "How many ways to choose %d people from %d?" % [k, n], c, [_npr(n, k), c + n, n * k, _ncr(n, k - 1)], "C(n,k) = n! / (k!(n−k)!).")
			return MC.build(rng, "How many ways to award gold, silver%s among %d runners?" % [", bronze" if k >= 3 else "", n], _npr(n, mini(k, 3)), [_ncr(n, mini(k, 3)), n * mini(k, 3), _npr(n, mini(k, 3)) / 2, int(pow(n, mini(k, 3)))])
		"number_theory":
			var a := rng.randi_range(2, 12) * rng.randi_range(1, 6); var b := rng.randi_range(2, 12) * rng.randi_range(1, 6)
			if rng.randf() < 0.5:
				var g := _gcd(a, b)
				return MC.build(rng, "GCD of %d and %d?" % [a, b], g, [a * b / g, g * 2, 1, mini(a, b), g + 1])
			var l := a * b / _gcd(a, b)
			return MC.build(rng, "LCM of %d and %d?" % [a, b], l, [a * b, _gcd(a, b), l * 2, a + b])
		"matrices":
			var m := [rng.randi_range(-5, 9), rng.randi_range(-5, 9), rng.randi_range(-5, 9), rng.randi_range(-5, 9)]
			var det: int = m[0] * m[3] - m[1] * m[2]
			return MC.build(rng, "Determinant of [[%d, %d], [%d, %d]]?" % m, det, [m[0] * m[3] + m[1] * m[2], -det, m[0] * m[1] - m[2] * m[3], m[0] + m[3]], "ad − bc.")
		"vectors":
			var u := [rng.randi_range(-5, 6), rng.randi_range(-5, 6), rng.randi_range(-5, 6)]
			var v := [rng.randi_range(-5, 6), rng.randi_range(-5, 6), rng.randi_range(-5, 6)]
			var dot: int = u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
			return MC.build(rng, "Dot product of (%d, %d, %d) and (%d, %d, %d)?" % (u + v), dot, MC.near_ints(rng, dot, 4))
		"limits":
			var a := rng.randi_range(1, 9)
			# lim x→a of (x² − a²)/(x − a) = 2a
			return MC.build(rng, "Limit as x → %d of (x² − %d)/(x − %d)?" % [a, a * a, a], 2 * a, [a, a * a, 0, "Does not exist", 2 * a + 1], "Factor: (x−a)(x+a)/(x−a) = x + a.")
		"series":
			var r_den := rng.randi_range(2, 5); var a := rng.randi_range(1, 9)
			# Σ a·(1/r)^n from n=0 = a / (1 − 1/r) = a·r/(r−1)
			var num := a * r_den; var den := r_den - 1; var g := _gcd(num, den)
			return MC.build(rng, "Sum of %d + %d/%d + %d/%d + … (ratio 1/%d)?" % [a, a, r_den, a, r_den * r_den, r_den], _frac(num / g, den / g),
				[_frac(a, r_den), "Diverges", _frac(a * (r_den + 1), r_den), str(a * 2)], "a / (1 − r).")
	return MC.build(rng, "What is 2 + 2?", 4, [3, 5, 22])

func _gcd(a: int, b: int) -> int:
	a = absi(a); b = absi(b)
	while b != 0:
		var t := b; b = a % b; a = t
	return maxi(a, 1)

func _ncr(n: int, k: int) -> int:
	var r := 1
	for i in k:
		r = r * (n - i) / (i + 1)
	return r

func _npr(n: int, k: int) -> int:
	var r := 1
	for i in k:
		r *= n - i
	return r

func _frac(n: int, d: int) -> String:
	if d < 0:
		n = -n; d = -d
	var g := _gcd(n, d)
	n /= g; d /= g
	if d == 1:
		return str(n)
	return "%d/%d" % [n, d]

func _sgn(v: int) -> String:
	return "+" if v >= 0 else "−"

func _sum(a: Array) -> int:
	var s := 0
	for v in a:
		s += int(v)
	return s

func _list(a: Array) -> String:
	return ", ".join(a.map(func(v): return str(v)))
