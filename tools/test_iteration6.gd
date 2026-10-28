extends SceneTree

const Content = preload("res://game/scripts/game_content.gd")
const Supplies = preload("res://game/scripts/group_supplies.gd")
var failures := 0


func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var burdens := 0
	for health in content["health"]:
		if not health["cost"].is_empty():
			burdens += 1
		for amount in health["cost"].values():
			check(amount > 0, "Explicit non-negative health resource demands")
	check(burdens >= 9, "Meaningful adverse health conditions")
	var players := Content.create_players(6, "Тест")
	for player in players:
		for card in player["cards"]:
			if card["id"] == "health":
				card["cost"] = {"medicine": 2, "water": 1}
	var stocks := Supplies.new()
	stocks.charge_round(2, players, [0, 1, 2], "heat")
	check(stocks.stock["water"] == 88 and stocks.stock["medicine"] == 26, "Active survivors and catastrophe consume shared supplies")
	stocks.charge_round(2, players, [0, 1, 2], "heat")
	check(stocks.stock["medicine"] == 26, "No double charge in same round")
	stocks.stock["medicine"] = 1
	stocks.charge_round(3, players, [0, 1], "toxic")
	check(stocks.shortage and stocks.stock["medicine"] == 0, "Shortages detected without negative inventory")
	var weather_ids := {}
	for scenario in Content.scenarios():
		weather_ids[scenario["weather"]] = true
	check(weather_ids.size() >= 12, "Distinct exterior modes")
	var room := (load("res://game/main.tscn") as PackedScene).instantiate()
	room.profile.scenario_choice = "meteor_storm"
	root.add_child(room)
	room.set_physics_process(false)
	room.menu.visible = false
	check(room.weather.meteor_field.meteors.size() == 6, "Six mesh-based burning meteorites")
	check(room.actors[0].get_child(0).get_meta("source").contains("kaykit"), "Different licensed character library integrated")
	check(is_instance_valid(room.actors[0].get_child(0).animation_player), "Authored locomotion clips available")
	room.weather.set_reduced_motion(true)
	room.weather.meteor_field._process(0)
	for meteor in room.weather.meteor_field.meteors:
		check(not meteor.visible, "Reduced motion hides moving meteorites")
	room.supplies.shortage = true
	room._complete_interaction("bed")
	room._tick_rest(4)
	check(room.stamina == 70, "Shared shortage reduces rest recovery for everyone")
	room.free()
	await process_frame
	print("Iteration 6 failures: ", failures)
	quit(1 if failures else 0)
