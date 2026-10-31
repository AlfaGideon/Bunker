extends SceneTree
const Gestures = preload("res://game/scripts/first_person_gestures.gd")
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func touch(id: int, at: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
 var event := InputEventScreenTouch.new()
 event.index = id
 event.position = at
 event.pressed = pressed
 event.canceled = canceled
 return event
func drag(id: int, at: Vector2) -> InputEventScreenDrag:
 var event := InputEventScreenDrag.new()
 event.index = id
 event.position = at
 return event
func _initialize() -> void:
 var g = Gestures.new()
 var size := Vector2(1280, 720)
 check(g.handle(touch(1, Vector2(200, 300), true), size).handled, "Left finger captured")
 check(g.handle(touch(2, Vector2(900, 300), true), size).handled, "Right finger captured concurrently")
 check(not g.handle(touch(3, Vector2(180, 300), true), size).handled, "Extra finger on occupied side ignored")
 g.handle(drag(1, Vector2(200, 200)), size)
 check(g.movement.y < -0.8, "Left drag sets forward movement")
 var turn: Dictionary = g.handle(drag(2, Vector2(970, 250)), size)
 check(turn.has("look") and turn.look.x > 0 and turn.look.y < 0, "Right drag produces direct look delta")
 g.handle(drag(1, Vector2(700, 300)), size)
 check(g.move_finger == 1 and g.look_finger == 2, "Crossing centre preserves original side")
 g.handle(touch(1, Vector2(700, 300), false, true), size)
 check(g.movement == Vector2.ZERO and g.look_finger == 2, "Canceled movement stops without interrupting look")
 var end: Dictionary = g.handle(touch(2, Vector2(970, 250), false), size)
 check(not end.has("tap") and g.fingers.is_empty(), "Dragging and releasing never selects an item")
 g.handle(touch(4, Vector2(800, 400), true), size)
 var tap: Dictionary = g.handle(touch(4, Vector2(802, 401), false), size)
 check(tap.has("tap"), "Short tap remains an interaction")
 g.handle(touch(5, Vector2(800, 400), true), size)
 var cancel: Dictionary = g.handle(touch(5, Vector2(800, 400), false, true), size)
 check(not cancel.has("tap"), "Canceled touch cannot interact")
 print("First-person gestures failures: ", failures)
 quit(1 if failures else 0)
