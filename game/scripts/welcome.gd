extends Node3D
const Catalog = preload("res://game/scripts/avatar_catalog.gd")
const Choice = preload("res://game/scripts/card_choice.gd")
const Deck = preload("res://game/scripts/card_deck.gd")
const Cards = preload("res://game/scripts/card_style.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const Style = preload("res://game/scripts/avatar_style.gd")
const Music = preload("res://game/scripts/music_library.gd")
var profile := Profile.new()
var library_editor: RefCounted
var draft_name := ""
var avatar: Node3D
var animator: AnimationPlayer
var fire_light: OmniLight3D
var camp_assets: Node3D
var camera: Camera3D
var ui: Control
var panel: PanelContainer
var panel_style: StyleBoxFlat
var cards: Array[Button] = []
var column: Container
var page := ""
var clock := 0.0
var animation_step_limit := INF
var error_label: Label
var entrance_nodes: Array[Node] = []
var start_button: Button
var name_input: LineEdit
var appearance_picker: Choice
var palette_picker: Choice
var radio_prop: Node3D
var radio_lamp: OmniLight3D
var radio_dial_material: StandardMaterial3D
var radio_music: AudioStreamPlayer
var radio_track := 0
var radio_hotspot: Button
var radio_caption: Label

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
 build_radio()
 build_ui()
 update_avatar()
 start_radio()
 _update_radio_hotspot()
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
 box(Vector3(0, -0.20, 0), Vector3(60, 0.3, 60), Color("253b37"))
 # A real little campsite outside the bunker, unrelated to the game world.
 box(Vector3(-1.9, 0.20, -0.20), Vector3(1.8, 0.35, 0.55), Color("534235"))
 for i in 10:
  var angle := float(i) * TAU / 10
  var rock := MeshInstance3D.new()
  var mesh := SphereMesh.new()
  mesh.radius = 0.20
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
 var entrance_start := get_child_count()
 # A framed entrance sits in the same camp in both scenes.
 box(Vector3(4, 0.68, -3.05), Vector3(3.8, 1.36, 1.9), Color("455359"))
 box(Vector3(4, 1.48, -3.05), Vector3(4.15, 0.28, 2.1), Color("394c43"))
 for x in [2.35, 5.65]:
  box(Vector3(x, 0.83, -2.04), Vector3(0.25, 1.66, 0.28), Color("7a8987"))
 box(Vector3(4, 1.75, -2.04), Vector3(3.55, 0.25, 0.3), Color("72817f"))
 box(Vector3(4, 0.08, -1.75), Vector3(2.0, 0.16, 0.65), Color("667274"))
 Art.spawn(self, "modular_sci_fi_Door_Single", Vector3(4, 0, -1.98), Vector3(1.4, 1.8, 0.20))
 for child in get_children().slice(entrance_start):
  entrance_nodes.append(child)
 # Authored CC0 grass remains visible in both welcome and the journey.
 var rng := RandomNumberGenerator.new()
 rng.seed = 73147
 var grass: Node3D = Art.spawn(self, "nature_pack_Grass_Short", Vector3(-6, 0, 3), Vector3(0.55, 0.3, 0.55), true)
 for i in 100:
  var x := rng.randf_range(-8, 8)
  var z := rng.randf_range(-4, 4)
  if (x > 1.8 and z < -1.1) or (absf(x) < 2.5 and absf(z) < 1.4):
   continue
  var tuft := grass.duplicate() as Node3D
  tuft.position = Vector3(x, 0, z)
  tuft.rotation.y = rng.randf_range(-PI, PI)
  var scale_factor := rng.randf_range(0.7, 1.4)
  tuft.scale = Vector3.ONE * scale_factor
  add_child(tuft)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 5.2
 camera.position = Vector3(6, 4.2, 10)
 add_child(camera)
 camera.look_at(Vector3(0.7, 1.2, 0))
 camera.current = true

## A working receiver by the bench: in the camp it only plays music, while the
## bunker's own radio also catches other bunkers.
func build_radio() -> void:
 # The receiver stands on its own crate at the edge of the camp, clear of the
 # survivor, so the prop itself is visible and not hidden by the seated model.
 box(Vector3(-2.98, 0.18, 0.92), Vector3(0.66, 0.36, 0.5), Color("4d4136"))
 radio_prop = Node3D.new()
 radio_prop.position = Vector3(-2.98, 0.56, 0.92)
 add_child(radio_prop)
 var body := MeshInstance3D.new()
 var body_mesh := BoxMesh.new()
 body_mesh.size = Vector3(0.66, 0.40, 0.32)
 body.mesh = body_mesh
 body.material_override = mat(Color("4a4038"))
 radio_prop.add_child(body)
 var grille := MeshInstance3D.new()
 var grille_mesh := BoxMesh.new()
 grille_mesh.size = Vector3(0.36, 0.26, 0.04)
 grille.mesh = grille_mesh
 grille.position = Vector3(-0.1, 0.02, 0.17)
 grille.material_override = mat(Color("1d2529"))
 radio_prop.add_child(grille)
 var dial := MeshInstance3D.new()
 var dial_mesh := BoxMesh.new()
 dial_mesh.size = Vector3(0.16, 0.06, 0.03)
 dial.mesh = dial_mesh
 dial.position = Vector3(0.2, 0.11, 0.17)
 radio_dial_material = mat(Color("e0b16a"), true)
 dial.material_override = radio_dial_material
 radio_prop.add_child(dial)
 var knob := MeshInstance3D.new()
 var knob_mesh := CylinderMesh.new()
 knob_mesh.top_radius = 0.05
 knob_mesh.bottom_radius = 0.05
 knob_mesh.height = 0.05
 knob.mesh = knob_mesh
 knob.rotation_degrees = Vector3(90, 0, 0)
 knob.position = Vector3(0.2, -0.09, 0.18)
 knob.material_override = mat(Color("8e7a5f"))
 radio_prop.add_child(knob)
 var antenna := MeshInstance3D.new()
 var antenna_mesh := CylinderMesh.new()
 antenna_mesh.top_radius = 0.008
 antenna_mesh.bottom_radius = 0.012
 antenna_mesh.height = 0.9
 antenna.mesh = antenna_mesh
 antenna.position = Vector3(0.26, 0.62, -0.06)
 antenna.rotation_degrees = Vector3(8, 0, -12)
 antenna.material_override = mat(Color("9aa4a2"))
 radio_prop.add_child(antenna)
 radio_lamp = OmniLight3D.new()
 radio_lamp.position = Vector3(0.2, 0.2, 0.34)
 radio_lamp.light_color = Color("ffcf8a")
 radio_lamp.light_energy = 0.45
 radio_lamp.omni_range = 1.4
 radio_prop.add_child(radio_lamp)


func start_radio() -> void:
 radio_music = AudioStreamPlayer.new()
 radio_music.volume_db = -7
 add_child(radio_music)
 _apply_audio_settings()
 play_track(0)


func _apply_audio_settings() -> void:
 AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, profile.volume)))
 AudioServer.set_bus_mute(0, profile.volume <= 0)


