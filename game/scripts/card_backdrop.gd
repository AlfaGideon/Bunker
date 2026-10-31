extends Control
## Printed-paper backdrop for the face-up side of the character card.

var accent := Color("c9a36a")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_accent(value: Color) -> void:
	accent = value
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var steps := 28
	for i in steps:
		var t := float(i) / float(steps - 1)
		var strip := Color("0b1d23").lerp(Color("0e2830"), t)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / float(steps) + 1.5), strip)
	# Warm vignette at the top-left, cool one at the bottom-right.
	for i in 9:
		var radius := 60.0 + i * 34.0
		draw_circle(Vector2(size.x * 0.14, size.y * 0.12), radius, Color(accent, 0.016))
		draw_circle(Vector2(size.x * 0.88, size.y * 0.94), radius, Color(0, 0, 0, 0.028))
	# Sparse diagonal hatch, clipped by construction to the card rect.
	var y := 16.0
	while y < size.y - 10.0:
		var x := 14.0
		while x < size.x - 10.0:
			draw_line(Vector2(x, y), Vector2(x + 7.0, y - 7.0), Color(1, 1, 1, 0.022), 1.0, true)
			x += 34.0
		y += 34.0
	# Inner printed rule and corner brackets.
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(accent, 0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	draw_style_box(box, Rect2(Vector2(1, 1), size - Vector2(2, 2)))
	var length := 20.0
	var inset := 16.0
	var corners := [
		[Vector2(inset, inset), Vector2.RIGHT],
		[Vector2(inset, inset), Vector2.DOWN],
		[Vector2(size.x - inset, inset), Vector2.LEFT],
		[Vector2(size.x - inset, inset), Vector2.DOWN],
		[Vector2(inset, size.y - inset), Vector2.RIGHT],
		[Vector2(inset, size.y - inset), Vector2.UP],
		[Vector2(size.x - inset, size.y - inset), Vector2.LEFT],
		[Vector2(size.x - inset, size.y - inset), Vector2.UP]
	]
	for corner in corners:
		draw_line(corner[0], corner[0] + corner[1] * length, Color(accent, 0.42), 1.5, true)
	# Two title hairlines across the top.
	draw_line(Vector2(size.x * 0.06, 74), Vector2(size.x * 0.94, 74), Color(accent, 0.14), 1.0, true)
