class_name BunkerProfile
extends RefCounted

const PATH := "user://profile.cfg"
const Library = preload("res://game/scripts/parameter_library.gd")
var custom_parameters: Dictionary = {}
var nickname := "Алекс"
var appearance := "male"
var outfit := 0
var player_count := 8
var camera_size := 11.0
var shadows := true
var reduced_motion := false
var completed_games := 0
var volume := 0.7
var narration := true
var scenario_choice := "random"
var world_count := 0
var last_layout := -1


func _init() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	custom_parameters = Library.sanitize(config.get_value("library", "custom", {}))
	nickname = str(config.get_value("profile", "nickname", "Алекс")).strip_edges().left(20)
	if nickname.is_empty():
		nickname = "Алекс"
	appearance = str(config.get_value("profile", "appearance", "male"))
	if not preload("res://game/scripts/avatar_catalog.gd").IDS.has(appearance):
		appearance = "male"
	outfit = clampi(int(config.get_value("profile", "outfit", 0)), 0, 2)
	player_count = clampi(int(config.get_value("game", "players", 8)), 6, 10)
	if not [6, 8, 10].has(player_count):
		player_count = 8
	camera_size = clampf(float(config.get_value("settings", "camera", 11.0)), 9.0, 14.0)
	shadows = bool(config.get_value("settings", "shadows", true))
	reduced_motion = bool(config.get_value("settings", "reduced_motion", false))
	volume = clampf(float(config.get_value("settings", "volume", 0.7)), 0, 1)
	narration = bool(config.get_value("settings", "narration", true))
	scenario_choice = str(config.get_value("game", "scenario", "random"))
	world_count = maxi(0, int(config.get_value("game", "world_count", 0)))
	last_layout = int(config.get_value("game", "last_layout", -1))
	completed_games = maxi(0, int(config.get_value("profile", "completed", 0)))


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("library", "custom", Library.sanitize(custom_parameters))
	config.set_value("profile", "nickname", nickname)
	config.set_value("profile", "appearance", appearance)
	config.set_value("profile", "outfit", outfit)
	config.set_value("profile", "completed", completed_games)
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "narration", narration)
	config.set_value("game", "scenario", scenario_choice)
	config.set_value("game", "world_count", world_count)
	config.set_value("game", "last_layout", last_layout)
	config.set_value("game", "players", player_count)
	config.set_value("settings", "camera", camera_size)
	config.set_value("settings", "shadows", shadows)
	config.set_value("settings", "reduced_motion", reduced_motion)
	return config.save(PATH)
