extends RefCounted
const Art = preload("res://game/scripts/scene_art.gd")
const Finish = preload("res://game/scripts/bunker_finish.gd")

static func cylinder(room: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = height
 node.mesh = mesh
 node.position = at
 node.material_override = room._material(color)
 room.add_child(node)
 return node

static func build(room: Node3D) -> void:
 var plan: Dictionary = room.layout
 var side: float = plan["med_side"]
 var kitchen: Vector3 = plan["items"]["kitchen"]["at"]
 room._box(kitchen - Vector3(0, 0.5, 0), Vector3(1.2, 0.8, 0.65), Color("727f83"))
 for x in [-0.3, 0.3]:
  cylinder(room, kitchen + Vector3(x, 0.04, 0), 0.18, 0.04, Color("172c35"))
  cylinder(room, kitchen + Vector3(x, 0.14, 0), 0.13, 0.17, Color("a2b6bd"))
 room._world_label("КУХНЯ • ПРОФЕССИЯ ПОВАРА", kitchen + Vector3(0, 0.9, 0), 20)
 var table: Vector3 = plan["table"]
 for i in 3:
  var at := table + Vector3(0.2 + float(i) * 0.45, 0.94, 0.15)
  cylinder(room, at, 0.17, 0.025, Color("dce8df"))
  var food := MeshInstance3D.new()
  var bread := SphereMesh.new()
  bread.radius = 0.12
  bread.height = 0.17
  food.mesh = bread
  food.position = at + Vector3(0, 0.07, 0)
  food.material_override = room._material(Color("c38c4d") if i != 1 else Color("ad4939"))
  room.add_child(food)
 var warehouse: Vector3 = plan["items"]["supply"]["at"]
 for z in [-0.3, 0.3]:
  Art.spawn(room, "modular_sci_fi_Props_Crate", warehouse + Vector3(0.5, 0.3, z), Vector3(0.4, 0.4, 0.35))
 room._world_label("СКЛАД • ЗАПАСЫ / ИНСТРУМЕНТЫ / ОРУЖИЕ", Vector3(side * 6.5, 1.8, 4.7), 18)
 room.warehouse_door = Art.spawn(room, "modular_sci_fi_Door_Single", Vector3(side * 4.4, 0, 3.4), Vector3(1.7, 1.8, 0.18))
 room.warehouse_door.rotation.y = PI / 2
 if plan["annex"] != "none":
  var kind: String = plan["annex"]
  var at: Vector3 = plan["items"][kind]["at"]
  if kind == "gym":
   room._box(at - Vector3(0, 0.4, 0), Vector3(1.1, 0.18, 0.6), Color("477e87"))
   var bar := cylinder(room, at + Vector3(0, 0.2, 0), 0.035, 1.1, Color("acb6bc"))
   bar.rotation.z = PI / 2
   for end in [-0.45, 0.45]:
    var weight := cylinder(room, at + Vector3(end, 0.2, 0), 0.19, 0.1, Color("26313a"))
    weight.rotation.z = PI / 2
  elif kind == "workshop":
   Art.spawn(room, "modular_sci_fi_Props_Computer", at - Vector3(0, 0.8, 0), Vector3(1.1, 1.1, 0.6))
  else:
   room._box(at - Vector3(0, 0.5, 0), Vector3(1.2, 0.4, 0.65), Color("56685a"))
   for i in 5:
    cylinder(room, at + Vector3(float(i) * 0.19 - 0.4, 0, 0), 0.07, 0.55, Color("719862"))
  room._world_label(plan["items"][kind]["title"], at + Vector3(0, 0.8, 0), 18)
 # A real cutaway dog-leg corridor aligned to the departure route.
 for part in [{"at": Vector3(3.8, -0.09, 6), "size": Vector3(1.5, 0.18, 2.4)}, {"at": Vector3(6, -0.09, 6.7), "size": Vector3(5.9, 0.18, 1.5)}]:
  var floor: MeshInstance3D = room._box(part["at"], part["size"], Color("596c76"))
  floor.material_override = Finish.metal(Color("536775"))
 for z in [5.4, 6.7]:
  for x in [3.05, 4.55]:
   room._box(Vector3(x, 0.7, z), Vector3(0.12, 1.4, 0.16), Color("7e949f"))
  room._box(Vector3(3.8, 1.45, z), Vector3(1.6, 0.13, 0.2), Color("6d8796"))
 for z in [5.95, 7.45]:
  Finish.wall(room, Vector2(6.1, z), Vector2(4.7, 0.15))
 for x in [5.0, 6.5, 8.0]:
  Finish.glow(room, Vector3(x, 0.04, 6.15), Vector3(0.6, 0.02, 0.05), Color("b8dad7"))
 Art.spawn(room, "modular_sci_fi_Door_Single", Vector3(8.7, 0, 6.7), Vector3(1.4, 1.7, 0.18)).rotation.y = PI / 2
 room._world_label("НАРУЖНЫЙ ШЛЮЗ", Vector3(8.7, 2, 6.7), 21)
