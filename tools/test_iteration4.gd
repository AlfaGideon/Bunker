extends SceneTree

const Content = preload("res://game/scripts/game_content.gd")
const Survival = preload("res://game/scripts/survival_rules.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Expand to wide screen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 749
	var choices := {}
	for trial in 120:
		var player: Dictionary = Content.create_players(6, "Тест")[0]
		var card := Content.random_hidden_card(player, rng)
		choices[card["id"]] = true
		check(card["id"] != "profession", "No repeat of already public profession")
	check(choices.size() == 6, "Additional cards selected across every category, not in order")
	for face in range(1, 7):
		check(Survival.resolve(face)["survived"] == (face >= 4), "D6 threshold explicit")
	var scene := load("res://game/main.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.menu.visible = false
	check(room.menu_button.size.x <= 70, "Compact menu button")
	check(room.weather.kind == room.scenario["weather"], "Weather matches selected catastrophe")
	# Force opposite appearance and a rotated/translated actor: replacement must
	# preserve world placement and visual scale, without revealing sex beforehand.
	room._change_appearance(0, "female")
	room.players[0]["sex"] = "male"
	room.actors[0].position = Vector3(2.4, 0, 2.6)
	room.actors[0].rotation.y = 1.3
	var before := Vector3(room.actors[0].position)
	room._reveal_card(0, room.players[0]["cards"][1])
	check(room.actors[0].get_meta("appearance") == "male", "Biology swaps appearance")
	check(room.actors[0].position == before, "Swap preserves actor position")
	check(room.actors[0].get_child(0).skeletons.size() > 0, "New visual has working rig")
	room.profile.appearance = "female"
	room.apply_settings()
	check(room.actors[0].get_meta("appearance") == "male", "Revealed biology overrides cosmetic preference")
	room.test_own_expulsion()
	check(not room.active.has(0), "Can test own expulsion without self-voting")
	for tick in 900:
		room._physics_process(1.0 / 30.0)
	check(room.survival_panel.visible, "Own departure shows survival panel")
	check(not room.actors[0].visible, "Own actor exits room")
	room.survival_panel.roll_dice()
	var first := int(room.survival_panel.outcome["face"])
	room.survival_panel.roll_dice()
	check(room.survival_panel.outcome["face"] == first, "Cannot reroll")
	room.survival_panel.show_result()
	check(not room.survival_panel.continue_button.disabled, "Can continue as observer")
	room.survival_panel.visible = false
	room._advance()
	check(room.phase == "reveal", "Observer reaches next round")
	room._advance()
	check(room.phase == "discussion", "Observer does not block reveal phase")
	print("Iteration 4 failures: ", failures)
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
