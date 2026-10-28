class_name BunkerSurvival
extends RefCounted
## Explicit optional prototype rule, not a claim about every tabletop edition.

static func resolve(face: int) -> Dictionary:
	assert(face >= 1 and face <= 6, "D6 must be between 1 and 6")
	return {"face": face, "survived": face >= 4}


static func roll(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return resolve(rng.randi_range(1, 6))
