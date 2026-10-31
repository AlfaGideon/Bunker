extends PanelContainer
## One parameter on the face-up character card. No scrolling: the whole card
## is a fixed grid of six tiles, each tile carries its own reveal state.

signal reveal_requested(id: String)

const Art = preload("res://game/scripts/profession_art.gd")
const RevealLock = preload("res://game/scripts/reveal_lock.gd")

var parameter_id := ""
var title_text := ""
var value_text := ""
var note_text := ""
var state := "hidden"
var icon := "note"
var accent := Color("c9a36a")
var number := 0
var revealable := false

var value_label: Label
var note_label: Label
var state_label: Label
var title_label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = Vector2(0, 140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(data: Dictionary) -> void:
	parameter_id = str(data.get("id", ""))
	title_text = str(data.get("title", ""))
	value_text = str(data.get("value", ""))
	note_text = str(data.get("note", ""))
	state = str(data.get("state", "hidden"))
	icon = str(data.get("icon", "note"))
	accent = data.get("accent", Color("c9a36a"))
	number = int(data.get("number", 0))
	revealable = bool(data.get("revealable", false))
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 7)
	column.add_child(head)
	var number_label := Label.new()
	number_label.text = "%02d" % number
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override("font_color", Color(accent, 0.75))
	head.add_child(number_label)
	title_label = Label.new()
	title_label.text = title_text.to_upper()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("a9bdc4"))
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	state_label = Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.text = _state_caption()
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", _state_color())
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(state_label)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	value_label = Label.new()
	value_label.text = value_text
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.max_lines_visible = 3
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", _value_font_size())
	value_label.add_theme_color_override("font_color", _value_color())
	body.add_child(value_label)
	note_label = Label.new()
	note_label.text = note_text
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note_label.add_theme_font_size_override("font_size", 12)
	note_label.add_theme_color_override("font_color", Color("a9bec5"))
	if not revealable:
		column.add_child(note_label)
		return
	# The lock sits in the footer row, so long values keep the full tile width
	# instead of breaking words against a lock-sized gutter.
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 8)
	column.add_child(foot)
	foot.add_child(note_label)
	var lock = RevealLock.new()
	lock.is_public = false
	lock.parameter_id = parameter_id
	if lock.has_meta("parameter_lock"):
		lock.remove_meta("parameter_lock")
	lock.tooltip_text = "Раскрыть «" + title_text + "» всем участникам"
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.pressed.connect(func(): reveal_requested.emit(parameter_id))
	foot.add_child(lock)


func _value_font_size() -> int:
	if state == "hidden":
		return 20
	if value_text.length() > 90:
		return 14
	if value_text.length() > 55:
		return 15
	if value_text.length() > 34:
		return 16
	return 17


func _state_caption() -> String:
	match state:
		"open":
			return "ОТКРЫТО"
		"own":
			return "ВАМ"
		_:
			return "СКРЫТО"


func _state_color() -> Color:
	match state:
		"open":
			return Color("7fe3b0")
		"own":
			return Color("f0b45f")
		_:
			return Color("70858d")


func _value_color() -> Color:
	match state:
		"open":
			return Color("eef4ec")
		"own":
			return Color("f7e7c7")
		_:
			return Color("5f737b")


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = _background_color()
	box.border_color = _border_color()
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(16, 0, maxf(0.0, size.x - 32), 2), Color(_state_color(), 0.65), true)
	draw_rect(Rect2(0, 18, 3, maxf(0.0, size.y - 36)), Color(accent, 0.70), true)
	# A faint watermark keeps every tile recognisable without reading it; the
	# reveal lock replaces it in the footer of an owner's tile.
	if not revealable:
		Art.draw_icon(self, Vector2(size.x - 32, size.y - 30), 18.0, icon, Color(accent, 0.12), 1.6)
	if state == "hidden":
		var y := 42.0
		while y < size.y - 30.0:
			var x := 14.0
			while x < size.x - 14.0:
				draw_line(Vector2(x, y), Vector2(x + 9, y - 9), Color(1, 1, 1, 0.035), 1.0, true)
				x += 23.0
			y += 21.0
		Art.draw_lock(self, Vector2(size.x - 45, size.y * 0.57), 26.0, Color("6b818a"))


func _background_color() -> Color:
	match state:
		"open":
			return Color("102b31")
		"own":
			return Color("1b2a22")
		_:
			return Color("0a1a20")


func _border_color() -> Color:
	match state:
		"open":
			return Color("36565d")
		"own":
			return Color("536e4a")
		_:
			return Color("203940")
