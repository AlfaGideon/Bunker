extends PanelContainer
## The compact turn panel in the bottom-left corner.
##
## It replaces the tall right-hand menu: only the turn itself stays on screen —
## round, timer, who is speaking, the two special abilities and one adaptive
## action. The three-line menu button now lives here too.

const Cards = preload("res://game/scripts/card_style.gd")
const Abilities = preload("res://game/scripts/special_abilities.gd")

const PHASE_NAMES := {
	"reveal": "РАСКРЫТИЕ", "discussion": "ОБСУЖДЕНИЕ", "vote": "ГОЛОСОВАНИЕ",
	"result": "РЕЗУЛЬТАТ", "end": "ИТОГ"
}
const PANEL_WIDTH := 356.0

var room: Node3D
var timer_label: Label
var speaker_label: Label
var phase_label: Label
var status_label: Label
var bar: Control
var ability_buttons: Array[Button] = []
var action_button: Button
var menu_button: Button
var ratio := 1.0


func setup(game: Node3D) -> void:
	room = game
	custom_minimum_size = Vector2(PANEL_WIDTH, 214)
	size = Vector2(PANEL_WIDTH, 214)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 13)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	phase_label = _label("", 10, Color("c9a36a"))
	top.add_child(phase_label)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	status_label = _label("", 10, Color("8ea3a8"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(status_label)

	var clock := HBoxContainer.new()
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_theme_constant_override("separation", 10)
	column.add_child(clock)
	timer_label = _label("--", 34, Color("f2ead9"))
	timer_label.custom_minimum_size.x = 62
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_child(timer_label)
	var who := VBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_constant_override("separation", 1)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock.add_child(who)
	who.add_child(_label("ХОД", 9, Color("6f8b92")))
	speaker_label = _label("", 14, Color("dbe6e4"))
	speaker_label.clip_text = true
	speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(speaker_label)

	bar = Control.new()
	bar.custom_minimum_size.y = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	column.add_child(bar)

	var abilities := HBoxContainer.new()
	abilities.add_theme_constant_override("separation", 7)
	column.add_child(abilities)
	for slot in 2:
		var index: int = slot
		var button := _button("", func(): room.use_ability(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		abilities.add_child(button)
		ability_buttons.append(button)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 7)
	column.add_child(footer)
	menu_button = _button("☰", func(): room.menu.home())
	menu_button.custom_minimum_size = Vector2(52, 46)
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.tooltip_text = "Меню и пауза"
	footer.add_child(menu_button)
	action_button = _button("", _act)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(action_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 46
	node.add_theme_font_size_override("font_size", 14)
	node.pressed.connect(action)
	Cards.button(node, true)
	node.custom_minimum_size.y = 46
	node.add_theme_font_size_override("font_size", 14)
	return node


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.085, 0.10, 0.94)
	box.border_color = Color(0.30, 0.46, 0.48, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.border_width_left = 3
	box.shadow_color = Color(0, 0, 0, 0.34)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 5)
	return box


func _draw_bar() -> void:
	var width := bar.size.x
	var height := bar.size.y
	if width < 8.0 or height < 4.0:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.16, 0.18, 0.95)
	track.set_corner_radius_all(int(height * 0.5))
	bar.draw_style_box(track, Rect2(Vector2.ZERO, Vector2(width, height)))
	var filled: float = clampf(ratio, 0.0, 1.0) * width
	if filled < 2.0:
		return
	var accent := Color("c9a36a")
	if room != null and room.phase == "vote":
		accent = Color("e08b6a")
	elif room != null and room.phase == "discussion":
		accent = Color("8ecbff")
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(int(height * 0.5))
	fill.shadow_color = Color(accent, 0.45)
	fill.shadow_size = 4
	bar.draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(filled, height)))


func _act() -> void:
	if room == null:
		return
	match room.phase:
		"reveal":
			room.pass_speech()
		"discussion":
			room.start_vote()
		"result":
			room._advance()
		_:
			pass


func refresh() -> void:
	if room == null or room.players.is_empty() or not is_instance_valid(timer_label):
		return
	phase_label.text = "РАУНД %d  ·  %s" % [room.round_number,
		str(PHASE_NAMES.get(room.phase, str(room.phase).to_upper()))]
	status_label.text = "В БУНКЕРЕ %d / %d" % [room.active.size(), room.players.size()]
	for slot in ability_buttons.size():
		ability_buttons[slot].text = "%d  %s" % [slot + 1, Abilities.NAMES[room.abilities.cards[slot]]]
		ability_buttons[slot].text += " ·" if room.abilities.used[slot] else ""
		ability_buttons[slot].disabled = room.abilities.used[slot] or not room.active.has(0) or room.phase in ["vote", "end"]
	ratio = 0.0
	timer_label.text = "--"
	speaker_label.text = "Партия завершена" if room.finished else "Ожидание"
	action_button.disabled = false
	match room.phase:
		"reveal":
			var name := "—"
			var remaining: float = room.speech.remaining
			var who: int = room.speech.speaker()
			if who >= 0 and who < room.players.size():
				name = str(room.players[who]["name"])
			timer_label.text = str(ceili(remaining))
			ratio = remaining / 60.0
			speaker_label.text = ("Говорит: " if who >= 0 else "") + name
			action_button.text = "Передать ход →"
			action_button.disabled = room.finished
		"discussion":
			timer_label.text = str(ceili(room.discussion_remaining))
			ratio = room.discussion_remaining / 60.0
			speaker_label.text = "Общее обсуждение"
			action_button.text = "К голосованию →"
		"vote":
			timer_label.text = str(ceili(room.vote_remaining))
			ratio = room.vote_remaining / 20.0
			speaker_label.text = "Голосование"
			action_button.text = "Идёт голосование"
			action_button.disabled = true
		"result":
			speaker_label.text = "Раунд завершён"
			action_button.text = "Следующий раунд →"
		"end":
			speaker_label.text = "Партия завершена"
			action_button.text = "Итог партии"
			action_button.disabled = true
	timer_label.add_theme_color_override("font_color", Color("f2ead9") if ratio > 0.25 else Color("e89a7c"))
	if is_instance_valid(bar):
		bar.queue_redraw()
