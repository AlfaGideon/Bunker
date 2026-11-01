class_name BunkerLayout
extends RefCounted

# All geometry and routes share these floor footprints. Empty space between
# modules is outside, never a hidden rectangular navigation floor.
static func generate(seed_value: int, capacity: int = 4) -> Dictionary:
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var hall := Rect2(-9, -5, 18, 10)
 var floors: Array[Rect2] = [hall]
 var modules: Dictionary = {}
 var slots: Array = ["north", "east", "south", "west"]
 for i in range(slots.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var saved: String = slots[i]
  slots[i] = slots[j]
  slots[j] = saved
 var annex: String = ["none", "gym", "workshop", "greenhouse"][rng.randi_range(0, 3)]
 var kinds: Array = ["medical", "kitchen", "supply"]
 if annex != "none":
  kinds.append(annex)
 var table := Vector3(0.3, 0, 0)
 var items := {
  "terminal": {"title": "Терминал — восстановить систему", "at": Vector3(3, 1, -3.5), "goal": Vector3(3, 0, -2.3)},
  "radio": {"title": "Радио — приёмник и эфир", "at": table + Vector3(-0.7, 1.05, 0), "goal": table + Vector3(-0.7, 0, 1.6)},
  "food": {"title": "Общий стол — поесть", "at": table + Vector3(0.7, 1, 0), "goal": table + Vector3(0.7, 0, 1.6)}
 }
 var blockers: Array[Rect2] = [Rect2(-1.65, -1.25, 3.9, 2.5), Rect2(2.2, -4.2, 1.6, 1.4)]
 var beds: Array[String] = []
 for i in clampi(capacity, 3, 5):
  var key := "bed" if i == 0 else "bed%d" % (i + 1)
  var z := -3.6 + float(i) * 7.2 / float(capacity - 1)
  beds.append(key)
  items[key] = {"title": "Койка %d — отдых" % (i + 1), "at": Vector3(-7.3, 0.65, z), "goal": Vector3(-5, 0, z)}
  blockers.append(Rect2(-8.35, z - 0.6, 2.5, 1.2))
 items["chair"] = {"title": "Кресло — посидеть", "at": Vector3(4.6, 0.55, 1.5), "goal": Vector3(4.6, 0, 2.95)}
 blockers.append(Rect2(4.1, 0.95, 1.5, 1.35))
 # Plasma panel on the hall wall: the crew's own cinema, run by the projectionist.
 items["cinema"] = {"title": "Плазма — включить кино", "at": Vector3(6.6, 1.55, -4.62), "goal": Vector3(6.6, 0, -2.95)}
 blockers.append(Rect2(4.55, -5.0, 4.1, 0.75))
 for index in kinds.size():
  var kind: String = kinds[index]
  var slot: String = slots[index]
  var length := float(rng.randi_range(2, 4))
  var bounds: Rect2
  var link: Rect2
  var gate: Vector3
  var approach: Vector3
  if slot == "north":
   bounds = Rect2(-3.4, -5 - length - 5.6, 6.8, 5.6)
   link = Rect2(-1.2, -5 - length - 0.1, 2.4, length + 0.2)
   gate = Vector3(0, 1, -5 - length * 0.5)
   approach = Vector3(0, 0, -4.4)
  elif slot == "south":
   bounds = Rect2(-6.4, 5 + length, 6.8, 5.6)
   link = Rect2(-4.2, 4.9, 2.4, length + 0.2)
   gate = Vector3(-3, 1, 5 + length * 0.5)
   approach = Vector3(-3, 0, 4.4)
  elif slot == "east":
   bounds = Rect2(9 + length, -3.4, 5.6, 6.8)
   link = Rect2(8.9, -1.2, length + 0.2, 2.4)
   gate = Vector3(9 + length * 0.5, 1, 0)
   approach = Vector3(8.4, 0, 0)
  else:
   bounds = Rect2(-9 - length - 5.6, -3.4, 5.6, 6.8)
   link = Rect2(-9 - length - 0.1, -1.2, length + 0.2, 2.4)
   gate = Vector3(-9 - length * 0.5, 1, 0)
   approach = Vector3(-8.4, 0, 0)
  var center := bounds.get_center()
  var at := Vector3(center.x, 0.8, center.y - 1.2)
  var goal := Vector3(center.x, 0, center.y + 0.4)
  var title: String = {"medical": "Медотсек — обследование", "kitchen": "Кухня — приготовить еду", "supply": "Склад — забрать снабжение", "gym": "Спортзал — тренировка", "workshop": "Мастерская — обслуживание", "greenhouse": "Теплица — сбор урожая"}[kind]
  items[kind] = {"title": title, "at": at, "goal": goal}
  floors.append(bounds)
  floors.append(link)
  modules[kind] = {"bounds": bounds, "corridor": link, "slot": slot, "gate": gate, "approach": approach, "center": Vector3(center.x, 0, center.y), "horizontal": slot in ["east", "west"]}
  blockers.append(Rect2(center.x - 1.25, center.y - 1.85, 2.5, 1.3))
  # Furnish the four corners, preserving a cross-shaped entry aisle.
  for corner in [bounds.position + Vector2(0.35, 0.35), Vector2(bounds.end.x - 1.35, bounds.position.y + 0.35), Vector2(bounds.position.x + 0.35, bounds.end.y - 1.35), bounds.end - Vector2(1.35, 1.35)]:
   blockers.append(Rect2(corner, Vector2.ONE))

 # Attached rooms. Each hangs off a module wall through a short corridor, so the
 # plan branches: an operating theatre off the medical bay, a pantry off the
 # kitchen and a bathroom beside it. A room only counts as reachable while its
 # door is open, and the door opens when the crew has the right profession.
 var annexes: Dictionary = {}
 var requests: Array = [
  {"kind": "operating", "parent": "medical", "title": "Операционная — подготовить стол",
   "requires": ["Врач", "Фельдшер"], "open_round": 2, "label": "ОПЕРАЦИОННАЯ"},
  {"kind": "pantry", "parent": "kitchen", "title": "Кладовая — пополнить рацион",
   "requires": ["Повар", "Пекарь", "Технолог пищевого производства"], "open_round": 1, "label": "КЛАДОВАЯ"},
  {"kind": "bathroom", "parent": "kitchen", "title": "Санузел — привести себя в порядок",
   "requires": [], "open_round": 1, "label": "САНУЗЕЛ"}
 ]
 for request in requests:
  var made := _attach(request, modules, floors, annexes)
  if made.is_empty():
   continue
  annexes[request["kind"]] = made
  floors.append(made["corridor"])
  floors.append(made["bounds"])
  var middle: Vector2 = made["bounds"].get_center()
  items[request["kind"]] = {"title": made["title"], "at": Vector3(middle.x, 0.8, middle.y), "goal": made["goal"]}
  # Block the far-wall furniture only: the middle of the room and the goal in
  # front of it must stay walkable, or the door would open onto a dead end.
  var inward: Vector2 = made["inward"]
  if absf(inward.y) > 0.5:
   blockers.append(Rect2(middle.x - 1.6, middle.y + inward.y * 2.3 - 0.45, 3.2, 0.9))
  else:
   blockers.append(Rect2(middle.x + inward.x * 2.3 - 0.45, middle.y - 1.6, 0.9, 3.2))

 var med: Dictionary = modules["medical"]
 var store: Dictionary = modules["supply"]
 items["gate"] = {"title": "Дверь медотсека — открыть врачом", "at": med["gate"], "goal": med["approach"]}
 items["warehouse_gate"] = {"title": "Дверь склада — совет", "at": store["gate"], "goal": store["approach"]}
 var all_bounds := hall
 for floor_rect in floors:
  all_bounds = all_bounds.merge(floor_rect)
 return {"seed": seed_value, "variant": posmod(seed_value, 3), "capacity": capacity, "beds": beds, "annex": annex, "table": table, "items": items, "blockers": blockers, "walls": [], "floors": floors, "hall": hall, "modules": modules, "bounds": all_bounds, "med_side": 1.0,
 "med_bounds": med["bounds"], "gate_blocker": med["corridor"], "annexes": annexes, "warehouse_bounds": store["bounds"], "warehouse_gate": store["corridor"], "floor_color": Color("35464b")}


# Copy a corridor and a room beyond one wall of a module. Modules are 5.6 m
# deep, so a 5.6 x 5.6 room keeps the grid modular.
static func _annex_rects(module: Dictionary, side: String, depth: float, gap: float) -> Dictionary:
 var bounds: Rect2 = module["bounds"]
 var center: Vector2 = Vector2(module["center"].x, module["center"].z)
 var corridor: Rect2
 var room: Rect2
 var inward := Vector2.ZERO
 match side:
  "north":
   corridor = Rect2(center.x - 1.2, bounds.position.y - gap, 2.4, gap + 0.2)
   room = Rect2(center.x - 2.8, corridor.position.y - depth, 5.6, depth)
   inward = Vector2(0, -1)
  "south":
   corridor = Rect2(center.x - 1.2, bounds.end.y - 0.1, 2.4, gap + 0.2)
   room = Rect2(center.x - 2.8, corridor.end.y, 5.6, depth)
   inward = Vector2(0, 1)
  "east":
   corridor = Rect2(bounds.end.x - 0.1, center.y - 1.2, gap + 0.2, 2.4)
   room = Rect2(corridor.end.x, center.y - 2.8, depth, 5.6)
   inward = Vector2(1, 0)
  _:
   corridor = Rect2(bounds.position.x - gap, center.y - 1.2, gap + 0.2, 2.4)
   room = Rect2(corridor.position.x - depth, center.y - 2.8, depth, 5.6)
   inward = Vector2(-1, 0)
 return {"side": side, "corridor": corridor, "bounds": room, "inward": inward,
  "gate": Vector3(corridor.get_center().x, 1, corridor.get_center().y),
  "horizontal": corridor.size.x > corridor.size.y}


static func _annex_fits(made: Dictionary, floors: Array, annexes: Dictionary, parent_bounds: Rect2) -> bool:
 var room: Rect2 = made["bounds"]
 # The corridor shares a 0.2 m doorway with its parent, but must not cut through
 # anything else — otherwise the passage would run across the hall.
 var corridor: Rect2 = made["corridor"]
 for footprint in floors:
  var floor_rect: Rect2 = footprint
  if floor_rect.is_equal_approx(parent_bounds):
   continue
  if corridor.grow(0.12).intersects(floor_rect.grow(0.12)):
   return false
 if absf(room.get_center().x) > 24.0 or absf(room.get_center().y) > 22.0:
  return false
 for footprint in floors:
  if room.grow(0.9).intersects(footprint.grow(0.4)):
   return false
 for kind in annexes:
  var other: Rect2 = annexes[kind]["bounds"]
  if room.grow(0.9).intersects(other.grow(0.4)):
   return false
 return true


static func _attach(request: Dictionary, modules: Dictionary, floors: Array, annexes: Dictionary) -> Dictionary:
 var parent: Dictionary = modules.get(request["parent"], {})
 if parent.is_empty():
  return {}
 var slot: String = parent["slot"]
 var order: Array = []
 if slot in ["north", "south", "east", "west"]:
  order.append(slot)
 order.append_array(["east", "west"] if slot in ["north", "south"] else ["north", "south"])
 for side in order:
  var made := _annex_rects(parent, side, 5.6, 2.2)
  if not _annex_fits(made, floors, annexes, parent["bounds"]):
   continue
  var bounds: Rect2 = made["bounds"]
  var middle: Vector2 = bounds.get_center()
  var inward: Vector2 = made["inward"]
  var parent_bounds: Rect2 = parent["bounds"]
  var approach_point: Vector2 = Vector2(made["corridor"].get_center().x, made["corridor"].get_center().y) - inward * 1.8
  made["parent"] = request["parent"]
  made["title"] = request["title"]
  made["label"] = request["label"]
  made["requires"] = request["requires"]
  made["open_round"] = request["open_round"]
  made["center"] = Vector3(middle.x, 0, middle.y)
  made["goal"] = Vector3(middle.x, 0, middle.y) + Vector3(inward.x, 0, inward.y) * 1.3
  made["approach"] = Vector3(approach_point.x, 0, approach_point.y)
  # Keep the parent's interior clear: the corridor mouth is the only opening.
  var keep: Rect2 = bounds.grow(-0.3)
  made["furniture"] = keep
  return made
 return {}
