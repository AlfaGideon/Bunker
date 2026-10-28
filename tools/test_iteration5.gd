extends SceneTree

const Layout = preload("res://game/scripts/bunker_layout.gd")
const Navigation = preload("res://game/scripts/room_navigation.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run")


func walk(room: Node3D, key: String) -> void:
	check(room.request_interaction(key), "Interaction queues: " + key)
	for tick in 2000:
		room._physics_process(1.0 / 60)
		if room.pending_inspection.is_empty():
			return
	check(false, "Interaction completed: " + key)


func run() -> void:
	var original := Profile.new()
	var variants := {}
	for seed_value in range(-12, 48):
		var plan := Layout.generate(seed_value)
		var repeated := Layout.generate(seed_value)
		check(plan == repeated, "Seed reproducible: %d" % seed_value)
		variants[plan["variant"]] = true
		var nav := Navigation.new(plan)
		var start := nav.nearest_walkable(Vector3(-2.5, 0, 1.8))
		check(not nav.is_walkable(plan["items"]["medical"]["goal"]), "Medical inaccessible while locked")
		for key in plan["items"]:
			if key == "medical":
				continue
			var route := nav.path_between(start, plan["items"][key]["goal"])
			check(not route.is_empty(), "Seed %d: reachable %s" % [seed_value, key])
			for point in route:
				check(nav.is_walkable(point), "Path follows shared geometry")
		nav.unlock_medical()
		check(not nav.path_between(start, plan["items"]["medical"]["goal"]).is_empty(), "Medical reachable after unlocking")
	check(variants.size() == 3, "Three layout variants")
	var scenarios := Content.scenarios()
	check(scenarios.size() == 4, "Four catastrophe stories")
	var scene := load("res://game/main.tscn") as PackedScene
	for index in scenarios.size():
		var room := scene.instantiate()
		room.profile.scenario_choice = scenarios[index]["id"]
		set_meta("world_seed", index + 10)
		root.add_child(room)
		room.set_physics_process(false)
		room.menu.visible = false
		check(room.scenario["weather"] == room.weather.kind, "Selected catastrophe drives exterior")
		check(room.med_cover.visible and room.med_light.light_energy == 0, "Locked medblock dark")
		check(not room.request_interaction("medical"), "Locked interaction refused")
		check(not room.medical_open, "No premature opening")
		walk(room, "terminal")
		check(not room.systems_ready, "Repair requires warehouse kit")
		walk(room, "supply")
		check(room.inventory["repair"] == 1, "Warehouse provides a kit")
		walk(room, "supply")
		check(room.inventory["repair"] == 1, "No infinite kit farming")
		walk(room, "terminal")
		check(room.systems_ready and not room.medical_open, "Repair alone insufficient during round one")
		check(room.inventory["repair"] == 0, "Repair consumes kit")
		walk(room, "bed")
		check(room.rest_remaining > 0, "Actor lies down on accessible bed")
		check(is_equal_approx(room.actors[0].get_child(0).rotation.z, PI / 2), "Lying pose")
		check(not room.request_interaction("radio"), "No actions during sleep")
		room._change_appearance(0, "female" if room.actors[0].get_meta("appearance") == "male" else "male")
		check(is_equal_approx(room.actors[0].get_child(0).rotation.z, PI / 2), "Appearance changes preserve sleeping pose")
		for tick in 200:
			room._physics_process(1.0 / 60)
		check(room.stamina == 80 and room.rest_remaining == 0, "Sleep restores stamina")
		check(room.navigation.is_walkable(room.actors[0].position), "Sleep restores walkable standing position")
		check(room.actors[0].get_child(0).rotation == Vector3.ZERO, "Sleep restores model pose")
		walk(room, "bed2")
		check(room.rest_remaining == 0 and room.stamina == 80, "Rest cooldown shared by beds")
		room.phase = "result"
		room._advance()
		check(room.round_number == 2 and room.medical_open, "Actual next-round transition opens repaired medblock")
		check(not room.med_cover.visible and room.med_light.light_energy > 0, "Unlock removes roof and enables light")
		walk(room, "medical")
		check(room.medicines == 1 and room.stamina == 95, "Limited medical treatment")
		walk(room, "medical")
		check(room.medicines == 1, "Treatment cooldown")
		walk(room, "radio")
		check(room.audio.radio_on and room.audio.radio.playing, "Radio plays local loop")
		check(room.audio.radio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Radio loops")
		walk(room, "radio")
		check(not room.audio.radio_on, "Radio toggles off")
		room.profile.narration = true
		if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			check(not room.audio.narrate() and not room.audio.narration_status.is_empty(), "Explicit unavailable native speech fallback")
		room.profile.narration = false
		check(not room.audio.narrate() and not room.audio.narration_status.is_empty(), "Explicit disabled/unavailable speech fallback")
		room.weather.set_reduced_motion(true)
		for emitter in room.weather.emitters:
			check(not emitter.emitting, "Reduced motion stops exterior particles")
		room.active.erase(0)
		check(not room.request_interaction("supply"), "Observer cannot interact")
		room.free()
		await process_frame
	original.save()
	print("Iteration 5 failures: ", failures)
	quit(1 if failures else 0)
