extends RefCounted
# Attached rooms: the operating theatre, the pantry and the bathroom. The shell
# (floors, ceilings, walls with the corridor opening) is drawn by
# modular_shell.gd from layout["floors"]; this script dresses the rooms, hangs
# their doors and puts a sign over each corridor.

const Art = preload("res://game/scripts/scene_art.gd")
const Finish = preload("res://game/scripts/bunker_finish.gd")
const Station = preload("res://game/scripts/station_motion.gd")

const INK := 0.008


static func build(room: Node3D) -> void:
	room.annex_doors = {}
	room.annex_labels = {}
	var plan: Dictionary = room.layout
	if not plan.has("annexes"):
		return
	for kind in plan["annexes"]:
		var annex: Dictionary = plan["annexes"][kind]
		_door(room, kind, annex)
		_light(room, annex, kind)
		match kind:
			"operating":
				_operating(room, annex)
			"pantry":
				_pantry(room, annex)
			"bathroom":
				_bathroom(room, annex)


static func _face(from: Vector3, toward: Vector3) -> float:
	return atan2(toward.x - from.x, toward.z - from.z)


# A room hangs off a corridor, so "left", "right" and "against the far wall"
# depend on which wall the room sits on. Everything is placed in wall space:
# `back` runs from the corridor into the room, `along` runs across it.
static func _axes(annex: Dictionary) -> Array:
	var inward: Vector2 = annex["inward"]
	var back := Vector3(inward.x, 0, inward.y)
	var along := Vector3(-inward.y, 0, inward.x)
	return [back, along]


static func _slab(along: Vector3, wide: float, deep: float, tall: float) -> Vector3:
	return Vector3(absf(along.x) * wide + absf(along.z) * deep, tall,
		absf(along.z) * wide + absf(along.x) * deep)


static func _door(room: Node3D, kind: String, annex: Dictionary) -> void:
	var gate: Vector3 = annex["gate"]
	var horizontal: bool = annex["horizontal"]
	var size := Vector3(0.16, 2.05, 2.2) if horizontal else Vector3(2.2, 2.05, 0.16)
	var door: MeshInstance3D = room._box(gate, size, Color("2c4a4d"))
	door.material_override = Finish.metal(Color("2c4a4d"))
	room.annex_doors[kind] = door
	# Warning stripe down the middle, so a sealed door reads as sealed.
	room._box(gate + Vector3(0, 0, 0) + (Vector3(0.10, 0, 0) if horizontal else Vector3(0, 0, 0.10)),
		Vector3(0.02, 1.9, 0.10) if horizontal else Vector3(0.10, 1.9, 0.02),
		Color("d0a24a"))
	for side in [-1.0, 1.0]:
		var hinge := gate + (Vector3(0, 0, side * 1.05) if horizontal else Vector3(side * 1.05, 0, 0))
		room._box(hinge, Vector3(0.20, 2.15, 0.18) if horizontal else Vector3(0.18, 2.15, 0.20),
			Color("3d5a60"))
	var label: Label3D = room._world_label(_sign(annex), Vector3(gate.x, 2.45, gate.z), 18)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	room.annex_labels[kind] = label


static func _sign(annex: Dictionary) -> String:
	var requires: Array = annex.get("requires", [])
	if requires.is_empty():
		return String(annex["label"]) + "\nОТКРЫТО ДЛЯ ВСЕХ"
	return String(annex["label"]) + "\nНУЖЕН: " + requires[0].to_upper()


static func _light(room: Node3D, annex: Dictionary, kind: String) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(annex["center"].x, 2.5, annex["center"].z)
	lamp.light_color = Color("bdf2ee") if kind == "operating" else Color("ffe3b6")
	lamp.light_energy = 0.9
	lamp.omni_range = 7.0
	room.add_child(lamp)


