extends Node3D
const Profile = preload("res://game/scripts/local_profile.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const Style = preload("res://game/scripts/avatar_style.gd")
var profile := Profile.new()
var draft_name := ""
var avatar: Node3D
var animator: AnimationPlayer
var fire_light: OmniLight3D
var camp_assets: Node3D
var camera: Camera3D
var ui: Control
var column: VBoxContainer
var page := ""
var clock := 0.0
var error_label: Label
var start_button: Button
var name_input: LineEdit
var appearance_picker: OptionButton
var palette_picker: OptionButton

func mat(color: Color, glow: bool = false) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = 0.9
 if glow:
  material.emission_enabled = true
  material.emission = color
  material.emission_energy_multiplier = 2
 return material

func box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = size
 node.mesh = mesh
 node.position = at
 node.material_override = mat(color)
 add_child(node)
 return node

func _ready() -> void:
 if OS.has_feature("android"):
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
 draft_name = profile.nickname
 build_camp()
 build_ui()
 update_avatar()
 home()

func build_camp() -> void:
 var world := WorldEnvironment.new()
 var environment := Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("101d25")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("93b0c0")
 environment.ambient_light_energy = 0.5
 world.environment = environment
 add_child(world)
 var moon := DirectionalLight3D.new()
 moon.rotation_degrees = Vector3(-48, -25, 0)
 moon.light_color = Color("829ab9")
 moon.light_energy = 0.8
 moon.shadow_enabled = profile.shadows
 add_child(moon)
 box(Vector3(0, -0.16, 0), Vector3(60, 0.3, 60), Color("253b37"))
 # A real little campsite outside the bunker, unrelated to the game world.
 box(Vector3(-1.9, 0.17, -0.15), Vector3(1.8, 0.35, 0.55), Color("534235"))
 for i in 10:
  var angle := float(i) * TAU / 10
  var rock := MeshInstance3D.new()
  var mesh := SphereMesh.new()
  mesh.radius = 0.15
  mesh.height = 0.25
  rock.mesh = mesh
  rock.position = Vector3(cos(angle) * 0.6, 0.08, 1.0 + sin(angle) * 0.6)
  rock.material_override = mat(Color("71807b"))
  add_child(rock)
 camp_assets = preload("res://game/scripts/camp_assets.gd").new()
 add_child(camp_assets)
 fire_light = OmniLight3D.new()
 fire_light.position = Vector3(0, 1.0, 1)
 fire_light.light_color = Color("ffb16c")
 fire_light.light_energy = 2.2
 fire_light.omni_range = 6
 add_child(fire_light)
 box(Vector3(4, 0.6, -3), Vector3(3.8, 1.2, 2), Color("445354"))
 Art.spawn(self, "modular_sci_fi_Door_Single", Vector3(4, 0, -1.98), Vector3(1.4, 1.8, 0.15))
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 5.2
 camera.position = Vector3(6, 4.2, 10)
 add_child(camera)
 camera.look_at(Vector3(0.7, 1.2, 0))
 camera.current = true

func update_avatar() -> void:
 if is_instance_valid(avatar):
  remove_child(avatar)
  avatar.queue_free()
 avatar = Art.spawn(self, "kaykit_Knight" if profile.appearance == "male" else "kaykit_Rogue", Vector3(-1.7, 0, 0), Vector3(1, 1.8, 1), true)
 avatar.rotation.y = 0.8
 Style.apply(avatar, profile.outfit)
 animator = avatar.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
 animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 animator.get_animation("Sit_Chair_Idle").loop_mode = Animation.LOOP_LINEAR
 animator.play("Sit_Chair_Idle")
 animator.advance(0.01)

func _process(delta: float) -> void:
 clock += delta
 if is_instance_valid(animator):
  animator.advance(delta)
 if is_instance_valid(fire_light):
  fire_light.light_energy = 2.1 if profile.reduced_motion else 2.1 + sin(clock * 9) * 0.15 + sin(clock * 17) * 0.1
 if is_instance_valid(camp_assets):
  camp_assets.reduced_motion = profile.reduced_motion

func label(text: String, size: int = 18) -> Label:
 var node := Label.new()
 node.text = text
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size", size)
 column.add_child(node)
 return node

func button(text: String, action: Callable) -> Button:
 var node := Button.new()
 node.text = text
 node.custom_minimum_size.y = 48
 node.pressed.connect(action)
 column.add_child(node)
 return node

func build_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 ui = Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(ui)
 var logo := TextureRect.new()
 logo.texture = preload("res://assets/branding/logo.png")
 logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 logo.position = Vector2(30, 10)
 logo.size = Vector2(380, 175)
 ui.add_child(logo)
 var panel := PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
 panel.offset_left = -480
 panel.offset_right = -30
 panel.offset_top = 25
 panel.offset_bottom = -25
 ui.add_child(panel)
 var theme := Theme.new()
 theme.default_font_size = 18
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.055, 0.115, 0.13, 0.96)
 style.set_corner_radius_all(12)
 for edge in ["left", "right", "top", "bottom"]:
  style.set("content_margin_" + edge, 22)
 theme.set_stylebox("panel", "PanelContainer", style)
 for state in ["normal", "hover", "pressed", "focus"]:
  var button_style := StyleBoxFlat.new()
  button_style.bg_color = Color("263f48") if state == "normal" else Color("375967")
  button_style.border_color = Color("64818a")
  button_style.set_border_width_all(1)
  button_style.set_corner_radius_all(6)
  button_style.content_margin_left = 12
  button_style.content_margin_right = 12
  theme.set_stylebox(state, "Button", button_style)
  theme.set_stylebox(state, "OptionButton", button_style)
 panel.theme = theme
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 column = VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation", 10)
 scroll.add_child(column)

