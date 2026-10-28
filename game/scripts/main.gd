extends Node3D

const VoteRules = preload("res://game/scripts/vote_rules.gd")
## Local visual prototype. All dossier data is local; no online privacy is provided.

const DATA_PATH = "res://data/prototype.json"
var players: Array = []
var actors: Array[Node3D] = []
var active: Array[int] = [0, 1, 2, 3]
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


func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось прочитать " + DATA_PATH)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	players = data["players"]
	_build_world()
	_build_ui()
	_refresh()


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
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_color = Color("ffe0af")
	light.light_energy = 1.2
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	camera.position = Vector3(9, 13, 13)
	add_child(camera)
	camera.look_at(Vector3(1.8, 0, 0))
	camera.current = true
	_box(Vector3(0, -0.2, 0), Vector3(10, 0.4, 8), Color("34444a"))
	# Back and side walls only: no roof to obstruct the camera.
	_box(Vector3(0, 0.7, -4), Vector3(10, 1.4, 0.25), Color("52646b"))
	_box(Vector3(-5, 0.7, 0), Vector3(0.25, 1.4, 8), Color("52646b"))
	for x in range(-4, 5):
		_box(Vector3(x, 0.006, 0), Vector3(0.018, 0.01, 8), Color("42555b"))
	for z in range(-3, 4):
		_box(Vector3(0, 0.006, z), Vector3(10, 0.01, 0.018), Color("42555b"))
	door = _box(Vector3(0, 0.85, -3.8), Vector3(2.3, 1.7, 0.25), Color("26383e"))
	_box(Vector3(0, 1.8, -3.65), Vector3(2.4, 0.12, 0.12), Color("caa261"))
	_world_label("ШЛЮЗ  /  02 МЕСТА", Vector3(0, 2.25, -3.7))
	_box(Vector3(0, 0.45, 0), Vector3(3.1, 0.9, 1.5), Color("384c4d"))
	_box(Vector3(0, 0.93, 0), Vector3(3.3, 0.12, 1.7), Color("b18a57"))
	_box(Vector3(0, 1.02, 0), Vector3(1.1, 0.04, 0.7), Color("68b7b0"))
	_box(Vector3(-3.7, 0.5, -2.5), Vector3(1.4, 1, 0.8), Color("677d6b"))
	_world_label("ЗАПАСЫ", Vector3(-3.7, 1.35, -2.5), 22)
	_box(Vector3(3.5, 0.65, -2.6), Vector3(1.1, 1.3, 0.8), Color("526671"))
	_world_label("ТЕРМИНАЛ", Vector3(3.5, 1.65, -2.6), 22)
	var positions := [Vector3(-2.5, 0, 1.8), Vector3(2.5, 0, 1.8),
		Vector3(-2.5, 0, -1.5), Vector3(2.5, 0, -1.5)]
	for i in players.size():
		var actor := Node3D.new()
		actor.position = positions[i]
		add_child(actor)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.26
		capsule.height = 1.05
		body.mesh = capsule
		body.position.y = 0.65
		body.material_override = _material(Color(players[i]["color"]))
		actor.add_child(body)
		var label := Label3D.new()
		label.text = players[i]["name"] + (" • ВЫ" if i == 0 else "")
		label.position.y = 1.5
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
	var header := VBoxContainer.new()
	header.position = Vector2(24, 18)
	header.size = Vector2(590, 140)
	root.add_child(header)
	header.add_child(_label("Б У Н К Е Р  /  ПОСЛЕДНИЙ ШЛЮЗ", 25))
	header.add_child(_label("ЛОКАЛЬНЫЙ ПРОТОТИП • НЕ СЕТЕВАЯ ИГРА", 15))
	phase_label = _label("", 20)
	header.add_child(phase_label)
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
	column.add_child(_label("Четверо у шлюза. В убежище хватит места только двоим."))
	var tabs := GridContainer.new()
	tabs.columns = 2
	column.add_child(tabs)
	for i in players.size():
		var index: int = i
		var button := _button(players[i]["name"], func():
			selected = index
			_refresh(), tabs)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	column.add_child(detail)
	status_label = _label("")
	column.add_child(status_label)
	_button("Следующий этап →", _advance, column)
	_button("Начать заново", func(): get_tree().reload_current_scene(), column)
	log_label = _label("Вы — Алекс. Выберите свою карту для раскрытия. Остальные участники — тестовые персонажи.", 16)
	column.add_child(log_label)
	var hint := _label("Нажмите на пол, чтобы переместить Алекса.\nСерые капсулы — выбывшие наблюдатели.", 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -75)
	hint.size = Vector2(560, 60)
	root.add_child(hint)


func _refresh() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var names := {"reveal": "Раскрытие", "discussion": "Обсуждение", "vote": "Голосование", "end": "Итог"}
	phase_label.text = "РАУНД %d  /  %s" % [round_number, names[phase]]
	status_label.text = "У шлюза: %d  •  Мест: 2" % active.size()
	detail.add_child(_label(players[selected]["name"] + (" — ваше досье" if selected == 0 else " — публичное досье"), 21))
	for c in players[selected]["cards"]:
		var card: Dictionary = c
		var visible: bool = selected == 0 or card["revealed"]
		detail.add_child(_label(card["label"] + ": " + (card["value"] if visible else "скрыто")))
		if selected == 0 and not card["revealed"] and phase == "reveal" and active.has(0):
			_button("Раскрыть: " + card["label"], func():
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
	var body := actors[eliminated].get_child(0) as MeshInstance3D
	body.material_override = _material(Color("56616a"))
	if active.size() == 2:
		phase = "end"
		finished = true
		var survivors: Array[String] = []
		for i in active:
			survivors.append(players[i]["name"])
		log_label.text = "В убежище проходят: " + ", ".join(survivors) + ". Это локальный тест, не полноценная партия."
		create_tween().tween_property(door, "position:x", 2.5, 1.2)
	else:
		round_number += 1
		phase = "reveal"
		log_label.text = "Начался новый раунд. Раскройте следующую карту."
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit != null and absf(hit.x) < 4.5 and absf(hit.z) < 3.3:
		# First prototype restricts movement to the front aisle; no navigation claim.
		target = Vector3(clampf(hit.x, -4.3, 4.3), 0, clampf(hit.z, 1.4, 3.2))


func _process(delta: float) -> void:
	clock += delta
	if actors.is_empty():
		return
	actors[0].position = actors[0].position.move_toward(target, delta * 2.5)
	for i in actors.size():
		var body := actors[i].get_child(0) as MeshInstance3D
		body.position.y = 0.65 + sin(clock * 2.0 + i) * 0.035
