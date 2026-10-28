extends Control
const Updates = preload("res://game/scripts/app_updates.gd")
const Cards = preload("res://game/scripts/card_style.gd")
var request: HTTPRequest
var headline: Label
var detail: Label
var latest: Label
var action: Button
var retry: Button
var release_url := ""
var api_fallback := false

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
 column.add_theme_constant_override("separation", 14)
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
 var subtitle := label("ПОСЛЕДНИЙ ШЛЮЗ  /  ANDROID", 14, Color("b9d1d0"))
 column.add_child(subtitle)
 var versions := HBoxContainer.new()
 versions.add_theme_constant_override("separation", 12)
 column.add_child(versions)
 version_card(versions, "УСТАНОВЛЕНА", Updates.VERSION_NAME + "  •  №" + str(Updates.VERSION_CODE))
 latest = version_card(versions, "ПОСЛЕДНИЙ РЕЛИЗ", "Проверяем…")
 headline = label("Проверяем обновления…", 23, Color("f1d4a3"))
 column.add_child(headline)
 detail = label("Соединяемся с официальной страницей проекта.", 16, Color("c4d7d6"))
 detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(detail)
 var footer := HBoxContainer.new()
 footer.name = "Actions"
 footer.add_theme_constant_override("separation", 12)
 column.add_child(footer)
 retry = make_button("Проверить ещё раз", 210)
 retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(retry)
 retry.pressed.connect(check_for_updates)
 action = make_button("Открыть релиз  →", 210)
 action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(action)
 action.disabled = true
 action.pressed.connect(func():
  if not release_url.is_empty():
   OS.shell_open(release_url))
 request = HTTPRequest.new()
 request.timeout = 12.0
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
 var text := label(value, 20, Color("f5eee0"))
 column.add_child(text)
 return text

func make_button(text: String, width: float) -> Button:
 var button := Button.new()
 button.text = text
 Cards.button(button, true)
 button.custom_minimum_size = Vector2(width, 52)
 button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 return button

func dismiss() -> void:
 get_parent().queue_free()

func check_for_updates() -> void:
 request.cancel_request()
 api_fallback = false
 release_url = ""
 action.disabled = true
 retry.disabled = true
 headline.text = "Проверяем обновления…"
 latest.text = "Проверяем…"
 detail.text = "Соединяемся с официальной страницей проекта."
 var error := request.request(Updates.LATEST, ["User-Agent: Bunker-Android", "Cache-Control: no-cache"], HTTPClient.METHOD_HEAD)
 if error != OK:
  start_api_fallback()

func start_api_fallback() -> void:
 api_fallback = true
 request.max_redirects = 0
 var error := request.request(Updates.API, ["Accept: application/vnd.github+json", "User-Agent: Bunker-Android", "X-GitHub-Api-Version: 2022-11-28"])
 if error != OK:
  show_error()

func completed(result: int, status: int, headers: PackedStringArray, body: PackedByteArray) -> void:
 var info := {}
 if not api_fallback:
  if result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED or result == HTTPRequest.RESULT_SUCCESS:
   info = Updates.inspect_redirect(status, headers)
  if info.is_empty():
   start_api_fallback()
   return
 else:
  if result == HTTPRequest.RESULT_SUCCESS and status == 200:
   var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
   if parsed is Dictionary:
    info = Updates.inspect_release(parsed)
  if info.is_empty():
   show_error()
   return
 show_result(info)

func show_result(info: Dictionary) -> void:
 action.disabled = true
 release_url = ""
 retry.disabled = false
 latest.text = "Сборка №" + str(info["code"])
 if info.get("current", false):
  headline.text = "У вас актуальная версия"
  detail.text = "Новых опубликованных сборок нет. Играть можно и без интернета."
 else:
  release_url = info["url"]
  action.disabled = false
  headline.text = "Доступно обновление!"
  detail.text = "Откройте официальный релиз, скачайте APK и подтвердите установку в Android. Не удаляйте приложение."

func show_error() -> void:
 action.disabled = true
 release_url = ""
 retry.disabled = false
 latest.text = "Не удалось проверить"
 headline.text = "Нет связи с обновлениями"
 detail.text = "Проверьте интернет и попробуйте ещё раз. Игра доступна без сети."

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  dismiss()
