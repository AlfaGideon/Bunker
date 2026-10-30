extends SceneTree
const Rules = preload("res://game/scripts/vote_rules.gd")
var failures := 0
func check(condition: bool, title: String) -> void:
 if not condition:
  failures += 1
  push_error(title)
func _initialize() -> void:
 var active := [0, 1, 2, 3]
 var result := Rules.resolve(active, {})
 check(result.status == "runoff" and result.leaders == active, "Every missed vote counts for its owner")
 check(result.votes == {0: 0, 1: 1, 2: 2, 3: 3}, "Missing votes do not disappear")
 result = Rules.resolve(active, {0: 0, 1: 0, 2: 0, 3: 2, 8: 0})
 check(result.status == "eliminated" and result.player == 0 and result.totals[0] == 3, "Self votes and explicit votes count")
 result = Rules.resolve(active, {0: 99, 1: 0, 2: 0, 3: 0})
 check(result.player == 0 and result.votes[0] == 0, "Invalid target becomes self vote")
 result = Rules.resolve(active, {0: 1, 1: 0, 2: 1, 3: 0})
 check(result.status == "runoff" and result.leaders == [0, 1], "First tie opens runoff")
 var rng := RandomNumberGenerator.new()
 rng.seed = 42
 result = Rules.resolve(active, {0: 1, 1: 0, 2: 1, 3: 0}, [0, 1], true, rng)
 check(result.status == "eliminated" and result.random and [0, 1].has(result.player), "Repeated tie resolves once")
 result = Rules.resolve(active, {0: 1, 1: 0, 2: 3}, [0, 1], true, rng)
 check(result.votes[2] == 2 and result.votes[3] == 3, "Runoff missed or invalid vote still goes to self")
 check(Rules.resolve([], {}).status == "no_votes", "Empty roster")
 print("Vote rules failures: ", failures)
 quit(1 if failures else 0)
