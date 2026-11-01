class_name BunkerArt
extends RefCounted

const FOLDER := "res://assets/quaternius/"
const BLENDER := "res://assets/blender/"

# Ink outline: an inverted hull drawn unshaded, which is what makes the Blender
# props read as animated film rather than grey boxes. Godot's built-in
# BaseMaterial3D grow flag is not uniform across renderers, so the expansion
# happens explicitly in the vertex stage.
const INK_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 ink : source_color = vec4(0.024, 0.055, 0.055, 1.0);
uniform float thickness = 0.012;
void vertex() {
	VERTEX += NORMAL * thickness;
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""


static func ink_outline(model: Node3D, thickness: float = 0.012) -> void:
	var shader := Shader.new()
	shader.code = INK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("thickness", thickness)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var shell := MeshInstance3D.new()
		shell.name = mesh.name + "_ink"
		shell.mesh = mesh.mesh
		shell.material_override = material
		# Parented to the mesh, not to its parent node: the shell then follows
		# the knobs and cursors that game/scripts/station_motion.gd animates.
		shell.transform = Transform3D.IDENTITY
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mesh.add_child(shell)


static func _bounds(node: Node, result: Array, reference: Transform3D) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var bounds: AABB = reference * node.global_transform * node.get_aabb()
		if result.is_empty():
			result.append(bounds)
		else:
			result[0] = result[0].merge(bounds)
	for child in node.get_children():
		_bounds(child, result, reference)


static func spawn(parent: Node3D, filename: String, at: Vector3,
		size: Vector3, uniform: bool = false, ink: float = 0.0) -> Node3D:
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	var source := FOLDER + filename + ".glb"
	if filename.begins_with("kaykit_"):
		source = "res://assets/kaykit/" + filename.trim_prefix("kaykit_") + ".glb"
	elif filename.begins_with("blender_"):
		source = BLENDER + filename.trim_prefix("blender_") + ".glb"
	var scene := load(source) as PackedScene
	assert(scene != null, "Missing art: " + filename)
	var model := scene.instantiate() as Node3D
	wrapper.add_child(model)
	wrapper.set_meta("source", source)
	if filename.begins_with("kaykit_"):
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for accessory in ["Sword", "Shield", "Knife", "Crossbow", "Throwable", "Cape", "Helmet", "Axe", "Wand", "Staff", "Spellbook", "Mug", "Mage_Hat", "Barbarian_Hat"]:
				if accessory in mesh.name:
					mesh.visible = false
	var found: Array = []
	_bounds(model, found, wrapper.global_transform.affine_inverse())
	assert(not found.is_empty(), "Model has no meshes: " + filename)
	var bounds: AABB = found[0]
	var factor := Vector3(size.x / maxf(bounds.size.x, 0.001),
		size.y / maxf(bounds.size.y, 0.001), size.z / maxf(bounds.size.z, 0.001))
	if uniform:
		factor = Vector3.ONE * factor.y
	model.scale *= factor
	model.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * factor.x,
		-bounds.position.y * factor.y, -(bounds.position.z + bounds.size.z * 0.5) * factor.z)
	if ink > 0.0:
		ink_outline(model, ink)
	wrapper.position = at
	return wrapper
