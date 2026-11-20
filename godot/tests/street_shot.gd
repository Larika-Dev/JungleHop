extends Node
func _ready() -> void:
	Settings.fullscreen = false
	Settings.apply()
	get_window().size = Vector2i(960, 540)
	GameClock.set_time(1, 16, 0)
	get_tree().root.add_child.call_deferred(load("res://world/city.tscn").instantiate())
	for i in 400:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/street.png")
	get_tree().quit()
