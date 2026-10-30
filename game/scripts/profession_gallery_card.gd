extends Control
## One profession in the main-menu library catalogue.
##
## The tile is a plain Control instead of a Button on purpose: the library deck
## keeps a fixed row height, and a Button would be re-measured from its text and
## crop the portrait. Everything here is drawn, so the picture always fits.

signal pressed

const Art = preload("res://game/scripts/profession_art.gd")

var profession := ""
var hovered := false


func _init() -> void:
	custom_minimum_size = Vector2(0, 124)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	visibility_changed.connect(func(): queue_redraw())
	resized.connect(queue_redraw)


func setup(value: String) -> void:
	profession = value
	tooltip_text = value
	queue_redraw()


func _set_hover(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		grab_focus()
		pressed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		pressed.emit()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		accept_event()
		pressed.emit()


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var look := Art.style(profession)
	var accent: Color = look["accent"]
	var deep: Color = look["deep"]
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1b3b47") if hovered else Color("142f3b")
	frame.border_color = Color(accent, 0.85 if hovered else 0.32)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(12)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var thumb_width := clampf(size.x * 0.30, 58.0, 88.0)
	var thumb := Rect2(7, 7, thumb_width, size.y - 14)
	var texture := Art.texture_for(profession)
	if texture != null:
		Art.draw_cover(self, texture, thumb)
		draw_rect(thumb, Color(deep, 0.22))
	else:
		Art.draw_background(self, thumb, look)
	draw_rect(thumb, Color(accent, 0.50 if hovered else 0.28), false, 1.0)
	var font := get_theme_font("font")
	var left := thumb.end.x + 12.0
	var text_width := maxf(24.0, size.x - left - 10.0)
	var title_size := 17 if size.y >= 118.0 else 16
	draw_string(font, Vector2(left, size.y * 0.42), profession, HORIZONTAL_ALIGNMENT_LEFT,
		text_width, title_size, Color("eef2e9"))
	draw_string(font, Vector2(left, size.y * 0.63), str(look["tag"]), HORIZONTAL_ALIGNMENT_LEFT,
		text_width, 11, Color(accent, 0.92))
	draw_string(font, Vector2(left, size.y * 0.81), "ПОРТРЕТ • 768 × 1152", HORIZONTAL_ALIGNMENT_LEFT,
		text_width, 10, Color("7f979d"))
	if has_focus():
		Art.draw_frame(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)), accent, 0.85)
