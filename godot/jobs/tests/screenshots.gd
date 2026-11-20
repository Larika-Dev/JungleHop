extends SceneTree
## Renders each mini-game to res://jobs/tests/shots/<name>.png (needs a display, e.g. xvfb-run).

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://jobs/data/jobs.json"))
	root.size = Vector2i(1600, 900)
	for j in data.jobs:
		var mg: Node = load("res://jobs/scenes/%s.tscn" % j.minigame).instantiate()
		root.add_child(mg)
		mg.begin(null, "", 0.5, 7)
		for i in (40 if j.minigame == "barista_bar" else 12):
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(OS.get_user_data_dir() + "/shots/%s.png" % j.minigame)
		mg.queue_free()
		await process_frame
	print("shots in ", OS.get_user_data_dir() + "/shots")
	quit()
