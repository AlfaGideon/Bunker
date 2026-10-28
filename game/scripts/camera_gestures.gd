extends RefCounted

const TAP_SLOP := 12.0
const MIN_ZOOM := 4.0
const MAX_ZOOM := 80.0
var room: Node3D
var fingers: Dictionary = {}
var mouse_down := false
var origin := Vector2.ZERO
var last_mouse := Vector2.ZERO
var moved := false
var multi := false

func setup(game: Node3D) -> void:
 room = game

func reset() -> void:
 fingers.clear()
 mouse_down = false
 moved = false
 multi = false

func ongoing(event: InputEvent) -> bool:
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  return fingers.has(event.index)
 if event is InputEventMouseMotion:
  return mouse_down
 if event is InputEventMouseButton:
  return mouse_down and event.button_index == MOUSE_BUTTON_LEFT
 return false

func ground(point: Vector2) -> Variant:
 return Plane(Vector3.UP, 0).intersects_ray(room.camera.project_ray_origin(point), room.camera.project_ray_normal(point))

func transform_view(before: Vector2, after: Vector2, factor: float = 1.0) -> void:
 if is_instance_valid(room.camera_tween):
  room.camera_tween.kill()
 var anchor: Variant = ground(before)
 room.camera.size = clampf(room.camera.size * factor, MIN_ZOOM, MAX_ZOOM)
 var target: Variant = ground(after)
 if anchor != null and target != null:
  room.camera.position += anchor - target
 var center: Variant = ground(room.get_viewport().get_visible_rect().size * 0.5)
 if center != null:
  var limits: Rect2 = room.layout["bounds"].grow(10)
  room.camera.position += Vector3(clampf(center.x, limits.position.x, limits.end.x) - center.x, 0, clampf(center.z, limits.position.y, limits.end.y) - center.z)

func handle(event: InputEvent) -> Dictionary:
 var result := {"handled": false}
 if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
  return result
 if event is InputEventScreenTouch:
  if event.pressed:
   if fingers.is_empty():
    origin = event.position
    moved = false
    multi = false
   fingers[event.index] = event.position
   if fingers.size() > 1:
    multi = true
  elif fingers.has(event.index):
   if fingers.size() == 1 and not moved and not multi and origin.distance_to(event.position) <= TAP_SLOP:
    result["tap"] = event.position
   fingers.erase(event.index)
  result["handled"] = true
 elif event is InputEventScreenDrag and fingers.has(event.index):
  var previous: Vector2 = fingers[event.index]
  if fingers.size() >= 2:
   var keys: Array = fingers.keys()
   var a: Vector2 = fingers[keys[0]]
   var b: Vector2 = fingers[keys[1]]
   var old_center := (a + b) * 0.5
   var old_distance := a.distance_to(b)
   fingers[event.index] = event.position
   a = fingers[keys[0]]
   b = fingers[keys[1]]
   transform_view(old_center, (a + b) * 0.5, old_distance / maxf(1, a.distance_to(b)))
   moved = true
  else:
   fingers[event.index] = event.position
   if moved or multi or origin.distance_to(event.position) > TAP_SLOP:
    transform_view(previous if moved or multi else origin, event.position)
    moved = true
  result["handled"] = true
 elif event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
   transform_view(event.position, event.position, 0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85)
   result["handled"] = true
  elif event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed:
    mouse_down = true
    origin = event.position
    last_mouse = event.position
    moved = false
   elif mouse_down:
    if not moved and origin.distance_to(event.position) <= TAP_SLOP:
     result["tap"] = event.position
    mouse_down = false
   result["handled"] = true
 elif event is InputEventMouseMotion and mouse_down:
  if moved or origin.distance_to(event.position) > TAP_SLOP:
   transform_view(last_mouse if moved else origin, event.position)
   moved = true
  last_mouse = event.position
  result["handled"] = true
 elif event is InputEventMagnifyGesture:
  transform_view(event.position, event.position, 1.0 / maxf(0.01, event.factor))
  result["handled"] = true
 elif event is InputEventPanGesture:
  transform_view(event.position, event.position - event.delta * 12)
  result["handled"] = true
 return result
