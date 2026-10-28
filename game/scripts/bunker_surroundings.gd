extends RefCounted

const Art = preload("res://game/scripts/scene_art.gd")


static func build(room: Node3D) -> void:
	# A facility cross-section instead of a floating square in an empty void.
	room._box(Vector3(0, -0.52, 0), Vector3(80, 0.2, 80), Color("242c30"))
	room._box(Vector3(-1.0, -0.3, 0.6), Vector3(18, 0.2, 16), Color("394549"))
	for x in range(-9, 9):
		room._box(Vector3(x, -0.18, 0.5), Vector3(0.025, 0.015, 15), Color("495558"))
	for z in range(-7, 9):
		room._box(Vector3(-1, -0.18, z), Vector3(18, 0.015, 0.025), Color("495558"))
	# Utility passage behind the discussion room.
	room._box(Vector3(0, -0.09, -5.3), Vector3(16, 0.1, 1.9), Color("5b6258"))
	for x in [-7, -4, -1, 2, 5]:
		room._box(Vector3(x, 0.7, -6.3), Vector3(2.8, 1.4, 0.18), Color("536165"))
		Art.spawn(room, "modular_sci_fi_Details_Vent_1", Vector3(x, 1.0, -6.15), Vector3(0.8, 0.1, 0.4)).rotation.x = PI / 2
	room._world_label("ТЕХНИЧЕСКИЙ КОРИДОР", Vector3(0, 1.3, -5.8), 22)
	# Dormitory on the left. Furniture is outside the playable meeting room.
	for z in [-2.6, 0.2, 3.0]:
		Art.spawn(room, "house_interior_pack_Bed_Bunk", Vector3(-7.2, -0.13, z), Vector3(2.0, 1.65, 1.0))
	room._world_label("ЖИЛОЙ ОТСЕК", Vector3(-7.0, 2.0, -3.5), 24)
	room._box(Vector3(-9, 0.7, 0), Vector3(0.2, 1.6, 9), Color("536165"))
	# Medical/storage wing on the right; deliberately open roof.
	Art.spawn(room, "house_interior_pack_Bed_Single", Vector3(6.4, -0.13, -2.2), Vector3(2.1, 0.65, 1.0))
	Art.spawn(room, "house_interior_pack_Kitchen_Fridge", Vector3(7.5, -0.13, -4.3), Vector3(0.7, 1.6, 0.7))
	Art.spawn(room, "modular_sci_fi_Props_Shelf", Vector3(6.1, -0.13, -4.3), Vector3(1.3, 1.6, 0.6))
	Art.spawn(room, "survival_pack_FirstAidKit", Vector3(6.4, 0.55, -2.2), Vector3(0.4, 0.2, 0.25))
	room._world_label("МЕДБЛОК", Vector3(6.2, 2.0, -3.5), 24)
	for x in [5.6, 6.6, 7.6]:
		Art.spawn(room, "modular_sci_fi_Props_Crate", Vector3(x, -0.13, 1.0), Vector3(0.7, 0.7, 0.7))
	# Foreground common room and clearly marked departure route.
	Art.spawn(room, "house_interior_pack_Table_RoundLarge", Vector3(-3.5, -0.13, 5.7), Vector3(1.8, 0.8, 1.2))
	Art.spawn(room, "house_interior_pack_Chair_1", Vector3(-4.7, -0.13, 5.7), Vector3(0.55, 0.9, 0.55))
	Art.spawn(room, "house_interior_pack_Light_Desk", Vector3(-3.5, 0.68, 5.7), Vector3(0.3, 0.4, 0.3))
	room._world_label("НАРУЖНЫЙ ВЫХОД →", Vector3(3.8, 0.7, 5.5), 24)
	room._box(Vector3(3.8, -0.06, 5.1), Vector3(1.2, 0.1, 3.7), Color("8d7848"))
	room._box(Vector3(6.0, -0.06, 6.7), Vector3(5.5, 0.1, 1.2), Color("8d7848"))
	for z in [3.9, 4.5, 5.1, 5.7]:
		room._box(Vector3(3.8, 0.01, z), Vector3(1.0, 0.025, 0.08), Color("d5b66c"))
	for x in [-4, -2, 0, 2]:
		room._box(Vector3(x, 0.08, 3.9), Vector3(1.7, 0.16, 0.12), Color("9b9d85"))
