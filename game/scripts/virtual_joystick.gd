extends Control
## Independent touch sticks: one finger can move while another looks around.
var value := Vector2.ZERO
var finger := -1
var mouse_pressed := false
var caption := ""

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 queue_redraw()

func reset() -> void:
 value = Vector2.ZERO
 finger = -1
 mouse_pressed = false
 queue_redraw()

func update_value(point: Vector2) -> void:
 var radius := minf(size.x, size.y) * 0.39
 var displacement := (point - size * 0.5).limit_length(radius) / radius
 value = Vector2.ZERO if displacement.length() < 0.12 else displacement
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and finger < 0:
   finger = event.index
   update_value(event.position)
  elif not event.pressed and event.index == finger:
   reset()
  accept_event()
 elif event is InputEventScreenDrag and event.index == finger:
  update_value(event.position)
  accept_event()
 elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
  mouse_pressed = event.pressed
  if mouse_pressed: update_value(event.position)
  else: reset()
  accept_event()
 elif event is InputEventMouseMotion and mouse_pressed:
  update_value(event.position)
  accept_event()

func _draw() -> void:
 var center := size * 0.5
 var radius := minf(size.x, size.y) * 0.39
 draw_circle(center, radius, Color(0.05, 0.13, 0.17, 0.62))
 draw_arc(center, radius, 0, TAU, 64, Color(0.59, 0.83, 0.84, 0.7), 2, true)
 draw_circle(center + value * radius, radius * 0.36, Color(0.62, 0.82, 0.80, 0.72))
 draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 3), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("d5e9e4"))
