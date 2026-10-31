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
 check(welcome.lobby_url == "wss://bunker-154de.containers.snapdeploy.app/ws", "Default lobby uses SnapDeploy")
 welcome.lobby_create()
 check(welcome.page == "lobby_connect", "Create lobby page opens")
 welcome._lobby_event({"type": "joined", "player_id": "one", "room": {"host_id": "one", "count": 2, "capacity": 6, "players": [{"id": "one", "name": "Me"}, {"id": "two", "name": "Friend", "skin": "male"}]}})
 for i in 3:
  await process_frame
 check(welcome.page == "lobby_room", "Room page opens")
 check(welcome.lobby_actors.size() == 1, "Remote player appears at camp")
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
   check(node.disabled, "Real guest cannot be presented as a local bot test")
 welcome.home()
 check(welcome.lobby_actors.is_empty(), "Leaving removes remote avatars")
 welcome.queue_free()
 await process_frame
 if failures == 0:
  print("Lobby UI smoke test passed")
 quit(1 if failures else 0)
