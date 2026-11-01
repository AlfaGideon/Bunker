extends RefCounted
const Art = preload("res://game/scripts/scene_art.gd")
const Finish = preload("res://game/scripts/bunker_finish.gd")
const Station = preload("res://game/scripts/station_motion.gd")

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
 # Each exterior room has an equipment set, not a lone interaction prop.
 for kind in plan["modules"]:
  var bounds: Rect2 = plan["modules"][kind]["bounds"]
  var corners: Array[Vector2] = [bounds.position + Vector2(0.85, 0.85), Vector2(bounds.end.x - 0.85, bounds.position.y + 0.85), Vector2(bounds.position.x + 0.85, bounds.end.y - 0.85), bounds.end - Vector2(0.85, 0.85)]
  for index in corners.size():
   var point: Vector2 = corners[index]
   var at := Vector3(point.x, 0, point.y)
   if kind == "medical":
    room._box(at + Vector3(0, 0.65, 0), Vector3(0.85, 1.3, 0.8), Color("b4cfd0"))
    for y in [0.3, 0.65, 1.0]:
     room._box(at + Vector3(0, y, 0.42), Vector3(0.6, 0.04, 0.04), Color("51777c"))
    if index == 2:
     # Open first-aid cabinet on the module wall: shelves, bottles, red cross.
     Art.spawn(room, "blender_medkit", at + Vector3(0.0, 0.66, -0.42),
      Vector3(0.52, 0.6, 0.2), false, 0.008)
    if index == 0:
     Finish.glow(room, at + Vector3(0, 1.55, 0), Vector3(0.55, 0.1, 0.08), Color("dd6b61"))
     Finish.glow(room, at + Vector3(0, 1.55, 0), Vector3(0.1, 0.55, 0.08), Color("dd6b61"))
   elif kind == "kitchen":
    if index == 0:
     Art.spawn(room, "house_interior_pack_Kitchen_Fridge", at, Vector3(0.8, 1.8, 0.8))
    elif index == 1:
     # The same galley counter the hall uses, so the kitchen matches it.
     Station.attach(Art.spawn(room, "blender_food_station", at, Vector3(1.0, 0.92, 0.5), false, 0.010), "steam")
    else:
     room._box(at + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95), Color("95a8a8"))
     room._box(at + Vector3(0, 0.94, 0), Vector3(1, 0.08, 1), Color("c5cfbd"))
   elif kind == "supply" or kind == "workshop":
    for y in [0.15, 0.75, 1.35]:
     room._box(at + Vector3(0, y, 0), Vector3(1, 0.08, 0.9), Color("75848a"))
     Art.spawn(room, "modular_sci_fi_Props_Crate", at + Vector3(0, y + 0.05, 0), Vector3(0.65, 0.45, 0.6))
    for x in [-0.44, 0.44]:
     room._box(at + Vector3(x, 0.7, 0), Vector3(0.06, 1.5, 0.85), Color("56636a"))
   elif kind == "gym":
    room._box(at + Vector3(0, 0.06, 0), Vector3(0.95, 0.12, 0.95), Color("426b79"))
    if index % 2 == 0:
     room._box(at + Vector3(0, 0.3, 0), Vector3(0.7, 0.12, 0.9), Color("8b6150"))
     for x in [-0.3, 0.3]:
      cylinder(room, at + Vector3(x, 0.16, 0), 0.035, 0.3, Color("9dabad"))
    else:
     for y in [0.3, 0.65, 1.0]:
      var bar := cylinder(room, at + Vector3(0, y, 0), 0.06, 0.8, Color("243942"))
      bar.rotation.z = PI / 2
   else:
    room._box(at + Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 0.95), Color("626d4d"))
    for x in [-0.25, 0.25]:
     cylinder(room, at + Vector3(x, 0.9, 0), 0.13, 0.7, Color("64a45a"))
 var exam: Vector3 = plan["items"]["medical"]["at"]
 room._box(exam - Vector3(0, 0.1, 0), Vector3(1.9, 0.15, 0.85), Color("b9d9d7"))
 room._box(exam - Vector3(0.65, -0.05, 0), Vector3(0.5, 0.15, 0.75), Color("d2e2dc"))
 for x in [-0.7, 0.7]:
  room._box(exam + Vector3(x, -0.45, 0), Vector3(0.09, 0.7, 0.7), Color("76999f"))
 # Medical bedside diagnostic display and illuminated controls.
 room._box(exam + Vector3(0.72, 0.35, -0.38), Vector3(0.08, 0.8, 0.08), Color("78939c"))
 room._box(exam + Vector3(0.72, 0.78, -0.38), Vector3(0.66, 0.43, 0.12), Color("1a343f"))
 Finish.glow(room, exam + Vector3(0.72, 0.78, -0.30), Vector3(0.52, 0.30, 0.025), Color("4faeb8"))
 for button in range(3):
  Finish.glow(room, exam + Vector3(0.55 + button * 0.17, 0.57, -0.30), Vector3(0.07, 0.035, 0.025), Color("b6e7e2"))
 var kitchen: Vector3 = plan["items"]["kitchen"]["at"]
 room._box(kitchen - Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.65), Color("727f83"))
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
 room._world_label("СКЛАД • ЗАПАСЫ / ИНСТРУМЕНТЫ / ОРУЖИЕ", warehouse + Vector3(0, 1.3, 1.7), 18)
 room.warehouse_door = Art.spawn(room, "modular_sci_fi_Door_Single", plan["modules"]["supply"]["gate"] - Vector3(0, 1, 0), Vector3(2.3, 1.8, 0.18))
 room.warehouse_door.rotation.y = PI / 2 if plan["modules"]["supply"]["horizontal"] else 0
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
   Station.attach(Art.spawn(room, "blender_terminal", at, Vector3(0.84, 1.12, 0.5), false, 0.010), "terminal")
  else:
   room._box(at - Vector3(0, 0.5, 0), Vector3(1.2, 0.4, 0.65), Color("56685a"))
   for i in 5:
    cylinder(room, at + Vector3(float(i) * 0.19 - 0.4, 0, 0), 0.07, 0.55, Color("719862"))
  room._world_label(plan["items"][kind]["title"], at + Vector3(0, 0.8, 0), 18)
 for x in [3.8, 5.5, 7.5]:
  room._box(Vector3(x, -0.31, 6.7), Vector3(0.35, 0.5, 0.5), Color("4b575c"))
 # A real cutaway dog-leg corridor aligned to the departure route.
 for part in [{"at": Vector3(3.8, -0.09, 6), "size": Vector3(1.5, 0.18, 2.4)}, {"at": Vector3(6, -0.09, 6.7), "size": Vector3(5.9, 0.18, 1.5)}]:
  var floor: MeshInstance3D = room._box(part["at"], part["size"], Color("596c76"))
  floor.material_override = Finish.metal(Color("536775"))
 # Solid walls follow the dog-leg; the inside corner remains passable.
 # West wall and the back wall meet without seams; the opposite wall ends at
 # the bend so a departing character can actually turn right into the tunnel.
 Finish.wall(room, Vector2(3.05, 6.22), Vector2(0.16, 2.5))
 Finish.wall(room, Vector2(4.55, 5.47), Vector2(0.16, 1.0))
 Finish.wall(room, Vector2(6.65, 5.95), Vector2(4.25, 0.16))
 Finish.wall(room, Vector2(5.9, 7.45), Vector2(5.8, 0.16))
 # A real, opaque pressure door at the entrance, not just a floating frame.
 # It slides down together with the exterior hatch during local expulsion.
 room.entrance_hatch = Node3D.new()
 room.entrance_hatch.name = "EntrancePressureDoor"
 room.entrance_hatch.position = Vector3(3.8, 0, 5.0)
 room.add_child(room.entrance_hatch)
 var backing := MeshInstance3D.new()
 var backing_mesh := BoxMesh.new()
 backing_mesh.size = Vector3(1.47, 2.12, 0.12)
 backing.mesh = backing_mesh
 backing.position = Vector3(0, 1.06, 0.075)
 backing.material_override = Finish.metal(Color("334e58"))
 room.entrance_hatch.add_child(backing)
 var pressure_door := Art.spawn(room.entrance_hatch, "modular_sci_fi_Door_Single", Vector3(0, 0, 0), Vector3(1.43, 2.08, 0.12))
 pressure_door.name = "PressureDoorDetail"
 # Head and jambs seal the gap above and either side of the moving door.
 var lintel: MeshInstance3D = room._box(Vector3(3.8, 2.40, 5.0), Vector3(1.65, 0.55, 0.24), Color("415d68"))
 lintel.material_override = Finish.metal(Color("415d68"))
 for x in [3.01, 4.59]:
  var jamb: MeshInstance3D = room._box(Vector3(x, 1.10, 5.0), Vector3(0.16, 2.2, 0.24), Color("526b74"))
  jamb.material_override = Finish.metal(Color("526b74"))
 var entrance_roof: MeshInstance3D = room._box(Vector3(3.8, 2.72, 6.15), Vector3(1.65, 0.14, 2.5), Color("344c55"))
 entrance_roof.material_override = Finish.metal(Color("344c55"))
 entrance_roof.visible = false
 entrance_roof.set_meta("first_person_ceiling", true)
 var entrance_light := Finish.glow(room, Vector3(3.8, 2.63, 5.65), Vector3(0.7, 0.03, 0.18), Color("c8f4ff"))
 entrance_light.visible = false
 entrance_light.set_meta("first_person_ceiling", true)
 for x in [5.0, 6.5, 8.0]:
  Finish.glow(room, Vector3(x, 0.04, 6.15), Vector3(0.6, 0.02, 0.05), Color("b8dad7"))
 # Close the exit tunnel above the door and cover its first-person roof.
 var tunnel_roof: MeshInstance3D = room._box(Vector3(6.15, 2.72, 6.7), Vector3(5.25, 0.14, 1.65), Color("344c55"))
 tunnel_roof.visible = false
 tunnel_roof.set_meta("first_person_ceiling", true)
 var tunnel_light := Finish.glow(room, Vector3(6.2, 2.63, 6.7), Vector3(2.0, 0.03, 0.2), Color("c8f4ff"))
 tunnel_light.visible = false
 tunnel_light.set_meta("first_person_ceiling", true)
 room._box(Vector3(8.75, 2.25, 6.7), Vector3(0.2, 0.85, 1.65), Color("344c55"))
 # Side jambs seal the ends without blocking the moving hatch.
 for z in [5.95, 7.45]:
  room._box(Vector3(8.75, 1.0, z), Vector3(0.2, 2.0, 0.20), Color("344c55"))
 room.exit_hatch = Art.spawn(room, "modular_sci_fi_Door_Single", Vector3(8.7, 0, 6.7), Vector3(1.4, 1.7, 0.18))
 room.exit_hatch.rotation.y = PI / 2
 room._box(Vector3(9.1, -0.14, 6.7), Vector3(0.5, 0.15, 1.4), Color("60717a"))
 room._world_label("НАРУЖНЫЙ ШЛЮЗ", Vector3(8.7, 2, 6.7), 21)
