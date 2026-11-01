extends RefCounted
# The surface around the bunker. It used to be a nearly flat sheet with a sine
# wobble; now it is a real heightfield: dunes and ridges from layered noise, a
# flat apron where the bunker stands, a cleared ramp along the exit route, and
# Blender-built boulders scattered on the slopes.

const STEP := 2.0
const REACH := 66.0
const BASE_HEIGHT := -0.31


static func noise_seed(room: Node3D) -> int:
	return int(room.layout_seed) + 771


static func height_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.028
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	noise.fractal_lacunarity = 2.1
	return noise


# Height at a world point. Shared by the mesh and by every prop placed on it, so
# boulders and grass sit on the ground instead of floating or sinking.
static func height_at(room: Node3D, point: Vector2) -> float:
	var noise: FastNoiseLite = room.get_meta("terrain_noise", null)
	if noise == null:
		noise = height_noise(noise_seed(room))
		room.set_meta("terrain_noise", noise)
	var dunes: float = noise.get_noise_2d(point.x, point.y)
	var ridge: float = 1.0 - absf(noise.get_noise_2d(point.x * 2.6, point.y * 2.6))
	var level: float = BASE_HEIGHT + dunes * 1.35 + ridge * 0.55
	# A flat apron around the bunker, then a smooth climb into the dunes.
	var clearance := 1.0
	var nearest := 1.0e9
	for footprint in room.layout["floors"]:
		nearest = minf(nearest, _outside_distance(footprint, point))
	clearance = clampf((nearest - 3.0) / 6.0, 0.0, 1.0)
	# The exit ramp stays level so the way out reads as a cleared track.
	if Rect2(1.5, 4.2, 9.5, 5.0).grow(1.2).has_point(point):
		clearance = 0.0
	return lerpf(BASE_HEIGHT, level, clearance)


static func _outside_distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dz := maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
	if dx <= 0.0 and dz <= 0.0:
		return 0.0
	return sqrt(dx * dx + dz * dz)


static func build(room: Node3D) -> void:
	var weather: String = room.scenario["weather"]
	var snow := weather == "snow"
	var dry := weather in ["heat", "sand", "volcano"]
	var tint := Color("a4b5bf") if snow else Color("71604a") if dry else Color("435446")
	var material := ShaderMaterial.new()
	material.shader = load("res://game/shaders/terrain.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("dryness", 1.0 if dry else 0.0)
	room.set_meta("terrain_noise", height_noise(noise_seed(room)))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := -REACH
	var cells := int(REACH * 2.0 / STEP)
	for ix in cells:
		for iz in cells:
			var x := low + float(ix) * STEP
			var z := low + float(iz) * STEP
			if absf(x + STEP * 0.5) < 10.0 and absf(z + STEP * 0.5) < 7.0:
				continue
			var a := Vector3(x, height_at(room, Vector2(x, z)), z)
			var b := Vector3(x + STEP, height_at(room, Vector2(x + STEP, z)), z)
			var c := Vector3(x, height_at(room, Vector2(x, z + STEP)), z + STEP)
			var d := Vector3(x + STEP, height_at(room, Vector2(x + STEP, z + STEP)), z + STEP)
			for vertex in [a, b, c, b, d, c]:
				surface.set_uv(Vector2(vertex.x, vertex.z) * 0.08)
				surface.add_vertex(vertex)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	ground.material_override = material
	ground.visible = weather != "flood"
	ground.name = "TerrainSurface"
	room.add_child(ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed(room)
	scatter_boulders(room, rng, snow, dry)
	scatter_grass(room, rng, snow, dry)


static func scatter_boulders(room: Node3D, rng: RandomNumberGenerator, snow: bool, dry: bool) -> void:
	var scene := load("res://assets/blender/boulder.glb") as PackedScene
	if scene == null:
		return
	var tint := Color("cfd9dd") if snow else Color("6f6a60") if dry else Color("616b5f")
	for index in 26:
		var at := Vector2(rng.randf_range(-30, 30), rng.randf_range(-27, 29))
		if covered(room.layout, at):
			continue
		var model := scene.instantiate() as Node3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)
		var scale_value := rng.randf_range(0.5, 1.9)
		var stone_tint := tint.darkened(rng.randf_range(0.0, 0.25))
		for node in mesh:
			var target: MeshInstance3D = node
			var shaded := StandardMaterial3D.new()
			# Keep the snow crown pale in every weather instead of tinting it grey.
			shaded.albedo_color = Color("dee6e9") if target.name.begins_with("boulder-snow") else stone_tint
			shaded.roughness = 0.92
			target.material_override = shaded
		model.scale = Vector3.ONE * scale_value
		model.rotation.y = rng.randf_range(0.0, TAU)
		model.position = Vector3(at.x, height_at(room, at) - 0.08 * scale_value, at.y)
		room.add_child(model)


static func scatter_grass(room: Node3D, rng: RandomNumberGenerator, snow: bool, dry: bool) -> void:
	var grass_scene := (load("res://assets/quaternius/nature_pack_Grass_Short.glb") as PackedScene).instantiate()
	var grass_mesh_node: MeshInstance3D = grass_scene.find_children("*", "MeshInstance3D", true, false)[0]
	var grass_mesh: Mesh = grass_mesh_node.mesh
	var grass_basis: Basis = grass_mesh_node.transform.basis
	grass_scene.free()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = grass_mesh
	batch.instance_count = 90 if snow or dry else 260
	for i in batch.instance_count:
		var at := Vector2(rng.randf_range(-24, 24), rng.randf_range(-20, 22))
		if covered(room.layout, at):
			at.x = 24.0 if at.x > 0 else -24.0
		var scale_value := rng.randf_range(0.4, 1.0)
		var tilt := Basis(Vector3.UP, rng.randf_range(0, TAU)) * grass_basis.scaled(Vector3.ONE * scale_value)
		batch.set_instance_transform(i, Transform3D(tilt, Vector3(at.x, height_at(room, at) + 0.02, at.y)))
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
