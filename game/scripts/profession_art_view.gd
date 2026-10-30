extends Control
## Portrait profession illustration for the card back.
##
## Each profession group has a generated vertical painting of a faceless
## mannequin in profession gear. The image is cropped like a printed card,
## then scrimmed at the top and bottom so the name and caption always read.
## The small header badge shows a square cameo of the same illustration.

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
	var texture := Art.texture_for(profession)
	if compact:
		_draw_cameo(texture, look)
		return
	var full := Rect2(Vector2.ZERO, size)
	if texture != null:
		Art.draw_cover(self, texture, full)
		draw_rect(full, Color(look["deep"], 0.12))
	else:
		Art.draw_background(self, full, look)
	# Darkness is a designed part of the card: the title block sits over it.
	var top_band := size.y * 0.15
	var top_steps := 8
	for i in top_steps:
		var t := float(i) / float(top_steps)
		draw_rect(Rect2(0, top_band * t, size.x, top_band / float(top_steps) + 1.5),
			Color(0.01, 0.025, 0.03, 0.42 * (1.0 - t)))
	var title_band := size.y * 0.48
	var band_height := size.y - title_band
	var steps := 24
	for i in steps:
		var t := float(i) / float(steps - 1)
		var alpha := 0.04 + 0.78 * pow(t, 1.5)
		draw_rect(Rect2(0, title_band + band_height * t, size.x, band_height / float(steps) + 1.5),
			Color(0.008, 0.025, 0.03, alpha))
	# Side vignette keeps the eye on the figure and the printed frame.
	var side := 12
	for i in side:
		var t := float(i) / float(side)
		var band_width := size.x * 0.10
		draw_rect(Rect2(band_width * t, 0, band_width / float(side) + 1.5, size.y),
			Color(0, 0, 0, 0.16 * (1.0 - t)))
		draw_rect(Rect2(size.x - band_width * (t + 1.0 / float(side)), 0,
			band_width / float(side) + 1.5, size.y), Color(0, 0, 0, 0.16 * (1.0 - t)))
	Art.draw_frame(self, Rect2(Vector2(8, 8), size - Vector2(16, 16)), accent, 0.50)
	draw_line(Vector2(size.x * 0.22, size.y * 0.775), Vector2(size.x * 0.78, size.y * 0.775),
		Color(accent, 0.34), 1.0, true)
	draw_line(Vector2(size.x * 0.34, size.y * 0.783), Vector2(size.x * 0.66, size.y * 0.783),
		Color(accent, 0.18), 1.0, true)


func _draw_cameo(texture: Texture2D, look: Dictionary) -> void:
	var accent: Color = look["accent"]
	var box := Rect2(Vector2.ZERO, size)
	if texture != null:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var region_side := minf(texture_size.x * 0.68, texture_size.y * 0.42)
			var region := Rect2((texture_size.x - region_side) * 0.5,
				texture_size.y * 0.14, region_side, region_side)
			draw_texture_rect_region(texture, box, region)
			draw_rect(box, Color(0.01, 0.03, 0.035, 0.20))
			var border := StyleBoxFlat.new()
			border.bg_color = Color.TRANSPARENT
			border.border_color = Color(accent, 0.85)
			border.set_border_width_all(1)
			border.set_corner_radius_all(maxi(2, int(minf(size.x, size.y) * 0.16)))
			draw_style_box(border, box)
			return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center, radius, Color(accent, 0.10))
	draw_arc(center, radius * 0.92, 0, TAU, 40, Color(accent, 0.55), 1.2, true)
	Art.draw_icon(self, center, radius * 0.58, str(look["icon"]), accent.lightened(0.32), maxf(1.4, radius * 0.13))
