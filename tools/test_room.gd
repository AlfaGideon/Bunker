extends SceneTree

var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	for actor in room.actors:
		check(not actor.get_child(0).skeletons.is_empty(), "Imported character has skeleton")
	for target in [Vector3(0, 0, -2.6), Vector3(3.8, 0, 1.8), Vector3(-3.8, 0, 0)]:
		room._set_route(target)
		for tick in 300:
			room._physics_process(1.0 / 30.0)
			check(room.navigation.is_walkable(room.actors[0].position), "Movement avoids furniture")
		check(room.actors[0].position.distance_to(target) < 0.22, "Character reaches destination")
	check(room.actors[0].get_child(0).motion < 0.01, "Walk animation stops on arrival")
	print("Room behavior failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
