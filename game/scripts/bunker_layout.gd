class_name BunkerLayout
extends RefCounted

static func generate(seed_value: int, capacity: int = 4) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var variant := posmod(seed_value, 3)
	var side := 1.0 if variant != 1 else -1.0
	var table := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.2, 0.4))
	var terminal := Vector3(2.9 if variant == 0 else -2.9, 0, -3.6)
	var kitchen := Vector3(-terminal.x, 0, -3.6)
	var supply := Vector3(side * 6.6, 0, 3.4)
	var bed_z := -2.6 if rng.randf() < 0.5 else 2.6
	var items := {
		"bed": {"title": "Койка — отдохнуть", "at": Vector3(-side * 6.6, 0.65, bed_z), "goal": Vector3(-side * 5.0, 0, bed_z)},
		"bed2": {"title": "Вторая койка — отдохнуть", "at": Vector3(-side * 6.6, 0.65, -bed_z), "goal": Vector3(-side * 5.0, 0, -bed_z)},
		"medical": {"title": "Медблок — обследование", "at": Vector3(side * 6.6, 0.7, -2.6), "goal": Vector3(side * 5.0, 0, -2.6)},
		"gate": {"title": "Дверь медблока — условия", "at": Vector3(side * 4.4, 1.0, -1.6), "goal": Vector3(side * 3.6, 0, -1.6)},
		"terminal": {"title": "Терминал — восстановить систему", "at": terminal + Vector3(0, 1, 0), "goal": terminal + Vector3(0, 0, 1.2)},
		"supply": {"title": "Склад — взять ремкомплект", "at": supply + Vector3(0, 0.5, 0), "goal": Vector3(side * 5.0, 0, 3.4)},
		"radio": {"title": "Радио — включить / выключить", "at": table + Vector3(-0.7, 1.05, 0), "goal": table + Vector3(-0.7, 0, 1.6)}
	}
	var blockers: Array[Rect2] = [Rect2(Vector2(table.x - 1.95, table.z - 1.25), Vector2(3.9, 2.5))]
	for location in [terminal, supply, kitchen]:
		blockers.append(Rect2(Vector2(location.x - 0.8, location.z - 0.7), Vector2(1.6, 1.4)))
	var bed_keys: Array[String] = []
	items.erase("bed")
	items.erase("bed2")
	for i in clampi(capacity, 3, 5):
		var key := "bed" if i == 0 else "bed%d" % (i + 1)
		bed_keys.append(key)
		var z := -3.8 + float(i) * 7.6 / float(capacity - 1)
		var at := Vector3(-side * 6.6, 0.65, z)
		items[key] = {"title": "Койка %d — отдых" % (i + 1), "at": at, "goal": Vector3(-side * 5, 0, z)}
	for key in bed_keys + ["medical"]:
		var at: Vector3 = items[key]["at"]
		blockers.append(Rect2(Vector2(at.x - 1.25, at.z - 0.65), Vector2(2.5, 1.3)))
	items["kitchen"] = {"title": "Кухня — приготовить еду", "at": kitchen + Vector3(0, 0.9, 0), "goal": kitchen + Vector3(0, 0, 1.2)}
	items["food"] = {"title": "Общий стол — поесть", "at": table + Vector3(0.7, 1, 0), "goal": table + Vector3(0.7, 0, 1.6)}
	items["warehouse_gate"] = {"title": "Шлюз склада — решение совета", "at": Vector3(side * 4.4, 1, 3.4), "goal": Vector3(side * 3.6, 0, 3.4)}
	var annex: String = ["none", "gym", "workshop", "greenhouse"][rng.randi_range(0, 3)]
	if annex != "none":
		var at := Vector3(-side * 2.7, 0, 3.7)
		items[annex] = {"title": {"gym": "Спортзал — тренировка", "workshop": "Мастерская — обслуживание", "greenhouse": "Теплица — сбор урожая"}[annex], "at": at + Vector3(0, 0.8, 0), "goal": at - Vector3(0, 0, 1.2)}
		blockers.append(Rect2(Vector2(at.x - 0.7, at.z - 0.65), Vector2(1.4, 1.3)))
	var walls: Array[Rect2] = []
	# Dorm divider has a central opening. Med divider has a single locked gate.
	var dorm_x := -side * 4.4
	walls.append(Rect2(Vector2(dorm_x - 0.2, -5.0), Vector2(0.4, 4.1)))
	walls.append(Rect2(Vector2(dorm_x - 0.2, 0.9), Vector2(0.4, 4.1)))
	var med_x := side * 4.4
	walls.append(Rect2(Vector2(med_x - 0.2, -5), Vector2(0.4, 2.5)))
	walls.append(Rect2(Vector2(med_x - 0.2, -0.7), Vector2(0.4, 2.5)))
	walls.append(Rect2(Vector2(4.2 if side > 0 else -8.5, 1.6), Vector2(4.3, 0.4)))
	walls.append(Rect2(Vector2(med_x - 0.2, 2), Vector2(0.4, 0.5)))
	walls.append(Rect2(Vector2(med_x - 0.2, 4.3), Vector2(0.4, 0.7)))
	blockers.append_array(walls)
	return {"beds": bed_keys, "capacity": capacity, "annex": annex, "walls": walls,
		"warehouse_bounds": Rect2(Vector2(4.6 if side > 0 else -8.4, 2), Vector2(3.8, 2.8)),
		"warehouse_gate": Rect2(Vector2(med_x - 0.2, 2.5), Vector2(0.4, 1.8)), "seed": seed_value, "variant": variant, "med_side": side, "table": table,
		"items": items, "blockers": blockers,
		"gate_blocker": Rect2(Vector2(med_x - 0.2, -2.5), Vector2(0.4, 1.8)),
		"med_bounds": Rect2(Vector2(4.6 if side > 0 else -8.4, -4.8), Vector2(3.8, 6.3)),
		"floor_color": [Color("35464b"), Color("454a40"), Color("3f4351")][variant]}
