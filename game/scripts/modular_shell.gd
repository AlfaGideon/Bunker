extends RefCounted
const Finish = preload("res://game/scripts/bunker_finish.gd")

static func inside(plan: Dictionary, point: Vector2) -> bool:
 if Rect2(3.05, 4.85, 1.5, 2.4).has_point(point):
  return true
 for footprint in plan["floors"]:
  if footprint.has_point(point):
   return true
 return false

# Split edges exactly at room/corridor boundaries instead of sampling a 0.4 m
# grid, which enlarged openings and left visible gaps at the junctions.
static func exposed_spans(plan: Dictionary, start: Vector2, direction: Vector2, outside: Vector2, length: float) -> Array:
 var cuts: Array[float] = [0.0, length]
 var footprints: Array = plan["floors"].duplicate()
 footprints.append(Rect2(3.05, 4.85, 1.5, 2.4))
 for footprint in footprints:
  var rect: Rect2 = footprint
  var low := rect.position.x if direction.x != 0 else rect.position.y
  var high := rect.end.x if direction.x != 0 else rect.end.y
  var base := start.x if direction.x != 0 else start.y
  for value in [low - base, high - base]:
   if value > 0.001 and value < length - 0.001:
    cuts.append(value)
 cuts.sort()
 var spans: Array = []
 var run := -1.0
 for i in range(cuts.size() - 1):
  var begin: float = cuts[i]
  var end: float = cuts[i + 1]
  if end - begin < 0.0001:
   continue
  var exposed := not inside(plan, start + direction * ((begin + end) * 0.5) + outside * 0.08)
  if exposed and run < 0:
   run = begin
  if not exposed and run >= 0:
   spans.append(Vector2(run, begin))
   run = -1.0
 if run >= 0:
  spans.append(Vector2(run, length))
 return spans

static func edge(room: Node3D, start: Vector2, direction: Vector2, outside: Vector2, length: float) -> void:
 for span in exposed_spans(room.layout, start, direction, outside, length):
  var at: Vector2 = start + direction * ((span.x + span.y) * 0.5)
  var width: float = span.y - span.x
  Finish.wall(room, at, Vector2(width, 0.16) if direction.x != 0 else Vector2(0.16, width))

static func build(room: Node3D) -> void:
 for footprint in room.layout["floors"]:
  var rect: Rect2 = footprint
  var center := rect.get_center()
  var color := Color("4b5b64")
  for kind in room.layout["modules"]:
   if room.layout["modules"][kind]["bounds"] == rect:
    color = {"medical": Color("4d8885"), "kitchen": Color("8b8068"), "supply": Color("70624e"), "gym": Color("536e86"), "workshop": Color("657076"), "greenhouse": Color("5d7856")}[kind]
  var floor: MeshInstance3D = room._box(Vector3(center.x, -0.2, center.y), Vector3(rect.size.x, 0.4, rect.size.y), color)
  floor.material_override = Finish.metal(color)
  # Hidden from the overhead tactical view but encloses the first-person view.
  var ceiling: MeshInstance3D = room._box(Vector3(center.x, 2.72, center.y), Vector3(rect.size.x, 0.14, rect.size.y), Color("273c44"))
  ceiling.material_override = Finish.metal(Color("273c44"))
  ceiling.visible = false
  ceiling.set_meta("first_person_ceiling", true)
  # Recessed diffusers remain visible only with the first-person ceiling.
  var fixture := Finish.glow(room, Vector3(center.x, 2.625, center.y), Vector3(minf(rect.size.x * 0.45, 2.4), 0.035, 0.23), Color("caefff"))
  fixture.visible = false
  fixture.set_meta("first_person_ceiling", true)
  var rim: MeshInstance3D = room._box(Vector3(center.x, 2.65, center.y), Vector3(minf(rect.size.x * 0.45 + 0.16, 2.56), 0.05, 0.38), Color("8da8b0"))
  rim.visible = false
  rim.set_meta("first_person_ceiling", true)
  edge(room, rect.position, Vector2.RIGHT, Vector2.UP, rect.size.x)
  edge(room, Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.DOWN, rect.size.x)
  edge(room, rect.position, Vector2.DOWN, Vector2.LEFT, rect.size.y)
  edge(room, Vector2(rect.end.x, rect.position.y), Vector2.DOWN, Vector2.RIGHT, rect.size.y)
 for kind in room.layout["modules"]:
  var module: Dictionary = room.layout["modules"][kind]
  var center: Vector3 = module["center"]
  var title: String = {"medical": "МЕДОТСЕК", "kitchen": "КУХНЯ", "supply": "СКЛАД", "gym": "СПОРТЗАЛ", "workshop": "МАСТЕРСКАЯ", "greenhouse": "ТЕПЛИЦА"}[kind]
  var sign_label: Label3D = room._world_label(title, center + Vector3(0, 1.8, -2.2), 25)
  if kind == "medical":
   room.med_label = sign_label
  var gate: Vector3 = module["gate"]
  var light := OmniLight3D.new()
  light.position = center + Vector3(0, 2.8, 0)
  light.light_color = Color("9ce8e4") if kind == "medical" else Color("ffe0b1")
  light.light_energy = 0.8
  light.omni_range = 6
  room.add_child(light)
  if kind == "medical":
   room.med_light = light
   light.light_energy = 0
  # Rounded pressure-door surround: the centre remains open for navigation.
  var horizontal: bool = module["horizontal"]
  var ring := MeshInstance3D.new()
  var torus := TorusMesh.new()
  torus.inner_radius = 1.10
  torus.outer_radius = 1.23
  torus.rings = 40
  torus.ring_segments = 10
  ring.mesh = torus
  ring.position = Vector3(gate.x, 1.13, gate.z)
  ring.rotation.z = PI / 2 if horizontal else 0.0
  ring.rotation.x = 0.0 if horizontal else PI / 2
  ring.material_override = room._material(Color("91aeb7"))
  ring.name = "RoundedPassageFrame"
  ring.set_meta("rounded_passage", true)
  room.add_child(ring)
