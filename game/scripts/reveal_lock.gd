extends Button
var is_public := false:
 set(value):
  is_public = value
  queue_redraw()
var parameter_id := ""

func _init() -> void:
 custom_minimum_size = Vector2(52, 52)
 size_flags_horizontal = Control.SIZE_SHRINK_CENTER
 size_flags_vertical = Control.SIZE_SHRINK_CENTER
 set_meta("parameter_lock", true)
 for state in ["normal", "hover", "pressed", "focus", "disabled"]:
  var box := StyleBoxFlat.new()
  box.bg_color = Color("122730")
  box.border_color = Color("516a74") if state in ["hover", "focus"] else Color("304b56")
  box.set_border_width_all(1)
  box.set_corner_radius_all(12)
  add_theme_stylebox_override(state, box)
 resized.connect(queue_redraw)

func _draw() -> void:
 var offset := (size - Vector2(52, 52)) * 0.5
 var color := Color("65d694") if is_public else Color("ef6b6b")
 var shackle := Vector2(30 if is_public else 26, 22) + offset
 draw_arc(shackle, 8, PI, TAU, 24, color, 3, true)
 draw_line(shackle + Vector2(8, 0), shackle + Vector2(8, 6), color, 3, true)
 if not is_public:
  draw_line(shackle - Vector2(8, 0), shackle + Vector2(-8, 5), color, 3, true)
 draw_style_box(lock_body(color), Rect2(Vector2(14, 23) + offset, Vector2(24, 19)))
 draw_circle(Vector2(26, 31) + offset, 2.2, Color("11242b"))
 draw_line(Vector2(26, 32) + offset, Vector2(26, 36) + offset, Color("11242b"), 2)

func lock_body(color: Color) -> StyleBoxFlat:
 var body := StyleBoxFlat.new()
 body.bg_color = color
 body.set_corner_radius_all(4)
 return body
