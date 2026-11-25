## Height distribution. A two-piece normal around the median, sampled by
## stratified quantiles so exactly 90% of each sex lands in the 25th to 75th
## range from the source table, never by luck of the dice.
class_name NpcHeights
extends RefCounted

const Z90 := 1.6448536  # standard normal z for the 95th percentile
const TAIL_STRETCH := 1.5  # widens the outer 10% so short and tall people show up


## Returns `count` heights in cm for `sex`, in a shuffled order.
static func sample(sex: String, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var h: Dictionary = NpcConfig.HEIGHT[sex]
	var sigma_lo: float = (h.median - h.low) / Z90
	var sigma_hi: float = (h.high - h.median) / Z90
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var z := inverse_normal(u)
		if absf(z) > Z90:
			z = signf(z) * (Z90 + (absf(z) - Z90) * TAIL_STRETCH)
		else:
			z *= 0.997  # keeps the core 90% inside the range after rounding to 1 mm
		var cm: float = h.median + z * (sigma_lo if z < 0.0 else sigma_hi)
		cm = clampf(cm, h.min, h.max)
		out[i] = snappedf(cm, 0.1)
	# Fisher-Yates with the seeded generator.
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Acklam's rational approximation of the standard normal inverse CDF.
static func inverse_normal(p: float) -> float:
	const A := [-39.69683028665376, 220.9460984245205, -275.9285104469687, 138.3577518672690, -30.66479806614716, 2.506628277459239]
	const B := [-54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572]
	const C := [-0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783]
	const D := [0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416]
	var plow := 0.02425
	if p < plow:
		var q := sqrt(-2.0 * log(p))
		return (((((C[0]*q+C[1])*q+C[2])*q+C[3])*q+C[4])*q+C[5]) / ((((D[0]*q+D[1])*q+D[2])*q+D[3])*q+1.0)
	if p > 1.0 - plow:
		var q := sqrt(-2.0 * log(1.0 - p))
		return -(((((C[0]*q+C[1])*q+C[2])*q+C[3])*q+C[4])*q+C[5]) / ((((D[0]*q+D[1])*q+D[2])*q+D[3])*q+1.0)
	var q := p - 0.5
	var r := q * q
	return (((((A[0]*r+A[1])*r+A[2])*r+A[3])*r+A[4])*r+A[5])*q / (((((B[0]*r+B[1])*r+B[2])*r+B[3])*r+B[4])*r+1.0)