## Camp radio: music only, four records, no bunker chatter at all.
func play_track(index: int) -> void:
 radio_track = posmod(index, Music.count())
 var source := load(Music.path(radio_track)) as AudioStreamWAV
 if source == null or not is_instance_valid(radio_music):
  return
 var stream := source.duplicate() as AudioStreamWAV
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin = 0
 stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
 radio_music.stream = stream
 radio_music.play()
 _update_radio_caption()


func cycle_track() -> void:
 play_track(radio_track + 1)


func _update_radio_caption() -> void:
 if not is_instance_valid(radio_caption):
  return
 radio_caption.text = "РАДИО · " + Music.title(radio_track) + "\nнажми — сменить запись"


func _update_radio_hotspot() -> void:
 if not is_instance_valid(radio_hotspot) or not is_instance_valid(radio_prop) or camera == null:
  return
 # The camp is seen through an orthographic camera, so the tap target follows
 # the prop. Square test viewports would push it off the edge: clamp instead.
 var bounds: Vector2 = ui.size if is_instance_valid(ui) and ui.size.x > 1.0 else get_viewport().get_visible_rect().size
 var point := camera.unproject_position(radio_prop.global_position + Vector3(0, 0.18, 0.1))
 var pill := radio_hotspot.size
 var corner := Vector2(point.x - pill.x * 0.5, point.y + 26.0)
 corner.x = clampf(corner.x, 12.0, maxf(12.0, bounds.x - pill.x - 12.0))
 corner.y = clampf(corner.y, 12.0, maxf(12.0, bounds.y - pill.y - 12.0))
 radio_hotspot.position = corner.round()



