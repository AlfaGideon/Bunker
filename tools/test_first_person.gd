extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for frame in 5: await process_frame
 room.menu.visible = false
 var old_camera: Camera3D = room.camera
 var old_position: Vector3 = room.actors[0].position
 room.toggle_first_person()
 check(room.first_person and room.camera == room.first_camera, "First-person camera is selected")
 check(room.move_stick.visible and room.look_stick.visible, "Both touch sticks are visible")
 check(not room.actors[0].get_child(0).visible, "Own model does not obscure the view")
 room.look_stick.value = Vector2(0.5, -0.5)
 room._tick_first_person(0.5)
 check(absf(room.view_pitch) > 0.1, "Look stick rotates perspective camera")
 check(room.first_camera.position.distance_to(room.actors[0].position + Vector3(0, 1.45, 0)) < 0.01, "Camera follows player")
 room.move_stick.value = Vector2(0, -1)
 for i in 8: room._tick_first_person(0.1)
 check(room.navigation.is_walkable(room.actors[0].position), "First-person movement remains on walkable floor")
 check(room.actors[0].position.distance_to(old_position) > 0.05, "Movement stick moves the player")
 room.toggle_first_person()
 check(not room.first_person and room.camera == old_camera, "Overhead camera restored")
 check(not room.move_stick.visible and not room.look_stick.visible, "Touch sticks hidden overhead")
 check(room.actors[0].get_child(0).visible, "Own model is visible overhead")
 var frames := room.find_children("RoundedPassageFrame", "MeshInstance3D", true, false)
 check(frames.size() == room.layout["modules"].size(), "Every module has a rounded passage frame")
 room.queue_free()
 await process_frame
 print("First-person failures: ", failures)
 quit(1 if failures else 0)
