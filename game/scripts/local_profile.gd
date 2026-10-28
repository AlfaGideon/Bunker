class_name BunkerProfile
extends RefCounted

const PATH := "user://profile.cfg"
var nickname := "Алекс"
var player_count := 8
var camera_size := 11.0
var shadows := true
var reduced_motion := false
var completed_games := 0


func _init() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	nickname = str(config.get_value("profile", "nickname", "Алекс")).strip_edges().left(20)
	if nickname.is_empty():
		nickname = "Алекс"
	player_count = clampi(int(config.get_value("game", "players", 8)), 6, 10)
	if not [6, 8, 10].has(player_count):
		player_count = 8
	camera_size = clampf(float(config.get_value("settings", "camera", 11.0)), 9.0, 14.0)
	shadows = bool(config.get_value("settings", "shadows", true))
	reduced_motion = bool(config.get_value("settings", "reduced_motion", false))
	completed_games = maxi(0, int(config.get_value("profile", "completed", 0)))


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("profile", "nickname", nickname)
	config.set_value("profile", "completed", completed_games)
	config.set_value("game", "players", player_count)
	config.set_value("settings", "camera", camera_size)
	config.set_value("settings", "shadows", shadows)
	config.set_value("settings", "reduced_motion", reduced_motion)
	return config.save(PATH)
