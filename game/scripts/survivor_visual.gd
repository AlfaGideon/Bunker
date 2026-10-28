extends Node3D
## Procedural skeletal animation for the CC0 Quaternius rig (not motion capture).
var skeletons: Array[Skeleton3D] = []
var phase := 0.0
var motion := 0.0
var gesture := 0.0


func _ready() -> void:
	_collect(self)


func _collect(node: Node) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	for child in node.get_children():
		_collect(child)


func _pose(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone, Quaternion(axis, angle))


func animate(delta: float, walking: bool, seed_offset: float) -> void:
	motion = move_toward(motion, 1.0 if walking else 0.0, delta * 7.0)
	phase += delta * (8.0 if walking else 1.8)
	gesture = maxf(0.0, gesture - delta)
	var stride := sin(phase) * motion
	for skeleton in skeletons:
		_pose(skeleton, "UpperLeg.L", Vector3.RIGHT, stride * 0.48)
		_pose(skeleton, "UpperLeg.R", Vector3.RIGHT, -stride * 0.48)
		_pose(skeleton, "LowerLeg.L", Vector3.RIGHT, maxf(0, -stride) * 0.65)
		_pose(skeleton, "LowerLeg.R", Vector3.RIGHT, maxf(0, stride) * 0.65)
		_pose(skeleton, "UpperArm.L", Vector3.FORWARD, -1.15 + stride * 0.2)
		_pose(skeleton, "UpperArm.R", Vector3.FORWARD, 1.15 - stride * 0.2 - gesture * 0.5)
		_pose(skeleton, "LowerArm.R", Vector3.RIGHT, -gesture * 0.65)
		_pose(skeleton, "Head", Vector3.UP, sin(phase * 0.3 + seed_offset) * 0.07)
	position.y = absf(sin(phase)) * motion * 0.035
