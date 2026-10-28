extends Node3D
const Art = preload("res://game/scripts/scene_art.gd")
var trees: Array[Node3D] = []
var wind_materials: Array[ShaderMaterial] = []
var fire_material: ShaderMaterial
var fire_model: Node3D
var embers: CPUParticles3D
var smoke: CPUParticles3D
var clock := 0.0
var reduced_motion := false

func _ready() -> void:
 var wind := Shader.new()
 wind.code = """shader_type spatial;
 uniform vec4 tint: source_color;
 uniform float wind_time = 0.0;
 uniform float phase = 0.0;
 uniform float wind_strength = 1.0;
 uniform float flutter = 0.0;
 void vertex(){
  vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
  float h=max(p.y,0.0);
  float bend=pow(clamp(h/4.0,0.0,1.0),1.7);
  vec3 offset=vec3(sin(wind_time*0.72+phase)*0.10,0.0,cos(wind_time*0.51+phase)*0.055)*bend;
  offset.x+=sin(wind_time*2.4+p.x*3.0+p.z*4.0)*flutter*bend;
  VERTEX+=inverse(mat3(MODEL_MATRIX))*offset*wind_strength;
 }
 void fragment(){ALBEDO=tint.rgb;ROUGHNESS=0.95;}
 """
 for i in 13:
  var x := float(i % 7) * 2.0 - 8.0
  var z := -4.5 - float(i / 7) * 2.5
  var height := 3.8 + sin(float(i) * 4.7) * 0.65
  var tree := Art.spawn(self, "nature_pack_PineTree_1" if i % 2 == 0 else "nature_pack_PineTree_3", Vector3(x, 0, z), Vector3(2.8, height, 2.8), true)
  tree.rotation.y = float(i) * 1.71
  trees.append(tree)
  for mesh in tree.find_children("*", "MeshInstance3D", true, false):
   for surface in mesh.mesh.get_surface_count():
    var original: Material = mesh.mesh.surface_get_material(surface)
    var material := ShaderMaterial.new()
    material.shader = wind
    material.set_shader_parameter("tint", original.albedo_color if original is StandardMaterial3D else Color("49684c"))
    material.set_shader_parameter("phase", float(i) * 1.37)
    material.set_shader_parameter("flutter", 0.018 if surface == 1 else 0.0)
    mesh.set_surface_override_material(surface, material)
    wind_materials.append(material)
 fire_model = Art.spawn(self, "survival_pack_Bonfire_Fire", Vector3(0, 0.03, 1), Vector3(1.2, 1.05, 1.2), true)
 var shader := Shader.new()
 shader.code = """shader_type spatial;
 render_mode unshaded, cull_disabled, depth_draw_never;
 uniform float fire_time=0.0;
 varying float height;
 varying vec3 position_world;
 void vertex(){
  vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
  height=clamp((p.y-0.08)/0.95,0.0,1.0);
  float sway=height*height;
  vec3 offset=vec3(sin(fire_time*5.0+p.z*13.0)*0.11, sin(fire_time*7.0+p.x*11.0)*0.06,cos(fire_time*4.0+p.x*9.0)*0.06)*sway;
  VERTEX+=inverse(mat3(MODEL_MATRIX))*offset;
  position_world=p;
 }
 void fragment(){
  float flicker=sin(position_world.x*24.0+position_world.z*18.0-fire_time*8.0)*0.5+0.5;
  ALBEDO=mix(vec3(1.0,0.67,0.12),vec3(0.85,0.13,0.018),clamp(height+flicker*0.16,0.0,1.0));
  ALPHA=0.72-height*0.28+flicker*0.08;
 }
 """
 fire_material = ShaderMaterial.new()
 fire_material.shader = shader
 for mesh in fire_model.find_children("*", "MeshInstance3D", true, false):
  for surface in mesh.mesh.get_surface_count():
   var material: Material = mesh.mesh.surface_get_material(surface)
   if material != null and "Fire" in material.resource_name:
    mesh.set_surface_override_material(surface, fire_material)
 embers = particles(24, 1.8, Color("ffb853"), 0.018, false)
 smoke = particles(14, 3.5, Color(0.32, 0.35, 0.36, 0.12), 0.13, true)

func particles(amount: int, lifetime: float, color: Color, radius: float, is_smoke: bool) -> CPUParticles3D:
 var effect := CPUParticles3D.new()
 effect.amount = amount
 effect.lifetime = lifetime
 effect.preprocess = lifetime
 effect.position = Vector3(0, 0.45, 1)
 effect.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
 effect.emission_sphere_radius = 0.17
 effect.direction = Vector3.UP
 effect.spread = 18
 effect.initial_velocity_min = 0.22 if is_smoke else 0.6
 effect.initial_velocity_max = 0.5 if is_smoke else 1.2
 effect.gravity = Vector3(0.05, 0.02, 0)
 effect.scale_amount_min = 0.4
 effect.scale_amount_max = 1.0
 var mesh := SphereMesh.new()
 mesh.radius = radius
 mesh.height = radius * 2
 mesh.radial_segments = 6
 mesh.rings = 3
 effect.mesh = mesh
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.vertex_color_use_as_albedo = true
 effect.material_override = material
 var gradient := Gradient.new()
 gradient.set_color(0, Color(1,1,1,0))
 gradient.add_point(0.2, Color.WHITE)
 gradient.set_color(2, Color(1,1,1,0))
 effect.color_ramp = gradient
 add_child(effect)
 return effect

func _process(delta: float) -> void:
 clock += delta
 for material in wind_materials:
  material.set_shader_parameter("wind_time", clock)
  material.set_shader_parameter("wind_strength", 0.0 if reduced_motion else 1.0)
 if fire_material != null:
  fire_material.set_shader_parameter("fire_time", clock * (0.25 if reduced_motion else 1.0))
 if is_instance_valid(embers):
  embers.emitting = not reduced_motion
 if is_instance_valid(smoke):
  smoke.emitting = not reduced_motion
