extends Node
## Persistent transport owner for the online match. The scene handing over
## the client must disconnect its own lobby callbacks before calling adopt().
signal state_changed(state)
signal connection_lost(message: String)
signal server_error(code: String)
signal player_away(player_id: String)

const State = preload("res://game/scripts/online_match_state.gd")
var state = State.new()
var client: Node
var closed := false

func adopt(lobby_client: Node, player_id: String) -> void:
 assert(client == null and is_instance_valid(lobby_client))
 state.setup(player_id)
 client = lobby_client
 if client.get_parent() != null:
  client.get_parent().remove_child(client)
 add_child(client)
 client.event_received.connect(_on_event)
 client.status_changed.connect(_on_status)
 state.changed.connect(func(): state_changed.emit(state))

func request_state() -> void:
 if not closed and is_instance_valid(client):
  client.send({"type": "game_sync"})

func reveal(card_id: String) -> void:
 _send("reveal", card_id)

func pass_turn() -> void:
 _send("pass", null)

func vote(player_index: int) -> void:
 if player_index >= 0 and player_index < state.ids.size():
  _send("vote", state.ids[player_index])

func _send(action: String, value: Variant) -> void:
 if not closed and is_instance_valid(client):
  client.send({"type": "game_action", "action": action, "value": value})

func _on_event(event: Dictionary) -> void:
 match str(event.get("type", "")):
  "game_state":
   var data: Variant = event.get("state", {})
   if data is Dictionary:
    state.apply_snapshot(data)
  "room_closed":
   closed = true
   connection_lost.emit("Партия завершена: участник отключился.")
  "player_away":
   player_away.emit(str(event.get("player_id", "")))
  "error":
   server_error.emit(str(event.get("code", "unknown")))

func _on_status(message: String) -> void:
 if not closed and is_instance_valid(client) and not client.opened and not client.connecting:
  closed = true
  connection_lost.emit(message)

func close_session() -> void:
 if is_instance_valid(client):
  client.disconnect_server()
 closed = true
 queue_free()

func _exit_tree() -> void:
 if is_instance_valid(client) and not closed:
  client.disconnect_server()
