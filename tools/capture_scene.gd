extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(640, 360)
	DirAccess.make_dir_recursive_absolute("res://builds")
	var bytes := image.save_jpg_to_buffer(0.7)
	var file := FileAccess.open("res://builds/scene.jpg", FileAccess.WRITE)
	file.store_buffer(bytes)
	print("::notice::SCREENSHOT_BASE64:" + Marshalls.raw_to_base64(bytes))
	quit()
