extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room = (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 room.menu.visible = false
 room.started = true
 for id in room.active:
  room.pass_speech()
 check(room.phase == "discussion" and room.discussion_remaining == 60.0, "Last speech starts 60s discussion")
 room.tick_round_timer(59.5)
 check(room.phase == "discussion" and room.discussion_remaining == 0.5, "Discussion cannot end early")
 room._advance()
 check(room.phase == "discussion", "Advance cannot bypass discussion")
 room.tick_round_timer(0.5)
 check(room.vote_panel.visible and room.vote_remaining == 20.0, "Vote appears automatically in center")
 for i in 4:
  await process_frame
 var panel: Control = room.vote_panel.find_child("VoteCard", true, false)
 check(panel.get_global_rect().end.y <= root.get_visible_rect().size.y, "Vote card fits the viewport")
 check(room.vote_panel.find_children("*", "ScrollContainer", true, false).is_empty(), "No vertical scrolling")
 check(room.vote_panel.deck.card_nodes.size() == room.active.size(), "All active candidates represented")
 check(room.cast_vote(1) and room.ballots[0] == 1, "Player selects candidate")
 room.vote_panel.skip.pressed.emit()
 check(room.ballots[0] == 0, "Skip explicitly votes for self")
 room.ballots.clear()
 for id in room.active:
  if id != 0:
   room.ballots[id] = 0
 room.tick_round_timer(19.5)
 check(room.phase == "vote" and room.active.has(0), "Still voting before deadline")
 room.tick_round_timer(0.5)
 check(room.last_vote_result["votes"][0] == 0 and not room.active.has(0), "Timeout self vote can expel player")
 check(not room.vote_panel.visible and room.departures.has(0), "Expulsion closes vote and starts exit")
 room.queue_free()
 await process_frame
 print("Timed voting failures: ", failures)
 quit(1 if failures else 0)
