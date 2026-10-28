extends Control

var room: Node3D
var column: VBoxContainer
var profile: BunkerProfile


func setup(game: Node3D, player_profile: BunkerProfile) -> void:
	room = game
	profile = player_profile
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.07, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 610)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	home()


func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()


func text(value: String, size: int = 20) -> void:
	column.add_child(room._label(value, size))


func button(value: String, action: Callable) -> void:
	room._button(value, action, column)


func home() -> void:
	visible = true
	clear()
	text("Б У Н К Е Р", 38)
	text("ПОСЛЕДНИЙ ШЛЮЗ  /  0.3", 18)
	text("Добро пожаловать, " + profile.nickname)
	text("Вы уже внутри убежища. Места ограничены — после каждого решения один участник покидает комплекс.", 18)
	button("Продолжить партию", func(): visible = false)
	button("Новая партия", new_game)
	button("Профиль игрока", show_profile)
	button("Настройки", settings)
	button("Как играть", instructions)
	button("Выйти из игры", func(): get_tree().quit())
	text("Локальная демонстрация. Остальные участники — тестовый сценарий, не онлайн-игроки.", 16)


func new_game() -> void:
	clear()
	text("НОВАЯ ПАРТИЯ", 28)
	text("Число участников (включая вас)")
	var count := OptionButton.new()
	for number in [6, 8, 10]:
		count.add_item(str(number), number)
	count.select([6, 8, 10].find(profile.player_count))
	count.custom_minimum_size.y = 48
	column.add_child(count)
	text("Половина группы останется. 3–5 раундов исключения, 7 характеристик на персонажа, 40 профессий. Новая раздача при каждом старте.", 18)
	button("Начать новую партию", func():
		profile.player_count = count.get_selected_id()
		if not save_profile():
			return
		get_tree().set_meta("start_game", true)
		get_tree().reload_current_scene())
	button("Назад", home)


func save_profile() -> bool:
	if profile.save() != OK:
		text("Не удалось сохранить профиль. Проверьте свободное место на устройстве.", 16)
		return false
	return true


func show_profile() -> void:
	clear()
	text("ЛОКАЛЬНЫЙ ПРОФИЛЬ", 28)
	var name_input := LineEdit.new()
	name_input.text = profile.nickname
	name_input.max_length = 20
	name_input.custom_minimum_size.y = 48
	column.add_child(name_input)
	text("Завершено локальных партий: %d" % profile.completed_games)
	text("Имя и настройки хранятся только на этом устройстве. Это не сетевой аккаунт. Новое имя применяется при следующей раздаче.", 18)
	button("Сохранить", func():
		var value := name_input.text.strip_edges()
		if value.is_empty():
			text("Введите непустое имя.", 16)
			return
		profile.nickname = value
		if save_profile():
			home())
	button("Назад", home)


func settings() -> void:
	clear()
	text("НАСТРОЙКИ", 28)
	var shadow_toggle := CheckButton.new()
	shadow_toggle.text = "Динамические тени"
	shadow_toggle.button_pressed = profile.shadows
	column.add_child(shadow_toggle)
	var motion_toggle := CheckButton.new()
	motion_toggle.text = "Уменьшить вторичные движения"
	motion_toggle.button_pressed = profile.reduced_motion
	column.add_child(motion_toggle)
	text("Отдаление камеры (9 — ближе, 14 — дальше)", 18)
	var zoom := HSlider.new()
	zoom.min_value = 9
	zoom.max_value = 14
	zoom.step = 0.5
	zoom.value = profile.camera_size
	zoom.custom_minimum_size.y = 48
	column.add_child(zoom)
	button("Применить и сохранить", func():
		profile.shadows = shadow_toggle.button_pressed
		profile.reduced_motion = motion_toggle.button_pressed
		profile.camera_size = zoom.value
		room.apply_settings()
		if save_profile():
			home())
	button("Назад", home)


func instructions() -> void:
	clear()
	text("КАК ИГРАТЬ", 28)
	text("1. Коснитесь свободного пола — персонаж обойдёт стол.\n2. Раскройте одну характеристику своего досье.\n3. Перейдите к обсуждению, затем к голосованию.\n4. Выберите другого активного участника и проголосуйте. Остальные голоса пока задаются тестовым сценарием.\n5. Исключённый покинет комнату через наружный проход. Нажмите «Следующий раунд».\n6. Когда останется половина группы, партия завершится.", 19)
	text("Меню приостанавливает движение. Партия в этой версии не сохраняется между перезапусками приложения; профиль и настройки сохраняются.", 17)
	button("Назад", home)
