extends Node

var radio: AudioStreamPlayer3D
var air: AudioStreamPlayer
var effect: AudioStreamPlayer
var room: Node3D
var radio_on := false
var narration_status := ""


func setup(game: Node3D, radio_position: Vector3) -> void:
	room = game
	radio = AudioStreamPlayer3D.new()
	radio.stream = _loop("radio_station.wav")
	radio.position = radio_position
	radio.unit_size = 4
	radio.max_distance = 24
	room.add_child(radio)
	air = AudioStreamPlayer.new()
	air.stream = _loop("air_loop.wav")
	air.volume_db = -28
	add_child(air)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -16
	add_child(effect)
	apply_settings()


func _loop(filename: String) -> AudioStreamWAV:
	var stream := load("res://assets/audio/" + filename).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, room.profile.volume)))
	AudioServer.set_bus_mute(0, room.profile.volume <= 0)
	radio.volume_db = -17
	if room.profile.volume <= 0 or not room.profile.narration:
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_stop()


func begin() -> void:
	if not air.playing:
		air.play()
	if not radio_on:
		toggle_radio()


func toggle_radio() -> void:
	radio_on = not radio_on
	if radio_on:
		radio.play()
	else:
		radio.stop()


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
