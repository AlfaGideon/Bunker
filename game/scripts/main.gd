extends Node3D

const Profile = preload("res://game/scripts/local_profile.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Menu = preload("res://game/scripts/game_menu.gd")
const Surroundings = preload("res://game/scripts/bunker_surroundings.gd")
const Navigation = preload("res://game/scripts/room_navigation.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const SurvivorVisual = preload("res://game/scripts/survivor_visual.gd")
const VoteRules = preload("res://game/scripts/vote_rules.gd")
## Local visual prototype. All dossier data is local; no online privacy is provided.

const DATA_PATH = "res://data/prototype.json"
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
var navigation := Navigation.new()
var route := PackedVector3Array()
var route_index := 0
var marker: MeshInstance3D
var pending_inspection := ""


func _ready() -> void:
	players = Content.create_players(profile.player_count, profile.nickname)
	active.assign(range(players.size()))
	capacity = players.size() / 2
	_build_world()
	_build_ui()
	apply_settings()
	_refresh()
	if get_tree().has_meta("start_game"):
		menu.visible = false
		get_tree().remove_meta("start_game")


func apply_settings() -> void:
	camera.size = profile.camera_size
	sun.shadow_enabled = profile.shadows



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


func _world_label(text: String, at: Vector3, size: int = 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b7ccd0")
	add_child(label)


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
	_box(Vector3(0, -0.2, 0), Vector3(10, 0.4, 8), Color("34444a"))
	# Modular imported walls: front/right walls are cut away for visibility.
	for x in [-4.0, -2.0, 2.0, 4.0]:
		Art.spawn(self, "modular_sci_fi_Wall_1", Vector3(x, 0, -3.9), Vector3(1.95, 2.1, 0.23))
	for z in [-2.8, -0.8, 1.2, 3.0]:
		var wall := Art.spawn(self, "modular_sci_fi_Wall_1", Vector3(-4.95, 0, z), Vector3(1.95, 2.1, 0.23))
		wall.rotation.y = PI / 2
	for x in range(-4, 5):
		_box(Vector3(x, 0.006, 0), Vector3(0.018, 0.01, 8), Color("42555b"))
	for z in range(-3, 4):
		_box(Vector3(0, 0.006, z), Vector3(10, 0.01, 0.018), Color("42555b"))
	door = _box(Vector3(0, 1.0, -3.8), Vector3(1.9, 2.0, 0.25), Color("26383e"))
	for x in [-0.75, 0.75]:
		var strip := _box(Vector3(x, 1, -3.64), Vector3(0.04, 1.8, 0.04), Color("68d9c3"))
		var glow := strip.material_override as StandardMaterial3D
		glow.emission_enabled = true
		glow.emission = Color("68d9c3")
	_box(Vector3(0, 2.1, -3.65), Vector3(2.4, 0.12, 0.12), Color("caa261"))
	_world_label("УБЕЖИЩЕ  /  %02d МЕСТА" % capacity, Vector3(0, 2.5, -3.7))
	Art.spawn(self, "house_interior_pack_Table_RoundLarge", Vector3.ZERO, Vector3(3.1, 0.9, 1.7))
	Art.spawn(self, "survival_pack_Radio", Vector3(-0.8, 0.91, 0), Vector3(0.45, 0.3, 0.25))
	Art.spawn(self, "survival_pack_FirstAidKit", Vector3(0.65, 0.91, 0), Vector3(0.45, 0.22, 0.3))
	Art.spawn(self, "modular_sci_fi_Props_Shelf", Vector3(-3.7, 0, -2.6), Vector3(1.5, 1.8, 0.65))
	Art.spawn(self, "modular_sci_fi_Props_Crate", Vector3(-3.65, 0.15, -2.5), Vector3(0.6, 0.55, 0.55))
	Art.spawn(self, "modular_sci_fi_Props_Computer", Vector3(3.5, 0, -2.6), Vector3(1.0, 1.5, 0.8))
	_world_label("ТЕРМИНАЛ", Vector3(3.5, 1.85, -2.6), 22)
	for x in [-3.0, 3.0]:
		var pipes := Art.spawn(self, "modular_sci_fi_Details_Pipes_Long", Vector3(x, 1.1, -3.65), Vector3(0.5, 0.25, 1.5))
		pipes.rotation.x = PI / 2
		Art.spawn(self, "modular_sci_fi_Details_Vent_1", Vector3(x, 1.6, -3.63), Vector3(0.8, 0.1, 0.45)).rotation.x = PI / 2
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.5, 0)
	lamp.light_color = Color("ffcf89")
	lamp.light_energy = 1.8
	lamp.omni_range = 6
	add_child(lamp)
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
	var model_names := ["modular_men_Worker", "modular_women_Casual", "modular_men_Adventurer", "modular_women_SciFi"]
	for i in players.size():
		var actor := Node3D.new()
		add_child(actor)
		var visual := Art.spawn(actor, model_names[i % model_names.size()], Vector3.ZERO, Vector3(1, 1.45, 1), true)
		visual.set_script(SurvivorVisual)
		visual._collect(visual)
		actor.position = positions[i]
		actor.rotation.y = PI if i > 1 else 0
		var label := Label3D.new()
		label.text = players[i]["name"] + (" • ВЫ" if i == 0 else "")
		label.position.y = 1.85
		label.font_size = 26
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
		actors.append(actor)



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
	parent.add_child(button)
	return button


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
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
	_button("☰ Меню / пауза", func(): menu.home(), header)
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
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(_label("ДОЛГАЯ ЗИМА", 25))
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
	_button("Следующий этап →", _advance, column)
	_button("Новая партия…", func(): menu.new_game(); menu.visible = true, column)
	log_label = _label("Выберите свою карту для раскрытия. Остальные участники — тестовые персонажи. Новая партия: 40 профессий, 7 характеристик, случайная раздача.", 16)
	column.add_child(log_label)
	var hint := _label("Коснитесь пола: персонаж обойдёт стол и мебель.\nТерминал и аптечка: подойдите и коснитесь предмета.", 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -75)
	hint.size = Vector2(560, 60)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	menu = Menu.new()
	root.add_child(menu)
	menu.setup(self, profile)


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
		if selected == 0 and not card["revealed"] and phase == "reveal" and active.has(0):
			_button("Раскрыть: " + card["label"], func():
				actors[0].get_child(0).gesture = 1.5
				card["revealed"] = true
				_demo_reveals()
				phase = "discussion"
				log_label.text = "Карта раскрыта. Тестовые персонажи тоже открыли по карте. В сети здесь будет общий чат."
				_refresh(), detail)
	if phase == "vote" and selected != 0 and active.has(selected):
		_button("Голосовать (тестовые участники)", _demo_vote, detail)
	if not active.has(selected):
		detail.add_child(_label("Наблюдатель — больше не участвует в голосовании."))


func _demo_reveals() -> void:
	for i in active:
		if i == 0:
			continue
		for card in players[i]["cards"]:
			if not card["revealed"]:
				card["revealed"] = true
				break


func _advance() -> void:
	match phase:
		"reveal":
			log_label.text = "Сначала раскройте одну свою карту."
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
				phase = "reveal"
				log_label.text = "Новый раунд. Откройте следующую характеристику."
		"end":
			log_label.text = "Демонстрация завершена. Можно начать заново."
	_refresh()


func _demo_vote() -> void:
	if phase != "vote" or selected == 0 or not active.has(selected):
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
		if menu.visible:
			menu.visible = false
		else:
			menu.home()
		return
	if menu.visible:
		return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	for item in [{"at": Vector3(3.5, 1, -2.6), "goal": Vector3(2.2, 0, -2.2), "name": "terminal"},
		{"at": Vector3(0.65, 1, 0), "goal": Vector3(0.6, 0, 1.6), "name": "medical"}]:
		if camera.unproject_position(item["at"]).distance_to(point) < 35:
			pending_inspection = item["name"]
			_set_route(item["goal"])
			log_label.text = "Идём осматривать предмет…"
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
	if actors.is_empty() or menu.visible:
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
			actors[0].get_child(0).gesture = 1.5
			if pending_inspection == "terminal":
				log_label.text = "ТЕРМИНАЛ: генератор исправен, запас топлива — 90 суток. Электрик может обслуживать систему. Это факт для обсуждения, не симуляция запасов."
			else:
				log_label.text = "АПТЕЧКА: обнаружены перевязочные материалы. Медицинский специалист поможет оценить их применение."
			pending_inspection = ""
	var departing_ids := departures.keys()
	for id in departing_ids:
		var entry: Dictionary = departures[id]
		var points: PackedVector3Array = entry["path"]
		var index: int = entry["index"]
		var actor: Node3D = actors[id]
		if index >= points.size():
			actor.visible = false
			departures.erase(id)
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(menu):
		menu.home()