func clear() -> void:
 for child in column.get_children():
  column.remove_child(child)
  child.queue_free()

func home() -> void:
 page = "home"
 clear()
 label("ДОБРО ПОЖАЛОВАТЬ", 26)
 label("У костра перед последним шлюзом", 17)
 label("Никнейм")
 name_input = LineEdit.new()
 name_input.text = draft_name
 name_input.max_length = 20
 name_input.custom_minimum_size.y = 48
 name_input.text_changed.connect(func(value): draft_name = value)
 column.add_child(name_input)
 label("Ваш персонаж")
 appearance_picker = OptionButton.new()
 appearance_picker.add_item("Мужской персонаж")
 appearance_picker.add_item("Женский персонаж")
 appearance_picker.select(0 if profile.appearance == "male" else 1)
 appearance_picker.custom_minimum_size.y = 48
 appearance_picker.item_selected.connect(func(index):
  profile.appearance = "male" if index == 0 else "female"
  update_avatar())
 column.add_child(appearance_picker)
 palette_picker = OptionButton.new()
 for title in ["Одежда: исходная", "Одежда: песочная", "Одежда: холодный графит"]:
  palette_picker.add_item(title)
 palette_picker.select(profile.outfit)
 palette_picker.custom_minimum_size.y = 48
 palette_picker.item_selected.connect(func(index):
  profile.outfit = index
  update_avatar())
 column.add_child(palette_picker)
 start_button = button("НАЧАТЬ ПАРТИЮ", launch)
 var primary := StyleBoxFlat.new()
 primary.bg_color = Color("c29a61")
 primary.set_corner_radius_all(6)
 start_button.add_theme_stylebox_override("normal", primary)
 start_button.add_theme_color_override("font_color", Color("14272e"))
 button("Параметры партии", game_options)
 button("Настройки", settings)
 button("Проверить обновления", func(): preload("res://game/scripts/app_updates.gd").show_updates(self))
 button("Сохранить профиль", save_draft)
 button("Как играть", instructions)
 button("Выйти", func(): get_tree().quit())
 error_label = label("Локальный прототип • 0.13\nПартия начнётся только после нажатия «Начать».", 15)

func save_draft() -> bool:
 var value := draft_name.strip_edges()
 if value.is_empty():
  error_label.text = "Введите непустой никнейм."
  return false
 profile.nickname = value
 if profile.save() != OK:
  error_label.text = "Не удалось сохранить профиль."
  return false
 error_label.text = "Профиль сохранён."
 return true

func launch() -> void:
 if not save_draft():
  return
 start_button.disabled = true
 get_tree().set_meta("start_game", true)
 var result := get_tree().change_scene_to_file("res://game/main.tscn")
 if result != OK:
  get_tree().remove_meta("start_game")
  start_button.disabled = false
  error_label.text = "Не удалось открыть партию."

func game_options() -> void:
 page = "options"
 clear()
 label("ПАРАМЕТРЫ ПАРТИИ", 25)
 label("Число участников")
 var count := OptionButton.new()
 for number in [6, 8, 10]:
  count.add_item(str(number), number)
 count.select([6, 8, 10].find(profile.player_count))
 count.custom_minimum_size.y = 48
 count.item_selected.connect(func(_index): profile.player_count = count.get_selected_id())
 column.add_child(count)
 label("Катастрофа")
 var picker := OptionButton.new()
 picker.add_item("Случайная")
 var scenarios: Array = Content.scenarios()
 for index in scenarios.size():
  picker.add_item(scenarios[index]["title"])
  if scenarios[index]["id"] == profile.scenario_choice:
   picker.select(index + 1)
 picker.custom_minimum_size.y = 48
 picker.item_selected.connect(func(index): profile.scenario_choice = "random" if index == 0 else scenarios[index - 1]["id"])
 column.add_child(picker)
 label("Внешние комнаты, коридоры и карты генерируются только при старте партии.")
 button("Назад", home)

func settings() -> void:
 page = "settings"
 clear()
 label("НАСТРОЙКИ", 25)
 label("Громкость в партии")
 var volume := HSlider.new()
 volume.min_value = 0
 volume.max_value = 1
 volume.step = 0.05
 volume.value = profile.volume
 volume.custom_minimum_size.y = 48
 volume.value_changed.connect(func(value): profile.volume = value)
 column.add_child(volume)
 var narration := CheckButton.new()
 narration.text = "Озвучивать сводку катастрофы"
 narration.button_pressed = profile.narration
 narration.toggled.connect(func(value): profile.narration = value)
 column.add_child(narration)
 var reduced := CheckButton.new()
 reduced.text = "Уменьшить эффекты, ветер и искры"
 reduced.button_pressed = profile.reduced_motion
 reduced.toggled.connect(func(value): profile.reduced_motion = value)
 column.add_child(reduced)
 label("Русскому TTS нужен установленный системный голос Android.", 16)
 button("Назад", home)

func instructions() -> void:
 page = "instructions"
 clear()
 label("ПЕРЕД НАЧАЛОМ", 25)
 label("Настройте имя и внешность у костра. Изменения видны сразу. Сохраните профиль или нажмите «Начать».\nВ бункере: касание — идти, свайп — камера, два пальца — масштаб. Профессия публична, выступления по минуте, рабочие помещения требуют подходящую профессию.\nДругие участники — локальные тестовые фикстуры, не онлайн-игроки. Профиль сохраняется, партия между перезапусками — нет.")
 button("Назад", home)

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  home()
