extends Node3D

const Meteors = preload("res://game/scripts/meteor_field.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const Visual = preload("res://game/scripts/survivor_visual.gd")
var emitters: Array[CPUParticles3D] = []
var kind := ""
var water: MeshInstance3D
var walkers: Array[Node3D] = []
var clock := 0.0
var reduced_motion := false
var meteor_field: Node3D
var hazard_lamp: OmniLight3D
var patrol_bounds: Rect2


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
		_build_hazard(room, weather)
		return
	room._box(Vector3(0, -0.45, 0), Vector3(160, 0.1, 160), Color("91a7b4"))
	var snow_material := StandardMaterial3D.new()
	snow_material.albedo_color = Color("9fb3bf")
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
		if preload("res://game/scripts/exterior_ground.gd").covered(room.layout, Vector2(drift.position.x, drift.position.z)):
			drift.position.x = side * 21.0
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
	if is_instance_valid(water) and water.material_override is ShaderMaterial:
		water.material_override.set_shader_parameter("still", reduced)
	if is_instance_valid(meteor_field):
		meteor_field.reduced_motion = reduced
	for child in get_children():
		if child.has_meta("aurora"):
			child.material_override.set_shader_parameter("still", reduced)
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
	water = room._box(Vector3(0, -0.24, 0), Vector3(160, 0.08, 160), Color("285b7b"))
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://game/shaders/flood_water.gdshader")
	water.material_override = water_mat
	_exterior_particles(Color("9fc2d9"), true)
	for i in 14:
		var debris: MeshInstance3D = room._box(Vector3(-11 if i % 2 == 0 else 11, -0.13, float(i) - 6), Vector3(0.7, 0.1, 0.3), Color("76654d"))
		debris.rotation.y = i * 0.7


func _build_meteors(room: Node3D) -> void:
	meteor_field = Meteors.new()
	add_child(meteor_field)
	meteor_field.setup(room)
	emitters.append_array(meteor_field.emitters)


# Infected follow a rectangular perimeter outside every procedural room and corridor.
func _perimeter_point(distance: float) -> Vector3:
	var w := patrol_bounds.size.x
	var h := patrol_bounds.size.y
	var d := fposmod(distance, 2.0 * (w + h))
	var x := patrol_bounds.position.x
	var z := patrol_bounds.position.y
	if d < w:
		return Vector3(x + d, -0.3, z)
	d -= w
	if d < h:
		return Vector3(x + w, -0.3, z + d)
	d -= h
	if d < w:
		return Vector3(x + w - d, -0.3, z + h)
	return Vector3(x, -0.3, z + h - (d - w))


func _build_walkers(room: Node3D) -> void:
	var layout_bounds: Rect2 = room.layout["bounds"]
	patrol_bounds = layout_bounds.grow(2.2)
	var perimeter := 2.0 * (patrol_bounds.size.x + patrol_bounds.size.y)
	for i in 8:
		var actor := Node3D.new()
		actor.name = "Infected%02d" % i
		add_child(actor)
		var pivot := Node3D.new()
		actor.add_child(pivot)
		var visual := Art.spawn(pivot, "modular_men_Worker" if i % 2 == 0 else "modular_women_Casual", Vector3.ZERO, Vector3(1, 1.4, 1), true)
		# Preserve each imported garment/skin material and texture, tint rather than replace it.
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(surface)
				if original is StandardMaterial3D:
					var infected: StandardMaterial3D = original.duplicate()
					infected.albedo_color *= Color(0.60, 0.76, 0.58, 1.0)
					infected.roughness = maxf(infected.roughness, 0.85)
					mesh.set_surface_override_material(surface, infected)
		visual.set_script(Visual)
		visual._collect(visual)
		var crawl := i == 2 or i == 6
		pivot.rotation.x = -1.08 if crawl else -0.18
		pivot.position.y = 0.35 if crawl else 0.0
		actor.set_meta("crawl", crawl)
		actor.set_meta("distance", perimeter * float(i) / 8.0)
		actor.set_meta("speed", 0.30 if crawl else 0.46 + float(i % 3) * 0.08)
		actor.position = _perimeter_point(actor.get_meta("distance"))
		var ahead := _perimeter_point(float(actor.get_meta("distance")) + 0.1) - actor.position
		actor.rotation.y = atan2(ahead.x, ahead.z)
		walkers.append(actor)
	_build_dust(Color("768b68"))


func _process(delta: float) -> void:
	if reduced_motion:
		return
	clock += delta
	if is_instance_valid(hazard_lamp):
		hazard_lamp.light_energy = 2.0 + sin(clock * 2.0) * 1.2
	if is_instance_valid(water):
		water.position.y = -0.24 + sin(clock * 0.9) * 0.025
	for i in walkers.size():
		var actor := walkers[i]
		var distance: float = actor.get_meta("distance") + delta * float(actor.get_meta("speed"))
		actor.set_meta("distance", distance)
		actor.position = _perimeter_point(distance)
		var direction := _perimeter_point(distance + 0.2) - actor.position
		if direction.length_squared() > 0.000001:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), minf(delta * 3.0, 1.0))
		var pivot: Node3D = actor.get_child(0)
		var visual: Node3D = pivot.get_child(0)
		visual.gesture = 0.8
		visual.animate(delta * (0.45 if actor.get_meta("crawl") else 0.65), true, float(i))
		pivot.rotation.z = sin(clock * 1.3 + float(i)) * (0.09 if actor.get_meta("crawl") else 0.045)


