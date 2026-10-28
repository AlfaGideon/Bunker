class_name BunkerVoteRules
extends RefCounted
## Local ballot: missing/invalid ballots automatically count for the voter.
static func resolve(active: Array, votes: Dictionary, candidates: Array = [],
		second_ballot: bool = false, rng: RandomNumberGenerator = null) -> Dictionary:
	var allowed: Array = active if candidates.is_empty() else candidates
	var totals := {}
	var counted := {}
	for voter in active:
		var target: Variant = votes.get(voter, voter)
		if not active.has(target) or (target != voter and not allowed.has(target)):
			target = voter
		counted[voter] = target
		totals[target] = int(totals.get(target, 0)) + 1
	if totals.is_empty():
		return {"status": "no_votes", "totals": totals, "leaders": [], "votes": counted}
	var maximum := 0
	var leaders: Array = []
	for candidate in totals:
		if totals[candidate] > maximum:
			maximum = totals[candidate]
			leaders = [candidate]
		elif totals[candidate] == maximum:
			leaders.append(candidate)
	leaders.sort()
	if leaders.size() == 1:
		return {"status": "eliminated", "player": leaders[0], "totals": totals, "votes": counted, "random": false}
	if not second_ballot:
		return {"status": "runoff", "leaders": leaders, "totals": totals, "votes": counted}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return {"status": "eliminated", "player": leaders[rng.randi_range(0, leaders.size() - 1)],
		"totals": totals, "votes": counted, "random": true}
