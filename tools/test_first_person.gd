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
 check(room.first_person and room.camera == room.first_camera, "First-person is default")
 var old_camera: Camera3D = room.top_camera
 var old_position: Vector3 = room.actors[0].position
 check(room.first_person and room.camera == room.first_camera, "First-person camera is selected")
 check(room.find_children("*", "Control", true, false).all(func(n): return not n.get_script() or not str(n.get_script().resource_path).ends_with("virtual_joystick.gd")), "No visible virtual joysticks")
 check(not room.actors[0].get_child(0).visible, "Own model does not obscure the view")
 var ceilings: Array = room.get_children().filter(func(n): return n.has_meta("first_person_ceiling"))
 check(ceilings.size() >= room.layout["floors"].size() and ceilings.all(func(n): return n.visible), "Ceilings enclose the first-person view")
 var viewport := root.get_visible_rect().size
 var left_start := Vector2(viewport.x * 0.25, viewport.y * 0.45)
 var right_start := Vector2(viewport.x * 0.65, viewport.y * 0.45)
 var left := InputEventScreenTouch.new()
 left.index = 4
 left.pressed = true
 left.position = left_start
 room._unhandled_input(left)
 var right := InputEventScreenTouch.new()
 right.index = 9
 right.pressed = true
 right.position = right_start
 room._unhandled_input(right)
 var left_drag := InputEventScreenDrag.new()
 left_drag.index = 4
 left_drag.position = left_start + Vector2(0, -100)
 room._input(left_drag)
 var right_drag := InputEventScreenDrag.new()
 right_drag.index = 9
 right_drag.position = right_start + Vector2(60, -60)
 room._input(right_drag)
 check(room.fp_gestures.movement.y < -0.5, "Left half drag moves while right finger is down")
 check(room.view_yaw != 0 and room.view_pitch > 0.1, "Right half drag changes look concurrently")
 room._tick_first_person(0.5)
 check(absf(room.view_pitch) > 0.1, "Look stick rotates perspective camera")
 check(room.first_camera.position.distance_to(room.actors[0].position + Vector3(0, 1.45, 0)) < 0.01, "Camera follows player")
 for i in 8: room._tick_first_person(0.1)
 check(room.navigation.is_walkable(room.actors[0].position), "First-person movement remains on walkable floor")
 check(room.actors[0].position.distance_to(old_position) > 0.05, "Movement stick moves the player")
 var left_up := InputEventScreenTouch.new()
 left_up.index = 4
 left_up.pressed = false
 left_up.position = left_drag.position
 room._input(left_up)
 check(room.fp_gestures.movement == Vector2.ZERO and room.fp_gestures.fingers.has(9), "Releasing movement stops it without stopping look")
 var right_up := InputEventScreenTouch.new()
 right_up.index = 9
 right_up.pressed = false
 right_up.position = right_drag.position
 room._input(right_up)
 check(room.fp_gestures.fingers.is_empty(), "Both releases clear their individual touches")
 # A touch that starts over the control panel remains GUI input.
 var ui_touch := InputEventScreenTouch.new()
 ui_touch.index = 17
 ui_touch.pressed = true
 ui_touch.position = room.turn_panel.get_global_rect().get_center()
 room._unhandled_input(ui_touch)
 check(not room.fp_gestures.fingers.has(17), "HUD controls do not initiate movement")
 # Focus loss, cancel, and switching camera must not leave a stuck direction.
 room._apply_camera_event(left)
 room._apply_camera_event(left_drag)
 room._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(room.fp_gestures.fingers.is_empty() and room.fp_gestures.movement == Vector2.ZERO, "Focus loss resets gestures")
 room._apply_camera_event(left)
 room._apply_camera_event(left_drag)
 room.toggle_first_person()
 check(not room.first_person and room.camera == old_camera, "Overhead camera restored")
 check(room.fp_gestures.fingers.is_empty() and room.fp_gestures.movement == Vector2.ZERO, "Switching view resets touch input")
 check(room.actors[0].get_child(0).visible, "Own model is visible overhead")
 check(ceilings.all(func(n): return not n.visible), "Ceilings do not obstruct the overhead view")
 var count := 0
 for node in room.find_children("*", "MeshInstance3D", true, false):
  if node.has_meta("rounded_passage"): count += 1
 check(count == room.layout["modules"].size(), "Every module has a rounded passage frame")
 var shell = preload("res://game/scripts/modular_shell.gd")
 var plan := {"floors": [Rect2(0, 0, 10, 5), Rect2(3, -2, 2, 2.1)]}
 var spans: Array = shell.exposed_spans(plan, Vector2(0, 0), Vector2.RIGHT, Vector2.UP, 10.0)
 check(spans.size() == 2 and spans[0].is_equal_approx(Vector2(0, 3)) and spans[1].is_equal_approx(Vector2(5, 10)), "Door openings follow exact corridor edges")
 room.queue_free()
 await process_frame
 print("First-person failures: ", failures)
 quit(1 if failures else 0)
