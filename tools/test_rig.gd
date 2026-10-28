extends SceneTree

var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func world_bone(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var bone := skeleton.find_bone(bone_name)
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
	for actor in room.actors:
		var visual = actor.get_child(0)
		var tracks := {"L": [], "R": []}
		for tick in 48:
			visual.animate(1.0 / 20.0, tick < 44, 0.0)
			for skeleton in visual.skeletons:
				for side in ["L", "R"]:
					var hip := world_bone(skeleton, "UpperLeg." + side)
					var knee := world_bone(skeleton, "LowerLeg." + side)
					var foot := world_bone(skeleton, "Foot." + side)
					tracks[side].append(foot - hip)
					check(knee.y < hip.y, "Knee must remain below hip, including during stride")
					check(foot.y < knee.y, "Foot must remain below knee")
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
			check(sideways_range < 0.04, "No sideways foot flapping on either rig")
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
