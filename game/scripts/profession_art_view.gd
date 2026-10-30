extends Control
## Card-back illustration and the small emblem used in the dossier header.

const Art = preload("res://game/scripts/profession_art.gd")

var profession := ""
var compact: bool = false:
	set(value):
		compact = value
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_profession(value: String) -> void:
	if profession == value:
		return
	profession = value
	queue_redraw()


func _draw() -> void:
	if size.x < 6.0 or size.y < 6.0:
		return
	var look := Art.style(profession)
	var accent: Color = look["accent"]
	if compact:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(center, radius, Color(accent, 0.10))
		draw_arc(center, radius * 0.92, 0, TAU, 40, Color(accent, 0.55), 1.2, true)
		Art.draw_icon(self, center, radius * 0.58, str(look["icon"]), accent.lightened(0.32), maxf(1.4, radius * 0.13))
		return
	Art.draw_background(self, Rect2(Vector2.ZERO, size), look)
	Art.draw_frame(self, Rect2(Vector2(9, 9), size - Vector2(18, 18)), accent)
	var center := Vector2(size.x * 0.5, size.y * 0.40)
	var radius := minf(size.x * 0.30, size.y * 0.215)
	Art.draw_emblem(self, center, radius, look)
	# Thin horizon accents echo the printed frame of a physical card.
	draw_line(Vector2(size.x * 0.16, size.y * 0.735), Vector2(size.x * 0.84, size.y * 0.735),
		Color(accent, 0.30), 1.0, true)
	draw_line(Vector2(size.x * 0.28, size.y * 0.748), Vector2(size.x * 0.72, size.y * 0.748),
		Color(accent, 0.16), 1.0, true)
