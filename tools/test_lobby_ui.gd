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
 welcome.home()
 check(welcome.lobby_actors.is_empty(), "Leaving removes remote avatars")
 welcome.queue_free()
 await process_frame
 if failures == 0:
  print("Lobby UI smoke test passed")
 quit(1 if failures else 0)
