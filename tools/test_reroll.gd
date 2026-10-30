extends SceneTree
const Content = preload("res://game/scripts/game_content.gd")
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
 await process_frame
 check(welcome.cards.size() == 8, "Library card appears in main menu")
 welcome.cards[1].pressed.emit()
 await process_frame
 check(welcome.page == "library", "Main menu opens library directly")
 welcome.free()
 await process_frame
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 room.phase = "reveal"
 room.speech.remaining = 37.0
 var old: Dictionary = room.players[0].duplicate(true)
 check(room.reroll_player(0, ["health"]), "One parameter rerolled")
 check(room.players[0].cards[4].value != old.cards[4].value, "Changed health value")
 check(room.players[0].cards[0] == old.cards[0], "Other cards unchanged")
 check(room.players[0].cards[4].revealed == old.cards[4].revealed, "Privacy unchanged")
 check(room.speech.remaining == 37.0, "Reroll does not reset speech timer")
 var ids: Array = []
 for card in room.players[1].cards:
  ids.append(card.id)
 room.players[1].cards[1].revealed = true
 old = room.players[1].duplicate(true)
 check(room.reroll_player(1, ids), "All parameters rerolled")
 for i in old.cards.size():
  check(room.players[1].cards[i].value != old.cards[i].value, "All values changed")
  check(room.players[1].cards[i].revealed == old.cards[i].revealed, "Existing visibility preserved")
 check(room.players[1].age == int(room.players[1].cards[1].value.get_slice(", ", 1).get_slice(" ", 0)), "Biology metadata updated")
 check(room.actors[1].get_meta("appearance") == room.biology_appearance(1), "Public biology updates appearance")
 room.phase = "vote"
 check(not room.reroll_player(0, ["health"]), "No rerolls during vote")
 room.phase = "reveal"
 room.active.erase(2)
 check(not room.reroll_player(2, ["health"]), "No reroll for eliminated player")
 room.menu.show_reroll()
 check(room.menu.page == "reroll", "Local reroll menu accessible")
 room.free()
 await process_frame
 print("Reroll failures: ", failures)
 quit(1 if failures else 0)
