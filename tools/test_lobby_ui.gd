extends SceneTree
var failures := 0
func check(ok: bool, title: String) -> void:
 if not ok:
  failures += 1
  push_error(title)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 for i in 4:
  await process_frame
 var invite: Dictionary = welcome._parse_invitation("bunkerinvite://join/0123456789abcdef?server=wss%3A%2F%2Fbunker.back4.app%2Fws")
 check(invite.get("room_id", "") == "0123456789abcdef" and invite.get("server", "") == "wss://bunker.back4.app/ws", "Invite decoded")
 check(welcome._parse_invitation("bunkerinvite://join/xyz?server=wss%3A%2F%2Fx%2Fws").is_empty(), "Invalid room rejected")
 check(welcome._parse_invitation("bunkerinvite://join/0123456789abcdef?server=http%3A%2F%2Fx%2Fws").is_empty(), "Insecure server rejected")
 check(welcome.lobby_url == "wss://alfagideon.blitz.cloud/ws", "Default lobby points at the deployed server")
 check(welcome.lobby_client.http_root_for("wss://alfagideon.blitz.cloud/ws") == "https://alfagideon.blitz.cloud", "HTTPS polling reuses the lobby host")
 check(welcome.lobby_client.http_root_for("wss://bunker.back4.app/ws") == "https://bunker.back4.app", "HTTPS polling follows an invited host")
 check(not welcome.lobby_client.http_fallback and not welcome.lobby_client.http_mode, "Client starts on WebSocket")
 welcome.lobby_create()
 check(welcome.page == "lobby_connect", "Create lobby page opens")
 welcome._lobby_event({"type": "joined", "player_id": "one", "room": {"host_id": "one", "count": 2, "capacity": 6, "players": [{"id": "one", "name": "Me"}, {"id": "two", "name": "Friend", "skin": "male"}]}})
 for i in 3:
  await process_frame
 check(welcome.page == "lobby_room", "Room page opens")
 check(welcome.lobby_actors.size() == 1, "Remote player appears at camp")
 check(welcome.avatar.position.is_equal_approx(Vector3(-1.7, 0, 0)) and welcome.animator.current_animation == "Sit_Chair_Idle", "Local avatar remains seated")
 var fixed_camera: Transform3D = welcome.camera.transform
 welcome._lobby_room_page()
 check(welcome.camera.transform.is_equal_approx(fixed_camera), "Lobby updates never move camera")
 var fire := Vector3(0, 0, 1)
 var toward_camera := Vector3(6, 0, 9).normalized()
 for actor in welcome.lobby_actors:
  check((actor.position - fire).dot(toward_camera) < 0, "Guests are behind the fire")
  check(actor.basis.z.dot((fire - actor.position).normalized()) > 0.99, "Guest faces fire")
 var disabled := false
 for node in welcome.find_children("*", "Button", true, false):
  if node.text == "НАЧАТЬ ИГРУ":
   disabled = node.disabled
 check(disabled, "Incomplete online game cannot be started")
 var bots: Array = [{"id": "one", "name": "Me", "bot": false}]
 for i in 5:
  bots.append({"id": "bot-" + str(i), "name": "Бот " + str(i + 1), "skin": "male", "bot": true})
 welcome.lobby_room = {"host_id": "one", "count": 6, "capacity": 6, "players": bots}
 welcome._lobby_room_page()
 await process_frame
 for node in welcome.find_children("*", "Button", true, false):
  if node.text == "НАЧАТЬ ИГРУ" and not node.is_queued_for_deletion():
   check(not node.disabled, "Full host-only bot test can start")
 bots[1]["bot"] = false
 welcome._lobby_room_page()
 await process_frame
 for node in welcome.find_children("*", "Button", true, false):
  if node.text == "НАЧАТЬ ИГРУ" and not node.is_queued_for_deletion():
   check(not node.disabled, "Host can start a full room with real guests")
 welcome.home()
 check(welcome.lobby_actors.is_empty(), "Leaving removes remote avatars")
 welcome.queue_free()
 await process_frame
 if failures == 0:
  print("Lobby UI smoke test passed")
 quit(1 if failures else 0)
