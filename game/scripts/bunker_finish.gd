extends RefCounted

const Art = preload("res://game/scripts/scene_art.gd")
static var materials := {}


static func metal(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	varying vec3 world;
	void vertex(){world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
	uniform vec4 tint : source_color;
	void fragment(){
		vec2 p = world.xz * 1.5;
		vec2 line = abs(fract(p)-0.5);
		float seam = smoothstep(0.475,0.495,max(line.x,line.y));
		float grain = fract(sin(dot(floor(world.xz*240.0),vec2(127.1,311.7)))*43758.5453);
		ALBEDO = tint.rgb * (0.88+grain*0.16) * (1.0-seam*0.55);
		METALLIC = 0.45; ROUGHNESS = 0.62;
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", color)
	materials[key] = material
	return material


static func glow(room: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var strip: MeshInstance3D = room._box(at, size, color)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	strip.material_override = mat
	return strip


static func wall(room: Node3D, center: Vector2, size: Vector2) -> void:
	var vertical := size.x < 1
	var length: float = size.y if vertical else size.x
	var count := ceili(length / 1.4)
	for i in count:
		var offset := (float(i) + 0.5) * length / count - length / 2
		var at := Vector3(center.x, 0, center.y) + (Vector3(0, 0, offset) if vertical else Vector3(offset, 0, 0))
		var panel := Art.spawn(room, "modular_sci_fi_Wall_3", at, Vector3(length / count - 0.02, 1.28, 0.16))
		panel.rotation.y = PI / 2 if vertical else 0
		glow(room, at + Vector3(0, 1.29, 0), Vector3(0.07, 0.025, length / count - 0.04) if vertical else Vector3(length / count - 0.04, 0.025, 0.07), Color("61c7d0"))


static func decorate(room: Node3D) -> void:
	var side: float = room.layout["med_side"]
	for x in range(-8, 9, 2):
		for z in range(-4, 5, 2):
			var tile := Art.spawn(room, "modular_sci_fi_FloorTile_Basic2", Vector3(x, 0.004, z), Vector3(1.97, 0.025, 1.97))
			for mesh in tile.find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = metal(Color("485965") if absf(x) < 4 else (Color("51534e") if x * side < 0 else Color("365b60")))
	for x in range(-8, 9, 2):
		Art.spawn(room, "modular_sci_fi_Details_Vent_2", Vector3(x, 1.1, -5.02), Vector3(0.8, 0.35, 0.14))
		Art.spawn(room, "modular_sci_fi_Details_Pipes_Long", Vector3(x, 1.65, -5.0), Vector3(1.8, 0.18, 0.18))
		glow(room, Vector3(x, 2.02, -5.0), Vector3(1.6, 0.055, 0.06), Color("b4e6f3"))
		Art.spawn(room, "modular_sci_fi_Wall_4", Vector3(x, 0, -5.22), Vector3(0.18, 2.05, 0.25))
	for x in [-4.05, 4.05]:
		for z in [-4.2, -2.8, 2.8, 4.2]:
			glow(room, Vector3(x, 0.045, z), Vector3(0.04, 0.015, 0.8), Color("edba63"))
	# Equipment stays on the wall or within existing furniture footprints.
	for key in room.layout["beds"] + ["medical"]:
		var at: Vector3 = room.layout["items"][key]["at"]
		glow(room, Vector3(at.x, 0.11, at.z), Vector3(1.7, 0.04, 0.65), Color("6cc4d3") if key == "medical" else Color("d4ab72"))
		for end in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.035
			cylinder.bottom_radius = 0.035
			cylinder.height = 0.9
			rail.mesh = cylinder
			rail.rotation.x = PI / 2
			rail.position = Vector3(at.x + end, 0.82, at.z)
			rail.material_override = room._material(Color("a5bac2"))
			room.add_child(rail)
	room.med_gate.mesh = null
	var hatch := Art.spawn(room.med_gate, "modular_sci_fi_Door_Single", Vector3(0, -1, 0), Vector3(1.7, 2, 0.18))
	hatch.rotation.y = PI / 2
	room.med_cover.material_override = metal(Color("1b2e38"))
	for key in ["terminal", "supply"]:
		var at: Vector3 = room.layout["items"][key]["at"]
		glow(room, Vector3(at.x, 0.05, at.z), Vector3(1.3, 0.03, 0.85), Color("4eb4d3"))
	# Differently coloured local light pools, not a flat ambient-only room.
	for at in [Vector3(-6.5 * side, 2.5, 0), Vector3(0, 3, -2.3)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color("ffd5a0") if absf(at.x) > 1 else Color("a0d8ef")
		light.light_energy = 0.8
		light.omni_range = 5
		room.add_child(light)
	var tactical := MeshInstance3D.new()
	var screen := PlaneMesh.new()
	screen.size = Vector2(2.1, 1.1)
	tactical.mesh = screen
	tactical.position = room.layout["table"] + Vector3(0.3, 0.915, 0)
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded, blend_add, depth_draw_never;
	void fragment(){vec2 p=UV-vec2(0.5); float grid=step(0.94,fract(UV.x*16.0))+step(0.94,fract(UV.y*8.0));
	float ring=1.0-smoothstep(0.01,0.025,abs(length(p)-0.3));
	ALBEDO=vec3(0.13,0.7,0.8); ALPHA=min(0.7,grid*0.25+ring*0.6);}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	tactical.material_override = material
	room.add_child(tactical)