func _build_hazard(room: Node3D, weather: String) -> void:
	var colors := {"radiation": Color("616342"), "toxic": Color("3b5a4b"), "volcano": Color("4a3028"), "sand": Color("a68a58"), "heat": Color("8e624b"), "blackout": Color("162333"), "quake": Color("5b5550"), "solar": Color("253346")}
	room._box(Vector3(0, -0.43, 0), Vector3(160, 0.08, 160), colors.get(weather, Color("384550")))
	if weather == "solar":
		_build_aurora()
	elif weather == "blackout":
		room.sun.light_energy = 0.18
		for x in [-11, 11]:
			room._world_label("АВАРИЙНАЯ СЕТЬ", Vector3(x, 1.4, 3), 20)
			room._box(Vector3(x, 0.6, 3), Vector3(0.25, 2, 0.25), Color("485a6b"))
	else:
		_build_dust(Color("82b06d") if weather in ["radiation", "toxic"] else (Color("c5aa77") if weather in ["sand", "heat"] else Color("8d8078")))
	if weather in ["volcano", "quake"]:
		for side in [-1, 1]:
			for i in 12:
				var crack: MeshInstance3D = room._box(Vector3(side * 11, -0.36, i - 5.0), Vector3(0.12, 0.02, 1.3), Color("ed6325") if weather == "volcano" else Color("181d23"))
				crack.rotation.y = sin(float(i) * 2) * 0.8
				if weather == "volcano":
					var mat := StandardMaterial3D.new()
					mat.emission_enabled = true
					mat.emission = Color("ff7529")
					mat.albedo_color = Color("fd8e40")
					crack.material_override = mat
	if weather in ["radiation", "toxic", "volcano", "blackout"]:
		hazard_lamp = OmniLight3D.new()
		hazard_lamp.position = Vector3(10, 2, 5)
		hazard_lamp.omni_range = 7
		hazard_lamp.light_color = Color("ffa44b") if weather == "volcano" else Color("66b8cd") if weather == "blackout" else Color("a8d27c")
		add_child(hazard_lamp)


func _build_dust(color: Color) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 64
	texture.height = 64
	for zone in [Vector3(-12, 1, 0), Vector3(12, 1, 0), Vector3(0, 1, 10), Vector3(0, 1, -10)]:
		var particles := CPUParticles3D.new()
		particles.position = zone
		particles.amount = 30
		particles.lifetime = 7
		particles.preprocess = 5
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents = Vector3(2, 0.5, 6) if absf(zone.x) > 0 else Vector3(10, 0.5, 2)
		particles.direction = Vector3(1, 0.05, 0)
		particles.initial_velocity_min = 0.2
		particles.initial_velocity_max = 0.6
		particles.gravity = Vector3.ZERO
		var cloud := QuadMesh.new()
		cloud.size = Vector2(2.5, 2.5)
		particles.mesh = cloud
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particles.material_override = material
		add_child(particles)
		emitters.append(particles)


func _build_aurora() -> void:
	var ribbon := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(24, 5)
	ribbon.mesh = plane
	ribbon.position = Vector3(0, 3, -9)
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
	uniform bool still = false;
	void fragment(){float t=still?0.0:TIME; float wave=sin(UV.x*20.0+t*0.4)*0.12;
	float band=exp(-pow((UV.y-0.55-wave)*6.0,2.0));
	ALBEDO=mix(vec3(0.2,0.8,0.65),vec3(0.55,0.2,0.9),UV.y); ALPHA=band*0.65;}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	ribbon.material_override = material
	add_child(ribbon)
	ribbon.set_meta("aurora", true)