func update_avatar() -> void:
 if is_instance_valid(avatar):
  remove_child(avatar)
  avatar.queue_free()
 avatar = Art.spawn(self, Catalog.model(profile.appearance), Vector3(-1.7, 0, 0), Vector3(1, 1.8, 1), true)
 avatar.rotation.y = 0.8
 Style.apply(avatar, profile.outfit, profile.appearance)
 animator = avatar.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
 animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 animator.get_animation("Sit_Chair_Idle").loop_mode = Animation.LOOP_LINEAR
 animator.play("Sit_Chair_Idle")
 animator.advance(0.01)

func _process(delta: float) -> void:
 clock += delta
 if is_instance_valid(animator):
  animator.advance(minf(delta, animation_step_limit))
 if is_instance_valid(fire_light):
  fire_light.light_energy = 2.1 if profile.reduced_motion else 2.1 + sin(clock * 9) * 0.20 + sin(clock * 17) * 0.1
 if is_instance_valid(camp_assets):
  camp_assets.reduced_motion = profile.reduced_motion
 if is_instance_valid(radio_lamp):
  radio_lamp.light_energy = 0.45 if profile.reduced_motion else 0.4 + 0.18 * (0.5 + 0.5 * sin(clock * 2.3))
 if is_instance_valid(radio_dial_material):
  radio_dial_material.emission_energy_multiplier = 1.2 if profile.reduced_motion else 1.1 + 0.5 * (0.5 + 0.5 * sin(clock * 2.3))
 _update_radio_hotspot()

func label(text: String, size: int = 18) -> Label:
 var node := Label.new()
 node.text = text
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size", size)
 add_control(node)
 return node

func button(text: String, action: Callable) -> Button:
 var node := Button.new()
 node.text = text
 node.custom_minimum_size.y = 48
 node.pressed.connect(action)
 Cards.button(node)
 add_control(node)
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
 build_radio_ui()
 panel = PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
 panel.offset_left = -660
 panel.offset_right = -30
 panel.offset_top = 25
 panel.offset_bottom = -25
 ui.add_child(panel)
 var theme := Theme.new()
 theme.default_font_size = 18
 var style := StyleBoxFlat.new()
 panel_style = style
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
 column = VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation", 12)
 panel.add_child(column)

## The camp radio is tapped through a caption pill under the prop: no box is
## drawn over the survivor, and the affordance is the text itself.
func build_radio_ui() -> void:
 radio_hotspot = Button.new()
 radio_hotspot.focus_mode = Control.FOCUS_NONE
 radio_hotspot.custom_minimum_size = Vector2(252, 56)
 radio_hotspot.size = Vector2(252, 56)
 radio_hotspot.text = ""
 radio_hotspot.tooltip_text = "Радио: сменить запись"
 radio_hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 for state in ["normal", "hover", "pressed", "focus"]:
  var pill := StyleBoxFlat.new()
  pill.bg_color = Color(0.035, 0.07, 0.08, 0.86) if state == "normal" else Color(0.06, 0.12, 0.13, 0.94)
  pill.border_color = Color(0.85, 0.65, 0.35, 0.45) if state == "normal" else Color(0.95, 0.78, 0.45, 0.85)
  pill.set_border_width_all(1)
  pill.set_corner_radius_all(11)
  for edge in ["left", "right", "top", "bottom"]:
   pill.set("content_margin_" + edge, 4)
  radio_hotspot.add_theme_stylebox_override(state, pill)
 radio_hotspot.pressed.connect(cycle_track)
 ui.add_child(radio_hotspot)
 radio_caption = Label.new()
 radio_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 radio_caption.add_theme_font_size_override("font_size", 13)
 radio_caption.add_theme_color_override("font_color", Color("e6c793"))
 radio_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 radio_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 radio_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 radio_hotspot.add_child(radio_caption)
 _update_radio_caption()


func add_control(node: Control) -> void:
 if column is Deck:
  column.add_card(node)
 else:
  column.add_child(node)

func clear() -> void:
 cards.clear()
 panel_style.bg_color = Color(0.035, 0.075, 0.09, 0.97)
 if column is Deck:
  column.clear_cards()
 else:
  for child in column.get_children():
   column.remove_child(child)
   child.queue_free()

