extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var loading = (load("res://game/loading.tscn") as PackedScene).instantiate()
 root.add_child(loading)
 loading.set_process(false)
 for frame in 15:
  await process_frame
 await create_timer(1.1).timeout
 var argument := OS.get_cmdline_user_args()
 var t := 3.4 if not argument.has("--arrival") else 6.95
 if argument.has("--start"):
  t = 0.4
 loading.elapsed = t
 loading.advance_cinematic()
 if t > 0.85 and t < 6.0:
  loading.animator.advance(0.35)
 for frame in 8:
  await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(800, roundi(image.get_height() * 800.0 / image.get_width()))
 var bytes := image.save_jpg_to_buffer(0.5)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.25)
 var encoded := Marshalls.raw_to_base64(bytes)
 var prefix := "LOADINGARRIVALSHOT" if argument.has("--arrival") else "LOADINGSHOT"
 if argument.has("--start"):
  prefix = "LOADINGSTARTSHOT"
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
 quit()
