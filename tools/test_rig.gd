extends SceneTree

const Visual = preload("res://game/scripts/survivor_visual.gd")
const Art = preload("res://game/scripts/scene_art.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func world_bone(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var bone := skeleton.find_bone(Visual.bone_name(skeleton, bone_name))
	assert(bone >= 0, "Missing bone: " + bone_name)
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.menu.visible = false
	for i in room.actors.size():
		room._change_appearance(i, "male" if i % 2 == 0 else "female")
	# Keep the old rigs covered as well: exterior infected still use them.
	for name in ["modular_men_Worker", "modular_women_Casual"]:
		var legacy := Node3D.new()
		room.add_child(legacy)
		var model := Art.spawn(legacy, name, Vector3.ZERO, Vector3(1, 1.45, 1), true)
		model.set_script(Visual)
		model._collect(model)
		room.actors.append(legacy)
	for actor in room.actors:
		var visual = actor.get_child(0)
		var tracks := {"L": [], "R": []}
		var arm_tracks := {"L": [], "R": []}
		for tick in 48:
			visual.animate(1.0 / 20.0, tick < 44, 0.0)
			for skeleton in visual.skeletons:
				for side in ["L", "R"]:
					var hip := world_bone(skeleton, "UpperLeg." + side)
					var knee := world_bone(skeleton, "LowerLeg." + side)
					var foot := world_bone(skeleton, "Foot." + side)
					tracks[side].append(foot - hip)
					arm_tracks[side].append(world_bone(skeleton, "Hand." + side) - world_bone(skeleton, "UpperArm." + side))
					check(knee.y < hip.y, "Knee must remain below hip, including during stride")
					var lowest_foot := minf(foot.y, world_bone(skeleton, "Toes." + side).y) if is_instance_valid(visual.animation_player) else foot.y
					check(lowest_foot < knee.y, "Foot geometry must remain below knee (heel pivot may lift)")
		var forward: Vector3 = actor.global_basis.z.normalized()
		var sideways: Vector3 = actor.global_basis.x.normalized()
		for side in ["L", "R"]:
			var along: Array = []
			var lateral: Array = []
			for offset in tracks[side]:
				along.append(offset.dot(forward))
				lateral.append(offset.dot(sideways))
			var forward_range: float = along.max() - along.min()
			var sideways_range: float = lateral.max() - lateral.min()
			check(forward_range > 0.1, "Feet move forward/back, not just hang")
			check(sideways_range < (0.14 if is_instance_valid(visual.animation_player) else 0.04), "No sideways foot flapping on either rig")
		for side in ["L", "R"]:
			var feet := PackedFloat64Array()
			var hands := PackedFloat64Array()
			for sample in range(8, tracks[side].size() - 5):
				feet.append(tracks[side][sample].dot(forward))
				hands.append(arm_tracks[side][sample].dot(forward))
			var foot_mean := 0.0
			var hand_mean := 0.0
			for sample in feet.size():
				foot_mean += feet[sample] / feet.size()
				hand_mean += hands[sample] / hands.size()
			var covariance := 0.0
			for sample in feet.size():
				covariance += (feet[sample] - foot_mean) * (hands[sample] - hand_mean)
			check(covariance < -0.002, "Same-side arm and leg must swing in opposite directions: " + side)
		visual.animate(1.0, false, 0.0)
		for skeleton in visual.skeletons:
			for side in ["L", "R"]:
				var shoulder := world_bone(skeleton, "UpperArm." + side)
				var wrist := world_bone(skeleton, "Hand." + side)
				check(wrist.y < shoulder.y - 0.1, "Idle arms must hang below shoulders")
	print("Rig pose failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
