extends Control

const Rules = preload("res://game/scripts/survival_rules.gd")
var room: Node3D
var face_label: Label
var result_label: Label
var roll_button: Button
var continue_button: Button
var outcome: Dictionary = {}


func setup(game: Node3D) -> void:
	room = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.075, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 560)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(room._label("ВЫ ПОКИНУЛИ БУНКЕР", 30))
	column.add_child(room._label("Гермодверь закрылась. Впереди снег и заброшенная метеостанция. Удастся ли добраться до неё?", 20))
	column.add_child(room._label("Правило прототипа: один бросок d6. 1–3 — не выжили; 4–6 — выжили. Вероятность 50%. Повторного броска нет.", 18))
	face_label = room._label("?", 64)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(face_label)
	roll_button = room._button("Бросить кубик d6", roll_dice, column)
	result_label = room._label("Ваш исход ещё не определён.", 20)
	column.add_child(result_label)
	continue_button = room._button("Продолжить наблюдателем", func():
		visible = false
		room.restore_camera(), column)
	continue_button.disabled = true
	visible = false


func roll_dice() -> void:
	if not outcome.is_empty():
		return
	outcome = Rules.roll()
	roll_button.disabled = true
	var tween := create_tween()
	var steps := 1 if room.profile.reduced_motion else 8
	for index in steps:
		tween.tween_callback(func(): face_label.text = str(randi_range(1, 6)))
		tween.tween_interval(0.1)
	tween.tween_callback(show_result)


func show_result() -> void:
	face_label.text = str(outcome["face"])
	result_label.text = "ВЫ ВЫЖИЛИ. Среди заносов вы нашли метеостанцию и укрылись от метели." if outcome["survived"] else "ВЫ НЕ ВЫЖИЛИ. Метель оказалась сильнее. История вашего персонажа закончилась."
	continue_button.disabled = false
