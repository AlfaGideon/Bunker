extends SceneTree

const Profile = preload("res://game/scripts/local_profile.gd")
var failures := 0


func check(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		push_error(title)


func _initialize() -> void:
	var original := Profile.new()
	var profile := Profile.new()
	profile.nickname = "Тест профиля"
	profile.appearance = "female"
	profile.player_count = 10
	profile.volume = 0.35
	profile.narration = false
	profile.scenario_choice = "great_flood"
	profile.camera_size = 9.5
	profile.reduced_motion = true
	profile.shadows = false
	profile.completed_games = 12
	check(profile.save() == OK, "Profile saves")
	var restored := Profile.new()
	check(restored.nickname == profile.nickname, "Nickname persists")
	check(restored.appearance == "female", "Preferred appearance persists")
	check(is_equal_approx(restored.volume, 0.35) and not restored.narration, "Audio settings persist")
	check(restored.scenario_choice == "great_flood", "Scenario selection persists")
	check(restored.player_count == 10, "Room size persists")
	check(restored.camera_size == 9.5, "Zoom persists")
	check(restored.reduced_motion and not restored.shadows, "Settings persist")
	check(restored.completed_games == 12, "Local statistics persist")
	check(original.save() == OK, "Restore prior test profile")
	print("Profile failures: ", failures)
	quit(1 if failures else 0)
