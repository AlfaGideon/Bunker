extends Control
const Updates = preload("res://game/scripts/app_updates.gd")
const Cards = preload("res://game/scripts/card_style.gd")
const MAX_BYTES := 200 * 1024 * 1024
const DIR := "user://updates"
var request: HTTPRequest
var headline: Label
var detail: Label
var latest: Label
var progress: ProgressBar
var action: Button
var retry: Button
var state := "idle"
var offer: Dictionary = {}
var latest_code := 0
var apk_path := ""
var part_path := ""

func setup(check_network: bool = true) -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var shade := ColorRect.new()
 shade.color = Color(0.015, 0.035, 0.045, 0.82)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(center)
 var panel := PanelContainer.new()
 panel.name = "UpdateCard"
 panel.custom_minimum_size = Vector2(760, 430)
 var style := Cards.panel()
 style.bg_color = Color("102b35")
 style.border_color = Color("64838a")
 style.set_corner_radius_all(20)
 for edge in ["left", "right", "top", "bottom"]:
  style.set("content_margin_" + edge, 28)
 panel.add_theme_stylebox_override("panel", style)
 center.add_child(panel)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 panel.add_child(column)
 var header := HBoxContainer.new()
 column.add_child(header)
 var title := label("ОБНОВЛЕНИЯ", 27, Color("f5eee0"))
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 var close := make_button("✕", 52)
 close.tooltip_text = "Закрыть"
 header.add_child(close)
 close.pressed.connect(dismiss)
 column.add_child(label("ПОСЛЕДНИЙ ШЛЮЗ  /  ANDROID", 14, Color("b9d1d0")))
 var versions := HBoxContainer.new()
 versions.add_theme_constant_override("separation", 12)
 column.add_child(versions)
 version_card(versions, "УСТАНОВЛЕНА", Updates.VERSION_NAME + "  •  №" + str(Updates.VERSION_CODE))
 latest = version_card(versions, "ПОСЛЕДНИЙ РЕЛИЗ", "Проверяем…")
 headline = label("Проверяем обновления…", 23, Color("f1d4a3"))
 column.add_child(headline)
 detail = label("Соединяемся с сервером обновлений.", 16, Color("c4d7d6"))
 detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(detail)
 progress = ProgressBar.new()
 progress.custom_minimum_size.y = 18
 progress.show_percentage = false
 progress.visible = false
 column.add_child(progress)
 var footer := HBoxContainer.new()
 footer.name = "Actions"
 footer.add_theme_constant_override("separation", 12)
 column.add_child(footer)
 retry = make_button("Проверить ещё раз", 210)
 retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(retry)
 retry.pressed.connect(check_for_updates)
 action = make_button("Скачать обновление", 210)
 action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(action)
 action.disabled = true
 action.pressed.connect(on_action)
 request = HTTPRequest.new()
 request.timeout = 20
 request.body_size_limit = 1024 * 1024
 request.max_redirects = 0
 add_child(request)
 request.request_completed.connect(completed)
 Cards.animate(panel)
 if check_network:
  check_for_updates()

func label(value: String, font_size: int, color: Color) -> Label:
 var node := Label.new()
 node.text = value
 node.add_theme_font_size_override("font_size", font_size)
 node.add_theme_color_override("font_color", color)
 return node

func version_card(parent: HBoxContainer, heading: String, value: String) -> Label:
 var card := PanelContainer.new()
 card.add_theme_stylebox_override("panel", Cards.panel())
 card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(card)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 5)
 card.add_child(column)
 column.add_child(label(heading, 13, Color("9ebcbf")))
 var value_label := label(value, 20, Color("f5eee0"))
 column.add_child(value_label)
 return value_label

func make_button(text: String, width: float) -> Button:
 var result := Button.new()
 result.text = text
 Cards.button(result, true)
 result.custom_minimum_size = Vector2(width, 52)
 result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 return result

func dismiss() -> void:
 if state == "download":
  request.cancel_request()
  remove_partial()
 get_parent().queue_free()

func remove_partial() -> void:
 if not part_path.is_empty() and FileAccess.file_exists(part_path):
  DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))

func check_for_updates() -> void:
 request.cancel_request()
 remove_partial()
 state = "latest"
 offer = {}
 latest_code = 0
 apk_path = ""
 request.download_file = ""
 request.max_redirects = 0
 request.timeout = 20
 request.body_size_limit = 1024 * 1024
 action.disabled = true
 retry.disabled = true
 progress.visible = false
 headline.text = "Проверяем обновления…"
 latest.text = "Проверяем…"
 detail.text = "Соединяемся с сервером обновлений."
 var error := request.request(Updates.LATEST, ["User-Agent: Bunker-Android", "Cache-Control: no-cache"], HTTPClient.METHOD_HEAD)
 if error != OK:
  start_metadata()

func start_metadata() -> void:
 state = "metadata"
 request.download_file = ""
 request.max_redirects = 0
 var error := request.request(Updates.API, ["Accept: application/vnd.github+json", "User-Agent: Bunker-Android"])
 if error != OK:
  start_checksums()

func start_checksums() -> void:
 if latest_code <= Updates.VERSION_CODE:
  show_error("Не удалось получить данные обновления. Проверьте интернет и попробуйте ещё раз.")
  return
 state = "checksums"
 request.download_file = ""
 request.max_redirects = 5
 request.body_size_limit = 16384
 var url: String = Updates.REPOSITORY + "/releases/download/android-%d/SHA256SUMS" % latest_code
 if request.request(url, ["User-Agent: Bunker-Android"]) != OK:
  show_error("Не удалось проверить файл обновления. Попробуйте ещё раз.")

