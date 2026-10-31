extends Control
## The receiver itself: three numbered stations, a live feed of other bunkers
## and a hidden beacon that needs a radio specialist at the dial.
##
## There is no scrolling and no second page — every station fits on one card.

signal closed

const Cards = preload("res://game/scripts/card_style.gd")

var room: Node3D
var panel: PanelContainer
var column: VBoxContainer
var title_label: Label
var frequency_label: Label
var status_label: Label
var specialist_label: Label
var feed_label: Label
var hint_label: Label
var power_button: Button
var scan_button: Button
var station_buttons: Array[Button] = []
var signal_segments: Array[ColorRect] = []


func setup(game: Node3D) -> void:
	room = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.018, 0.024, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 604)
	panel.add_theme_stylebox_override("panel", _cabinet())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	panel.add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	title_label = _label("РАДИОПРИЁМНИК", 24, Color("f2ead9"))
	head.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	frequency_label = _label("", 13, Color("c9a36a"))
	head.add_child(frequency_label)

	var dial := HBoxContainer.new()
	dial.add_theme_constant_override("separation", 4)
	dial.custom_minimum_size.y = 12
	column.add_child(dial)
	for step in 24:
		var segment := ColorRect.new()
		segment.color = Color("274c5b")
		segment.custom_minimum_size = Vector2(16, 8)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dial.add_child(segment)
		signal_segments.append(segment)

	status_label = _label("ВЫКЛЮЧЕНО", 16, Color("7fe3b0"))
	column.add_child(status_label)
	specialist_label = _label("", 13, Color("8ea3a8"))
	column.add_child(specialist_label)

	for slot in 3:
		var index: int = slot
		var button := Button.new()
		button.custom_minimum_size.y = 74
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		Cards.button(button, true)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func(): _tune(index))
		column.add_child(button)
		station_buttons.append(button)

	var feed_frame := PanelContainer.new()
	feed_frame.add_theme_stylebox_override("panel", Cards.panel())
	column.add_child(feed_frame)
	var feed_margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		feed_margin.add_theme_constant_override("margin_" + edge, 10)
	feed_frame.add_child(feed_margin)
	var feed_column := VBoxContainer.new()
	feed_column.add_theme_constant_override("separation", 4)
	feed_margin.add_child(feed_column)
	feed_column.add_child(_label("ЭФИР", 11, Color("c9a36a")))
	feed_label = _label("Пока тишина.", 13, Color("dbe6e4"))
	feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed_label.max_lines_visible = 4
	feed_label.custom_minimum_size.y = 78
	feed_column.add_child(feed_label)

	hint_label = _label("", 12, Color("8ea3a8"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	power_button = _button("ВКЛЮЧИТЬ РАДИО", _toggle_power)
	power_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(power_button)
	scan_button = _button("СКАНИРОВАТЬ 1180", _scan)
	scan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(scan_button)
	var back := _button("ВЕРНУТЬСЯ В ИГРУ", close)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 48)
	Cards.button(close_button, true)
	add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -78
	close_button.offset_right = -22
	close_button.offset_top = 20
	close_button.offset_bottom = 68
	close_button.pressed.connect(close)


func _label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.add_theme_font_size_override("font_size", 14)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.clip_text = true
	Cards.button(node, true)
	node.add_theme_font_size_override("font_size", 14)
	node.pressed.connect(action)
	return node


func _cabinet() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0c2b31")
	box.border_color = Color("5a9790")
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 18
	return box


func open() -> void:
	visible = true
	refresh()
	Cards.animate(self)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _tune(index: int) -> void:
	if room == null or room.radio == null:
		return
	var entry: Dictionary = room.radio.station_list[index]
	var station_id: String = str(entry.get("id", ""))
	if not room.radio.tunes_all(station_id) and not room.can_scan_radio():
		room.log_label.text = "Маяк 1180 слушает только специалист: связист или радиотехник."
		refresh()
		return
	var active: bool = room.radio.powered and room.radio.station == station_id
	if active and str(entry.get("kind", "")) == "music":
		# A second tap on the music station changes the record.
		room.radio.next_track()
		room.apply_radio_audio()
		room.log_label.text = "Пластинка: " + room.radio.track_title() + " · " + room.radio.track_mood() + "."
		refresh()
		return
	room.radio.tune(station_id)
	room.apply_radio_audio()
	if str(entry.get("kind", "")) == "music":
		room.log_label.text = "Радио: " + str(entry.get("name", "")) + " — " + room.radio.track_title() + "."
	else:
		room.log_label.text = "Радио настроено: " + str(entry.get("name", "")) + " — " + str(entry.get("subtitle", "")) + "."
	refresh()


func _toggle_power() -> void:
	if room == null or room.radio == null:
		return
	if room.radio.powered:
		room.radio.power(false)
		room.log_label.text = "Радио выключено."
	else:
		room.radio.power(true)
		room.log_label.text = "Радио включено. Настройтесь на станцию."
	room.apply_radio_audio()
	refresh()


func _scan() -> void:
	if room == null:
		return
	if not room.scan_radio():
		refresh()
		return
	refresh()


func refresh() -> void:
	if room == null or room.radio == null:
		return
	var receiver: RefCounted = room.radio
	status_label.text = receiver.status_text()
	status_label.add_theme_color_override("font_color", Color("7fe3b0") if receiver.powered else Color("8ea3a8"))
	power_button.text = "ВЫКЛЮЧИТЬ РАДИО" if receiver.powered else "ВКЛЮЧИТЬ РАДИО"

	frequency_label.text = receiver.frequency

	var specialist: bool = room.can_scan_radio()
	var operator_name: String = room.radio_operator_name()
	specialist_label.text = ("За приёмником: " + operator_name) if specialist else "Специалиста по связи в бункере нет."
	specialist_label.add_theme_color_override("font_color", Color("c9a36a") if specialist else Color("a97f6a"))

	for index in station_buttons.size():
		var entry: Dictionary = receiver.station_list[index]
		var button: Button = station_buttons[index]
		var station_id := str(entry.get("id", ""))
		var locked: bool = not receiver.tunes_all(station_id) and not specialist
		var active: bool = receiver.powered and receiver.station == station_id
		button.disabled = locked
		var subtitle := str(entry.get("subtitle", ""))
		if str(entry.get("kind", "")) == "music":
			subtitle = receiver.track_title() + " · " + receiver.track_mood()
		button.text = ("●  " if active else "○  ") + str(entry.get("number", "")) + "   " + str(entry.get("name", "")) + "   ·   " + subtitle
		button.tooltip_text = str(entry.get("note", ""))

	var lines: Array = receiver.feed_lines(4)
	if lines.is_empty():
		feed_label.text = "Пока тишина. Другие бункеры выходят в эфир не сразу."
	else:
		var text: String = ""
		for line in lines:
			text += ("\n" if not text.is_empty() else "") + str(line)
		feed_label.text = text

	var kind: String = receiver.kind()
	scan_button.disabled = kind != "signal" or not specialist or receiver.scans_left() == 0 or receiver.scan_round == room.round_number
	if kind != "signal":
		hint_label.text = "Сканирование 1180 доступно на третьей станции. Маяк разбирает только связист или радиотехник."
	elif receiver.scans_left() == 0:
		hint_label.text = "Все передачи маяка прочитаны."
	elif not specialist:
		hint_label.text = "На маяке нужен связист или радиотехник — сейчас такого специалиста в бункере нет."
	elif receiver.scan_round == room.round_number:
		hint_label.text = "В этом раунде маяк уже прочитан. Вернитесь в следующем."
	else:
		hint_label.text = "Сканирование вслепую: одна передача за раунд, всего %d." % receiver.scans_left()
	if kind == "music":
		hint_label.text = "Повторное касание первой станции меняет пластинку — всего %d записей." % receiver.track_count()

	var strength: int = receiver.signal_strength() + (4 if specialist and kind == "signal" else 0)
	for index in signal_segments.size():
		var lit: bool = index < strength * 3
		signal_segments[index].color = Color("c9a36a") if lit else Color("274c5b")
