extends SceneTree
## Opens the generator, checks unit conversion round trips, and renders it.
func _initialize() -> void:
	var g := NpcGenerator.new()
	root.add_child(g)

var f := 0
func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		var g: NpcGenerator = root.get_child(root.get_child_count() - 1)
		g._ui.units.selected = 0
		g._ui.ft.value = 5; g._ui.inch.value = 9.0; g._ui.weight.value = 160.0
		g._refresh()
		var r := g.current_record()
		print("  5 ft 9 in, 160 lb -> %.1f cm, %.1f kg" % [r.height_cm, r.weight_kg])
		var ok: bool = absf(r.height_cm - 175.3) < 0.05 and absf(r.weight_kg - 72.6) < 0.05
		g._ui.units.selected = 1
		g._refresh()
		print("  metric fields: %.1f cm, %.1f kg" % [g._ui.cm.value, g._ui.weight.value])
		ok = ok and absf(g._ui.cm.value - 175.3) < 0.05
		print("RESULT test_generator: ", "PASS" if ok else "FAIL")
		var args := OS.get_cmdline_user_args()
		if args.size() > 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[0])
		quit(0 if ok else 1)
	return false
