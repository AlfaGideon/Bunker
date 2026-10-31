extends Node
## Native MediaPlayer is Android-only; no URL is opened in the browser.
var bridge: Object
var status := "stopped"
var poll_time := 0.0
var address := ""

func _ready() -> void:
 if OS.has_feature("android") and Engine.has_singleton("JavaClassWrapper"):
  var wrapper = Engine.get_singleton("JavaClassWrapper")
  bridge = wrapper.wrap("org.bunker.prototype.InternetRadioPlayer")

func play(url: String, volume: float) -> void:
 stop()
 if not url.begins_with("https://"):
  status = "error"
  return
 address = url
 if bridge == null:
  status = "unsupported"
  return
 status = "connecting"
 bridge.play(url, volume)

func stop() -> void:
 if bridge != null:
  bridge.stop()
 status = "stopped"
 address = ""

func set_volume(volume: float) -> void:
 if bridge != null:
  bridge.setVolume(volume)

func _process(delta: float) -> void:
 if bridge == null or address.is_empty():
  return
 poll_time -= delta
 if poll_time <= 0:
  poll_time = 0.5
  status = str(bridge.getState())

func status_text() -> String:
 match status:
  "connecting": return "Подключаемся к интернет-радио…"
  "playing": return "Прямой эфир · интернет-радио"
  "error": return "Нет подключения к станции. Проверьте интернет и нажмите станцию ещё раз."
  "unsupported": return "Интернет-радио доступно в Android-версии игры."
  _: return "Эфир остановлен."

func _exit_tree() -> void:
 stop()
