extends SceneTree
## Clothes are loose garments, not paint: checks that shirts, jackets, trousers,
## skirts and dresses stand off the body, bridge over the chest and the groin
## (no anatomy shows through), keep all body shapes, and that the ethnicity
## shapes no longer change a person's height.
var failures := 0


func check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		failures += 1


## Distance from p to the nearest body vertex (brute force over every 2nd vertex).
func skin_dist(body: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for i in range(0, body.size(), 2):
		best = minf(best, p.distance_squared_to(body[i]))
	return sqrt(best)


func _init() -> void:
	if not NpcBody.use_mh:
		print("RESULT test_clothes: SKIP (no MakeHuman body data)")
		quit(0)
		return
	var names: Array = NpcBody.shape_names()
	for sex in ["male", "female"]:
		var src: Array = NpcMhMesh.source(sex)
		var body: PackedVector3Array = src[0][Mesh.ARRAY_VERTEX]
		var buv: PackedVector2Array = src[0][Mesh.ARRAY_TEX_UV]
		# Heights: ethnicity shapes are height-neutral now.
		var top0 := 0.0
		for i in body.size():
			if int(floor(buv[i].x + 0.01)) == 3:
				top0 = maxf(top0, body[i].y)
		for nm in ["caucasian", "african", "asian"]:
			var sp: PackedVector3Array = src[1][names.find(nm)][Mesh.ARRAY_VERTEX]
			var t := 0.0
			for i in sp.size():
				if int(floor(buv[i].x + 0.01)) == 3:
					t = maxf(t, sp[i].y)
			check(absf(t - top0) < 0.002, "%s %s shape keeps the height (%+.1f mm)" % [sex, nm, (t - top0) * 1000.0])
		var yc := NpcWardrobe.crotch_y(sex)
		var rp: Array = NpcMhMesh.rest_positions(sex)
		var chest_y: float = rp[NpcBodyMesh.B_CHEST].y + 0.06
		var ids := ["tee_white", "oxford_blue", "jeans_dark", "chinos_khaki", "hoodie", "puffer"]
		if sex == "female":
			ids += ["skirt_pleated", "sundress", "blouse"]
		for id in ids:
			var t0 := Time.get_ticks_msec()
			var m := NpcWardrobe.mesh(sex, id)
			var ms := Time.get_ticks_msec() - t0
			check(m.get_blend_shape_count() == names.size(), "%s %s: separate mesh with all %d body shapes (%d ms)" % [sex, id, names.size(), ms])
			var a := m.surface_get_arrays(0)
			var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var UV: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var UV2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			var it := NpcWardrobe.item(id)
			# Ease: trunk cloth (below the armpits) sits well off the skin on average.
			var sum := 0.0
			var n := 0
			var chest_min := INF
			var groin_min := INF
			for j in range(0, V.size(), 7):
				if UV2[j].y < 0.0:
					continue   # trimmed off at the hem
				var part := int(floor(UV[j].x + 0.01))
				var p := V[j]
				if part == 0 and p.y < chest_y and p.y > yc + 0.08:
					sum += skin_dist(body, p)
					n += 1
				# front centre of the chest (between the breasts / sternum)
				if it.slot in ["top", "outer"] or it.get("dress", false):
					if part == 0 and absf(p.x) < 0.025 and p.z < 0.0 and absf(p.y - chest_y) < 0.04:
						chest_min = minf(chest_min, skin_dist(body, p))
				# front of the groin
				if it.slot == "bottom" and it.skirt <= 0.0 and part <= 1 and absf(p.x) < 0.03 and p.z < 0.0 and p.y > yc - 0.02 and p.y < yc + 0.05:
					groin_min = minf(groin_min, skin_dist(body, p))
			if n > 0:
				var ease := sum / n
				var want := 0.012 if it.slot != "bottom" else 0.006
				check(ease >= want, "%s %s stands off the body: %.1f mm average (>= %.0f)" % [sex, id, ease * 1000.0, want * 1000.0])
			if chest_min < INF:
				check(chest_min >= 0.008, "%s %s bridges the chest: %.1f mm off the sternum" % [sex, id, chest_min * 1000.0])
			if groin_min < INF:
				check(groin_min >= 0.005, "%s %s never skin-tight at the groin: %.1f mm off the body" % [sex, id, groin_min * 1000.0])
			if it.skirt > 0.0:
				var tube := 0
				for j in UV.size():
					if int(floor(UV[j].x + 0.01)) == 12:
						tube += 1
				check(tube > 1000, "%s %s has a hanging skirt tube (%d vertices)" % [sex, id, tube])
	print("RESULT test_clothes: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
