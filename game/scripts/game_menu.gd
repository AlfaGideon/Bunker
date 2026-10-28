extends Control

const Professions = preload("res://game/scripts/profession_rules.gd")
const Content = preload("res://game/scripts/game_content.gd")

var room: Node3D
var column: VBoxContainer
var profile: BunkerProfile
var page := ""


func setup(game: Node3D, player_profile: BunkerProfile) -> void:
	room = game
	profile = player_profile
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.07, 0.104)
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


func button(value: String, action: Callable) -> Button:
	return room._button(value, action, column)


func home() -> void:
	page = "home"
	visible = true
	clear()
	text("Б У Н К Е Р", 38)
	text("ПОСЛЕДНИЙ ШЛЮЗ  /  0.10", 18)
	text("Добро пожаловать, " + profile.nickname)
	text("Вы уже внутри убежища. Места ограничены — после каждого решения один участник покидает комплекс.", 18)
	button("Продолжить партию", room.begin_game)
	button("Новая партия", new_game)
	button("Помещения и предметы", show_facility)
	button("Сводка катастрофы / озвучка", briefing)
	button("Профиль игрока", show_profile)
	button("Настройки", settings)
	button("Как играть", instructions)
	var test_button := button("Тест: меня исключили → кубик", room.test_own_expulsion)
	test_button.disabled = not room.active.has(0) or room.finished
	button("В приветственное меню (партия будет потеряна)", func(): get_tree().change_scene_to_file("res://game/welcome.tscn"))
	button("Выйти из игры", func(): get_tree().quit())
	text("Локальная демонстрация. Остальные участники — тестовый сценарий, не онлайн-игроки.", 16)


func new_game() -> void:
	page = "new_game"
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
	text("Катастрофа", 18)
	var scenario_picker := OptionButton.new()
	scenario_picker.add_item("Случайная", 0)
	var all: Array = Content.scenarios()
	for i in all.size():
		scenario_picker.add_item(all[i]["title"], i + 1)
		if all[i]["id"] == profile.scenario_choice:
			scenario_picker.select(i + 1)
	scenario_picker.custom_minimum_size.y = 48
	column.add_child(scenario_picker)
	var seed_input := LineEdit.new()
	seed_input.placeholder_text = "Seed убежища (необязательно)"
	seed_input.custom_minimum_size.y = 48
	column.add_child(seed_input)
	text("Три варианта планировки, зеркальное расположение отсеков и случайная мебель. Указанный seed повторяет расстановку.", 17)
	button("Начать новую партию", func():
		var seed_text := seed_input.text.strip_edges()
		if not seed_text.is_empty() and not seed_text.is_valid_int():
			text("Seed должен быть целым числом.", 16)
			return
		if not seed_text.is_empty():
			get_tree().set_meta("world_seed", seed_text.to_int())
		profile.scenario_choice = "random" if scenario_picker.selected == 0 else all[scenario_picker.selected - 1]["id"]
		profile.player_count = count.get_selected_id()
		if not save_profile():
			return
		get_tree().set_meta("start_game", true)
		get_tree().change_scene_to_file("res://game/main.tscn"))
	button("Назад", home)


func save_profile() -> bool:
	if profile.save() != OK:
		text("Не удалось сохранить профиль. Проверьте свободное место на устройстве.", 16)
		return false
	return true


func show_profile() -> void:
	page = "show_profile"
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
	page = "settings"
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
	text("Внешний вид до раскрытия биологии", 18)
	var appearance := OptionButton.new()
	appearance.add_item("Мужской", 0)
	appearance.add_item("Женский", 1)
	appearance.select(0 if profile.appearance == "male" else 1)
	appearance.custom_minimum_size.y = 48
	column.add_child(appearance)
	text("После раскрытия карточки «Биология» модель примет указанный в карточке пол.", 17)
	text("Громкость", 18)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = profile.volume
	volume.custom_minimum_size.y = 48
	column.add_child(volume)
	var narration_toggle := CheckButton.new()
	narration_toggle.text = "Зачитывать катастрофу системным голосом"
	narration_toggle.button_pressed = profile.narration
	column.add_child(narration_toggle)
	text("Для русской озвучки нужен установленный голос синтеза речи Android. Радио работает без интернета.", 16)
	text("Отдаление камеры (9 — ближе, 14 — дальше)", 18)
	var zoom := HSlider.new()
	zoom.min_value = 9
	zoom.max_value = 14
	zoom.step = 0.5
	zoom.value = profile.camera_size
	zoom.custom_minimum_size.y = 48
	column.add_child(zoom)
	button("Применить и сохранить", func():
		profile.volume = volume.value
		profile.narration = narration_toggle.button_pressed
		profile.appearance = "male" if appearance.selected == 0 else "female"
		profile.shadows = shadow_toggle.button_pressed
		profile.reduced_motion = motion_toggle.button_pressed
		profile.camera_size = zoom.value
		room.apply_settings()
		if save_profile():
			home())
	button("Назад", home)


