extends RefCounted

static func build(room: Node3D) -> void:
 var weather: String = room.scenario["weather"]
 var snow := weather == "snow"
 var dry := weather in ["heat", "sand", "volcano"]
 var tint := Color("a4b5bf") if snow else Color("71604a") if dry else Color("435446")
 var material := ShaderMaterial.new()
 material.shader = load("res://game/shaders/terrain.gdshader")
 material.set_shader_parameter("tint", tint)
 material.set_shader_parameter("dryness", 1.0 if dry else 0.0)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-64, 64, 2):
  for z in range(-64, 64, 2):
   if abs(x) < 9 and abs(z) < 6:
    continue
   for offset in [Vector2(0, 0), Vector2(2, 0), Vector2(0, 2), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]:
    var px: float = float(x) + offset.x
    var pz: float = float(z) + offset.y
    var y := -0.31 + sin(px * 0.44) * cos(pz * 0.31) * 0.09
    if pz > 5 and pz < 8.5 and px > 2 and px < 10:
     y = -0.4
    surface.set_normal(Vector3.UP)
    surface.add_vertex(Vector3(px, y, pz))
 var ground := MeshInstance3D.new()
 ground.mesh = surface.commit()
 ground.material_override = material
 room.add_child(ground)
 ground.name = "TerrainSurface"
 var rng := RandomNumberGenerator.new()
 rng.seed = room.layout_seed + 771
 var rock := SphereMesh.new()
 rock.radial_segments = 7
 rock.rings = 3
 rock.radius = 0.5
 rock.height = 1
 for i in 34:
  var at := Vector3(rng.randf_range(-19, 19), -0.25, rng.randf_range(-16, 17))
  if covered(room.layout, Vector2(at.x, at.z)):
   continue
  var stone := MeshInstance3D.new()
  stone.mesh = rock
  stone.material_override = room._material(Color("66737b") if snow else Color("57534d"))
  stone.position = at
  stone.scale = Vector3(rng.randf_range(0.4, 1.5), rng.randf_range(0.3, 0.9), rng.randf_range(0.6, 1.4))
  room.add_child(stone)
 # Reuse the detailed CC0 grass model as one instanced draw instead of cones.
 var grass_scene := (load("res://assets/quaternius/nature_pack_Grass_Short.glb") as PackedScene).instantiate()
 var grass_mesh_node: MeshInstance3D = grass_scene.find_children("*", "MeshInstance3D", true, false)[0]
 var grass_mesh: Mesh = grass_mesh_node.mesh
 var grass_basis: Basis = grass_mesh_node.transform.basis
 grass_scene.free()
 var batch := MultiMesh.new()
 batch.transform_format = MultiMesh.TRANSFORM_3D
 batch.use_colors = true
 batch.mesh = grass_mesh
 batch.instance_count = 90 if snow or dry else 240
 for i in batch.instance_count:
  var x := rng.randf_range(-20, 20)
  var z := rng.randf_range(-16, 18)
  if covered(room.layout, Vector2(x, z)):
   x = 21.0 if x > 0 else -21.0
  var scale_value := rng.randf_range(0.4, 1.0)
  batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * grass_basis.scaled(Vector3.ONE * scale_value), Vector3(x, -0.3, z)))
  batch.set_instance_color(i, Color("8b8261") if snow or dry else Color("718450"))
 var blades := MultiMeshInstance3D.new()
 blades.multimesh = batch
 var grass_mat := StandardMaterial3D.new()
 grass_mat.vertex_color_use_as_albedo = true
 grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 blades.material_override = grass_mat
 room.add_child(blades)

static func covered(plan: Dictionary, point: Vector2) -> bool:
 for footprint in plan["floors"]:
  if footprint.grow(1.0).has_point(point):
   return true
 return Rect2(2, 4, 8, 5).has_point(point)
