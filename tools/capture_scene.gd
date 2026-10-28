extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	var show_menu := OS.get_cmdline_user_args().has("--menu")
	room.menu.visible = show_menu
	var show_survival := OS.get_cmdline_user_args().has("--survival")
	if show_survival:
		room.survival_panel.visible = true
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if OS.get_cmdline_user_args().has("--wide"):
		if image.get_size() != Vector2i(2460, 1080):
			print("::error::Unexpected wide framebuffer: " + str(image.get_size()))
			quit(1)
			return
		if absf(room.ui_root.size.x - root.get_visible_rect().size.x) >= 1:
			print("::error::HUD does not fill expanded canvas: " + str(room.ui_root.size) + " / " + str(root.get_visible_rect().size))
			quit(1)
			return
		var logical := root.get_visible_rect().size
		if absf(logical.x / logical.y - 2460.0 / 1080.0) > 0.01:
			print("::error::Letterboxed logical canvas: " + str(logical))
			quit(1)
			return
	image.resize(640, roundi(image.get_height() * 640.0 / image.get_width()))
	DirAccess.make_dir_recursive_absolute("res://builds")
	var bytes := image.save_jpg_to_buffer(0.6)
	var file := FileAccess.open("res://builds/scene.jpg", FileAccess.WRITE)
	file.store_buffer(bytes)
	if bytes.size() > 22000:
		bytes = image.save_jpg_to_buffer(0.3)
	if bytes.size() > 22000:
		image.resize(512, roundi(image.get_height() * 512.0 / image.get_width()))
		bytes = image.save_jpg_to_buffer(0.25)
	var encoded := Marshalls.raw_to_base64(bytes)
	var chunks := ceili(encoded.length() / 3500.0)
	for index in chunks:
		var prefix := "MENUSHOT" if show_menu else ("SURVIVALSHOT" if show_survival else ("WIDESHOT" if OS.get_cmdline_user_args().has("--wide") else "SCREENSHOT"))
		print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
	quit()