func subpage() -> void:
 clear()
 panel.remove_child(column)
 column.queue_free()
 var deck := Deck.new()
 deck.page_height = 480
 panel.add_child(deck)
 deck.set_exit(home)
 column = deck

func card(title: String, description: String, action: Callable, target: Container, primary: bool = false) -> Button:
 var node := Button.new()
 node.set_meta("card_control", true)
 node.custom_minimum_size = Vector2(0, 88 if primary else 75)
 node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 node.clip_contents = true
 node.pressed.connect(action)
 for state in ["normal", "hover", "pressed", "focus", "disabled"]:
  var style := StyleBoxFlat.new()
  style.bg_color = Color("b98d53") if primary else Color("142e39")
  if state in ["hover", "focus"]:
   style.bg_color = Color("d2aa70") if primary else Color("244958")
  if state == "pressed":
   style.bg_color = Color("9c733e") if primary else Color("102631")
  style.border_color = Color("dfbd87") if primary else Color("44616a")
  style.set_border_width_all(1)
  style.set_corner_radius_all(14)
  style.shadow_color = Color(0, 0, 0, 0.22)
  style.shadow_size = 5
  node.add_theme_stylebox_override(state, style)
 var margin := MarginContainer.new()
 margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + edge, 16)
 node.add_child(margin)
 var content := VBoxContainer.new()
 content.mouse_filter = Control.MOUSE_FILTER_IGNORE
 margin.add_child(content)
 var heading := Label.new()
 heading.text = title
 heading.add_theme_font_size_override("font_size", 25 if primary else 20)
 heading.add_theme_color_override("font_color", Color("172b31") if primary else Color("edf0e7"))
 heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
 content.add_child(heading)
 var caption := Label.new()
 caption.text = description
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size", 16)
 caption.add_theme_color_override("font_color", Color("294047") if primary else Color("9cb8bc"))
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 content.add_child(caption)
 target.add_child(node)
 cards.append(node)
 node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
 if not profile.reduced_motion:
  node.modulate.a = 0
  node.scale = Vector2(0.97, 0.97)
  var tween := node.create_tween().set_parallel(true)
  tween.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(cards.size() * 0.045)
  tween.tween_property(node, "scale", Vector2.ONE, 0.4).set_delay(cards.size() * 0.045).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 return node

func home() -> void:
 page = "home"
 clear()
 if column is Deck:
  panel.remove_child(column)
  column.queue_free()
  column = VBoxContainer.new()
  column.add_theme_constant_override("separation", 12)
  panel.add_child(column)
 panel_style.bg_color = Color(0, 0, 0, 0)
 label("ПОСЛЕДНИЙ ШЛЮЗ", 28)
 label("У костра перед новым испытанием", 17)
 start_button = card("НАЧАТЬ ИГРУ  →", "Подготовить убежище и новую историю", launch, column, true)
 var grid := GridContainer.new()
 grid.columns = 2
 grid.add_theme_constant_override("h_separation", 12)
 grid.add_theme_constant_override("v_separation", 8)
 column.add_child(grid)
 card("БИБЛИОТЕКА", "Профессии и параметры", open_library, grid)
 card("ПЕРСОНАЖ", draft_name + " • внешность и профиль", edit_profile, grid)
 card("ПАРАМЕТРЫ ПАРТИИ", "Катастрофа и состав группы", game_options, grid)
 card("НАСТРОЙКИ", "Звук, озвучка и эффекты", settings, grid)
 card("ОБНОВЛЕНИЯ", "Проверить новую версию", func(): preload("res://game/scripts/app_updates.gd").show_updates(self), grid)
 card("КАК ИГРАТЬ", "Правила и управление", instructions, grid)
 card("ВЫХОД", "Завершить приложение", func(): get_tree().quit(), grid)
 error_label = label("Локальная партия • " + preload("res://game/scripts/app_updates.gd").VERSION_NAME + " • без сетевого поиска", 15)

