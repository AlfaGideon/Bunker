extends Node3D
# Dedicated circular steel blast door for the cinematic, not the in-game door.
var door: Node3D

func material(hex: String, metallic: float = 0.0) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = Color(hex)
 m.metallic = metallic
 m.roughness = 0.64
 return m

func cylinder(parent: Node3D, radius: float, depth: float, at: Vector3, color: String) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = depth
 mesh.radial_segments = 48
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.rotation.x = PI / 2
 node.position = at
 node.material_override = material(color, 0.7)
 parent.add_child(node)
 return node

func ring(parent: Node3D, inner: float, outer: float, at: Vector3, color: String) -> MeshInstance3D:
 var mesh := TorusMesh.new()
 mesh.inner_radius = inner
 mesh.outer_radius = outer
 mesh.rings = 48
 mesh.ring_segments = 12
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.rotation.x = PI / 2
 node.position = at
 node.material_override = material(color, 0.75)
 parent.add_child(node)
 return node

func bar(parent: Node3D, at: Vector3, size: Vector3, color: String, angle: float = 0) -> void:
 var mesh := BoxMesh.new()
 mesh.size = size
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.position = at
 node.rotation.z = angle
 node.material_override = material(color, 0.65)
 parent.add_child(node)

func _ready() -> void:
 # An earthen covered shelter with a projecting concrete face and round hatch.
 var mound := MeshInstance3D.new()
 var shape := SphereMesh.new()
 shape.radius = 1.0
 shape.height = 2.0
 mound.mesh = shape
 mound.scale = Vector3(3.8, 2.9, 2.2)
 mound.position = Vector3(0, 0.25, -3.0)
 mound.material_override = material("3f5648")
 add_child(mound)
 bar(self, Vector3(0, 1.55, -0.6), Vector3(3.35, 3.1, 0.7), "78847d")
 bar(self, Vector3(0, 0.14, 0.02), Vector3(3.75, 0.28, 1.5), "56665f")
 door = Node3D.new()
 door.name = "CircularBlastDoor"
 door.position = Vector3(0, 1.65, -0.17)
 add_child(door)
 cylinder(door, 1.32, 0.20, Vector3(0, 0, 0), "303d3b")
 cylinder(door, 1.15, 0.18, Vector3(0, 0, 0.14), "697b79")
 ring(door, 1.13, 1.27, Vector3(0, 0, 0.24), "a4aea0")
 ring(door, 0.90, 0.95, Vector3(0, 0, 0.25), "354a47")
 for i in 12:
  var angle := TAU * float(i) / 12.0
  var at := Vector3(cos(angle) * 1.19, sin(angle) * 1.19, 0.31)
  cylinder(door, 0.047, 0.055, at, "ced0b5")
 # Reinforced radial ribs and central hand wheel distinguish a proper vault.
 for i in 6:
  var angle := TAU * float(i) / 6.0
  var mid := Vector3(cos(angle) * 0.57, sin(angle) * 0.57, 0.27)
  bar(door, mid, Vector3(0.68, 0.075, 0.08), "445b58", angle)
 cylinder(door, 0.19, 0.12, Vector3(0, 0, 0.34), "c0a66e")
 ring(door, 0.31, 0.37, Vector3(0, 0, 0.39), "d1b579")
 for i in 4:
  bar(door, Vector3.ZERO + Vector3(0, 0, 0.39), Vector3(0.62, 0.045, 0.04), "d1b579", TAU * i / 4.0)
