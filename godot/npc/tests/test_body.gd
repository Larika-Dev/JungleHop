extends SceneTree
## Builds every body template and reports size and build time.
var failures := 0
func check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok: failures += 1

func _init() -> void:
	for sex in ["male", "female"]:
		for lod in 3:
			var t0 := Time.get_ticks_msec()
			var b := NpcBodyMesh.new()
			var m := b.build(sex, lod)
			var ms := Time.get_ticks_msec() - t0
			var tris := m.surface_get_array_index_len(0) / 3
			print("  %s LOD%d: %d vertices, %d triangles, %d blend shapes, built in %d ms" % [sex, lod, b.vertex_count(), tris, m.get_blend_shape_count(), ms])
			check(m.get_blend_shape_count() == NpcBodyMesh.SHAPES.size(), "%s LOD%d has all blend shapes" % [sex, lod])
			var aabb := m.get_aabb()
			check(absf(aabb.size.y - NpcBodyMesh.REF_HEIGHT[sex]) < 0.01, "%s LOD%d is %.3f m tall (ref %.3f)" % [sex, lod, aabb.size.y, NpcBodyMesh.REF_HEIGHT[sex]])
	print("RESULT test_body: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
