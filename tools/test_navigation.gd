extends SceneTree

const Navigation = preload("res://game/scripts/room_navigation.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	var nav := Navigation.new()
	check(not nav.is_walkable(Vector3.ZERO), "Table blocked")
	check(not nav.is_walkable(Vector3(8, 0, 0)), "Outside room blocked")
	check(not nav.is_walkable(Vector3(3.5, 0, -2.6)), "Terminal blocked")
	var start := Vector3(-2.5, 0, 1.8)
	for target in [Vector3(0, 0, -2.6), Vector3(3.8, 0, 1.8), Vector3(-3.8, 0, 0), Vector3(2.2, 0, -2.2)]:
		var route := nav.path_between(start, target)
		check(not route.is_empty(), "Can reach all sides of table")
		for point in route:
			check(nav.is_walkable(point), "Path avoids furniture")
		for i in range(1, route.size()):
			check(route[i].distance_to(route[i - 1]) <= 0.284, "No path jumps")
	check(nav.path_between(start, Vector3.ZERO).is_empty(), "Cannot target table")
	print("Navigation failures: ", failures)
	quit(1 if failures else 0)
