extends Control
## Full-screen collectible-style character card.
##
## A tap on a survivor (or on their name in the side roster) opens a single
## vertical card: its face is a fixed six-tile grid of characteristics, its
## back is a generated portrait of a faceless mannequin in profession gear.
## Nothing scrolls and nothing is paginated — every parameter is on the face,
## hidden ones stay masked until the rules open them.

signal closed
signal player_changed(index: int)
signal reveal_requested(id: String)

const Art = preload("res://game/scripts/profession_art.gd")
const ArtView = preload("res://game/scripts/profession_art_view.gd")
const Tile = preload("res://game/scripts/character_card_tile.gd")
const Backdrop = preload("res://game/scripts/card_backdrop.gd")
const Cards = preload("res://game/scripts/card_style.gd")
const Supplies = preload("res://game/scripts/group_supplies.gd")

const CARD_SIZE := Vector2(520, 780)
const PARAMETER_ORDER := ["biology", "health", "quality", "skill", "baggage", "fact"]
const PARAMETER_TITLE := {
	"biology": "Биология", "health": "Здоровье", "quality": "Характер",
	"skill": "Увлечение", "baggage": "Багаж", "fact": "Факт"
}
const PARAMETER_SUBTITLE := {
	"biology": "Пол и возраст",
	"health": "Медицинская нагрузка",
	"quality": "Черты характера",
	"skill": "Практическое умение",
	"baggage": "Что взято с собой",
	"fact": "Дополнительная деталь"
}
const PHASE_NAMES := {
	"reveal": "РАСКРЫТИЕ", "discussion": "ОБСУЖДЕНИЕ", "vote": "ГОЛОСОВАНИЕ",
	"result": "РЕЗУЛЬТАТ", "end": "ИТОГ ПАРТИИ"
}

var room: Node3D
var index := 0
var showing_back := false
var flipping := false

var card_root: Control
var frame: PanelContainer
var surface: Control
var front: PanelContainer
var back: Control
var front_backdrop
var mini_art
var art_view
var flip_tween: Tween

var name_label: Label
var profession_label: Label
var phase_label: Label
var count_label: Label
var flip_button: Button
var close_button: Button
var prev_button: Button
var next_button: Button
var nav_label: Label
var grid: GridContainer
var tiles: Array = []

var back_brand: Label
var back_number: Label
var back_profession: Label
var back_tag: Label
var back_name: Label
var back_hint: Label


func setup(room_node: Node3D) -> void:
	room = room_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.018, 0.024, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	card_root = Control.new()
	card_root.size = CARD_SIZE
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card_root)

	frame = PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _frame_style())
	card_root.add_child(frame)

	surface = Control.new()
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(surface)
	surface.resized.connect(func(): surface.pivot_offset = surface.size * 0.5)

	_build_front()
	_build_back()

	flip_button = _action_button("Оборот", 100, 36)
	flip_button.add_theme_font_size_override("font_size", 12)
	flip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	flip_button.offset_left = -168
	flip_button.offset_right = -64
	flip_button.offset_top = 12
	flip_button.offset_bottom = 48
	flip_button.tooltip_text = "Перевернуть карточку"
	flip_button.pressed.connect(func(): set_side(not showing_back))
	card_root.add_child(flip_button)

	close_button = _action_button("×", 36, 36)
	close_button.add_theme_font_size_override("font_size", 15)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -58
	close_button.offset_right = -22
	close_button.offset_top = 12
	close_button.offset_bottom = 48
	close_button.tooltip_text = "Закрыть карточку"
	close_button.pressed.connect(close)
	card_root.add_child(close_button)


func _build_front() -> void:
	front = PanelContainer.new()
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_STOP
	front.add_theme_stylebox_override("panel", _surface_style())
	surface.add_child(front)

	front_backdrop = Backdrop.new()
	front_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.add_child(front_backdrop)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	front.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := VBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 3)
	header.custom_minimum_size.y = 58
	column.add_child(header)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 9)
	header.add_child(top)
	mini_art = ArtView.new()
	mini_art.compact = true
	mini_art.custom_minimum_size = Vector2(42, 42)
	mini_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(mini_art)
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_theme_constant_override("separation", 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(identity)
	name_label = _label("", 22, Color("f2ead9"))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(name_label)
	profession_label = _label("", 11, Color("c9a36a"))
	profession_label.clip_text = true
	profession_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(profession_label)
	var reserve := Control.new()
	reserve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reserve.custom_minimum_size.x = 160
	top.add_child(reserve)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 8)
	header.add_child(meta)
	phase_label = _label("", 10, Color("b9cdd2"))
	meta.add_child(phase_label)
	var meta_gap := Control.new()
	meta_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(meta_gap)
	count_label = _label("", 10, Color("d9b06e"))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(count_label)

	var rule := ColorRect.new()
	rule.color = Color(0.788, 0.639, 0.416, 0.28)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)

	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 3)
	footer.custom_minimum_size.y = 52
	column.add_child(footer)
	var nav := HBoxContainer.new()
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_theme_constant_override("separation", 6)
	footer.add_child(nav)
	prev_button = _nav_button("‹", func(): step(-1))
	nav.add_child(prev_button)
	nav_label = _label("", 12, Color("d6c6a6"))
	nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_label.clip_text = true
	nav_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nav.add_child(nav_label)
	next_button = _nav_button("›", func(): step(1))
	nav.add_child(next_button)
	var legend := HBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 8)
	footer.add_child(legend)
	_add_legend(legend, Color("7fe3b0"), "ОТКРЫТО ВСЕМ")
	_add_legend(legend, Color("f0b45f"), "ВИДНО ТОЛЬКО ВАМ")
	_add_legend(legend, Color("70858d"), "СКРЫТО")


