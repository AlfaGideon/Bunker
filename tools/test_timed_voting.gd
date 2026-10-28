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
 for i in 10:
  await process_frame
 var panel: Control = room.vote_panel.find_child("VoteCard", true, false)
 check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= root.get_visible_rect().size.y, "Vote card fits the viewport")
 check(room.vote_panel.timer.size.x >= 120 and room.vote_panel.timer.size.y < 60, "Timer is horizontal, not wrapped vertically")
 check(room.vote_panel.skip.get_global_rect().end.y <= panel.get_global_rect().end.y, "Skip action fits inside vote card")
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
 var tie_room = (load("res://game/main.tscn") as PackedScene).instantiate()
 tie_room.profile.player_count = 10
 root.add_child(tie_room)
 tie_room.set_physics_process(false)
 tie_room.menu.visible = false
 tie_room.started = true
 tie_room.start_vote()
 for i in 5:
  await process_frame
 check(tie_room.vote_panel.deck.card_nodes.size() == 10 and tie_room.vote_panel.deck.pages.size() > 1, "Ten candidates accessible through card pages")
 tie_room.ballots.clear()
 for id in tie_room.active:
  tie_room.ballots[id] = 0 if id % 2 == 0 else 1
 tie_room.tick_round_timer(20.0)
 check(tie_room.phase == "vote" and tie_room.vote_second and tie_room.vote_remaining == 20.0, "Tie starts a fresh 20-second runoff")
 check(tie_room.vote_candidates == [0, 1], "Runoff limits explicit candidate choices")
 check(not tie_room.cast_vote(2), "Reject a non-runoff candidate")
 tie_room.ballots.clear()
 for id in tie_room.active:
  tie_room.ballots[id] = 1
 tie_room.tick_round_timer(20.0)
 check(not tie_room.active.has(1) and not tie_room.vote_panel.visible, "Runoff finishes exactly once")
 tie_room.queue_free()
 await process_frame
 print("Timed voting failures: ", failures)
 quit(1 if failures else 0)
