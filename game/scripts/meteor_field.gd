extends Node3D

var meteors: Array[Node3D] = []
var flashes: Array[MeshInstance3D] = []
var lamps: Array[OmniLight3D] = []
var emitters: Array[CPUParticles3D] = []
var clock := 1.0
var reduced_motion := false


func rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in points.size():
		var p := points[i]
		points[i] *= 1.0 + 0.28 * sin(p.x * 31 + p.y * 19) * cos(p.z * 23)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func setup(room: Node3D) -> void:
	var rock := rock_mesh()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("45342e")
	material.roughness = 1
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color("ff8e36")
	fire.emission_enabled = true
	fire.emission = Color("ff631c")
	fire.emission_energy_multiplier = 1.2
	var tail_shader := Shader.new()
	tail_shader.code = """shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
	void fragment(){float fade = UV.y; ALBEDO = mix(vec3(1.0,0.1,0.01),vec3(1.0,0.8,0.25),UV.y); ALPHA = fade*0.7;}"""
	var tail_material := ShaderMaterial.new()
	tail_material.shader = tail_shader
	var locations := [Vector3(-11, -0.35, -3), Vector3(11, -0.35, 0), Vector3(0, -0.35, 10), Vector3(-6, -0.35, 9), Vector3(8, -0.35, 9), Vector3(-11, -0.35, 5)]
	for i in locations.size():
		var meteor := Node3D.new()
		add_child(meteor)
		meteor.set_meta("impact", locations[i])
		var core := MeshInstance3D.new()
		core.mesh = rock
		core.material_override = material
		meteor.add_child(core)
		var tail := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.28
		cone.height = 2.8
		cone.radial_segments = 12
		tail.mesh = cone
		tail.rotation.x = PI / 2
		tail.position.z = 1.3
		tail.material_override = tail_material
		meteor.add_child(tail)
		var sparks := CPUParticles3D.new()
		sparks.amount = 22
		sparks.lifetime = 0.6
		sparks.local_coords = false
		sparks.direction = Vector3(0, 1, 0)
		sparks.initial_velocity_min = 0.2
		sparks.initial_velocity_max = 0.8
		sparks.gravity = Vector3(0, 0.2, 0)
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.035
		spark_mesh.height = 0.07
		spark_mesh.radial_segments = 4
		spark_mesh.rings = 2
		sparks.mesh = spark_mesh
		sparks.material_override = fire
		meteor.add_child(sparks)
		emitters.append(sparks)
		meteors.append(meteor)
		var flash := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 1.1
		disk.bottom_radius = 1.2
		disk.height = 0.04
		flash.mesh = disk
		flash.position = locations[i]
		var blast_shader := Shader.new()
		blast_shader.code = """shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
		void fragment(){float ring=exp(-pow((length(UV-vec2(0.5))-0.35)*12.0,2.0)); ALBEDO=vec3(1.0,0.25,0.03); ALPHA=ring*0.55;}"""
		var blast_material := ShaderMaterial.new()
		blast_material.shader = blast_shader
		flash.material_override = blast_material
		add_child(flash)
		flashes.append(flash)
		var lamp := OmniLight3D.new()
		lamp.position = locations[i] + Vector3.UP
		lamp.light_color = Color("ff8e36")
		lamp.omni_range = 4
		add_child(lamp)
		lamps.append(lamp)
		var crater := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.5
		ring.outer_radius = 1.1
		crater.mesh = ring
		crater.position = locations[i] - Vector3(0, 0.1, 0)
		crater.scale.y = 0.25
		crater.material_override = room._material(Color("30221e"))
		add_child(crater)
	_process(0)


func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
	for i in meteors.size():
		var t := fposmod(clock * 0.25 + i * 0.167, 1.0)
		var meteor := meteors[i]
		var impact: Vector3 = meteor.get_meta("impact")
		meteor.position = impact + Vector3(-2, 9, -4) * (1.0 - t)
		meteor.look_at(meteor.position + Vector3(2, -9, 4), Vector3.UP)
		meteor.visible = not reduced_motion and t < 0.96
		var energy := maxf(0, (t - 0.90) / 0.10)
		flashes[i].visible = energy > 0 and not reduced_motion
		flashes[i].scale = Vector3.ONE * maxf(0.1, energy)
		lamps[i].light_energy = energy * 3 if not reduced_motion else 0