func _build_back() -> void:
	back = Control.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.visible = false
	back.gui_input.connect(_on_back_input)
	surface.add_child(back)
	art_view = ArtView.new()
	art_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.add_child(art_view)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	back.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	back_brand = _label("БУНКЕР · ДОСЬЕ", 10, Color("d9b06e"))
	top.add_child(back_brand)
	back_number = _label("", 10, Color("93a8ad"))
	top.add_child(back_number)
	var top_gap := Control.new()
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_gap)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	back_profession = _label("", 32, Color("f6efdd"))
	back_profession.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_profession.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(back_profession)
	back_tag = _label("", 10, Color("c9a36a"))
	back_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(back_tag)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	back_name = _label("", 13, Color("c9d5d6"))
	bottom.add_child(back_name)
	var bottom_gap := Control.new()
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_gap.custom_minimum_size.x = 14
	bottom.add_child(bottom_gap)
	back_hint = _label("ОБОРОТ — ПАРАМЕТРЫ", 9, Color("8ea3a8"))
	bottom.add_child(back_hint)


# ------------------------------------------------------------------ builders

func _label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _chip(content: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1a20")
	style.border_color = Color("2d4a52")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _nav_button(glyph: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(36, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Cards.button(button, true)
	button.custom_minimum_size = Vector2(36, 36)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button


func _action_button(text: String, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	Cards.button(button, true)
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 13)
	return button


func _add_legend(parent: HBoxContainer, color: Color, text: String) -> void:
	var dot := _label("●", 8, color)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(dot)
	var caption := _label(text, 9, Color("8ea3a8"))
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(caption)


func _frame_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("071418")
	box.border_color = Color("c9a36a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(24)
	for side in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + side, 10)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 9)
	return box


func _surface_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1d23")
	box.set_corner_radius_all(18)
	return box


# --------------------------------------------------------------------- state

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


func show_for(player_index: int, animate: bool = true, keep_side: bool = false) -> void:
	if not is_instance_valid(room) or room.players.is_empty():
		return
	index = clampi(player_index, 0, room.players.size() - 1)
	visible = true
	if not keep_side:
		showing_back = false
	flipping = false
	if is_instance_valid(flip_tween):
		flip_tween.kill()
	if is_instance_valid(surface):
		surface.scale = Vector2.ONE
	refresh()
	_apply_side()
	_layout()
	if animate and not room.profile.reduced_motion:
		card_root.modulate.a = 0.0
		create_tween().tween_property(card_root, "modulate:a", 1.0, 0.18)
		frame.pivot_offset = CARD_SIZE * 0.5
		frame.scale = Vector2(0.956, 0.956)
		var tween := create_tween()
		tween.tween_property(frame, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		card_root.modulate.a = 1.0
		frame.scale = Vector2.ONE


func close() -> void:
	if not visible:
		return
	visible = false
	flipping = false
	showing_back = false
	if is_instance_valid(flip_tween):
		flip_tween.kill()
	if is_instance_valid(surface):
		surface.scale = Vector2.ONE
	closed.emit()


func step(direction: int) -> void:
	if not is_instance_valid(room) or room.players.is_empty():
		return
	index = posmod(index + direction, room.players.size())
	refresh()
	player_changed.emit(index)


func set_side(back_side: bool, animate: bool = true) -> void:
	if room == null or flipping:
		return
	if back_side == showing_back:
		_apply_side()
		return
	if not animate or room.profile.reduced_motion or not visible:
		showing_back = back_side
		_apply_side()
		return
	flipping = true
	if is_instance_valid(flip_tween):
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(surface, "scale:x", 0.02, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		showing_back = back_side
		_apply_side())
	flip_tween.tween_property(surface, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_callback(func(): flipping = false)


func _apply_side() -> void:
	if is_instance_valid(front):
		front.visible = not showing_back
	if is_instance_valid(back):
		back.visible = showing_back
	if is_instance_valid(flip_button):
		flip_button.text = "Параметры" if showing_back else "Оборот"


func _layout() -> void:
	if not is_instance_valid(card_root):
		return
	var area := size
	if area.x < 20.0 or area.y < 20.0:
		return
	var factor := minf(1.0, minf((area.x - 24.0) / CARD_SIZE.x, (area.y - 24.0) / CARD_SIZE.y))
	# Scale around the card centre, so the anchor position stays centred for
	# every factor instead of drifting on narrow screens.
	card_root.pivot_offset = CARD_SIZE * 0.5
	card_root.scale = Vector2(factor, factor)
	card_root.position = (area - CARD_SIZE) * 0.5
	if is_instance_valid(frame):
		frame.pivot_offset = CARD_SIZE * 0.5
	if is_instance_valid(surface):
		surface.pivot_offset = surface.size * 0.5


# ------------------------------------------------------------------- content

func refresh() -> void:
	if not is_instance_valid(room) or room.players.is_empty():
		return
	index = clampi(index, 0, room.players.size() - 1)
	var player: Dictionary = room.players[index]
	var profession := _profession_of(player)
	var look := Art.style(profession)
	var accent: Color = look["accent"]
	front_backdrop.set_accent(accent)
	mini_art.set_profession(profession)
	art_view.set_profession(profession)
	var active: bool = room.active.has(index)
	name_label.text = str(player["name"]) + ("  ·  ВЫ" if index == 0 else "")
	name_label.add_theme_color_override("font_color", Color("f2ead9") if active else Color("d98b7f"))
	var meta := profession
	var biology := _card_of(player, "biology")
	if not biology.is_empty() and can_view(index, biology):
		meta += "  ·  " + str(biology["value"])
	else:
		meta += "  ·  биология скрыта"
	profession_label.text = meta.to_upper()
	phase_label.text = _phase_text()
	count_label.text = "%d / %d ОТКРЫТО" % [_public_count(player), player["cards"].size()]
	nav_label.text = "%d / %d  ·  %s" % [index + 1, room.players.size(), str(player["name"])]
	prev_button.disabled = room.players.size() < 2
	next_button.disabled = room.players.size() < 2
	back_profession.text = profession
	var title_size := 32
	if profession.length() > 26:
		title_size = 22
	elif profession.length() > 18:
		title_size = 27
	back_profession.add_theme_font_size_override("font_size", title_size)
	back_tag.text = str(look["tag"])
	back_name.text = str(player["name"]) + ("  ·  вы" if index == 0 else "")
	back_number.text = "%02d / %02d" % [index + 1, room.players.size()]
	_rebuild_tiles(player, accent)


func _rebuild_tiles(player: Dictionary, accent: Color) -> void:
	for tile in tiles:
		if is_instance_valid(tile):
			grid.remove_child(tile)
			tile.queue_free()
	tiles.clear()
	var number := 1
	for parameter_id in PARAMETER_ORDER:
		var card := _card_of(player, parameter_id)
		if card.is_empty():
			continue
		var state := state_for(index, card)
		var tile := Tile.new()
		tile.setup({
			"id": parameter_id,
			"title": str(PARAMETER_TITLE.get(parameter_id, card["label"])),
			"number": number,
			"state": state,
			"icon": Art.parameter_icon(parameter_id),
			"accent": accent,
			"value": visible_value(index, card) if state != "hidden" else "••••",
			"note": _note_for(card, state),
			"revealable": state == "own" and room.can_reveal_parameter()
		})
		tile.reveal_requested.connect(func(parameter: String): reveal_requested.emit(parameter))
		grid.add_child(tile)
		tiles.append(tile)
		number += 1


func _note_for(card: Dictionary, state: String) -> String:
	if state == "hidden":
		return "Скроется до раскрытия"
	if state == "own":
		return "Можно раскрыть сейчас" if room.can_reveal_parameter() else "Скрыто от остальных"
	if str(card.get("id", "")) == "health":
		return Supplies.cost_text(card.get("cost", {}))
	return str(PARAMETER_SUBTITLE.get(str(card.get("id", "")), ""))


func _public_count(player: Dictionary) -> int:
	if room.finished or room.phase == "end":
		return player["cards"].size()
	var total := 0
	for card in player["cards"]:
		if bool(card.get("revealed", false)):
			total += 1
	return total


func _phase_text() -> String:
	if room.finished or room.phase == "end":
		return "ИТОГ ПАРТИИ"
	return "РАУНД %d  ·  %s" % [room.round_number, str(PHASE_NAMES.get(room.phase, str(room.phase).to_upper()))]


func _card_of(player: Dictionary, parameter_id: String) -> Dictionary:
	for card in player["cards"]:
		if str(card.get("id", "")) == parameter_id:
			return card
	return {}


func _profession_of(player: Dictionary) -> String:
	for card in player["cards"]:
		if str(card.get("id", "")) == "profession":
			return str(card["value"])
	return ""


# --------------------------------------------------------------------- input

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func _on_back_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_side(false)
	elif event is InputEventScreenTouch and event.pressed:
		set_side(false)
