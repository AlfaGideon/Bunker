class_name RoomNavigation
extends RefCounted

const STEP := 0.2
const ORIGIN := Vector2(-4.6, -3.4)
const SIZE := Vector2i(47, 35)
# Furniture footprints enlarged by the character radius.
const BLOCKERS := [Rect2(-1.95, -1.25, 3.9, 2.5),
	Rect2(-4.7, -3.3, 2.0, 1.55), Rect2(2.6, -3.3, 1.8, 1.55)]
var grid := AStarGrid2D.new()


func _init() -> void:
	grid.region = Rect2i(Vector2i.ZERO, SIZE)
	grid.cell_size = Vector2.ONE * STEP
	grid.offset = ORIGIN
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			var point := grid.get_point_position(cell)
			for obstacle in BLOCKERS:
				if obstacle.has_point(point):
					grid.set_point_solid(cell)


func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(((Vector2(point.x, point.z) - ORIGIN) / STEP).round())


func is_walkable(point: Vector3) -> bool:
	var cell := cell_at(point)
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


func path_between(start: Vector3, destination: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not is_walkable(start) or not is_walkable(destination):
		return result
	for point in grid.get_point_path(cell_at(start), cell_at(destination)):
		result.append(Vector3(point.x, 0, point.y))
	return result
