extends RefCounted
## Invisible, independently tracked touch regions. A drag stays assigned to
## the side on which it began even if the finger crosses the centre line.
const TAP_SLOP := 12.0
const LOOK_SENSITIVITY := 0.004
var fingers: Dictionary = {}
var move_finger := -1
var look_finger := -1
var movement := Vector2.ZERO
var mouse_down := false
const MOUSE_ID := -100

func reset() -> void:
 fingers.clear()
 move_finger = -1
 look_finger = -1
 movement = Vector2.ZERO
 mouse_down = false

func ongoing(event: InputEvent) -> bool:
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  return fingers.has(event.index)
 if event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
  return mouse_down
 return false

func handle(event: InputEvent, viewport_size: Vector2) -> Dictionary:
 var out := {"handled": false}
 if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
  return out
 if event is InputEventScreenTouch:
  if event.pressed:
   return _press(event.index, event.position, viewport_size)
  return _release(event.index, event.position, event.canceled)
 if event is InputEventScreenDrag:
  return _drag(event.index, event.position, viewport_size)
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if event.pressed:
   var result := _press(MOUSE_ID, event.position, viewport_size)
   mouse_down = result["handled"]
   return result
  mouse_down = false
  return _release(MOUSE_ID, event.position, false)
 if event is InputEventMouseMotion and mouse_down:
  return _drag(MOUSE_ID, event.position, viewport_size)
 return out

func _press(id: int, point: Vector2, viewport_size: Vector2) -> Dictionary:
 if fingers.has(id):
  return {"handled": false}
 var side := "move" if point.x < viewport_size.x * 0.5 else "look"
 if (side == "move" and move_finger != -1) or (side == "look" and look_finger != -1):
  return {"handled": false}
 fingers[id] = {"side": side, "origin": point, "last": point, "moved": false}
 if side == "move": move_finger = id
 else: look_finger = id
 return {"handled": true}

func _drag(id: int, point: Vector2, viewport_size: Vector2) -> Dictionary:
 if not fingers.has(id):
  return {"handled": false}
 var entry: Dictionary = fingers[id]
 var origin: Vector2 = entry["origin"]
 var last: Vector2 = entry["last"]
 if origin.distance_to(point) > TAP_SLOP:
  entry["moved"] = true
 var result := {"handled": true}
 if entry["side"] == "move":
  var radius := clampf(viewport_size.y * 0.15, 70.0, 120.0)
  var direction := (point - origin).limit_length(radius) / radius
  movement = direction if entry["moved"] else Vector2.ZERO
 elif entry["moved"]:
  # Include the initial displacement once the gesture crosses the tap slop.
  var previous := last if origin.distance_to(last) > TAP_SLOP else origin
  result["look"] = (point - previous) * LOOK_SENSITIVITY
 entry["last"] = point
 return result

func _release(id: int, point: Vector2, canceled: bool) -> Dictionary:
 if not fingers.has(id):
  return {"handled": false}
 var entry: Dictionary = fingers[id]
 var result := {"handled": true}
 if not canceled and not entry["moved"] and (entry["origin"] as Vector2).distance_to(point) <= TAP_SLOP:
  result["tap"] = point
 if id == move_finger:
  move_finger = -1
  movement = Vector2.ZERO
 if id == look_finger:
  look_finger = -1
 fingers.erase(id)
 return result
