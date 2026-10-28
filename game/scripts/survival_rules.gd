class_name BunkerSurvival
extends RefCounted

static func resolve(face: int) -> Dictionary:
 return resolve_choice(face, 6, [4, 5, 6])

static func resolve_choice(face: int, sides: int, chosen: Array) -> Dictionary:
 if sides not in [6, 20] or face < 1 or face > sides or not valid_choice(sides, chosen):
  return {"valid": false}
 return {"valid": true, "face": face, "sides": sides, "chosen": chosen.duplicate(), "survived": face in chosen}

static func valid_choice(sides: int, chosen: Array) -> bool:
 if sides not in [6, 20] or chosen.size() != sides / 2:
  return false
 var unique := {}
 for number in chosen:
  if typeof(number) != TYPE_INT or number < 1 or number > sides or unique.has(number):
   return false
  unique[number] = true
 return true

static func roll(rng: RandomNumberGenerator = null, sides: int = 6, chosen: Array = [4, 5, 6]) -> Dictionary:
 if not valid_choice(sides, chosen):
  return {"valid": false}
 if rng == null:
  rng = RandomNumberGenerator.new()
  rng.randomize()
 return resolve_choice(rng.randi_range(1, sides), sides, chosen)
