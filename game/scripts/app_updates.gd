extends RefCounted

const VERSION_CODE := 13
const VERSION_NAME := "0.13.0"
const REPOSITORY := "https://github.com/AlfaGideon/Bunker"
const API := "https://api.github.com/repos/AlfaGideon/Bunker/releases/latest"

# Trust only the canonical public repository, numeric Android tags and exact APK.
# No GitHub token, signing key or executable script is ever shipped to the client.
static func inspect_release(release: Dictionary, installed: int = VERSION_CODE) -> Dictionary:
 if release.get("draft", false) or release.get("prerelease", false):
  return {}
 var tag: String = str(release.get("tag_name", ""))
 if not tag.begins_with("android-"):
  return {}
 var number := tag.trim_prefix("android-")
 if not number.is_valid_int() or number != str(number.to_int()):
  return {}
 var code := number.to_int()
 if code <= 0:
  return {}
 if code <= installed:
  return {"current": true}
 var expected := REPOSITORY + "/releases/download/" + tag + "/bunker-%d.apk" % code
 var assets: Variant = release.get("assets", [])
 if not assets is Array:
  return {}
 for asset in assets:
  if not asset is Dictionary:
   continue
  var asset_size: Variant = asset.get("size", 0)
  if not (asset_size is int or asset_size is float):
   continue
  if asset.get("name", "") == "bunker-%d.apk" % code and asset.get("browser_download_url", "") == expected and asset_size > 0:
   return {"code": code, "url": expected}
 return {}

static func show_updates(parent: Node, check_network: bool = true) -> ConfirmationDialog:
 parent.get_viewport().gui_embed_subwindows = true
 var dialog := ConfirmationDialog.new()
 dialog.title = "Обновление приложения • " + VERSION_NAME
 dialog.dialog_autowrap = true
 dialog.dialog_text = "Проверяем обновления…"
 dialog.get_label().add_theme_font_size_override("font_size", 20)
 dialog.get_ok_button().text = "Скачать APK"
 dialog.get_ok_button().custom_minimum_size.y = 48
 dialog.get_ok_button().disabled = true
 dialog.get_cancel_button().text = "Закрыть"
 dialog.get_cancel_button().custom_minimum_size.y = 48
 parent.add_child(dialog)
 dialog.popup_centered(Vector2i(620, 340))
 var request := HTTPRequest.new()
 request.timeout = 15.0
 request.body_size_limit = 1024 * 1024
 dialog.add_child(request)
 var download := {"url": ""}
 dialog.canceled.connect(func(): dialog.queue_free())
 dialog.confirmed.connect(func():
  var url: String = download["url"]
  if not url.is_empty():
   OS.shell_open(url)
  dialog.queue_free())
 request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray):
  if result != HTTPRequest.RESULT_SUCCESS:
   dialog.dialog_text = "Не удалось связаться с сервером. Проверьте интернет и попробуйте позже. Игра доступна без сети."
   return
  if status == 404:
   dialog.dialog_text = "Подписанные обновления ещё не опубликованы. Текущая версия: " + VERSION_NAME + "."
   return
  if status != 200:
   dialog.dialog_text = "Сервер обновлений временно недоступен (HTTP %d). Попробуйте позже." % status
   return
  var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
  var update := inspect_release(parsed) if parsed is Dictionary else {}
  if update.get("current", false):
   dialog.dialog_text = "Установлена актуальная версия: " + VERSION_NAME + "."
  elif update.has("url"):
   download["url"] = update["url"]
   dialog.dialog_text = "Доступна сборка №%d.\n\nAPK скачается через браузер с официальной страницы проекта. Затем откройте скачанный файл и подтвердите установку в Android. Если система попросит, разрешите установку из этого браузера. При одинаковой подписи профиль сохраняется.\n\nНе удаляйте приложение для обычного обновления." % update["code"]
   dialog.get_ok_button().disabled = false
  else:
   dialog.dialog_text = "Публикация обновления не прошла проверку формата. Скачивание отключено. Попробуйте позже."
 )
 if not check_network:
  return dialog
 var error := request.request(API, ["Accept: application/vnd.github+json", "User-Agent: Bunker-Android", "X-GitHub-Api-Version: 2022-11-28"])
 if error != OK:
  dialog.dialog_text = "Не удалось начать проверку обновлений. Игра остаётся доступна без сети."
 return dialog