static func _operating(room: Node3D, annex: Dictionary) -> void:
	var center: Vector3 = annex["center"]
	var axes := _axes(annex)
	var back: Vector3 = axes[0]
	var along: Vector3 = axes[1]
	# The far wall is the one opposite the door; that is where the theatre kit goes.
	var wall: Vector3 = center + back * 2.30
	var table := Art.spawn(room, "blender_operating_table", center - back * 0.25,
		Vector3(2.05, 1.62, 0.80), false, INK)
	table.rotation.y = atan2(-along.z, along.x)
	var cabinet := Art.spawn(room, "blender_medkit", wall + along * 1.35 + Vector3(0, 1.45, 0),
		Vector3(1.1, 0.85, 0.42), false, INK)
	cabinet.rotation.y = _face(wall + along * 1.35, center)
	# Stainless sink counter on the other side of the far wall.
	var sink: Vector3 = wall - along * 1.35
	room._box(sink + Vector3(0, 0.5, 0), _slab(along, 0.9, 0.62, 0.12), Color("b8c6c4"))
	room._box(sink + Vector3(0, 0.06, 0), _slab(along, 0.10, 0.10, 1.0), Color("7f8f92"))
	room._box(sink + Vector3(0, 0.60, 0), _slab(along, 0.44, 0.30, 0.06), Color("99adaa"))
	Finish.glow(room, sink + Vector3(0, 1.55, 0), _slab(along, 0.8, 0.05, 0.06), Color("cdf7f2"))
	room._world_label("СТОЛ ГОТОВ • ХИРУРГИЯ", center + Vector3(0, 1.9, 0), 16)


static func _pantry(room: Node3D, annex: Dictionary) -> void:
	var center: Vector3 = annex["center"]
	var axes := _axes(annex)
	var back: Vector3 = axes[0]
	var along: Vector3 = axes[1]
	var wall: Vector3 = center + back * 2.30
	for offset in [-1.25, 1.25]:
		var spot: Vector3 = wall + along * offset
		var shelf := Art.spawn(room, "blender_pantry_shelf", spot,
			Vector3(1.34, 1.95, 0.55), false, INK)
		shelf.rotation.y = _face(spot, center)
	var stack_at: Vector3 = center - along * 1.3 + back * 0.4
	var stack := Art.spawn(room, "blender_crate", stack_at, Vector3(0.62, 0.42, 0.55), false, INK)
	stack.rotation.y = _face(stack_at, center) + 0.4
	var upper := Art.spawn(room, "blender_crate", stack_at + Vector3(0, 0.42, 0),
		Vector3(0.5, 0.34, 0.45), false, INK)
	upper.rotation.y = _face(stack_at, center) - 0.25
	Finish.glow(room, center + Vector3(0, 2.3, 0), Vector3(1.6, 0.05, 0.10), Color("ffe4b0"))
	room._world_label("ЗАПАСЫ ПРОДУКТОВ", center + Vector3(0, 1.9, 0), 16)


static func _bathroom(room: Node3D, annex: Dictionary) -> void:
	var center: Vector3 = annex["center"]
	var axes := _axes(annex)
	var back: Vector3 = axes[0]
	var along: Vector3 = axes[1]
	var wall: Vector3 = center + back * 2.38
	var toilet := Art.spawn(room, "blender_toilet", wall - along * 1.30,
		Vector3(0.58, 0.98, 0.62), false, INK)
	toilet.rotation.y = _face(toilet.position, center)
	# Washbasin, mirror light and a towel rail on the same wall.
	var basin: Vector3 = wall + along * 1.25
	room._box(basin + Vector3(0, 0.80, 0), _slab(along, 0.62, 0.44, 0.14), Color("d8ded9"))
	room._box(basin + Vector3(0, 0.48, 0), _slab(along, 0.12, 0.12, 0.62), Color("8a979a"))
	room._box(basin + Vector3(0, 0.87, 0), _slab(along, 0.42, 0.28, 0.06), Color("9fb3b0"))
	Finish.glow(room, basin + Vector3(0, 1.55, 0), _slab(along, 0.74, 0.04, 0.9), Color("a9f0ff"))
	room._box(basin - back * 0.55 + Vector3(0, 1.10, 0), _slab(along, 0.5, 0.10, 0.06),
		Color("c9d4d0"))
	# A stall divider keeps the joke behind a screen, not in the middle of the room.
	room._box(center + along * 0.95 + Vector3(0, 1.15, 0), _slab(along, 0.08, 1.8, 2.1),
		Color("5b7a78"))
	room._world_label("САНУЗЕЛ • ВОДА ЕСТЬ", center + Vector3(0, 1.9, 0), 16)
