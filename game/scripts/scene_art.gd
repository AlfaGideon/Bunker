class_name BunkerArt
extends RefCounted

const FOLDER := "res://assets/quaternius/"


static func _bounds(node: Node, result: Array, reference: Transform3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = reference * node.global_transform * node.get_aabb()
		if result.is_empty():
			result.append(bounds)
		else:
			result[0] = result[0].merge(bounds)
	for child in node.get_children():
		_bounds(child, result, reference)


static func spawn(parent: Node3D, filename: String, at: Vector3,
		size: Vector3, uniform: bool = false) -> Node3D:
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	var scene := load(FOLDER + filename + ".glb") as PackedScene
	assert(scene != null, "Missing art: " + filename)
	var model := scene.instantiate() as Node3D
	wrapper.add_child(model)
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
	wrapper.position = at
	return wrapper
