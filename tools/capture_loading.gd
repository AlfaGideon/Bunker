extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var loading := (load("res://game/loading.tscn") as PackedScene).instantiate()
 root.add_child(loading)
 # Diagnostic still: prevent auto-transition, but advance the actual rig/process.
 loading.set_process(false)
 for frame in 15:
  await process_frame
 loading._process(1.15)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(800, 450)
 var bytes := image.save_jpg_to_buffer(0.5)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.2)
 var encoded := Marshalls.raw_to_base64(bytes)
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::LOADINGSHOT_%02d:" % index + encoded.substr(index * 3500, 3500))
 quit()
