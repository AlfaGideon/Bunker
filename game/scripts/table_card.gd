extends Control
## The single dossier card that lives on the table during a game.
##
## The old right-hand menu is gone: this vertical playing card follows the
## survivor you tapped, starts on the profession portrait and flips in place to
## the six parameters. The card of whoever is speaking right now glows.

signal expand_requested

const Art = preload("res://game/scripts/profession_art.gd")
const ArtView = preload("res://game/scripts/profession_art_view.gd")
const Cards = preload("res://game/scripts/card_style.gd")

const CARD_SIZE := Vector2(340, 500)
const PARAMETER_ORDER := ["biology", "health", "quality", "skill", "baggage", "fact"]
const PARAMETER_TITLE := {
	"biology": "Биология", "health": "Здоровье", "quality": "Характер",
	"skill": "Увлечение", "baggage": "Багаж", "fact": "Факт"
}
const PHASE_NAMES := {
	"reveal": "РАСКРЫТИЕ", "discussion": "ОБСУЖДЕНИЕ", "vote": "ГОЛОСОВАНИЕ",
	"result": "РЕЗУЛЬТАТ", "end": "ИТОГ"
}

var room: Node3D
var index := 0
var showing_back := true
var flipping := false
var pulse := 0.0

var card_root: Control
var frame: PanelContainer
var surface: Control
var front: Control
var back: Control
var art_view
var badge: PanelContainer
var badge_label: Label
var flip_button: Button
var open_button: Button
var flip_tween: Tween

var back_profession: Label
var back_tag: Label
var back_name: Label
var back_number: Label
var front_name: Label
var front_role: Label
var front_meta: Label
var rows: Array = []
var hint: Label


func setup(room_node: Node3D) -> void:
	room = room_node
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(func(): queue_redraw())


func _build() -> void:
	card_root = Control.new()
	card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(card_root)

	frame = PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _frame_style(Color("c9a36a"), false))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_card_input)
	card_root.add_child(frame)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	surface = Control.new()
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.clip_contents = true
	column.add_child(surface)
	surface.resized.connect(func(): surface.pivot_offset = surface.size * 0.5)

	_build_back()
	_build_front()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	flip_button = _footer_button("ОБОРОТ")
	footer.add_child(flip_button)
	flip_button.tooltip_text = "Перевернуть карточку: профессия ↔ параметры"
	flip_button.pressed.connect(func(): set_side(not showing_back))
	open_button = _footer_button("ОТКРЫТЬ")
	footer.add_child(open_button)
	open_button.tooltip_text = "Полная карточка с раскрытием параметров"
	open_button.pressed.connect(func(): expand_requested.emit())

	badge = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.02, 0.06, 0.07, 0.92)
	badge_style.border_color = Color("f0d9a6")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(9)
	badge_style.content_margin_left = 9
	badge_style.content_margin_right = 9
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	badge_label = _label("● ГОВОРИТ", 10, Color("f3e3bd"))
	badge.add_child(badge_label)
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	badge.offset_left = -58
	badge.offset_right = 58
	badge.offset_top = -29
	badge.offset_bottom = -3
	badge.visible = false
	card_root.add_child(badge)


func _footer_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	Cards.button(button, true)
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 12)
	return button


func _build_back() -> void:
	back = Control.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(back)
	art_view = ArtView.new()
	art_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.add_child(art_view)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	back.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(_label("БУНКЕР · ДОСЬЕ", 9, Color("d9b06e")))
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	back_number = _label("", 9, Color("93a8ad"))
	top.add_child(back_number)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	back_profession = _label("", 26, Color("f6efdd"))
	back_profession.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_profession.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(back_profession)
	back_tag = _label("", 9, Color("c9a36a"))
	back_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(back_tag)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	back_name = _label("", 12, Color("c9d5d6"))
	bottom.add_child(back_name)
	var bottom_gap := Control.new()
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_gap)
	bottom.add_child(_label("ПАРАМЕТРЫ ⇄", 8, Color("8ea3a8")))


