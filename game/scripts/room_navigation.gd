class_name RoomNavigation
extends RefCounted

const Layout = preload("res://game/scripts/bunker_layout.gd")
const STEP := 0.2
const ORIGIN := Vector2(-20, -16)
const SIZE := Vector2i(201, 161)
var grid := AStarGrid2D.new()
var layout: Dictionary
var medical_open := false
var warehouse_open := false


func _init(plan: Dictionary = {}) -> void:
	layout = Layout.generate(0) if plan.is_empty() else plan
	rebuild()


func rebuild() -> void:
	grid.region = Rect2i(Vector2i.ZERO, SIZE)
	grid.cell_size = Vector2.ONE * STEP
	grid.offset = ORIGIN
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.fill_solid_region(grid.region, true)
	for footprint in layout["floors"]:
		var rect: Rect2 = footprint
		var first := Vector2i(((rect.position - ORIGIN) / STEP).ceil())
		var last := Vector2i(((rect.end - ORIGIN) / STEP).floor())
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				_mark_cell(Vector2i(x, y))


func _mark_cell(cell: Vector2i) -> void:
	if not grid.is_in_boundsv(cell):
		return
	var point := grid.get_point_position(cell)
	var solid := not on_floor(point)
	if not solid:
		for offset in [Vector2(0.18, 0), Vector2(-0.18, 0), Vector2(0, 0.18), Vector2(0, -0.18)]:
			if not on_floor(point + offset):
				solid = true
	for obstacle in layout["blockers"]:
		if obstacle.has_point(point):
			solid = true
	if not medical_open and (layout["gate_blocker"].has_point(point) or layout["med_bounds"].has_point(point)):
		solid = true
	if not warehouse_open and (layout["warehouse_bounds"].has_point(point) or layout["warehouse_gate"].has_point(point)):
		solid = true
	grid.set_point_solid(cell, solid)


func unlock_medical() -> void:
	medical_open = true
	rebuild()


func lock_medical() -> void:
	medical_open = false
	rebuild()


func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(((Vector2(point.x, point.z) - ORIGIN) / STEP).round())


func is_walkable(point: Vector3) -> bool:
	var cell := cell_at(point)
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


func nearest_walkable(point: Vector3) -> Vector3:
	if is_walkable(point):
		var at := grid.get_point_position(cell_at(point))
		return Vector3(at.x, 0, at.y)
	var nearest := Vector3.ZERO
	var distance := INF
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell):
				continue
			var at := grid.get_point_position(cell)
			var candidate := Vector3(at.x, 0, at.y)
			if candidate.distance_squared_to(point) < distance:
				distance = candidate.distance_squared_to(point)
				nearest = candidate
	return nearest


func path_between(start: Vector3, destination: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not is_walkable(start) or not is_walkable(destination):
		return result
	for point in grid.get_point_path(cell_at(start), cell_at(destination)):
		result.append(Vector3(point.x, 0, point.y))
	return result


func unlock_warehouse() -> void:
	warehouse_open = true
	rebuild()


func on_floor(point: Vector2) -> bool:
	for footprint in layout["floors"]:
		if footprint.has_point(point):
			return true
	return false
