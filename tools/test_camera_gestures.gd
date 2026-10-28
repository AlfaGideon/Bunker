extends SceneTree
var failures := 0
func check(value: bool, title: String) -> void:
 if not value:
  failures += 1
  push_error(title)
func touch(controller: RefCounted, index: int, at: Vector2, down: bool) -> Dictionary:
 var event := InputEventScreenTouch.new()
 event.index = index
 event.position = at
 event.pressed = down
 return controller.handle(event)
func drag(controller: RefCounted, index: int, at: Vector2) -> void:
 var event := InputEventScreenDrag.new()
 event.index = index
 event.position = at
 controller.handle(event)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.menu.visible = false
 room.set_physics_process(false)
 for frame in 4:
  await process_frame
 var controller: RefCounted = room.camera_gestures
 var center := root.get_visible_rect().size * 0.5
 var original: Transform3D = room.camera.transform
 var size_before: float = room.camera.size
 check(not touch(controller, 0, center, true).has("tap"), "Touch down never orders movement")
 check(touch(controller, 0, center + Vector2(2, 2), false).has("tap"), "Short release is a tap")
 touch(controller, 0, center, true)
 drag(controller, 0, center + Vector2(80, 30))
 check(room.camera.transform != original, "One finger pans")
 check(not touch(controller, 0, center + Vector2(80, 30), false).has("tap"), "Swipe never orders movement")
 touch(controller, 0, center - Vector2(80, 0), true)
 touch(controller, 1, center + Vector2(80, 0), true)
 drag(controller, 1, center + Vector2(160, 0))
 check(room.camera.size < size_before, "Spread zooms in")
 var smaller: float = room.camera.size
 drag(controller, 1, center + Vector2(40, 0))
 check(room.camera.size > smaller, "Pinch zooms out")
 touch(controller, 1, center + Vector2(40, 0), false)
 check(not touch(controller, 0, center - Vector2(80, 0), false).has("tap"), "Pinch release never orders movement")
 var anchor_before: Variant = controller.ground(center)
 controller.transform_view(center, center, 0.8)
 var anchor_after: Variant = controller.ground(center)
 check(anchor_before.distance_to(anchor_after) < 0.01, "Zoom anchored under gesture")
 controller.transform_view(center, center, 0.0001)
 check(room.camera.size == controller.MIN_ZOOM, "Minimum zoom")
 controller.transform_view(center, center, 10000)
 check(room.camera.size <= controller.MAX_ZOOM, "Maximum zoom")
 for offset in [Vector2(10000,10000), Vector2(-20000,-20000), Vector2(10000,-10000)]:
  controller.transform_view(center, center + offset, 1000)
  var bounds: Rect2 = controller.ground_bounds()
  check(bounds.position.x >= -56.01 and bounds.end.x <= 56.01 and bounds.position.y >= -56.01 and bounds.end.y <= 56.01, "Whole visible terrain stays inside safe border")
 touch(controller, 2, center, true)
 room.menu.visible = true
 room._input(InputEventMouseMotion.new())
 check(controller.fingers.is_empty(), "Modal cancels active fingers")
 room.menu.visible = false
 # Local viewport coordinates: headless has a 64px physical window, so
 # Input.parse_input_event would multiply these logical coordinates by 20.
 # Dispatch through GUI normally, without applying physical stretch twice.
 var event := InputEventScreenTouch.new()
 event.index = 4
 event.position = Vector2(root.get_visible_rect().size.x - 60, 70)
 event.pressed = true
 root.push_input(event, true)
 await process_frame
 check(controller.fingers.is_empty(), "Touch over HUD stays in GUI")
 event = InputEventScreenTouch.new()
 event.index = 4
 event.position = Vector2(root.get_visible_rect().size.x - 60, 70)
 event.pressed = false
 root.push_input(event, true)
 await process_frame
 room.menu.visible = false
 event = InputEventScreenTouch.new()
 event.index = 5
 event.position = center
 event.pressed = true
 root.push_input(event, true)
 await process_frame
 check(controller.fingers.has(5), "Touch over world starts gesture")
 event = InputEventScreenTouch.new()
 event.index = 5
 event.position = center
 event.canceled = true
 event.pressed = false
 check(not controller.handle(event).has("tap"), "Canceled touch cannot order movement")
 room.free()
 print("Camera gesture failures: ", failures)
 quit(1 if failures else 0)
