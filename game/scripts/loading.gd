extends Node3D
const Cards = preload("res://game/scripts/card_style.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const Style = preload("res://game/scripts/avatar_style.gd")
const MAIN := "res://game/main.tscn"
var profile := Profile.new()
var runner: Node3D
var animator: AnimationPlayer
var status: Label
var progress: ProgressBar
var enter: Button
var pending: Array[String] = []
var retained: Array[Resource] = []
var elapsed := 0.0
var ready_to_enter := false
var transitioning := false
var cancel_requested := false
var failed := false
var total := 0

func _ready() -> void:
 var world := WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.background_mode = Environment.BG_COLOR
 world.environment.background_color = Color("0a1820")
 world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color = Color("a6c5cd")
 world.environment.ambient_light_energy = 0.8
 add_child(world)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-50, -30, 0)
 light.light_color = Color("ffe1ad")
 light.light_energy = 1.3
 add_child(light)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 4.8
 camera.position = Vector3(0, 2.3, 12)
 add_child(camera)
 camera.look_at(Vector3(0, 1.0, 0))
 camera.current = true
 for i in range(-12, 13):
  var marker := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = Vector3(0.5, 0.025, 0.06)
  marker.mesh = mesh
  marker.position = Vector3(i, -0.02, 0)
  var material := StandardMaterial3D.new()
  material.albedo_color = Color("816a48")
  material.emission_enabled = true
  material.emission = Color("665037")
  marker.material_override = material
  add_child(marker)
 runner = Art.spawn(self, "kaykit_Knight" if profile.appearance == "male" else "kaykit_Rogue", Vector3(-4.2, 0, 0), Vector3(1, 1.8, 1), true)
 runner.rotation.y = PI / 2
 Style.apply(runner, profile.outfit)
 animator = runner.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
 animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var clip := "Idle" if profile.reduced_motion else "Running_A"
 animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
 animator.play(clip)
 animator.advance(0.01)
 build_ui()
 var assets: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/loading_assets.json"))
 pending.append(MAIN)
 for asset in assets:
  pending.append(str(asset))
 total = pending.size()
 for path in pending:
  var error := ResourceLoader.load_threaded_request(path, "", true)
  if error != OK:
   fail("Не удалось начать загрузку ресурсов. Вернитесь в меню и повторите.")
   return

func text(parent: Node, value: String, size: int, anchors: Rect2) -> Label:
 var label := Label.new()
 label.text = value
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", size)
 parent.add_child(label)
 label.anchor_left = anchors.position.x
 label.anchor_top = anchors.position.y
 label.anchor_right = anchors.end.x
 label.anchor_bottom = anchors.end.y
 return label

func build_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(root)
 text(root, "БУНКЕР  /  ПОСЛЕДНИЙ ШЛЮЗ", 22, Rect2(0.1, 0.06, 0.8, 0.08))
 text(root, "ПОДГОТОВКА ПАРТИИ", 34, Rect2(0.1, 0.16, 0.8, 0.09))
 text(root, "Собираем припасы и открываем убежище", 19, Rect2(0.1, 0.25, 0.8, 0.07))
 status = text(root, "Загружаем модели…", 20, Rect2(0.1, 0.73, 0.8, 0.08))
 progress = ProgressBar.new()
 root.add_child(progress)
 progress.anchor_left = 0.25
 progress.anchor_right = 0.75
 progress.anchor_top = 0.83
 progress.anchor_bottom = 0.85
 progress.show_percentage = false
 var cancel := Button.new()
 cancel.text = "Вернуться к костру"
 Cards.button(cancel, true)
 cancel.custom_minimum_size = Vector2(240, 48)
 root.add_child(cancel)
 cancel.anchor_left = 0.28
 cancel.anchor_right = 0.49
 cancel.anchor_top = 0.9
 cancel.anchor_bottom = 0.97
 cancel.pressed.connect(cancel_loading)
 enter = Button.new()
 enter.text = "Войти сейчас"
 Cards.button(enter, true)
 enter.disabled = true
 root.add_child(enter)
 enter.anchor_left = 0.51
 enter.anchor_right = 0.72
 enter.anchor_top = 0.9
 enter.anchor_bottom = 0.97
 enter.pressed.connect(finish)

func _process(delta: float) -> void:
 elapsed += delta
 if is_instance_valid(animator):
  animator.advance(delta)
 if is_instance_valid(runner):
  runner.position.x = 0.0 if profile.reduced_motion else -4.2 + fmod(elapsed * 3.5, 8.4)
 if failed or transitioning:
  return
 for index in range(pending.size() - 1, -1, -1):
  var path := pending[index]
  var state := ResourceLoader.load_threaded_get_status(path)
  if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
   fail("Ошибка загрузки. Вернитесь к костру и повторите.")
   return
  if state == ResourceLoader.THREAD_LOAD_LOADED:
   retained.append(ResourceLoader.load_threaded_get(path))
   pending.remove_at(index)
 progress.value = 100.0 * float(total - pending.size()) / maxf(1, total)
 ready_to_enter = pending.is_empty()
 if ready_to_enter and cancel_requested:
  transitioning = true
  get_tree().change_scene_to_file("res://game/welcome.tscn")
  return
 enter.disabled = not ready_to_enter
 status.text = "Убежище готово • входим…" if ready_to_enter else "Загружено ресурсов: %d / %d" % [total - pending.size(), total]
 # A short skippable transition, not a simulated online matchmaking wait.
 if ready_to_enter and elapsed >= 2.4:
  finish()

func fail(message: String) -> void:
 failed = true
 status.text = message
 enter.disabled = true

func finish() -> void:
 if not ready_to_enter or transitioning or failed:
  return
 transitioning = true
 get_tree().set_meta("start_game", true)
 var result := get_tree().change_scene_to_packed(load(MAIN) as PackedScene)
 if result != OK:
  get_tree().remove_meta("start_game")
  transitioning = false
  fail("Не удалось открыть партию. Вернитесь в меню.")

func cancel_loading() -> void:
 if transitioning:
  return
 cancel_requested = true
 status.text = "Возвращаемся к костру…"
 if ready_to_enter or failed:
  transitioning = true
  get_tree().change_scene_to_file("res://game/welcome.tscn")

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  cancel_loading()
