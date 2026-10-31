extends Node
## WebSockets elsewhere; SnapDeploy's free tier needs HTTPS polling.
signal event_received(data: Dictionary)
signal status_changed(text: String)
var socket := WebSocketPeer.new()
var opened := false
var pending: Dictionary = {}
var keepalive := 0.0
var connecting := false
var http_mode := false
var http_root := ""
var http_token := ""
var http_queue: Array[Dictionary] = []
var http_request: HTTPRequest
var http_action := ""
var http_wait := 0.0

func _ready() -> void:
 http_request = HTTPRequest.new()
 http_request.timeout = 100.0
 add_child(http_request)
 http_request.request_completed.connect(_http_completed)

func connect_to(url: String, first_message: Dictionary) -> bool:
 disconnect_server()
 if not url.begins_with("wss://") or not url.ends_with("/ws"):
  status_changed.emit("Нужен защищённый адрес wss://…/ws")
  return false
 pending = first_message.duplicate(true)
 connecting = true
 status_changed.emit("Подключение к серверу…")
 if url.begins_with("wss://bunker-154de.containers.snapdeploy.app/"):
  http_mode = true
  http_root = "https://" + url.trim_prefix("wss://").trim_suffix("/ws")
  _http_call("open", {})
  return true
 socket = WebSocketPeer.new()
 var err := socket.connect_to_url(url)
 if err != OK:
  connecting = false
  status_changed.emit("Не удалось начать подключение: %s" % error_string(err))
  return false
 return true

func send(data: Dictionary) -> void:
 if http_mode:
  if opened:
   http_queue.append(data.duplicate(true))
 elif socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  socket.send_text(JSON.stringify(data))

func _http_call(action: String, data: Dictionary) -> void:
 if http_action != "":
  return
 http_action = action
 var headers := PackedStringArray(["Content-Type: application/json"])
 if not http_token.is_empty():
  headers.append("X-Lobby-Session: " + http_token)
 var err := http_request.request(http_root + "/transport/" + action, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
 if err != OK:
  http_action = ""
  _http_fail()

func _http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 var action := http_action
 http_action = ""
 if not http_mode or action.is_empty():
  return
 var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
 if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not payload is Dictionary:
  _http_fail()
  return
 if action == "open":
  http_token = str(payload.get("session", ""))
  if http_token.is_empty():
   _http_fail()
   return
  connecting = false
  opened = true
  status_changed.emit("Соединение установлено")
  if not pending.is_empty():
   http_queue.append(pending.duplicate(true))
   pending.clear()
 else:
  var events: Variant = payload.get("events", [])
  if events is Array:
   for item in events:
    if item is Dictionary:
     event_received.emit(item)
 http_wait = 0.0

func _http_fail() -> void:
 opened = false
 connecting = false
 http_mode = false
 http_token = ""
 http_queue.clear()
 status_changed.emit("Соединение потеряно. Проверьте сервер и его настройки.")

func disconnect_server() -> void:
 if http_mode and is_instance_valid(http_request):
  http_request.cancel_request()
  http_action = ""
  if not http_token.is_empty():
   # Fire-and-forget; the server also expires disconnected sessions.
   var closer := HTTPRequest.new()
   closer.timeout = 5.0
   get_tree().root.add_child(closer)
   closer.request_completed.connect(func(_r, _c, _h, _b): closer.queue_free())
   var err := closer.request(http_root + "/transport/close", PackedStringArray(["Content-Type: application/json", "X-Lobby-Session: " + http_token]), HTTPClient.METHOD_POST, "{}")
   if err != OK:
    closer.queue_free()
 if socket.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
  socket.close()
 opened = false
 connecting = false
 http_mode = false
 http_token = ""
 http_queue.clear()
 pending.clear()

func _process(delta: float) -> void:
 if http_mode:
  if opened and http_action.is_empty():
   if not http_queue.is_empty():
    _http_call("send", http_queue.pop_front())
   else:
    http_wait += delta
    if http_wait >= 1.0:
     http_wait = 0.0
     _http_call("poll", {})
  return
 if not connecting and not opened:
  return
 socket.poll()
 var state := socket.get_ready_state()
 if state == WebSocketPeer.STATE_OPEN:
  if not opened:
   opened = true
   connecting = false
   keepalive = 0.0
   status_changed.emit("Соединение установлено")
   if not pending.is_empty():
    send(pending)
    pending.clear()
  keepalive += delta
  if keepalive >= 20.0:
   keepalive = 0.0
   send({"type": "ping"})
  while socket.get_available_packet_count() > 0:
   var result: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if result is Dictionary:
    event_received.emit(result)
 elif state == WebSocketPeer.STATE_CLOSED:
  opened = false
  connecting = false
  status_changed.emit("Соединение потеряно. Проверьте адрес и срок его действия.")
