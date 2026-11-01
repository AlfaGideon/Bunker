extends SceneTree
# The bunker must branch: attached rooms hang off the medical bay and the
# kitchen, each with its own door, sign and furniture, and a room only becomes
# part of the walkable plan while its door is open.

var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run_test")


func sources(room: Node) -> Dictionary:
	var found := {}
	for node in room.find_children("*", "Node3D", true, false):
		var source := str(node.get_meta("source", ""))
		if not source.is_empty():
			found[source] = int(found.get(source, 0)) + 1
	return found


func run_test() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)

	var annexes: Dictionary = room.layout.get("annexes", {})
	check(annexes.size() >= 2, "The bunker has attached rooms")
	for kind in annexes:
		var annex: Dictionary = annexes[kind]
		check(annex["bounds"].size.x >= 4.0 and annex["bounds"].size.y >= 4.0,
			"Attached room is a room, not a closet: " + kind)
		check(room.layout["floors"].has(annex["bounds"]), "Annex floor is part of the plan: " + kind)
		check(room.layout["floors"].has(annex["corridor"]), "Annex corridor is part of the plan: " + kind)
		check(room.layout["items"].has(kind), "Annex has an interaction point: " + kind)
		check(room.annex_doors.has(kind), "Annex has its own door: " + kind)
		check(room.annex_labels.has(kind), "Annex has a sign over the door: " + kind)

	# A sealed room is not walkable; opening its door puts it on the grid.
	if annexes.has("pantry"):
		var pantry: Dictionary = annexes["pantry"]
		var middle: Vector3 = pantry["center"]
		room.navigation.close_annex("pantry")
		check(not room.navigation.is_walkable(middle), "A sealed pantry cannot be entered")
		room.navigation.open_annex("pantry")
		check(room.navigation.is_walkable(middle), "An open pantry can be entered")
		room.navigation.close_annex("pantry")

	# The rooms come with their own furniture.
	var found := sources(room)
	check(int(found.get("res://assets/blender/bed.glb", 0)) >= 3, "Bunks are Blender cots")
	check(int(found.get("res://assets/blender/toilet.glb", 0)) >= 1, "The bathroom has a toilet")
	check(int(found.get("res://assets/blender/operating_table.glb", 0)) >= 1, "The theatre has a table")
	check(int(found.get("res://assets/blender/pantry_shelf.glb", 0)) >= 1, "The pantry has shelving")
	check(int(found.get("res://assets/blender/chair.glb", 0)) >= 1, "The hall has a chair")
	check(room.layout["items"].has("chair"), "The chair can be used")
	check(not found.has("res://assets/quaternius/house_interior_pack_Bed_Single.glb"),
		"The old sofa-shaped bed is gone")

	# The bathroom gag needs its three sounds.
	for sound in ["toilet_flush", "toilet_giggle", "toilet_fart"]:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % sound), "Bathroom sound exists: " + sound)

	# Terrain relief: the surface must not be a flat sheet.
	var high := -100.0
	var low := 100.0
	for point in [Vector2(14, 18), Vector2(-22, 12), Vector2(30, -18), Vector2(-26, -24)]:
		var height: float = load("res://game/scripts/exterior_ground.gd").height_at(room, point)
		high = maxf(high, height)
		low = minf(low, height)
	check(high - low > 0.5, "The ground outside has real relief")

	print("Annex failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
