extends Node3D
## Procedural skeletal animation for the CC0 Quaternius rig (not motion capture).
var skeletons: Array[Skeleton3D] = []
var base_rotations: Dictionary = {}
var phase := 0.0
var motion := 0.0
var gesture := 0.0


func _ready() -> void:
	_collect(self)


func _collect(node: Node) -> void:
	if node is Skeleton3D:
		if not skeletons.has(node):
			skeletons.append(node)
			var rotations: Array[Quaternion] = []
			for bone in node.get_bone_count():
				rotations.append(node.get_bone_pose_rotation(bone))
			base_rotations[node.get_instance_id()] = rotations
	for child in node.get_children():
		_collect(child)


func _pose(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone, base_rotations[skeleton.get_instance_id()][bone] * Quaternion(axis, angle))


func _arm(skeleton: Skeleton3D, bone_name: String, direction: Vector3) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	# Quaternius arms start in a T-pose. Convert a world-space direction
	# into the bone's rest-local axes rather than guessing Euler angles.
	var rest_basis := skeleton.global_basis * skeleton.get_bone_global_rest(bone).basis
	var local_direction := (rest_basis.inverse() * direction).normalized()
	skeleton.set_bone_pose_rotation(bone, base_rotations[skeleton.get_instance_id()][bone] * Quaternion(Vector3.UP, local_direction))


func animate(delta: float, walking: bool, seed_offset: float, reduced_motion: bool = false) -> void:
	motion = move_toward(motion, 1.0 if walking else 0.0, delta * 7.0)
	phase += delta * (8.0 if walking else 1.8)
	gesture = maxf(0.0, gesture - delta)
	var stride := sin(phase) * motion
	for skeleton in skeletons:
		_pose(skeleton, "UpperLeg.L", Vector3.RIGHT, stride * 0.48)
		_pose(skeleton, "UpperLeg.R", Vector3.RIGHT, -stride * 0.48)
		_pose(skeleton, "LowerLeg.L", Vector3.RIGHT, maxf(0, -stride) * 0.65)
		_pose(skeleton, "LowerLeg.R", Vector3.RIGHT, maxf(0, stride) * 0.65)
		var forward := global_basis.z.normalized()
		_arm(skeleton, "UpperArm.L", Vector3.DOWN + forward * stride * 0.6)
		_arm(skeleton, "UpperArm.R", Vector3.DOWN + forward * (-stride * 0.6 + gesture))
		_pose(skeleton, "LowerArm.R", Vector3.RIGHT, -gesture * 0.65)
		_pose(skeleton, "Head", Vector3.UP, 0.0 if reduced_motion else sin(phase * 0.3 + seed_offset) * 0.07)
	position.y = 0.0 if reduced_motion else absf(sin(phase)) * motion * 0.035
