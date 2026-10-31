extends SceneTree
const State = preload("res://game/scripts/online_match_state.gd")
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var view := State.new()
 view.setup("b")
 var snapshot := {
  "revision": 1, "seed": 8, "scenario": {"id": "test"}, "capacity": 1,
  "round": 1, "phase": "reveal", "speaker": "a", "remaining": 60,
  "active": ["a", "b"], "candidates": [],
  "players": [
   {"id": "a", "name": "A", "cards": [{"id": "health", "revealed": false}]},
   {"id": "b", "name": "B", "cards": [{"id": "health", "revealed": false, "value": "секрет"}]}
  ]}
 check(view.apply_snapshot(snapshot), "Accept valid snapshot")
 check(view.index_for("b") == 0 and view.index_for("a") == 1, "Local player is always index zero")
 check(view.speaker == 1 and view.active == [1, 0], "Server order is preserved by mapping IDs")
 check(view.players[1].cards[0].value == "скрыто" and view.players[0].cards[0].value == "секрет", "Hidden cards stay hidden")
 view.tick(12)
 check(view.remaining == 48 and view.phase == "reveal", "Clock is display only")
 var stale := snapshot.duplicate(true)
 stale.revision = 0
 check(not view.apply_snapshot(stale) and view.remaining == 48, "Old snapshot ignored")
 var invalid := snapshot.duplicate(true)
 invalid.revision = 2
 invalid.speaker = "missing"
 check(not view.apply_snapshot(invalid) and view.revision == 1, "Invalid snapshot is not partially applied")
 var vote := snapshot.duplicate(true)
 vote.revision = 2
 vote.phase = "vote"
 vote.speaker = null
 vote.candidates = ["a"]
 vote.my_vote = "b"
 check(view.apply_snapshot(vote) and view.candidates == [1] and view.my_vote == 0, "Votes map to local indices")
 print("Online match state failures: ", failures)
 quit(1 if failures else 0)
