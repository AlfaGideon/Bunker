extends Node3D

const Supplies = preload("res://game/scripts/group_supplies.gd")
const Layout = preload("res://game/scripts/bunker_layout.gd")
const BunkerAudio = preload("res://game/scripts/bunker_audio.gd")
const Weather = preload("res://game/scripts/winter_weather.gd")
const SurvivalPanel = preload("res://game/scripts/survival_panel.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Menu = preload("res://game/scripts/game_menu.gd")
const Surroundings = preload("res://game/scripts/bunker_surroundings.gd")
const Navigation = preload("res://game/scripts/room_navigation.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const SurvivorVisual = preload("res://game/scripts/survivor_visual.gd")
const VoteRules = preload("res://game/scripts/vote_rules.gd")
## Local visual prototype. All dossier data is local; no online privacy is provided.

var supplies := Supplies.new()
var scenario: Dictionary
var layout: Dictionary
var layout_seed := 0
var audio: Node
var med_gate: MeshInstance3D
var med_cover: MeshInstance3D
var med_label: Label3D
var med_light: OmniLight3D
var systems_ready := false
var medical_open := false
var inventory := {"repair": 0}
var supply_taken := false
var medicines := 2
var stamina := 60
var used_actions := {}
var rest_remaining := 0.0
var rest_return := Vector3.ZERO
var rest_rotation := 0.0
var started := false
var step_clock := 0.0
var players: Array = []
var actors: Array[Node3D] = []
var active: Array[int] = []
var capacity := 4
var profile := Profile.new()
var menu: Control
var sun: DirectionalLight3D
var departures: Dictionary = {}
var selected := 0
var round_number := 1
var phase := "reveal"
var camera: Camera3D
var detail: VBoxContainer
var status_label: Label
var log_label: Label
var phase_label: Label
var door: MeshInstance3D
var target := Vector3(-2.5, 0, 1.8)
var clock := 0.0
var finished := false
var navigation: RoomNavigation
var route := PackedVector3Array()
var route_index := 0
var marker: MeshInstance3D
var pending_inspection := ""
var weather: Node3D
var survival_panel: Control
var ui_root: Control
var menu_button: Button
var original_camera: Transform3D
var reveal_log: Array = []


func _ready() -> void:
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	scenario = Content.pick_scenario(profile.scenario_choice)
	var explicit_seed := get_tree().has_meta("world_seed")
	layout_seed = int(get_tree().get_meta("world_seed", randi()))
	if get_tree().has_meta("world_seed"):
		get_tree().remove_meta("world_seed")
	if not explicit_seed and posmod(layout_seed, 3) == profile.last_layout:
		layout_seed += 1
	layout = Layout.generate(layout_seed)
	profile.world_count += 1
	profile.last_layout = layout["variant"]
	profile.save()
	navigation = Navigation.new(layout)
	players = Content.create_players(profile.player_count, profile.nickname, profile.appearance)
	active.assign(range(players.size()))
	capacity = players.size() / 2
	_build_world()
	audio = BunkerAudio.new()
	add_child(audio)
	audio.setup(self, layout["items"]["radio"]["at"])
	_build_ui()
	original_camera = camera.transform
	apply_settings()
	_refresh()
	get_viewport().size_changed.connect(_frame_camera)
	if get_tree().has_meta("start_game"):
		get_tree().remove_meta("start_game")
		begin_game()


func apply_settings() -> void:
	_frame_camera()
	sun.shadow_enabled = profile.shadows
	weather.set_reduced_motion(profile.reduced_motion)
	audio.apply_settings()
	if not _biology_revealed(0) and actors[0].get_meta("appearance") != profile.appearance and rest_remaining <= 0:
		_change_appearance(0, profile.appearance)



func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	add_child(instance)
	return instance


func _world_label(text: String, at: Vector3, size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b7ccd0")
	add_child(label)
	return label


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101a22")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b2c6d3")
	settings.ambient_light_energy = 0.48
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_color = Color("ffe0af")
	light.light_energy = 1.0
	sun = light
	light.shadow_enabled = profile.shadows
	light.directional_shadow_max_distance = 30.0
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = profile.camera_size
	camera.position = Vector3(9, 13, 13)
	add_child(camera)
	camera.look_at(Vector3(1.8, 0, 0))
	camera.current = true
	Surroundings.build(self)
	weather = Weather.new()
	add_child(weather)
	weather.setup(self, scenario["weather"])
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.21
	marker.mesh = ring
	marker.material_override = _material(Color("73dfc5"))
	marker.visible = false
	add_child(marker)
	var positions := [Vector3(-2.5, 0, 1.8), Vector3(2.5, 0, 1.8),
		Vector3(-2.5, 0, -1.5), Vector3(2.5, 0, -1.5),
		Vector3(-3.8, 0, 0), Vector3(3.8, 0, 0), Vector3(0, 0, 2.7),
		Vector3(0, 0, -2.7), Vector3(-3.8, 0, 2.6), Vector3(3.8, 0, 2.6)]
	for i in players.size():
		var actor := Node3D.new()
		add_child(actor)
		var appearance: String = players[i]["appearance"]
		actor.set_meta("appearance", appearance)
		var visual := Art.spawn(actor, _model_name(i, appearance), Vector3.ZERO, Vector3(1, 1.45, 1), true)
		visual.set_script(SurvivorVisual)
		visual._collect(visual)
		actor.position = navigation.nearest_walkable(positions[i])
		actor.rotation.y = PI if i > 1 else 0
		var label := Label3D.new()
		label.text = players[i]["name"] + (" • ВЫ" if i == 0 else "")
		label.position.y = 1.85
		label.font_size = 26
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
		actors.append(actor)
	var listener := AudioListener3D.new()
	actors[0].add_child(listener)
	listener.make_current()



func _label(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	button.pressed.connect(func():
		if is_instance_valid(audio):
			audio.blip())
	parent.add_child(button)
	return button


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root = root
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_constant("outline_size", "Label", 3)
	theme.set_color("font_outline_color", "Label", Color("101b20"))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("14272c")
	panel_style.border_color = Color("42666a")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("25474d") if state == "normal" else Color("3d706d")
		style.border_color = Color("5a9790")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		theme.set_stylebox(state, "Button", style)
	root.theme = theme
	var header := VBoxContainer.new()
	header.position = Vector2(24, 18)
	header.size = Vector2(590, 140)
	root.add_child(header)
	header.add_child(_label("Б У Н К Е Р  /  ПОСЛЕДНИЙ ШЛЮЗ", 25))
	header.add_child(_label("ЛОКАЛЬНЫЙ ПРОТОТИП • НЕ СЕТЕВАЯ ИГРА", 15))
	phase_label = _label("", 20)
	header.add_child(phase_label)
	menu_button = _button("☰", func(): menu.home(), root)
	menu_button.tooltip_text = "Меню / пауза"
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -438
	menu_button.offset_right = -382
	menu_button.offset_top = 16
	menu_button.offset_bottom = 68
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -370
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)
	shell.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(_label(scenario["title"], 25))
	_button("Помещения и предметы", func(): menu.show_facility(), column)
	_button("Сводка катастрофы / озвучка", func(): menu.briefing(), column)
	column.add_child(_label("Все уже внутри. Из %d выживших останутся %d. Партия: %d исключений." % [players.size(), capacity, players.size() - capacity]))
	var roster := OptionButton.new()
	roster.custom_minimum_size.y = 48
	for i in players.size():
		roster.add_item(players[i]["name"] + (" — вы" if i == 0 else ""), i)
	roster.item_selected.connect(func(index: int):
		selected = index
		_refresh())
	column.add_child(roster)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	column.add_child(detail)
	status_label = _label("")
	column.add_child(status_label)
	var advance_button := _button("Следующий этап →", _advance, column)
	log_label = _label("Профессии открыты обязательно. Выберите ещё одну характеристику. У остальных тестовых участников дополнительная карта выбирается случайно.", 16)
	column.add_child(log_label)
	# Keep phase controls reachable without scrolling through seven cards.
	for control in [status_label, advance_button, log_label]:
		column.remove_child(control)
		shell.add_child(control)
	var hint := _label("Коснитесь пола: персонаж обойдёт стол и мебель.\nТерминал и аптечка: подойдите и коснитесь предмета.", 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -75)
	hint.size = Vector2(560, 60)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	menu = Menu.new()
	root.add_child(menu)
	menu.setup(self, profile)
	survival_panel = SurvivalPanel.new()
	root.add_child(survival_panel)
	survival_panel.setup(self)
	get_viewport().size_changed.connect(_update_safe_area)
	call_deferred("_update_safe_area")


func _refresh() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var names := {"reveal": "Раскрытие", "discussion": "Обсуждение", "vote": "Голосование", "result": "Результат", "end": "Итог"}
	phase_label.text = "РАУНД %d  /  %s" % [round_number, names[phase]]
	status_label.text = "В бункере: %d  •  Мест: %d  •  Раунд: %d/%d" % [active.size(), capacity, round_number, players.size() - capacity]
	detail.add_child(_label(players[selected]["name"] + (" — ваше досье" if selected == 0 else " — публичное досье"), 21))
	for c in players[selected]["cards"]:
		var card: Dictionary = c
		var visible: bool = selected == 0 or card["revealed"]
		detail.add_child(_label(card["label"] + ": " + (card["value"] if visible else "скрыто")))
		if card["id"] == "health" and visible:
			detail.add_child(_label("Доп. нагрузка: " + Supplies.cost_text(card.get("cost", {})), 16))
		if selected == 0 and not card["revealed"] and phase == "reveal" and active.has(0):
			_button("Раскрыть: " + card["label"], func():
				actors[0].get_child(0).gesture = 1.5
				_reveal_card(0, card)
				_demo_reveals()
				phase = "discussion"
				log_label.text = "Карта раскрыта. Тестовые персонажи тоже открыли по карте. В сети здесь будет общий чат."
				_refresh(), detail)
	if phase == "vote" and active.has(0) and selected != 0 and active.has(selected):
		_button("Голосовать (тестовые участники)", _demo_vote, detail)
	if phase == "vote" and not active.has(0):
		_button("Тестовое голосование оставшихся", _spectator_vote, detail)
	if not active.has(selected):
		detail.add_child(_label("Наблюдатель — больше не участвует в голосовании."))


func _demo_reveals() -> void:
	for i in active:
		if i == 0:
			continue
		var card := Content.random_hidden_card(players[i])
		if not card.is_empty():
			_reveal_card(i, card)


func _reveal_card(index: int, card: Dictionary) -> void:
	if card["revealed"]:
		return
	card["revealed"] = true
	reveal_log.append({"player": index, "card": card["id"]})
	if card["id"] == "biology":
		_change_appearance(index, players[index]["sex"])


func _biology_revealed(index: int) -> bool:
	for card in players[index]["cards"]:
		if card["id"] == "biology":
			return card["revealed"]
	return false


func _model_name(index: int, appearance: String) -> String:
	return "kaykit_Knight" if appearance == "male" else ("kaykit_Rogue" if index % 2 == 0 else "kaykit_Rogue_Hooded")


func _change_appearance(index: int, appearance: String) -> void:
	var actor := actors[index]
	if actor.get_meta("appearance") == appearance:
		return
	var old := actor.get_child(0)
	actor.remove_child(old)
	old.queue_free()
	var visual := Art.spawn(actor, _model_name(index, appearance), Vector3.ZERO, Vector3(1, 1.45, 1), true)
	visual.set_script(SurvivorVisual)
	visual._collect(visual)
	actor.move_child(visual, 0)
	actor.set_meta("appearance", appearance)
	players[index]["appearance"] = appearance
	if index == 0 and rest_remaining > 0:
		visual.rotation.z = PI / 2
		visual.position = Vector3(0.7, 0.7, 0)


func _advance() -> void:
	match phase:
		"reveal":
			if active.has(0):
				log_label.text = "Профессия уже открыта. Раскройте одну дополнительную карту."
			else:
				_demo_reveals()
				phase = "discussion"
				log_label.text = "Наблюдатель: тестовые участники раскрыли случайные характеристики."
		"discussion":
			phase = "vote"
			log_label.text = "Демонстрация результата: выберите другого участника и нажмите «Голосовать». Остальные голоса задаёт явно тестовый сценарий."
		"vote":
			log_label.text = "Выберите другого активного персонажа."
		"result":
			if not departures.is_empty():
				log_label.text = "Подождите: исключённый участник идёт к выходу."
			else:
				round_number += 1
				supplies.charge_round(round_number, players, active, scenario["weather"])
				phase = "reveal"
				_update_medical_access()
				log_label.text = "Новый раунд. Откройте следующую характеристику. " + supplies.last_report
		"end":
			log_label.text = "Демонстрация завершена. Можно начать заново."
	_refresh()


func _demo_vote() -> void:
	if phase != "vote" or not active.has(0) or selected == 0 or not active.has(selected):
		return
	# Explicit deterministic fixture, not intelligent bots or real online votes.
	var votes := {0: selected}
	for voter in active:
		if voter == 0:
			continue
		votes[voter] = 0 if voter == selected else selected
	var result := VoteRules.resolve(active, votes)
	if result["status"] != "eliminated":
		log_label.text = "Тестовый бюллетень не дал результата: " + result["status"]
		return
	var eliminated: int = result["player"]
	_eliminate(eliminated)


func _spectator_vote() -> void:
	if phase != "vote" or active.has(0):
		return
	var candidate: int = active.pick_random()
	var votes := {}
	for voter in active:
		if voter != candidate:
			votes[voter] = candidate
	var result := VoteRules.resolve(active, votes)
	if result["status"] == "eliminated":
		_eliminate(result["player"])


func test_own_expulsion() -> void:
	if not active.has(0) or finished:
		return
	menu.visible = false
	_eliminate(0)


func _eliminate(eliminated: int) -> void:
	if not active.has(eliminated):
		return
	if eliminated == 0:
		if rest_remaining > 0:
			rest_remaining = 0
			actors[0].position = rest_return
			actors[0].rotation.y = rest_rotation
			actors[0].get_child(0).rotation = Vector3.ZERO
			actors[0].get_child(0).position = Vector3.ZERO
		route.clear()
		marker.visible = false
		pending_inspection = ""
	active.erase(eliminated)
	actors[eliminated].get_child(1).modulate = Color("71828c")
	var departure := navigation.path_between(actors[eliminated].position, Vector3(3.8, 0, 3.2))
	departure.append_array(PackedVector3Array([Vector3(3.8, 0, 4.5), Vector3(3.8, 0, 6.7), Vector3(8, 0, 6.7)]))
	departures[eliminated] = {"path": departure, "index": 0}
	if active.size() == capacity:
		phase = "end"
		finished = true
		profile.completed_games += 1
		profile.save()
		var survivors: Array[String] = []
		for i in active:
			survivors.append(players[i]["name"])
		log_label.text = "В бункере остаются: " + ", ".join(survivors) + ". Остальные покинули убежище."
	else:
		phase = "result"
		log_label.text = players[eliminated]["name"] + " покидает бункер по наружному проходу. Затем нажмите «Следующий этап»."

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if survival_panel.visible:
			return
		if menu.visible:
			menu.visible = false
		else:
			menu.home()
		return
	if menu.visible or survival_panel.visible or not active.has(0):
		return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	if rest_remaining > 0:
		return
	var nearest_item := ""
	var nearest_distance := 34.0
	for key in layout["items"]:
		if key == "medical" and not medical_open:
			continue
		var point_3d: Vector3 = layout["items"][key]["at"]
		var distance := camera.unproject_position(point_3d).distance_to(point)
		if distance < nearest_distance:
			nearest_item = key
			nearest_distance = distance
	if not nearest_item.is_empty():
		request_interaction(nearest_item)
		return
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return
	if not navigation.is_walkable(hit):
		log_label.text = "Здесь препятствие. Коснитесь свободного пола рядом с предметом."
		return
	pending_inspection = ""
	_set_route(hit)


func _set_route(destination: Vector3) -> void:
	route = navigation.path_between(actors[0].position, destination)
	route_index = 0
	marker.visible = not route.is_empty()
	if marker.visible:
		marker.position = route[route.size() - 1] + Vector3(0, 0.035, 0)


func _physics_process(delta: float) -> void:
	if actors.is_empty() or menu.visible or survival_panel.visible:
		return
	if rest_remaining > 0:
		_tick_rest(delta)
		return
	var budget := delta * 2.4
	var previous := actors[0].position
	while route_index < route.size() and budget > 0:
		var next := route[route_index]
		var distance := actors[0].position.distance_to(next)
		if distance <= budget:
			actors[0].position = next
			budget -= distance
			route_index += 1
		else:
			actors[0].position = actors[0].position.move_toward(next, budget)
			budget = 0
	var direction := actors[0].position - previous
	if direction.length_squared() > 0.000001:
		actors[0].rotation.y = lerp_angle(actors[0].rotation.y, atan2(direction.x, direction.z), delta * 12.0)
	if route_index >= route.size():
		marker.visible = false
		if not pending_inspection.is_empty():
			var item := pending_inspection
			pending_inspection = ""
			_complete_interaction(item)
			if rest_remaining > 0:
				return
	if direction.length_squared() > 0.000001:
		step_clock += delta
		if step_clock > 0.38:
			audio.blip("step")
			step_clock = 0
	var departing_ids := departures.keys()
	for id in departing_ids:
		var entry: Dictionary = departures[id]
		var points: PackedVector3Array = entry["path"]
		var index: int = entry["index"]
		var actor: Node3D = actors[id]
		if index >= points.size():
			actor.visible = false
			departures.erase(id)
			if id == 0:
				_show_survival()
			continue
		var travel := points[index] - actor.position
		actor.position = actor.position.move_toward(points[index], delta * 2.2)
		if travel.length_squared() > 0.0001:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(travel.x, travel.z), delta * 12)
		if actor.position.distance_to(points[index]) < 0.03:
			entry["index"] = index + 1
	for i in actors.size():
		actors[i].get_child(0).animate(delta, (i == 0 and direction.length_squared() > 0.000001) or departures.has(i), float(i), profile.reduced_motion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(menu) and not (is_instance_valid(survival_panel) and survival_panel.visible):
		menu.home()


func _show_survival() -> void:
	survival_panel.visible = true
	var outside := Transform3D(Basis.IDENTITY, Vector3(14, 11, 18)).looking_at(Vector3(6, 0, 7), Vector3.UP)
	create_tween().tween_property(camera, "transform", outside, 0.8)


func restore_camera() -> void:
	create_tween().tween_property(camera, "transform", original_camera, 0.6)


func _update_safe_area() -> void:
	# Expand the 3D viewport to every pixel, inset only the HUD around cutouts.
	if not is_instance_valid(ui_root) or not OS.has_feature("android"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var physical := Vector2(get_window().size)
	if physical.x <= 0 or physical.y <= 0 or safe.size.x <= 0:
		return
	var logical := get_viewport().get_visible_rect().size
	ui_root.offset_left = safe.position.x / physical.x * logical.x
	ui_root.offset_top = safe.position.y / physical.y * logical.y
	ui_root.offset_right = -(physical.x - safe.end.x) / physical.x * logical.x
	ui_root.offset_bottom = -(physical.y - safe.end.y) / physical.y * logical.y


func begin_game() -> void:
	if started:
		menu.visible = false
		return
	started = true
	audio.begin()
	menu.briefing()
	_narrate_intro()


func _narrate_intro() -> void:
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree():
		audio.narrate()
		if menu.visible and menu.page == "briefing":
			menu.briefing(false)


func medical_status() -> String:
	if medical_open:
		return "Медблок открыт. Осталось наборов: %d." % medicines
	return "Медблок закрыт: нужен ремкомплект со склада, восстановленная система и начало второго раунда. Система: %s; раунд: %d." % ["готова" if systems_ready else "не восстановлена", round_number]


func request_interaction(key: String) -> bool:
	if not active.has(0) or rest_remaining > 0:
		log_label.text = "Сейчас персонаж не может взаимодействовать."
		return false
	if key == "gate" or (key == "medical" and not medical_open):
		log_label.text = medical_status()
		return false
	if not layout["items"].has(key):
		return false
	var goal: Vector3 = layout["items"][key]["goal"]
	var path: PackedVector3Array = navigation.path_between(actors[0].position, goal)
	if path.is_empty():
		log_label.text = "Проход недоступен."
		return false
	pending_inspection = key
	_set_route(goal)
	log_label.text = "Идём: " + layout["items"][key]["title"]
	return true


func _complete_interaction(key: String) -> void:
	if not active.has(0):
		return
	actors[0].get_child(0).gesture = 1.2
	match key:
		"supply":
			if supply_taken:
				log_label.text = "Склад проверен: ремкомплект уже забрали."
			else:
				supply_taken = true
				inventory["repair"] += 1
				log_label.text = "Взяли ремкомплект. Теперь можно восстановить систему терминалом."
		"terminal":
			if systems_ready:
				log_label.text = medical_status()
			elif inventory["repair"] < 1:
				log_label.text = "Для ремонта нужен ремкомплект со склада."
			else:
				inventory["repair"] -= 1
				systems_ready = true
				log_label.text = scenario["repair"] + " " + medical_status()
				_update_medical_access()
		"radio":
			audio.toggle_radio()
			log_label.text = "Радио: аварийная частота, авторская инструментальная петля." if audio.radio_on else "Радио выключено."
		"bed", "bed2":
			if used_actions.get("rest", 0) == round_number:
				log_label.text = "В этом раунде вы уже отдыхали."
				return
			used_actions["rest"] = round_number
			rest_return = actors[0].position
			rest_rotation = actors[0].rotation.y
			actors[0].rotation.y = 0
			var at: Vector3 = layout["items"][key]["at"]
			actors[0].position = Vector3(at.x, 0, at.z)
			var visual := actors[0].get_child(0) as Node3D
			visual.rotation.z = PI / 2
			visual.position = Vector3(0.7, 0.7, 0)
			rest_remaining = 3.0
			log_label.text = "Отдых на койке… (3 секунды)"
		"medical":
			if not medical_open:
				log_label.text = medical_status()
			elif used_actions.get("medical", 0) == round_number or medicines <= 0:
				log_label.text = "Осмотр уже выполнен в этом раунде или запасы закончились."
			else:
				used_actions["medical"] = round_number
				medicines -= 1
				stamina = mini(100, stamina + (5 if supplies.shortage else 15))
				log_label.text = "Осмотр выполнен, бодрость +%d. Закрытые характеристики не раскрываются. " % (5 if supplies.shortage else 15) + medical_status()


func _tick_rest(delta: float) -> void:
	rest_remaining = maxf(0, rest_remaining - delta)
	if rest_remaining == 0:
		var visual := actors[0].get_child(0) as Node3D
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
		actors[0].position = rest_return
		actors[0].rotation.y = rest_rotation
		stamina = mini(100, stamina + (10 if supplies.shortage else 20))
		log_label.text = "Вы отдохнули. Бодрость: %d/100. Снова можно отдохнуть в следующем раунде." % stamina


func _update_medical_access() -> void:
	if medical_open or not systems_ready or round_number < 2:
		return
	medical_open = true
	navigation.unlock_medical()
	med_cover.visible = false
	med_label.text = "МЕДБЛОК • ОТКРЫТ"
	med_light.light_energy = 1.2
	create_tween().tween_property(med_gate, "position:y", -1.2, 0.6)
	audio.blip("door")


func _frame_camera() -> void:
	if is_instance_valid(survival_panel) and survival_panel.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var usable_width := maxf(500, viewport_size.x - 330)
	camera.size = maxf(14.0, 22.0 * viewport_size.y / usable_width) * profile.camera_size / 11.0
	var right := Vector3(13, 0, -7.2).normalized()
	var focus := right * (camera.size / viewport_size.y * 165)
	camera.position = focus + Vector3(7.2, 13, 13)
	camera.look_at(focus)
	original_camera = camera.transform
