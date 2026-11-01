extends SceneTree
## Capture the hall-facing entrance and the bend, not only the far hatch.
func _initialize() -> void:
 call_deferred("capture")

func screenshot(room: Node3D, prefix: String, position: Vector3, yaw: float) -> void:
 room.actors[0].position = position
 room.view_yaw = yaw
 room.view_pitch = 0.0
 room._update_first_camera()
 for i in 6: await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(960, roundi(image.get_height() * 960.0 / image.get_width()))
 var bytes := image.save_jpg_to_buffer(0.45)
 if bytes.size() > 28000: bytes = image.save_jpg_to_buffer(0.25)
 var encoded := Marshalls.raw_to_base64(bytes)
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::%s_%02d:" % [prefix, index] + encoded.substr(index * 3500, 3500))

func capture() -> void:
 set_meta("world_seed", 0)
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for i in 15: await process_frame
 room.menu.visible = false
 if not room.first_person: room.toggle_first_person()
 var args := OS.get_cmdline_user_args()
 var view := args[0] if not args.is_empty() else "front"
 if view == "angle":
  await screenshot(room, "ENTRANCE_ANGLE", Vector3(2.6, 0, 3.1), -2.55)
 elif view == "bend":
  room.entrance_hatch.position.y = -2.2
  await screenshot(room, "TUNNEL_BEND", Vector3(3.75, 0, 5.35), -PI / 2.0)
 else:
  await screenshot(room, "ENTRANCE_FRONT", Vector3(3.8, 0, 2.9), PI)
 quit()