func edit_profile() -> void:
 page = "profile"
 subpage()
 label("ВАШ ПЕРСОНАЖ", 27)
 label("Внешность меняется прямо у костра", 17)
 label("Никнейм")
 name_input = LineEdit.new()
 name_input.text = draft_name
 name_input.max_length = 20
 name_input.custom_minimum_size.y = 48
 name_input.text_changed.connect(func(value): draft_name = value)
 add_control(name_input)
 appearance_picker = Choice.new()
 for name in Catalog.NAMES:
  appearance_picker.add_item(name)
 appearance_picker.select(Catalog.index_of(profile.appearance))
 appearance_picker.custom_minimum_size.y = 48
 appearance_picker.item_selected.connect(func(index):
  profile.appearance = Catalog.IDS[index]
  update_avatar())
 add_control(appearance_picker)
 palette_picker = Choice.new()
 for title in ["Одежда: исходная", "Одежда: песочная", "Одежда: холодный графит"]:
  palette_picker.add_item(title)
 palette_picker.select(profile.outfit)
 palette_picker.custom_minimum_size.y = 48
 palette_picker.item_selected.connect(func(index):
  profile.outfit = index
  update_avatar())
 add_control(palette_picker)
 button("Сохранить профиль", save_draft)
 button("Назад к карточкам", home)
 error_label = label("Изменения будут сохранены также при старте партии.", 16)

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
 if not save_draft() or start_button.disabled:
  return
 start_button.disabled = true
 var result := get_tree().change_scene_to_file("res://game/loading.tscn")
 if result != OK:
  start_button.disabled = false
  error_label.text = "Не удалось открыть экран подготовки."

func game_options() -> void:
 page = "options"
 subpage()
 label("ПАРАМЕТРЫ ПАРТИИ", 25)
 label("Число участников")
 var count := Choice.new()
 for number in [6, 8, 10]:
  count.add_item(str(number), number)
 count.select([6, 8, 10].find(profile.player_count))
 count.custom_minimum_size.y = 48
 count.item_selected.connect(func(_index): profile.player_count = count.get_selected_id())
 add_control(count)
 label("Катастрофа")
 var picker := Choice.new()
 picker.add_item("Случайная")
 var scenarios: Array = Content.scenarios()
 for index in scenarios.size():
  picker.add_item(scenarios[index]["title"])
  if scenarios[index]["id"] == profile.scenario_choice:
   picker.select(index + 1)
 picker.custom_minimum_size.y = 48
 picker.item_selected.connect(func(index): profile.scenario_choice = "random" if index == 0 else scenarios[index - 1]["id"])
 add_control(picker)
 label("Внешние комнаты, коридоры и карты генерируются только при старте партии.")
 button("Назад", home)

func settings() -> void:
 page = "settings"
 subpage()
 label("НАСТРОЙКИ", 25)
 label("Громкость в партии")
 var volume := HSlider.new()
 volume.min_value = 0
 volume.max_value = 1
 volume.step = 0.05
 volume.value = profile.volume
 volume.custom_minimum_size.y = 48
 volume.value_changed.connect(func(value):
  profile.volume = value
  _apply_audio_settings())
 add_control(volume)
 var narration := CheckButton.new()
 narration.text = "Озвучивать катастрофу и радио"
 Cards.button(narration)
 narration.button_pressed = profile.narration
 narration.toggled.connect(func(value): profile.narration = value)
 add_control(narration)
 var reduced := CheckButton.new()
 reduced.text = "Уменьшить эффекты, ветер и искры"
 Cards.button(reduced)
 reduced.button_pressed = profile.reduced_motion
 reduced.toggled.connect(func(value): profile.reduced_motion = value)
 add_control(reduced)
 label("Русскому TTS нужен установленный системный голос Android.", 16)
 button("Назад", home)

func instructions() -> void:
 page = "instructions"
 subpage()
 label("ПЕРЕД НАЧАЛОМ", 25)
 label("Настройте имя и внешность у костра. Изменения видны сразу. Сохраните профиль или нажмите «Начать».\nВ бункере: касание — идти, свайп — камера, два пальца — масштаб. Профессия публична, выступления по минуте, рабочие помещения требуют подходящую профессию.\nДругие участники — локальные тестовые фикстуры, не онлайн-игроки. Профиль сохраняется, партия между перезапусками — нет.")
 button("Назад", home)

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  home()

func open_library() -> void:
 if not column is Deck:
  subpage()
 library_editor = preload("res://game/scripts/library_editor.gd").new(self)
 library_editor.show_home()
