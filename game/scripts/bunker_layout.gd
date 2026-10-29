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
  "radio": {"title": "Радио — включить / выключить", "at": table + Vector3(-0.7, 1.05, 0), "goal": table + Vector3(-0.7, 0, 1.6)},
  "food": {"title": "Общий стол — поесть", "at": table + Vector3(0.7, 1, 0), "goal": table + Vector3(0.7, 0, 1.6)}
 }
 var blockers: Array[Rect2] = [Rect2(-1.65, -1.25, 3.9, 2.5), Rect2(2.2, -4.2, 1.6, 1.4)]
 var beds: Array[String] = []
 for i in clampi(capacity, 3, 5):
  var key := "bed" if i == 0 else "bed%d" % (i + 1)
  var z := -3.6 + float(i) * 7.2 / float(capacity - 1)
  beds.append(key)
  items[key] = {"title": "Койка %d — отдых" % (i + 1), "at": Vector3(-6.6, 0.65, z), "goal": Vector3(-5, 0, z)}
  blockers.append(Rect2(-7.85, z - 0.6, 2.5, 1.2))
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

 var med: Dictionary = modules["medical"]
 var store: Dictionary = modules["supply"]
 items["gate"] = {"title": "Дверь медотсека — открыть врачом", "at": med["gate"], "goal": med["approach"]}
 items["warehouse_gate"] = {"title": "Дверь склада — совет", "at": store["gate"], "goal": store["approach"]}
 var all_bounds := hall
 for floor_rect in floors:
  all_bounds = all_bounds.merge(floor_rect)
 return {"seed": seed_value, "variant": posmod(seed_value, 3), "capacity": capacity, "beds": beds, "annex": annex, "table": table, "items": items, "blockers": blockers, "walls": [], "floors": floors, "hall": hall, "modules": modules, "bounds": all_bounds, "med_side": 1.0,
 "med_bounds": med["bounds"], "gate_blocker": med["corridor"], "warehouse_bounds": store["bounds"], "warehouse_gate": store["corridor"], "floor_color": Color("35464b")}
