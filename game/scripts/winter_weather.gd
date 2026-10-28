extends Node3D

var emitters: Array[CPUParticles3D] = []


func setup(room: Node3D, weather: String) -> void:
	if weather != "snow":
		return
	room._box(Vector3(0, -0.45, 0), Vector3(80, 0.1, 80), Color("c7d5de"))
	var snow_material := StandardMaterial3D.new()
	snow_material.albedo_color = Color("e2edf2")
	snow_material.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 8146
	for i in 24:
		var drift := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1
		sphere.height = 2
		drift.mesh = sphere
		drift.material_override = snow_material
		var side := -1 if i % 2 == 0 else 1
		drift.position = Vector3(side * rng.randf_range(9.5, 14), -0.25, rng.randf_range(-10, 13))
		drift.scale = Vector3(rng.randf_range(0.7, 1.8), rng.randf_range(0.15, 0.45), rng.randf_range(0.8, 2))
		add_child(drift)
	for zone in [Vector3(-12, 5, 0), Vector3(12, 5, 0), Vector3(0, 5, 12), Vector3(0, 5, -11)]:
		var snow := CPUParticles3D.new()
		snow.amount = 70
		snow.lifetime = 6
		snow.preprocess = 4
		snow.fixed_fps = 30
		snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		snow.emission_box_extents = Vector3(2.5, 2.0, 8) if absf(zone.x) > 0 else Vector3(14, 2, 2.5)
		snow.position = zone
		snow.direction = Vector3(0.2, -1, 0.1)
		snow.spread = 12
		snow.initial_velocity_min = 1.3
		snow.initial_velocity_max = 2.0
		snow.gravity = Vector3(0.15, -0.1, 0.05)
		var flake := SphereMesh.new()
		flake.radius = 0.025
		flake.height = 0.05
		flake.radial_segments = 4
		flake.rings = 2
		snow.mesh = flake
		snow.material_override = snow_material
		add_child(snow)
		emitters.append(snow)


func set_reduced_motion(reduced: bool) -> void:
	for snow in emitters:
		snow.visible = not reduced
		snow.emitting = not reduced
