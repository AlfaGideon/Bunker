extends SceneTree

const Rules = preload("res://game/scripts/vote_rules.gd")
var failures := 0
var checks := 0


func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	var active := [0, 1, 2, 3]
	check(Rules.resolve(active, {}).status == "no_votes", "Empty ballot")
	check(Rules.resolve(active, {0: 0, 8: 1, 1: 8}).status == "no_votes", "Invalid votes ignored")
	var result := Rules.resolve(active, {0: 1, 2: 1, 3: 2})
	check(result.status == "eliminated" and result.player == 1, "Majority")
	check(result.totals[1] == 2, "Totals")
	result = Rules.resolve(active, {0: 1, 1: 0, 2: 1, 3: 0})
	check(result.status == "runoff" and result.leaders == [0, 1], "First tie")
	check(Rules.resolve(active, {0: 2, 1: 3}, [0, 1], true).status == "no_votes", "Runoff limits")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	result = Rules.resolve(active, {0: 1, 1: 0, 2: 1, 3: 0}, [0, 1], true, rng)
	check(result.status == "eliminated" and result.random, "Second tie randomly resolved")
	check([0, 1].has(result.player), "Random selection limited to leaders")
	check(Rules.resolve([0, 2, 3], {0: 1, 1: 2}).status == "no_votes", "Eliminated cannot vote or receive votes")
	var votes := {0: 1}
	votes[0] = 2
	result = Rules.resolve(active, votes)
	check(result.player == 2 and not result.totals.has(1), "Last vote replaces previous vote")
	result = Rules.resolve(active, {0: 1, 1: 0, 2: 0}, [0, 1], true)
	check(result.player == 0 and not result.random, "Runoff winner without randomness")
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
