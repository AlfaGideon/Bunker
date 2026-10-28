extends RefCounted

const Art = preload("res://game/scripts/scene_art.gd")


static func build(room: Node3D) -> void:
	var plan: Dictionary = room.layout
	var side: float = plan["med_side"]
	room._box(Vector3(0, -0.52, 0), Vector3(80, 0.2, 80), Color("242c30"))
	room._box(Vector3(0, -0.2, 0), Vector3(18, 0.4, 10.6), plan["floor_color"])
	for x in range(-8, 9):
		room._box(Vector3(x, 0.005, 0), Vector3(0.018, 0.01, 10.5), Color("526066"))
	for z in range(-5, 6):
		room._box(Vector3(0, 0.005, z), Vector3(18, 0.01, 0.018), Color("526066"))
	# One continuous floor and real partitions, not a room placed inside a set.
	for x in range(-8, 9, 2):
		Art.spawn(room, "modular_sci_fi_Wall_1", Vector3(x, 0, -5.2), Vector3(1.95, 2.0, 0.2))
	for wall in plan["blockers"].slice(6):
		var center: Vector2 = wall.get_center()
		var size: Vector2 = wall.size
		room._box(Vector3(center.x, 0.6, center.y), Vector3(0.13 if size.x < 1 else size.x, 1.2, 0.13 if size.y < 1 else size.y), Color("65777a"))
	var table: Vector3 = plan["table"]
	Art.spawn(room, "house_interior_pack_Table_RoundLarge", table, Vector3(3.1, 0.9, 1.7))
	Art.spawn(room, "survival_pack_Radio", plan["items"]["radio"]["at"] - Vector3(0, 0.14, 0), Vector3(0.5, 0.3, 0.25))
	for key in ["bed", "bed2", "medical"]:
		var at: Vector3 = plan["items"][key]["at"]
		Art.spawn(room, "house_interior_pack_Bed_Single", Vector3(at.x, 0, at.z), Vector3(1.9, 0.65, 0.9))
	var medical_at: Vector3 = plan["items"]["medical"]["at"]
	Art.spawn(room, "survival_pack_FirstAidKit", medical_at + Vector3(0, 0.03, 0), Vector3(0.45, 0.25, 0.3))
	var terminal: Vector3 = plan["items"]["terminal"]["at"]
	Art.spawn(room, "modular_sci_fi_Props_Computer", Vector3(terminal.x, 0, terminal.z), Vector3(1.0, 1.5, 0.8))
	var supply: Vector3 = plan["items"]["supply"]["at"]
	Art.spawn(room, "modular_sci_fi_Props_Crate", Vector3(supply.x, 0, supply.z), Vector3(1.1, 0.8, 0.8))
	room._world_label("РЕМКОМПЛЕКТ", supply + Vector3(0, 0.65, 0), 22)
	room._world_label("СПАЛЬНЯ • ОТДЫХ", Vector3(-side * 6.5, 2.1, -4.7), 24)
	room.med_label = room._world_label("МЕДБЛОК • ЗАКРЫТ", Vector3(side * 6.5, 2.1, -4.7), 24)
	room.med_gate = room._box(Vector3(side * 4.4, 1, -1.6), Vector3(0.17, 2, 1.8), Color("33464c"))
	room.door = room.med_gate
	room.med_cover = room._box(Vector3(side * 6.5, 1.85, -1.65), Vector3(3.75, 0.08, 6.3), Color("10191f"))
	room.med_light = OmniLight3D.new()
	room.med_light.position = Vector3(side * 6.5, 2.2, -1.8)
	room.med_light.light_color = Color("8ee3d3")
	room.med_light.light_energy = 0
	room.med_light.omni_range = 5
	room.add_child(room.med_light)
	room._world_label("УБЕЖИЩЕ %d • ПЛАН %d" % [room.capacity, plan["variant"] + 1], Vector3(0, 2.2, -5.1), 26)
	room._box(Vector3(3.8, -0.07, 6.5), Vector3(1.2, 0.12, 3.1), Color("8d7848"))
	room._box(Vector3(6.0, -0.07, 7.4), Vector3(5.5, 0.12, 1.2), Color("8d7848"))
	room._world_label("НАРУЖНЫЙ ВЫХОД →", Vector3(3.8, 0.8, 5.5), 22)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3, 0)
	lamp.omni_range = 7
	lamp.light_color = Color("ffcf89")
	lamp.light_energy = 1.4
	room.add_child(lamp)
