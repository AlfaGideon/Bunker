extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for i in 15: await process_frame
 room.menu.visible = false
 if not room.first_person: room.toggle_first_person()
 room.actors[0].position = Vector3(4.2, 0, 6.7)
 room.view_yaw = -PI / 2
 room.view_pitch = 0.15
 room._update_first_camera()
 for i in 10: await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(800, roundi(image.get_height() * 800.0 / image.get_width()))
 var bytes := image.save_jpg_to_buffer(0.45)
 if bytes.size() > 22000: bytes = image.save_jpg_to_buffer(0.25)
 var encoded := Marshalls.raw_to_base64(bytes)
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::EXITVIEW_%02d:" % index + encoded.substr(index * 3500, 3500))
 quit()
