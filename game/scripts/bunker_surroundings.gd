extends RefCounted

const Facilities = preload("res://game/scripts/facility_art.gd")
const Ground = preload("res://game/scripts/exterior_ground.gd")
const Finish = preload("res://game/scripts/bunker_finish.gd")
const Art = preload("res://game/scripts/scene_art.gd")
const Station = preload("res://game/scripts/station_motion.gd")


static func build(room: Node3D) -> void:
	var plan: Dictionary = room.layout
	var side: float = plan["med_side"]
	room._box(Vector3(0, -1.15 if room.scenario["weather"] == "flood" else -0.52, 0), Vector3(160, 0.2, 160), Color("242c30"))
	preload("res://game/scripts/modular_shell.gd").build(room)
	var table: Vector3 = plan["table"]
	var desk := Art.spawn(room, "house_interior_pack_Table_RoundLarge", table, Vector3(3.1, 0.9, 1.7))
	for mesh in desk.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = Finish.metal(Color("35434e"))
	# The Blender receiver stands on the table itself, so the model the player
	# taps is the model they see; the ink hull gives it the stylised edge.
	var receiver := Art.spawn(room, "blender_radio_station", Vector3(table.x - 0.7, 0.91, table.z),
		Vector3(0.64, 0.48, 0.38), false, 0.010)
	room.radio_motion = Station.attach(receiver, "radio")
	# Galley counter at the south edge of the table: pot, bowls, tins on one deck.
	var galley := Art.spawn(room, "blender_food_station", Vector3(table.x + 2.05, 0, table.z + 1.05),
		Vector3(1.0, 0.92, 0.5), false, 0.010)
	Station.attach(galley, "steam")
	for key in plan["beds"]:
		var at: Vector3 = plan["items"][key]["at"]
		Art.spawn(room, "house_interior_pack_Bed_Single", Vector3(at.x, 0, at.z), Vector3(1.9, 0.65, 0.9))
	var terminal: Vector3 = plan["items"]["terminal"]["at"]
	var console := Art.spawn(room, "blender_terminal", Vector3(terminal.x, 0, terminal.z),
		Vector3(0.84, 1.12, 0.5), false, 0.010)
	Station.attach(console, "terminal")
	var supply: Vector3 = plan["items"]["supply"]["at"]
	Art.spawn(room, "blender_crate", Vector3(supply.x, 0, supply.z), Vector3(1.0, 0.72, 0.8), false, 0.010)
	room._world_label("СНАБЖЕНИЕ • СКЛАД", supply + Vector3(0, 0.65, 0), 22)
	room._world_label("СПАЛЬНЯ • ОТДЫХ", Vector3(-side * 6.5, 2.1, -4.7), 24)
	room.med_label.text = "МЕДОТСЕК • ЗАКРЫТ"
	room.med_gate = room._box(plan["modules"]["medical"]["gate"], (Vector3(0.17, 2, 2.2) if plan["modules"]["medical"]["horizontal"] else Vector3(2.2, 2, 0.17)), Color("33464c"))
	room.door = room.med_gate
	room.med_cover = MeshInstance3D.new()
	room.med_cover.visible = false
	room.add_child(room.med_cover)
	room._world_label("УБЕЖИЩЕ %d • ПЛАН %d" % [room.capacity, plan["variant"] + 1], Vector3(0, 2.2, -5.1), 26)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3, 0)
	lamp.omni_range = 7
	lamp.light_color = Color("ffcf89")
	lamp.light_energy = 1.4
	room.add_child(lamp)
	Finish.decorate(room)
	Facilities.build(room)
	Ground.build(room)
