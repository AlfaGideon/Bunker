extends SceneTree
## Exercise the actual lobby -> cinematic -> bunker transition over polling.
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 current_scene = welcome
 welcome.lobby_create()
 var client: Node = welcome.lobby_client
 client.http_mode = true
 client.http_root = "http://127.0.0.1:8080"
 client.pending = {"type":"create", "name":"Host", "title":"Room", "capacity":6, "skin":"male"}
 client.connecting = true
 client._http_call("open", {})
 var until := Time.get_ticks_msec() + 20000
 while welcome.page != "lobby_room" and Time.get_ticks_msec() < until:
  await create_timer(0.05).timeout
 if welcome.page != "lobby_room":
  push_error("Failed to join room")
  quit(1)
  return
 for i in 5:
  client.send({"type": "add_bot"})
 until = Time.get_ticks_msec() + 20000
 while int(welcome.lobby_room.get("count", 0)) != 6 and Time.get_ticks_msec() < until:
  await create_timer(0.05).timeout
 if int(welcome.lobby_room.get("count", 0)) != 6:
  push_error("Failed to fill room")
  quit(1)
  return
 client.send({"type":"online_start"})
 until = Time.get_ticks_msec() + 55000
 while (not is_instance_valid(current_scene) or not current_scene.has_method("reveal_parameter")) and Time.get_ticks_msec() < until:
  await create_timer(0.05).timeout
 if not is_instance_valid(current_scene) or not current_scene.has_method("reveal_parameter"):
  push_error("Lobby did not reach bunker scene")
  quit(1)
  return
 var room = current_scene
 check(room.online_active and room.players.size() == 6, "Lobby opened a real online bunker with six players")
 check(room.online_session.client.opened, "Polling connection survived cinematic")
 var hidden := ""
 for card in room.players[0].cards:
  if not card.revealed:
   hidden = card.id
   break
 check(room.reveal_parameter(hidden), "Request reveal")
 until = Time.get_ticks_msec() + 15000
 while not room.speech.revealed and Time.get_ticks_msec() < until:
  await create_timer(0.05).timeout
 check(room.speech.revealed, "Server confirmed reveal in real scene")
 room.pass_speech()
 until = Time.get_ticks_msec() + 15000
 while room.speech.speaker() == 0 and Time.get_ticks_msec() < until:
  await create_timer(0.05).timeout
 check(room.speech.speaker() != 0, "Server advanced to bot")
 print("Live lobby entry failures: ", failures)
 quit(1 if failures else 0)