func _build_front() -> void:
	front = PanelContainer.new()
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.visible = false
	front.add_theme_stylebox_override("panel", _surface_style())
	surface.add_child(front)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + state, 12)
	front.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	front_name = _label("", 16, Color("f2ead9"))
	front_name.clip_text = true
	front_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(front_name)
	front_role = _label("", 9, Color("8ea3a8"))
	column.add_child(front_role)
	front_meta = _label("", 9, Color("c9a36a"))
	front_meta.clip_text = true
	front_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(front_meta)
	var rule := ColorRect.new()
	rule.color = Color(0.788, 0.639, 0.416, 0.26)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", 2)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list)
	for slot in PARAMETER_ORDER.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_child(row)
		var number := _label("%02d" % (slot + 1), 9, Color("c9a36a"))
		number.custom_minimum_size.x = 16
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(number)
		var body := VBoxContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_theme_constant_override("separation", 0)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(body)
		var title := _label("", 8, Color("93a8ad"))
		body.add_child(title)
		var value := _label("", 11, Color("eef4ec"))
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.max_lines_visible = 2
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(value)
		var state_dot := _label("●", 8, Color("70858d"))
		state_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state_dot)
		rows.append({"number": number, "title": title, "value": value, "dot": state_dot})
	var legend := HBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 5)
	column.add_child(legend)
	for pair in [[Color("7fe3b0"), "ВСЕМ"], [Color("f0b45f"), "ВАМ"], [Color("70858d"), "СКРЫТО"]]:
		var dot := _label("●", 7, pair[0])
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(dot)
		var caption := _label(pair[1], 8, Color("8ea3a8"))
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(caption)
	hint = _label("", 8, Color("b9a27a"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(hint)


# ------------------------------------------------------------------ builders

func _label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _frame_style(accent: Color, lit: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("071418")
	box.border_color = accent if lit else Color(accent, 0.45)
	box.set_border_width_all(2)
	box.set_corner_radius_all(20)
	for side in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + side, 8)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 7)
	return box


func _surface_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1d23")
	box.set_corner_radius_all(14)
	return box


# --------------------------------------------------------------------- state

func _profession_of(player: Dictionary) -> String:
	for card in player["cards"]:
		if str(card.get("id", "")) == "profession":
			return str(card["value"])
	return ""


func _card_of(player: Dictionary, parameter_id: String) -> Dictionary:
	for card in player["cards"]:
		if str(card.get("id", "")) == parameter_id:
			return card
	return {}


func can_view(owner: int, card: Dictionary) -> bool:
	if room == null:
		return false
	if owner == 0 or bool(card.get("revealed", false)):
		return true
	return room.finished or room.phase == "end"


func state_for(owner: int, card: Dictionary) -> String:
	if not can_view(owner, card):
		return "hidden"
	if owner == 0 and not bool(card.get("revealed", false)):
		return "own"
	return "open"


func visible_value(owner: int, card: Dictionary) -> String:
	return str(card.get("value", "")) if can_view(owner, card) else "••••"


func speaker() -> int:
	if room == null or room.speech == null:
		return -1
	return int(room.speech.speaker())


func is_speaker() -> bool:
	if room == null or room.phase != "reveal":
		return false
	return speaker() == index and room.active.has(index)


# -------------------------------------------------------------------- update

func show_for(player_index: int, animate: bool = true, keep_side: bool = true) -> void:
	if not is_instance_valid(room) or room.players.is_empty():
		return
	index = clampi(player_index, 0, room.players.size() - 1)
	if not keep_side:
		showing_back = true
		flipping = false
		if is_instance_valid(flip_tween):
			flip_tween.kill()
		if is_instance_valid(surface):
			surface.scale = Vector2.ONE
	visible = true
	refresh()
	_apply_side()
	if animate and not room.profile.reduced_motion:
		card_root.modulate.a = 0.35
		create_tween().tween_property(card_root, "modulate:a", 1.0, 0.16)


func set_side(back_side: bool, animate: bool = true) -> void:
	if room == null or flipping:
		return
	if back_side == showing_back:
		_apply_side()
		return
	if not animate or room.profile.reduced_motion:
		showing_back = back_side
		_apply_side()
		return
	flipping = true
	if is_instance_valid(flip_tween):
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(surface, "scale:x", 0.04, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		showing_back = back_side
		_apply_side())
	flip_tween.tween_property(surface, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_callback(func(): flipping = false)


func _apply_side() -> void:
	if is_instance_valid(front):
		front.visible = not showing_back
	if is_instance_valid(back):
		back.visible = showing_back
	if is_instance_valid(flip_button):
		flip_button.text = "ПАРАМЕТРЫ" if showing_back else "ОБОРОТ"


func refresh() -> void:
	if not is_instance_valid(room) or room.players.is_empty():
		return
	index = clampi(index, 0, room.players.size() - 1)
	var player: Dictionary = room.players[index]
	var profession := _profession_of(player)
	var look := Art.style(profession)
	var accent: Color = look["accent"]
	var alive: bool = room.active.has(index)
	var lit := is_speaker()
	frame.add_theme_stylebox_override("panel", _frame_style(accent, lit))
	badge.visible = lit
	if lit:
		badge_label.text = "●  ГОВОРИТ"
	badge_label.add_theme_color_override("font_color", accent.lightened(0.35))
	art_view.set_profession(profession)
	back_profession.text = profession
	var title_size := 26
	if profession.length() > 20:
		title_size = 19
	elif profession.length() > 14:
		title_size = 22
	back_profession.add_theme_font_size_override("font_size", title_size)
	back_tag.text = str(look["tag"])
	back_name.text = str(player["name"]) + ("  ·  вы" if index == 0 else "")
	back_number.text = "%02d / %02d" % [index + 1, room.players.size()]
	front_name.text = str(player["name"]) + ("  ·  ВЫ" if index == 0 else "")
	front_name.add_theme_color_override("font_color", Color("f2ead9") if alive else Color("d98b7f"))
	front_role.text = ("В БУНКЕРЕ" if alive else "НАБЛЮДАТЕЛЬ") + ("  ·  ГОВОРИТ" if lit else "")
	front_role.add_theme_color_override("font_color", accent if lit else Color("8ea3a8"))
	front_meta.text = (profession + "  ·  РАУНД %d  ·  %s" % [room.round_number,
		str(PHASE_NAMES.get(room.phase, str(room.phase).to_upper()))]).to_upper()
	var slot := 0
	for parameter_id in PARAMETER_ORDER:
		var card := _card_of(player, parameter_id)
		var row: Dictionary = rows[slot]
		slot += 1
		if card.is_empty():
			row["number"].text = "--"
			row["title"].text = str(PARAMETER_TITLE.get(parameter_id, "")).to_upper()
			row["value"].text = "нет данных"
			row["dot"].add_theme_color_override("font_color", Color("70858d"))
			continue
		var state := state_for(index, card)
		row["title"].text = str(PARAMETER_TITLE.get(parameter_id, card["label"])).to_upper()
		row["value"].text = visible_value(index, card)
		row["value"].add_theme_color_override("font_color", _value_color(state))
		row["dot"].add_theme_color_override("font_color", _state_color(state))
	hint.text = "ГОВОРИТ" if lit else ""


func _state_color(state: String) -> Color:
	match state:
		"open":
			return Color("7fe3b0")
		"own":
			return Color("f0b45f")
		_:
			return Color("70858d")


func _value_color(state: String) -> Color:
	match state:
		"open":
			return Color("eef4ec")
		"own":
			return Color("f7e7c7")
		_:
			return Color("5f737b")


# --------------------------------------------------------------------- input

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		set_side(not showing_back)
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		set_side(not showing_back)


func _draw() -> void:
	if room == null or room.players.is_empty() or not is_speaker():
		return
	var accent: Color = Art.style(_profession_of(room.players[index]))["accent"]
	var alpha := 0.42
	if not room.profile.reduced_motion:
		alpha = 0.32 + 0.14 * sin(pulse)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(accent, alpha)
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	box.shadow_color = Color(accent, alpha * 0.45)
	box.shadow_size = 14
	draw_style_box(box, Rect2(Vector2(-5, -5), size + Vector2(10, 10)))


func _process(delta: float) -> void:
	if room == null or room.profile.reduced_motion or not is_speaker():
		return
	pulse += delta * 3.2
	queue_redraw()
