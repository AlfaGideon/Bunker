extends Node3D
const Cards = preload("res://game/scripts/card_style.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const MAIN := "res://game/main.tscn"
const RUN_START := Vector3(-1.7, 0, 0)
const RUN_END := Vector3(3.95, 0, -1.62)
const STAND_TIME := 0.85
const RUN_TIME := 3.8
const ARRIVAL_TIME := 4.9
var profile
var camp
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
var running := false
var arrived := false
var camera_from: Vector3
var camera_target_from := Vector3(0.7, 1.2, 0)

func _ready() -> void:
 # Reuse the actual welcome scene: same stump, avatar, forest, fire and door.
 # This is a continuation of the camp, not a detached loading animation.
 camp = (load("res://game/welcome.tscn") as PackedScene).instantiate()
 add_child(camp)
 profile = camp.profile
 runner = camp.avatar
 animator = camp.animator
 camera_from = camp.camera.position
 camp.ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
 for button in camp.find_children("*", "Button", true, false):
  button.disabled = true
 if profile.reduced_motion:
  camp.panel.visible = false
  runner.position = RUN_END
  animator.play("Idle")
  arrived = true
 else:
  animator.get_animation("Sit_Chair_StandUp").loop_mode = Animation.LOOP_NONE
  animator.play("Sit_Chair_StandUp", 0.18)
  var slide: Tween = camp.panel.create_tween().set_parallel(true)
  slide.tween_property(camp.panel, "offset_left", camp.panel.offset_left + 750, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
  slide.tween_property(camp.panel, "offset_right", camp.panel.offset_right + 750, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
  slide.tween_property(camp.ui.get_child(0), "modulate:a", 0.0, 0.65)
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
 layer.layer = 5
 add_child(layer)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(root)
 var heading := text(root, "ПОДГОТОВКА ПАРТИИ", 24, Rect2(0.18, 0.04, 0.64, 0.06))
 heading.add_theme_color_override("font_color", Color("f5e6ca"))
 status = text(root, "Готовим убежище…", 16, Rect2(0.2, 0.78, 0.6, 0.05))
 progress = ProgressBar.new()
 root.add_child(progress)
 progress.anchor_left = 0.32
 progress.anchor_right = 0.68
 progress.anchor_top = 0.845
 progress.anchor_bottom = 0.86
 progress.show_percentage = false
 var cancel := Button.new()
 cancel.text = "Вернуться к костру"
 Cards.button(cancel, true)
 cancel.custom_minimum_size = Vector2(230, 48)
 root.add_child(cancel)
 cancel.anchor_left = 0.3
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
 enter.anchor_right = 0.7
 enter.anchor_top = 0.9
 enter.anchor_bottom = 0.97
 enter.pressed.connect(finish)

func advance_cinematic() -> void:
 if profile.reduced_motion:
  return
 var camera_progress := smoothstep(0.0, 1.8, elapsed)
 camp.camera.position = camera_from.lerp(Vector3(7.0, 5.3, 13.0), camera_progress)
 camp.camera.size = lerpf(5.2, 8.0, camera_progress)
 camp.camera.look_at(camera_target_from.lerp(Vector3(1.0, 0.8, -0.6), camera_progress))
 if elapsed >= STAND_TIME and not running:
  running = true
  animator.get_animation("Running_A").loop_mode = Animation.LOOP_LINEAR
  animator.play("Running_A", 0.16)
  var direction := RUN_END - RUN_START
  runner.rotation.y = atan2(direction.x, direction.z)
 if running and not arrived:
  var travel := clampf((elapsed - STAND_TIME) / RUN_TIME, 0.0, 1.0)
  runner.position = RUN_START.lerp(RUN_END, travel)
  if travel >= 1.0:
   arrived = true
   animator.play("Idle", 0.2)

func _process(delta: float) -> void:
 elapsed += delta
 advance_cinematic()
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
 status.text = "Убежище готово" if ready_to_enter else "Готовим убежище: %d / %d" % [total - pending.size(), total]
 if ready_to_enter and (profile.reduced_motion or elapsed >= ARRIVAL_TIME):
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
