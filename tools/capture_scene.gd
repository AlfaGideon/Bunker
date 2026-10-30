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
	if args.has("--infection-detail"):
		scenario_id = "infection"
		seed_value = 3
		shot_prefix = "INFECTDETAILSHOT"
	if args.has("--solar"):
		scenario_id = "solar_superstorm"
		shot_prefix = "AURORASHOT"
	if args.has("--architecture-alt"):
		seed_value = 17
	room.profile.scenario_choice = scenario_id
	set_meta("world_seed", seed_value)
	root.add_child(room)
	if args.has("--architecture") or args.has("--architecture-alt"):
		room.ui_root.visible = false
		room._frame_camera()
		shot_prefix = "ARCHALTSHOT" if args.has("--architecture-alt") else "ARCHSHOT"
	var show_menu := OS.get_cmdline_user_args().has("--menu")
	room.menu.visible = show_menu
	var show_survival := OS.get_cmdline_user_args().has("--survival")
	if show_survival:
		room.survival_panel.mode.select(4)
		room.survival_panel.configure()
		room.survival_panel.visible = true
	if args.has("--open-med"):
		room.players[0]["cards"][0]["value"] = "Врач"
		room.round_number = 2
		room._open_medical(0)
		room._refresh()
		await create_timer(0.7).timeout
		room.ui_root.visible = false
		room.camera.size = 7
		var focus: Vector3 = room.layout["modules"]["medical"]["center"] + Vector3(0, 0.8, 0)
		room.camera.position = focus + Vector3(7, 9, 13)
		room.camera.look_at(focus)
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
	if args.has("--vote"):
		room.start_vote()
		shot_prefix = "VOTESHOT"
	if args.has("--council"):
		room.menu.show_council()
		shot_prefix = "COUNCILSHOT"
	if args.has("--facilities"):
		room.ui_root.visible = false
		room.camera.size = 8
		var focus: Vector3 = room.layout["modules"]["kitchen"]["center"] + Vector3(0, 0.5, 0)
		room.camera.position = focus + Vector3(7, 9, 13)
		room.camera.look_at(focus)
		shot_prefix = "FACILITYSHOT"
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
	if args.has("--infection-detail"):
		room.ui_root.visible = false
		room.set_physics_process(false)
		var infected: Node3D = room.weather.walkers[2]
		var focus: Vector3 = infected.position + Vector3(0, 0.5, 0)
		room.camera.size = 5
		room.camera.position = focus + Vector3(3, 3.5, 6)
		room.camera.look_at(focus)
	if args.has("--meteor-detail"):
		room.ui_root.visible = false
		room.camera.size = 8
		var focus := Vector3(0, 2.2, 9)
		room.camera.position = focus + Vector3(7, 9, 13)
		room.camera.look_at(focus)
		shot_prefix = "METEORDETAILSHOT"
	if args.has("--negative-actions"):
		room.NegativeActions.quality_card(room.players[0])["value"] = "Вспыльчивый"
		room.menu.show_negative_actions()
		shot_prefix = "NEGATIVEACTIONSHOT"
	for i in 15:
		await process_frame
	if is_instance_valid(room.weather.meteor_field):
		# Capture the same travelling-rock phase after shader warm-up, not a
		# random moment in the short impact flash.
		room.weather.meteor_field.set_process(false)
		room.weather.meteor_field.clock = 1.2
		room.weather.meteor_field._process(0)
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
	var width := 800 if args.has("--characters") or args.has("--meteor-detail") or args.has("--infection-detail") else 640
	image.resize(width, roundi(image.get_height() * float(width) / image.get_width()))
	DirAccess.make_dir_recursive_absolute("res://builds")
	var bytes := image.save_jpg_to_buffer(0.6)
	var file := FileAccess.open("res://builds/scene.jpg", FileAccess.WRITE)
	file.store_buffer(bytes)
	# Actions retains at most ten notices per step. Stay under 24 KB even for
	# close-ups, otherwise the final JPEG chunks silently disappear.
	var cap := 24000 if width == 800 else 22000
	for quality in [0.3, 0.2, 0.12]:
		if bytes.size() > cap:
			bytes = image.save_jpg_to_buffer(quality)
	if bytes.size() > cap:
		image.resize(512, roundi(image.get_height() * 512.0 / image.get_width()))
		bytes = image.save_jpg_to_buffer(0.25)
	if bytes.size() > cap:
		print("::error::Preview exceeds annotation transport budget")
		quit(1)
		return
	var encoded := Marshalls.raw_to_base64(bytes)
	var chunks := ceili(encoded.length() / 3500.0)
	for index in chunks:
		var prefix := "MENUSHOT" if show_menu else ("SURVIVALSHOT" if show_survival else ("WIDESHOT" if OS.get_cmdline_user_args().has("--wide") else "SCREENSHOT"))
		if not shot_prefix.is_empty():
			prefix = shot_prefix
		print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
	quit()
