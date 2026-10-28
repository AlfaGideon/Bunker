extends SceneTree
const Rules = preload("res://game/scripts/negative_actions.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 await process_frame
 var card: Dictionary = Rules.quality_card(room.players[0])
 card["value"] = "Спокойный"
 check(Rules.available(room.players[0]).is_empty(), "Positive personality has no negative actions")
 check(not room.perform_negative_action("quarrel"), "API rejects missing trait")
 card["value"] = "Вспыльчивый"
 card["revealed"] = false
 var water: int = room.supplies.stock["water"]
 check(not room.perform_negative_action("unknown"), "Unknown action rejected")
 room.menu.show_negative_actions()
 var start: Button
 for child in room.menu.column.find_children("*", "Button", true, false):
  if child is Button and child.text == "Устроить ссору":
   start = child
 check(is_instance_valid(start) and not start.disabled, "Matching flaw enables actual menu button")
 if is_instance_valid(start):
  start.pressed.emit()
  var confirm: Button
  for child in room.menu.column.find_children("*", "Button", true, false):
   if child is Button and child.text == "Подтвердить":
    confirm = child
  check(is_instance_valid(confirm), "Harmful action needs confirmation")
  if is_instance_valid(confirm):
   confirm.pressed.emit()
 check(room.supplies.stock["water"] == water - 3 and card["revealed"], "Group loss and public consequence")
 check(not room.perform_negative_action("quarrel"), "Once per round, no repeated drain")
 room.round_number += 1
 room.phase = "vote"
 check(not room.perform_negative_action("quarrel"), "No sabotage during vote")
 room.phase = "reveal"
 room.supplies.stock["water"] = 2
 check(not room.perform_negative_action("quarrel"), "Insufficient stock is not spent")
 for pair in [["Эгоистичный", "hoard"], ["Небрежный", "neglect"], ["Упрямый", "neglect"]]:
  card["value"] = pair[0]
  check(pair[1] in Rules.available(room.players[0]), "Specific flaw unlocks specific action")
  check("quarrel" not in Rules.available(room.players[0]), "Unrelated flaw does not unlock quarrel")
 card["value"] = "Эгоистичный"
 check(room.perform_negative_action("hoard"), "Selfish action uses food")
 room.active.erase(0)
 room.round_number += 1
 check(not room.perform_negative_action("hoard"), "Expelled player cannot act")
 room.free()
 print("Negative actions failures: ", failures)
 quit(1 if failures else 0)
