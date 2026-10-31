extends Node
## Transport only: lobby snapshots are public, no game state or secrets here.
signal event_received(data: Dictionary)
signal status_changed(text: String)
var socket := WebSocketPeer.new()
var opened := false
var pending: Dictionary = {}
var keepalive := 0.0
var connecting := false

func connect_to(url: String, first_message: Dictionary) -> bool:
 disconnect_server()
 if not url.begins_with("wss://") or not url.ends_with("/ws"):
  status_changed.emit("Нужен защищённый адрес wss://…/ws")
  return false
 socket = WebSocketPeer.new()
 pending = first_message.duplicate(true)
 var err := socket.connect_to_url(url)
 if err != OK:
  status_changed.emit("Не удалось начать подключение: %s" % error_string(err))
  return false
 connecting = true
 status_changed.emit("Подключение к серверу…")
 return true

func send(data: Dictionary) -> void:
 if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  socket.send_text(JSON.stringify(data))

func disconnect_server() -> void:
 if socket.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
  socket.close()
 opened = false
 connecting = false
 pending.clear()

func _process(delta: float) -> void:
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