func instructions() -> void:
	page = "instructions"
	clear()
	text("КАК ИГРАТЬ", 28)
	text("Управление камерой: свайп одним пальцем — перемещение, два пальца — масштаб и перемещение. Короткое касание — движение персонажа. На ПК — перетаскивание мышью и колесо. Жесты над интерфейсом остаются интерфейсу.\n1. Профессия уже открыта. По очереди раскройте ещё одну карту, объясните выбор. На речь каждого — 60 секунд; есть передача хода, пропуск и автопереход. Голосовой связи нет.\n2. После круга — обсуждение и тестовое голосование.\n3. Рабочие предметы доступны только подходящим профессиям. Через список помещений можно поручить работу подходящему тестовому участнику. Радио, койки и еда за столом доступны всем. Готовит только пищевая профессия.\n4. Слева — две одноразовые способности. Цель выберите в списке досье справа. После начала голосования способности недоступны.\n5. Совет отдельно решает, открывать ли склад. Без большинства он может остаться закрытым.\n6. При изгнании выберите d6 или d20, диапазон, чётность или свои числа ДО единственного броска. Варианты равновероятны — половина граней.\n7. Профиль сохраняется, партия — нет. Остальные участники — локальные фикстуры, не онлайн-игроки.", 18)
	text("Меню приостанавливает движение. Партия в этой версии не сохраняется между перезапусками приложения; профиль и настройки сохраняются.", 17)
	button("Назад", home)


func briefing(_unused: bool = false) -> void:
	page = "briefing"
	visible = true
	clear()
	text("АВАРИЙНАЯ СВОДКА", 27)
	text(room.scenario["title"], 23)
	text(room.scenario["brief"], 18)
	text("Убежище: seed %d • план %d" % [room.layout_seed, room.layout["variant"] + 1], 17)
	text(room.audio.narration_status, 16)
	button("Зачитать / повторить", func():
		room.audio.narrate()
		briefing())
	button("В убежище", func(): visible = false)
	button("Назад в меню", home)


func show_facility() -> void:
	page = "facility"
	visible = true
	clear()
	text("ПОМЕЩЕНИЯ И ПРЕДМЕТЫ", 26)
	text("Бодрость: %d/100 • Ремкомплекты: %d" % [room.stamina, room.inventory["repair"]], 18)
	text(room.medical_status(), 17)
	text(room.supplies.summary(), 17)
	text(room.supplies.last_report, 16)
	text("Каждый раунд: −12 бодрости; при дефиците −20. Усталость замедляет ходьбу, но не блокирует управление.", 16)
	text("Характеристики здоровья влияют на расход запасов всей группы. Симуляции заражения нет; голоса и d6 не меняются автоматически.", 16)
	text("Порций за столом: %d. Инструменты: %d; оружие: %d (инвентарь, без боя)." % [room.meals, room.inventory["tools"], room.inventory["weapons"]], 17)
	text("Выберите предмет — персонаж сам подойдёт к нему. Отдых и обследование доступны один раз за раунд.", 17)
	text("Осмотреть отдельную пристройку (без выполнения работы):", 17)
	for kind in room.layout["modules"]:
		var module_kind: String = kind
		button("Осмотреть: " + room.layout["items"][kind]["title"].split(" — ")[0], func():
			room.focus_module(module_kind)
			visible = false)
	text("Исполнитель (тестовые участники выполняют ваше поручение, это не сетевые игроки):", 16)
	var operator_picker := OptionButton.new()
	for id in room.active:
		operator_picker.add_item(room.players[id]["name"] + " — " + Professions.profession(room.players[id]), id)
	operator_picker.custom_minimum_size.y = 48
	column.add_child(operator_picker)
	for key in room.layout["items"]:
		var id: String = key
		text(Professions.requirement(key) if key not in ["gate", "warehouse_gate"] else "Доступ определяется условиями / советом", 15)
		button(room.layout["items"][key]["title"], func():
			if room.request_interaction(id, operator_picker.get_selected_id()):
				visible = false
			else:
				text(room.log_label.text, 17))
	button("Вернуться в игру", func(): visible = false)


func show_council() -> void:
	page = "council"
	visible = true
	clear()
	text("СОВЕТ: ОТКРЫВАТЬ ЛИ СКЛАД?", 24)
	text("Локальный тест решений: отметьте голоса участников. Это не реальные онлайн-голоса. Больше половины активных — открыть. Без большинства склад остаётся закрытым, в том числе до конца партии.", 17)
	text("Статус: " + ("открыт" if room.warehouse_open else "опечатан"), 20)
	for id in room.active:
		var voter: int = id
		text(room.players[id]["name"], 18)
		button("За открытие", func():
			room.vote_warehouse(voter, true)
			show_council())
		button("Оставить закрытым", func():
			room.vote_warehouse(voter, false)
			show_council())
	button("Вернуться в игру", func(): visible = false)
