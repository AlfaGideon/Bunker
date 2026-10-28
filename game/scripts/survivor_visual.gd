extends Node3D
## Procedural skeletal animation for the CC0 Quaternius rig (not motion capture).
var skeletons: Array[Skeleton3D] = []
var base_rotations: Dictionary = {}
var phase := 0.0
var motion := 0.0
var gesture := 0.0
var animation_player: AnimationPlayer
var current_clip := ""


func _ready() -> void:
	_collect(self)


func _collect(node: Node) -> void:
	if node is AnimationPlayer and get_meta("source", "").contains("kaykit"):
		animation_player = node
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
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


func _aim_bone(skeleton: Skeleton3D, bone_name: String, direction: Vector3) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	# Quaternius arms start in a T-pose. Convert a world-space direction
	# into the bone's rest-local axes rather than guessing Euler angles.
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var baseline: Quaternion = base_rotations[skeleton.get_instance_id()][bone]
	var rest_basis := skeleton.global_basis * parent_basis * Basis(baseline)
	var local_direction := (rest_basis.inverse() * direction).normalized()
	skeleton.set_bone_pose_rotation(bone, base_rotations[skeleton.get_instance_id()][bone] * Quaternion(Vector3.UP, local_direction))


func animate(delta: float, walking: bool, seed_offset: float, reduced_motion: bool = false) -> void:
	motion = move_toward(motion, 1.0 if walking else 0.0, delta * 7.0)
	phase += delta * (8.0 if walking else 1.8)
	gesture = maxf(0.0, gesture - delta)
	if is_instance_valid(animation_player):
		var clip := "Walking_C" if walking else ("Use_Item" if gesture > 0 else "Idle")
		if clip != current_clip:
			current_clip = clip
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animation_player.play(clip)
		animation_player.advance(delta * (1.8 if walking else 1.0))
		return
	var stride := sin(phase) * motion
	for skeleton in skeletons:
		var forward := global_basis.z.normalized()
		# Aim in the character's forward plane. Male/female rigs have different
		# local bone roll, so a fixed local X rotation is not a walking axis.
		for side in ["L", "R"]:
			var step := stride if side == "L" else -stride
			_aim_bone(skeleton, "UpperLeg." + side, Vector3.DOWN + forward * step * 0.48)
			_aim_bone(skeleton, "LowerLeg." + side, Vector3.DOWN + forward * (step * 0.12 - maxf(0.0, -step) * 0.35))
			_aim_bone(skeleton, "Foot." + side, forward)
		_aim_bone(skeleton, "UpperArm.L", Vector3.DOWN - forward * stride * 0.6)
		_aim_bone(skeleton, "UpperArm.R", Vector3.DOWN + forward * (stride * 0.6 + gesture))
		_pose(skeleton, "LowerArm.R", Vector3.RIGHT, -gesture * 0.65)
		_pose(skeleton, "Head", Vector3.UP, 0.0 if reduced_motion else sin(phase * 0.3 + seed_offset) * 0.07)
	position.y = 0.0 if reduced_motion else absf(sin(phase)) * motion * 0.035


static func bone_name(skeleton: Skeleton3D, original: String) -> String:
	if skeleton.find_bone(original) >= 0:
		return original
	var names := {"UpperLeg": "upperleg", "LowerLeg": "lowerleg", "Foot": "foot", "Toes": "toes", "UpperArm": "upperarm", "LowerArm": "lowerarm", "Hand": "hand", "Head": "head"}
	var parts := original.split(".")
	return str(names.get(parts[0], parts[0].to_lower())) + ("." + parts[1].to_lower() if parts.size() > 1 else "")
