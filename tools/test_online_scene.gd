extends SceneTree
const Session = preload("res://game/scripts/online_session.gd")
const Content = preload("res://game/scripts/game_content.gd")
class MockClient extends Node:
 signal event_received(data: Dictionary)
 signal status_changed(text: String)
 var opened := true
 var connecting := false
 var sent: Array = []
 func send(data: Dictionary) -> void:
  sent.append(data)
 func disconnect_server() -> void:
  pass
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var client := MockClient.new()
 root.add_child(client)
 var session := Session.new()
 root.add_child(session)
 session.adopt(client, "p1")
 var players: Array = Content.create_players(6, "Host", "male")
 var ids: Array = []
 for i in players.size():
  players[i].id = "p%d" % i
  players[i]["seat"] = i
  ids.append(players[i].id)
  if i != 1:
   for card in players[i].cards:
    if not card.revealed:
     card.erase("value")
     card.erase("cost")
   players[i].erase("sex")
   players[i].erase("age")
 var state := {"revision": 1, "seed": 42, "scenario": Content.scenarios()[0], "players": players,
  "active": ids, "capacity": 3, "round": 1, "phase": "reveal", "speaker": "p1",
  "remaining": 60, "candidates": [], "result": null}
 check(session.state.apply_snapshot(state), "Initial state accepted")
 set_meta("online_session", session)
 set_meta("start_game", true)
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 await process_frame
 check(room.online_active and room.players[0].id == "p1", "Match scene uses the real local participant")
 check(room.speech.speaker() == 0 and room.first_person, "Local speech and default viewpoint")
 var hidden: String = ""
 for card in room.players[0].cards:
  if not card.revealed:
   hidden = card.id
   break
 check(room.reveal_parameter(hidden), "Player can request a reveal")
 check(client.sent[-1].action == "reveal" and not room.speech.revealed, "Server must confirm reveal")
 room.pass_speech()
 check(client.sent[-1].action == "pass", "Passing is sent to server")
 room._complete_interaction("food")
 check(client.sent[-1].action == "food", "Food request goes to the server")
 room._complete_interaction("bed")
 check(client.sent[-1].action == "rest", "Rest request goes to the server")
 room.radio_panel._tune(1)
 check(client.sent[-1].action == "radio_tune" and client.sent[-1].value == "bunkers", "Radio tuning goes to the server")
 var station_state := state.duplicate(true)
 station_state.revision = 2
 station_state.stations = {"meals": 2, "stock": {"food": 100, "water": 100, "medicine": 32, "filters": 24}, "stamina": {"p1": 70}, "radio": {"powered": true, "station": "bunkers", "track_index": 0, "internet_index": 0, "signal_index": 0, "scan_round": 0, "message_id": 0, "received": []}}
 client.event_received.emit({"type": "game_state", "state": station_state})
 check(room.meals == 2 and room.stamina == 70 and room.radio.station == "bunkers", "Shared stations applied from server")
 var next := state.duplicate(true)
 next.revision = 3
 next.speaker = "p2"
 client.event_received.emit({"type": "game_state", "state": next})
 check(room.speech.speaker() == session.state.index_for("p2"), "Remote speech applied")
 var old_count: int = client.sent.size()
 room.pass_speech()
 check(client.sent.size() == old_count, "Cannot skip another player")
 next.revision = 4
 next.phase = "vote"
 next.speaker = null
 next.remaining = 20
 client.event_received.emit({"type": "game_state", "state": next})
 check(room.vote_panel.visible and room.phase == "vote", "Server opens ballot")
 check(room.cast_vote(1) and client.sent[-1].action == "vote", "Vote goes to server")
 room._process(30)
 check(room.phase == "vote", "Local clock cannot resolve a server ballot")
 next.revision = 5
 next.phase = "result"
 next.active = ids.slice(0, 5)
 next.result = {"player": "p5"}
 client.event_received.emit({"type": "game_state", "state": next})
 check(not room.active.has(session.state.index_for("p5")) and not room.vote_panel.visible, "Server elimination applied")
 room.queue_free()
 await process_frame
 print("Online scene failures: ", failures)
 quit(1 if failures else 0)
