extends SceneTree

const Content = preload("res://game/scripts/game_content.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	for count in [6, 8, 10]:
		var players := Content.create_players(count, "Тест")
		var professions: Array = []
		check(players.size() == count, "Selected player count")
		for player in players:
			check(player["cards"].size() == 7, "Seven characteristics")
			professions.append(player["cards"][0]["value"])
		var unique := {}
		for profession in professions:
			unique[profession] = true
		check(professions.size() == unique.size(), "Unique professions in party")
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	check(room.menu.visible, "Start at main menu")
	var start := Vector3(room.actors[0].position)
	room._set_route(Vector3(0, 0, -2.6))
	room._physics_process(1.0)
	check(room.actors[0].position == start, "Menu pauses movement")
	room.menu.visible = false
	var expected_rounds: int = room.players.size() - room.capacity
	for index in expected_rounds:
		for card in room.players[0]["cards"]:
			if not card["revealed"]:
				card["revealed"] = true
				break
		room._demo_reveals()
		room.phase = "discussion"
		room._advance()
		check(room.phase == "vote", "Discussion to vote")
		room.selected = room.active[1]
		var expelled: int = room.selected
		room._demo_vote()
		check(not room.active.has(expelled), "Vote excludes a player")
		check(room.departures.has(expelled), "Expelled player gets departure path")
		for tick in 600:
			room._physics_process(1.0 / 30.0)
		check(not room.actors[expelled].visible, "Expelled player walks out and disappears")
		if index < expected_rounds - 1:
			check(room.phase == "result", "Result phase before next round")
			room._advance()
			check(room.phase == "reveal", "Next round")
	check(room.phase == "end" and room.active.size() == room.capacity, "Party finishes at capacity")
	check(room.round_number == expected_rounds, "Configured number of rounds")
	print("Game flow failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