func completed(result: int, status: int, headers: PackedStringArray, body: PackedByteArray) -> void:
 if state == "latest":
  var info := {}
  if result in [HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED, HTTPRequest.RESULT_SUCCESS]:
   info = Updates.inspect_redirect(status, headers)
  if info.is_empty():
   start_metadata()
  elif info.get("current", false):
   show_result(info)
  else:
   latest_code = info["code"]
   start_metadata()
 elif state == "metadata":
  var info := {}
  if result == HTTPRequest.RESULT_SUCCESS and status == 200:
   var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
   if parsed is Dictionary:
    info = Updates.inspect_release(parsed)
  if not info.is_empty() and (latest_code == 0 or int(info.get("code", 0)) == latest_code):
   show_result(info)
  else:
   start_checksums()
 elif state == "checksums":
  var info := Updates.inspect_checksums(latest_code, body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and status == 200 else {}
  if info.is_empty():
   show_error("Не удалось проверить контрольную сумму обновления.")
  else:
   show_result(info)
 elif state == "download":
  if result != HTTPRequest.RESULT_SUCCESS or status != 200:
   remove_partial()
   show_error("Загрузка прервалась. Проверьте интернет и свободное место, затем попробуйте снова.")
   return
  headline.text = "Проверяем файл…"
  if not Updates.verified_file(part_path, str(offer["sha256"]), int(offer.get("size", 0))):
   remove_partial()
   show_error("Файл повреждён или не прошёл проверку. Скачайте его ещё раз.")
   return
  if FileAccess.file_exists(apk_path):
   DirAccess.remove_absolute(ProjectSettings.globalize_path(apk_path))
  var renamed := DirAccess.rename_absolute(ProjectSettings.globalize_path(part_path), ProjectSettings.globalize_path(apk_path))
  if renamed != OK:
   remove_partial()
   show_error("Не удалось сохранить обновление. Проверьте свободное место.")
   return
  state = "ready"
  progress.visible = false
  headline.text = "Обновление скачано"
  detail.text = "Нажмите «Обновить». Android попросит подтвердить установку; браузер не нужен."
  action.text = "Обновить  →"
  action.disabled = false
  retry.disabled = false

func show_result(info: Dictionary) -> void:
 action.disabled = true
 retry.disabled = false
 progress.visible = false
 latest.text = "Сборка №" + str(info["code"])
 if info.get("current", false):
  state = "current"
  headline.text = "У вас актуальная версия"
  detail.text = "Новых опубликованных сборок нет. Играть можно и без интернета."
 elif Updates.valid_apk(info):
  offer = info.duplicate(true)
  state = "available"
  headline.text = "Доступно обновление!"
  detail.text = "Загрузим обновление прямо в игре и проверим его. После загрузки появится кнопка «Обновить»."
  action.text = "Скачать обновление"
  action.disabled = false
 else:
  show_error("Нет проверенных данных об APK. Попробуйте ещё раз.")

func on_action() -> void:
 if state == "available":
  start_download()
 elif state == "ready":
  install_update()

func start_download() -> void:
 if not Updates.valid_apk(offer):
  show_error("Неверные данные обновления.")
  return
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR)) != OK:
  show_error("Не удалось создать папку обновлений.")
  return
 apk_path = DIR.path_join("bunker-%d.apk" % int(offer["code"]))
 part_path = apk_path + ".part"
 remove_partial()
 state = "download"
 retry.disabled = true
 action.disabled = true
 progress.value = 0
 progress.visible = true
 headline.text = "Загружаем обновление…"
 detail.text = "Загрузка внутри приложения. Не закрывайте это окно."
 request.download_file = part_path
 request.body_size_limit = MAX_BYTES
 request.max_redirects = 5
 request.timeout = 300
 var error := request.request(str(offer["apk_url"]), ["User-Agent: Bunker-Android"])
 if error != OK:
  remove_partial()
  show_error("Не удалось начать загрузку. Проверьте интернет.")

func _process(_delta: float) -> void:
 if state != "download":
  return
 var bytes := request.get_downloaded_bytes()
 var total: int = int(offer.get("size", 0))
 if total <= 0:
  total = request.get_body_size()
 if bytes > MAX_BYTES or total > MAX_BYTES:
  request.cancel_request()
  remove_partial()
  show_error("Файл обновления слишком велик.")
  return
 if total > 0:
  progress.value = clampf(100.0 * float(bytes) / float(total), 0.0, 100.0)
  detail.text = "Загружено %.1f из %.1f МБ" % [bytes / 1048576.0, total / 1048576.0]
 else:
  detail.text = "Загружено %.1f МБ" % (bytes / 1048576.0)

func install_update() -> void:
 if OS.get_name() != "Android":
  detail.text = "Установка APK доступна только на Android."
  return
 if not Updates.verified_file(apk_path, str(offer.get("sha256", "")), int(offer.get("size", 0))):
  show_error("Файл обновления отсутствует или повреждён. Скачайте его снова.")
  return
 # Godot's Android FileProvider grants Android's package installer read access
 # to this private app file. This never opens a web page or a browser.
 var error := OS.shell_open(ProjectSettings.globalize_path(apk_path))
 if error != OK:
  detail.text = "Не удалось запустить установщик Android. Разрешите этой игре установку неизвестных приложений в настройках Android и нажмите «Обновить» снова."
 else:
  detail.text = "Подтвердите обновление в Android. Если система попросит разрешение, разрешите установку из этой игры и нажмите «Обновить» снова."

func show_error(message: String = "Проверьте интернет и попробуйте ещё раз.") -> void:
 state = "error"
 action.disabled = true
 retry.disabled = false
 progress.visible = false
 latest.text = "Не удалось проверить" if latest_code == 0 else "Сборка №" + str(latest_code)
 headline.text = "Не удалось обновить"
 detail.text = message

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  dismiss()
