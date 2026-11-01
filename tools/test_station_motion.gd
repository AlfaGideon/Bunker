extends SceneTree
# The stations must be alive: knobs turn and the needle slides when the record
# changes, the terminal cursor walks the screen, the steam rises and fades.
# Every check steps the motion by hand so the result does not depend on frame
# timing in CI.

var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run_test")


func motion_of(kind: String, room: Node) -> Node:
	for node in room.find_children("*", "Node", true, false):
		if node.has_meta("motion") and str(node.get_meta("motion")) == kind:
			return node
	return null


func step(motion: Node, seconds: float) -> void:
	var frames := 40
	for index in frames:
		motion._process(seconds / float(frames))


func run_test() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)

	check(is_instance_valid(room.radio_motion), "The receiver has a motion driver")
	var radio: Node = room.radio_motion
	check(radio != null and radio.kind == "radio", "Receiver motion is the radio kind")
	check(radio != null and radio.knobs.size() == 3, "All three knobs are separate nodes")
	check(radio != null and radio.needle != null, "The tuning needle is its own node")

	var needle_before: float = radio.needle.position.x
	var knob_before: Quaternion = radio.knobs[0].quaternion
	radio.tune(3)
	check(radio.tuning > 0.5, "Tuning lights the dial")
	step(radio, 0.8)
	check(absf(radio.needle.position.x - needle_before) > 0.01, "The needle slides to a new station")
	check(not radio.knobs[0].quaternion.is_equal_approx(knob_before), "The knobs turn with the record")

	var terminal: Node = motion_of("terminal", room)
	check(terminal != null, "The hall console has a motion driver")
	if terminal != null and terminal.cursor != null:
		var cursor_before: float = terminal.cursor.position.y
		step(terminal, 1.4)
		check(absf(terminal.cursor.position.y - cursor_before) > 0.01, "The cursor walks down the screen")
		check(terminal.cursor.visible, "The cursor stays visible while typing")
	else:
		check(false, "The console exports a cursor node")

	var steam: Node = motion_of("steam", room)
	check(steam != null, "The galley pot has a steam driver")
	if steam != null and steam.steam != null:
		var height_before: float = steam.steam.position.y
		var alpha_before: float = 1.0
		if steam.puff != null:
			alpha_before = steam.puff.albedo_color.a
		step(steam, 2.0)
		check(steam.steam.position.y > height_before, "The steam rises")
		if steam.puff != null:
			check(steam.puff.albedo_color.a < alpha_before, "The steam fades as it rises")
	else:
		check(false, "The galley exports a steam node")

	# The ink hull must ride on its mesh, otherwise animated parts lose the edge.
	var carried := 0
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).ends_with("_ink") and mesh.get_parent() is MeshInstance3D:
			carried += 1
	check(carried > 0, "Ink outlines are parented to their meshes")

	print("Station motion failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
