extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 if OS.get_cmdline_user_args().has("--female"):
  welcome.profile.appearance = "female"
  welcome.profile.outfit = 1
  welcome.draft_name = "Мира"
  welcome.update_avatar()
  welcome.home()
 for frame in 25:
  await process_frame
 await create_timer(0.9).timeout
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(800, roundi(image.get_height() * 800.0 / image.get_width()))
 var bytes := image.save_jpg_to_buffer(0.6)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.3)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.15)
 var encoded := Marshalls.raw_to_base64(bytes)
 var prefix := "WELCOMEAVATARSHOT" if OS.get_cmdline_user_args().has("--female") else "MENUSHOT"
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
 quit()
