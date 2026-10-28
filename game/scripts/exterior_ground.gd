extends RefCounted

static func build(room: Node3D) -> void:
 var weather: String = room.scenario["weather"]
 var snow := weather == "snow"
 var dry := weather in ["heat", "sand", "volcano"]
 var tint := Color("667b88") if snow else Color("71604a") if dry else Color("435446")
 var shader := Shader.new()
 shader.code = """shader_type spatial;
 varying vec3 world;
 uniform vec4 tint: source_color;
 void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
 void fragment(){float n=sin(world.x*1.7+sin(world.z*2.1))*sin(world.z*1.3)+sin(world.x*18.0+world.z*11.0)*0.15;
 ALBEDO=tint.rgb*(0.85+n*0.11); ROUGHNESS=1.0;}"""
 var material := ShaderMaterial.new()
 material.shader = shader
 material.set_shader_parameter("tint", tint)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-24, 24, 2):
  for z in range(-22, 24, 2):
   if abs(x) < 9 and abs(z) < 6:
    continue
   for offset in [Vector2(0, 0), Vector2(0, 2), Vector2(2, 0), Vector2(2, 0), Vector2(0, 2), Vector2(2, 2)]:
    var px := float(x) + offset.x
    var pz := float(z) + offset.y
    var y := -0.31 + sin(px * 0.44) * cos(pz * 0.31) * 0.09
    if pz > 5 and pz < 8.5 and px > 2 and px < 10:
     y = -0.4
    surface.add_vertex(Vector3(px, y, pz))
 surface.generate_normals()
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
  if absf(at.x) < 10 and at.z < 9 and at.z > -6:
   continue
  var stone := MeshInstance3D.new()
  stone.mesh = rock
  stone.material_override = room._material(Color("66737b") if snow else Color("57534d"))
  stone.position = at
  stone.scale = Vector3(rng.randf_range(0.4, 1.5), rng.randf_range(0.3, 0.9), rng.randf_range(0.6, 1.4))
  room.add_child(stone)
 # Hundreds of blades use one instanced draw rather than individual nodes.
 var grass := SurfaceTool.new()
 grass.begin(Mesh.PRIMITIVE_TRIANGLES)
 for angle in [0.0, PI / 2]:
  var across := Vector3(cos(angle), 0, sin(angle)) * 0.14
  for p in [-across, across, Vector3(0, 0.55, 0)]:
   grass.add_vertex(p)
 grass.generate_normals()
 var batch := MultiMesh.new()
 batch.transform_format = MultiMesh.TRANSFORM_3D
 batch.use_colors = true
 batch.mesh = grass.commit()
 batch.instance_count = 90 if snow or dry else 240
 for i in batch.instance_count:
  var x := rng.randf_range(-20, 20)
  var z := rng.randf_range(-16, 18)
  if absf(x) < 10 and z < 9 and z > -6:
   x = 11.0 if x > 0 else -11.0
  var scale_value := rng.randf_range(0.4, 1.0)
  batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale_value), Vector3(x, -0.3, z)))
  batch.set_instance_color(i, Color("8b8261") if snow or dry else Color("718450"))
 var blades := MultiMeshInstance3D.new()
 blades.multimesh = batch
 var grass_mat := StandardMaterial3D.new()
 grass_mat.vertex_color_use_as_albedo = true
 grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 blades.material_override = grass_mat
 room.add_child(blades)
