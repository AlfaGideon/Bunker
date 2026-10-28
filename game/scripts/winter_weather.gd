extends Node3D

const Art = preload("res://game/scripts/scene_art.gd")
const Visual = preload("res://game/scripts/survivor_visual.gd")
var emitters: Array[CPUParticles3D] = []
var kind := ""
var water: MeshInstance3D
var walkers: Array[Node3D] = []
var clock := 0.0
var reduced_motion := false


func setup(room: Node3D, weather: String) -> void:
	kind = weather
	if weather == "flood":
		_build_flood(room)
		return
	if weather == "meteors":
		_build_meteors(room)
		return
	if weather == "zombies":
		_build_walkers(room)
		return
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
	reduced_motion = reduced
	for snow in emitters:
		snow.visible = not reduced
		snow.emitting = not reduced


func _exterior_particles(color: Color, falling: bool) -> void:
	for zone in [Vector3(-12, 7, 0), Vector3(12, 7, 0), Vector3(0, 7, 10), Vector3(0, 7, -10)]:
		var particles := CPUParticles3D.new()
		particles.position = zone
		particles.amount = 45 if falling else 14
		particles.lifetime = 2.5
		particles.preprocess = 2
		particles.fixed_fps = 30
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents = Vector3(2.5, 1, 6) if absf(zone.x) > 0 else Vector3(10, 1, 2)
		particles.direction = Vector3(0.4, -1, 0.1)
		particles.spread = 6
		particles.initial_velocity_min = 4 if falling else 7
		particles.initial_velocity_max = 6 if falling else 10
		particles.gravity = Vector3(0, -1, 0)
		var streak := BoxMesh.new()
		streak.size = Vector3(0.025 if falling else 0.09, 0.3 if falling else 0.8, 0.025 if falling else 0.09)
		particles.mesh = streak
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = not falling
		mat.emission = color
		particles.material_override = mat
		add_child(particles)
		emitters.append(particles)


func _build_flood(room: Node3D) -> void:
	water = room._box(Vector3(0, -0.24, 0), Vector3(80, 0.08, 80), Color("285b7b"))
	_exterior_particles(Color("9fc2d9"), true)
	for i in 14:
		var debris := room._box(Vector3(-11 if i % 2 == 0 else 11, -0.13, float(i) - 6), Vector3(0.7, 0.1, 0.3), Color("76654d"))
		debris.rotation.y = i * 0.7


func _build_meteors(room: Node3D) -> void:
	_exterior_particles(Color("ff943e"), false)
	for i in 8:
		var crater := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.5
		ring.outer_radius = 0.9
		crater.mesh = ring
		crater.material_override = room._material(Color("50372e"))
		crater.position = Vector3(-11 if i % 2 == 0 else 11, -0.25, float(i) * 2 - 7)
		add_child(crater)


func _build_walkers(room: Node3D) -> void:
	for i in 6:
		var actor := Node3D.new()
		add_child(actor)
		var visual := Art.spawn(actor, "modular_men_Worker" if i % 2 == 0 else "modular_women_Casual", Vector3.ZERO, Vector3(1, 1.4, 1), true)
		visual.set_script(Visual)
		visual._collect(visual)
		actor.position = Vector3(-10.3 if i % 2 == 0 else 10.3, -0.3, i * 1.8 - 4)
		actor.set_meta("origin", actor.position)
		walkers.append(actor)
		var beacon := room._box(actor.position + Vector3(0, 0, -1), Vector3(0.15, 0.8, 0.15), Color("ae5748"))
		beacon.rotation.z = 0.25


func _process(delta: float) -> void:
	if reduced_motion:
		return
	clock += delta
	if is_instance_valid(water):
		water.position.y = -0.24 + sin(clock * 0.9) * 0.025
	for i in walkers.size():
		var actor := walkers[i]
		var previous := actor.position
		var origin: Vector3 = actor.get_meta("origin")
		actor.position = origin + Vector3(sin(clock * 0.3 + i) * 0.4, 0, sin(clock * 0.45 + i) * 0.8)
		var direction := actor.position - previous
		if direction.length_squared() > 0.000001:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), delta * 2)
		actor.get_child(0).animate(delta * 0.6, true, float(i))
