extends RefCounted

var order: Array = []
var index := 0
var remaining := 60.0
var revealed := false
var finished := false

func start(active: Array) -> void:
 order = active.duplicate()
 index = 0
 remaining = 60
 revealed = false
 finished = order.is_empty()

func speaker() -> int:
 return -1 if finished else int(order[index])

func pass_turn() -> void:
 if finished:
  return
 index += 1
 remaining = 60
 revealed = false
 finished = index >= order.size()

func tick(delta: float) -> bool:
 if finished:
  return false
 remaining = maxf(0, remaining - maxf(0, delta))
 if remaining == 0:
  pass_turn()
  return true
 return false
