extends SceneTree
const Session = preload("res://game/scripts/online_session.gd")
class MockClient extends Node:
 signal event_received(data: Dictionary)
 signal status_changed(text: String)
 var opened := true
 var connecting := false
 var sent: Array = []
 var disconnected := false
 func send(data: Dictionary) -> void:
  sent.append(data)
 func disconnect_server() -> void:
  disconnected = true
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var old_scene := Node.new()
 root.add_child(old_scene)
 var client := MockClient.new()
 old_scene.add_child(client)
 var session := Session.new()
 root.add_child(session)
 session.adopt(client, "one")
 old_scene.queue_free()
 await process_frame
 check(is_instance_valid(client) and client.get_parent() == session, "Connection survives scene transition")
 client.event_received.emit({"type":"game_state", "state": {
  "revision": 1, "phase": "reveal", "speaker": "one", "active": ["one", "two"], "candidates": [],
  "players": [{"id":"one", "cards":[]}, {"id":"two", "cards":[]}]}})
 session.vote(1)
 session.reveal("health")
 session.pass_turn()
 check(client.sent[0].value == "two" and client.sent[1].value == "health" and client.sent[2].action == "pass", "Commands use server IDs")
 client.event_received.emit({"type": "room_closed"})
 session.pass_turn()
 check(client.sent.size() == 3 and session.closed, "No commands sent after room closes")
 session.close_session()
 check(client.disconnected, "Closing explicitly releases the connection")
 await process_frame
 print("Online session failures: ", failures)
 quit(1 if failures else 0)
