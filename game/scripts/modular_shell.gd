extends RefCounted
const Finish = preload("res://game/scripts/bunker_finish.gd")

static func inside(plan: Dictionary, point: Vector2) -> bool:
 if Rect2(3.05, 4.85, 1.5, 2.4).has_point(point):
  return true
 for footprint in plan["floors"]:
  if footprint.has_point(point):
   return true
 return false

static func edge(room: Node3D, start: Vector2, direction: Vector2, outside: Vector2, length: float) -> void:
 var count := ceili(length / 0.4)
 var stride := length / count
 var run := -1
 for index in range(count + 1):
  var exposed := false
  if index < count:
   exposed = not inside(room.layout, start + direction * ((index + 0.5) * stride) + outside * 0.08)
  if exposed and run == -1:
   run = index
  if not exposed and run != -1:
   var span := (index - run) * stride
   var at := start + direction * ((run + index) * stride * 0.5)
   Finish.wall(room, at, Vector2(span, 0.16) if direction.x != 0 else Vector2(0.16, span))
   run = -1

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
  room.add_child(ring)
