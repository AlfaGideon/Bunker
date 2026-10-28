extends RefCounted

const Facilities = preload("res://game/scripts/facility_art.gd")
const Ground = preload("res://game/scripts/exterior_ground.gd")
const Finish = preload("res://game/scripts/bunker_finish.gd")
const Art = preload("res://game/scripts/scene_art.gd")


static func build(room: Node3D) -> void:
	var plan: Dictionary = room.layout
	var side: float = plan["med_side"]
	room._box(Vector3(0, -0.52, 0), Vector3(80, 0.2, 80), Color("242c30"))
	preload("res://game/scripts/modular_shell.gd").build(room)
	var table: Vector3 = plan["table"]
	var desk := Art.spawn(room, "house_interior_pack_Table_RoundLarge", table, Vector3(3.1, 0.9, 1.7))
	for mesh in desk.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = Finish.metal(Color("35434e"))
	Art.spawn(room, "survival_pack_Radio", plan["items"]["radio"]["at"] - Vector3(0, 0.14, 0), Vector3(0.5, 0.3, 0.25))
	for key in plan["beds"]:
		var at: Vector3 = plan["items"][key]["at"]
		Art.spawn(room, "house_interior_pack_Bed_Single", Vector3(at.x, 0, at.z), Vector3(1.9, 0.65, 0.9))
	var medical_at: Vector3 = plan["items"]["medical"]["at"]
	Art.spawn(room, "survival_pack_FirstAidKit", medical_at + Vector3(0, 0.03, 0), Vector3(0.45, 0.25, 0.3))
	var terminal: Vector3 = plan["items"]["terminal"]["at"]
	Art.spawn(room, "modular_sci_fi_Props_ComputerSmall", Vector3(terminal.x, 0, terminal.z), Vector3(1.0, 1.5, 0.8))
	var supply: Vector3 = plan["items"]["supply"]["at"]
	Art.spawn(room, "modular_sci_fi_Props_Chest", Vector3(supply.x, 0, supply.z), Vector3(1.1, 0.8, 0.8))
	room._world_label("СНАБЖЕНИЕ • СКЛАД", supply + Vector3(0, 0.65, 0), 22)
	room._world_label("СПАЛЬНЯ • ОТДЫХ", Vector3(-side * 6.5, 2.1, -4.7), 24)
	room.med_label.text = "МЕДОТСЕК • ЗАКРЫТ"
	room.med_gate = room._box(plan["modules"]["medical"]["gate"], (Vector3(0.17, 2, 2.2) if plan["modules"]["medical"]["horizontal"] else Vector3(2.2, 2, 0.17)), Color("33464c"))
	room.door = room.med_gate
	room.med_cover = MeshInstance3D.new()
	room.med_cover.visible = false
	room.add_child(room.med_cover)
	room._world_label("УБЕЖИЩЕ %d • ПЛАН %d" % [room.capacity, plan["variant"] + 1], Vector3(0, 2.2, -5.1), 26)

	room._world_label("НАРУЖНЫЙ ВЫХОД →", Vector3(3.8, 0.8, 5.5), 22)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3, 0)
	lamp.omni_range = 7
	lamp.light_color = Color("ffcf89")
	lamp.light_energy = 1.4
	room.add_child(lamp)
	Finish.decorate(room)
	Facilities.build(room)
	Ground.build(room)
