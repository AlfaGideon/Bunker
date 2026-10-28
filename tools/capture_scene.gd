extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	var args := OS.get_cmdline_user_args()
	var scenario_id := "long_winter"
	var seed_value := 0
	var shot_prefix := ""
	if args.has("--flood"):
		scenario_id = "great_flood"
		seed_value = 1
		shot_prefix = "FLOODSHOT"
	elif args.has("--meteors") or args.has("--meteor-detail"):
		scenario_id = "meteor_storm"
		seed_value = 2
		shot_prefix = "METEORSHOT"
	elif args.has("--infection"):
		scenario_id = "infection"
		seed_value = 3
		shot_prefix = "INFECTIONSHOT"
	if args.has("--solar"):
		scenario_id = "solar_superstorm"
		shot_prefix = "AURORASHOT"
	room.profile.scenario_choice = scenario_id
	set_meta("world_seed", seed_value)
	root.add_child(room)
	var show_menu := OS.get_cmdline_user_args().has("--menu")
	room.menu.visible = show_menu
	var show_survival := OS.get_cmdline_user_args().has("--survival")
	if show_survival:
		room.survival_panel.visible = true
	if args.has("--open-med"):
		room.systems_ready = true
		room.round_number = 2
		room._update_medical_access()
		room._refresh()
		await create_timer(0.7).timeout
		shot_prefix = "MEDICALSHOT"
	if args.has("--sleep"):
		room.set_physics_process(false)
		room.request_interaction("bed")
		for tick in 2000:
			room._physics_process(1.0 / 60)
			if room.rest_remaining > 0:
				break
		if room.rest_remaining <= 0:
			print("::error::Sleep preview did not reach actual lying state")
			quit(1)
			return
		shot_prefix = "SLEEPSHOT"
	if args.has("--characters"):
		room.ui_root.visible = false
		room.set_physics_process(false)
		room._change_appearance(0, "male")
		room._change_appearance(1, "female")
		room.actors[0].position = Vector3(0, 0, 3.5)
		room.actors[1].position = Vector3(1.7, 0, 3.5)
		for index in [0, 1]:
			room.actors[index].rotation = Vector3.ZERO
			room.actors[index].get_child(0).animate(0.1, false, 0)
		room.camera.size = 3.8
		room.camera.position = Vector3(3.6, 3.4, 9)
		room.camera.look_at(Vector3(0.8, 0.8, 3.5))
		shot_prefix = "CHARACTERSHOT"
	if args.has("--meteor-detail"):
		room.ui_root.visible = false
		room.camera.size = 7
		var focus := Vector3(0, 2, 10)
		room.camera.position = focus + Vector3(7, 9, 13)
		room.camera.look_at(focus)
		shot_prefix = "METEORDETAILSHOT"
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
		if not shot_prefix.is_empty():
			prefix = shot_prefix
		print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
	quit()
