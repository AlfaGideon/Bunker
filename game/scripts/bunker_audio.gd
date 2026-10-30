extends Node

var radio: AudioStreamPlayer3D
var static_noise: AudioStreamPlayer3D
var transmission: AudioStreamPlayer3D
var air: AudioStreamPlayer
var effect: AudioStreamPlayer
var room: Node3D
var radio_on := false
var narration_status := ""


func setup(game: Node3D, radio_position: Vector3) -> void:
	room = game
	# Three receivers share the cabinet: the music station, the static bed used
	# by the bunker feed and the beacon, and the voice of a transmission.
	radio = _cabinet_player(radio_position, "radio_music.wav", -3.0)
	static_noise = _cabinet_player(radio_position, "radio_static.wav", -9.0)
	transmission = AudioStreamPlayer3D.new()
	transmission.stream = load("res://assets/audio/radio_voice.wav")
	transmission.position = radio_position
	transmission.unit_size = 4
	transmission.max_distance = 24
	transmission.volume_db = -4
	room.add_child(transmission)
	air = AudioStreamPlayer.new()
	air.stream = _loop("air_loop.wav")
	air.volume_db = -10
	add_child(air)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -1
	add_child(effect)
	apply_settings()


func _cabinet_player(at: Vector3, filename: String, gain: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = _loop(filename)
	player.position = at
	player.unit_size = 4
	player.max_distance = 24
	player.volume_db = gain
	room.add_child(player)
	return player


func _loop(filename: String) -> AudioStreamWAV:
	var stream := load("res://assets/audio/" + filename).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, room.profile.volume)))
	AudioServer.set_bus_mute(0, room.profile.volume <= 0)
	radio.volume_db = -3
	static_noise.volume_db = -12 if radio_on else -9
	if room.profile.volume <= 0 or not room.profile.narration:
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_stop()


func begin() -> void:
	if not air.playing:
		air.play()


## Syncs the cabinet with the receiver state that the player tuned.
func play_station(kind: String) -> void:
	radio.stop()
	static_noise.stop()
	radio_on = not kind.is_empty()
	if not radio_on:
		return
	match kind:
		"music":
			radio.play()
		"broadcast":
			static_noise.volume_db = -12
			static_noise.play()
		"signal":
			static_noise.volume_db = -9
			static_noise.play()


func play_transmission() -> void:
	if transmission.stream == null:
		return
	transmission.play()


func blip(kind: String = "click") -> void:
	effect.stream = load("res://assets/audio/" + kind + ".wav")
	effect.play()


func narrate() -> bool:
	if not room.profile.narration or room.profile.volume <= 0:
		narration_status = "Озвучка выключена в настройках."
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		narration_status = "Системный синтез речи недоступен. Сводка показана текстом."
		return false
	var voices := DisplayServer.tts_get_voices_for_language("ru")
	if voices.is_empty():
		narration_status = "Русский голос недоступен. Установите его в настройках синтеза речи Android; сводка доступна текстом."
		return false
	DisplayServer.tts_speak(room.scenario["brief"], voices[0], roundi(room.profile.volume * 100), 1.0, 1.0, 1, true)
	narration_status = "Зачитывается аварийная сводка."
	return true


func _exit_tree() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
