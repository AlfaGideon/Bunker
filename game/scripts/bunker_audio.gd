extends Node

const Music = preload("res://game/scripts/music_library.gd")

## The cabinet is heard across the whole bunker, so its players are plain
## (non-positional) ones: a positional emitter was too quiet from the camera.
var radio: AudioStreamPlayer
var static_noise: AudioStreamPlayer
var transmission: AudioStreamPlayer
var music_index := 0
var air: AudioStreamPlayer
var effect: AudioStreamPlayer
var room: Node3D
var radio_on := false
var narration_status := ""


func setup(game: Node3D, radio_position: Vector3) -> void:
	room = game
	# Three receivers share the cabinet: the music station, the static bed used
	# by the bunker feed and the beacon, and the voice of a transmission.
	radio = _cabinet_player(Music.path(music_index), -6.0)
	static_noise = _cabinet_player("radio_static.wav", -14.0)
	transmission = AudioStreamPlayer.new()
	transmission.stream = load("res://assets/audio/radio_voice.wav")
	transmission.volume_db = -7
	room.add_child(transmission)
	air = AudioStreamPlayer.new()
	air.stream = _loop("air_loop.wav")
	air.volume_db = -10
	add_child(air)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -1
	add_child(effect)
	apply_settings()


func _cabinet_player(filename: String, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = _loop(filename)
	player.volume_db = gain
	room.add_child(player)
	return player


func _loop(filename: String) -> AudioStreamWAV:
	var path := filename if filename.begins_with("res://") else "res://assets/audio/" + filename
	var stream := load(path).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, room.profile.volume)))
	AudioServer.set_bus_mute(0, room.profile.volume <= 0)
	radio.volume_db = -6
	static_noise.volume_db = -14
	if room.profile.volume <= 0 or not room.profile.narration:
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_stop()


func begin() -> void:
	if not air.playing:
		air.play()


## Syncs the cabinet with the receiver state that the player tuned.
func play_station(kind: String, track: int = 0) -> void:
	radio.stop()
	static_noise.stop()
	radio_on = not kind.is_empty()
	if not radio_on:
		return
	match kind:
		"music":
			play_music(track)
		"broadcast":
			static_noise.play()
		"signal":
			static_noise.volume_db = -11
			static_noise.play()


## Switches the record on the music station. Every track is a full loop.
func play_music(track: int) -> void:
	music_index = posmod(track, Music.count())
	radio.stream = _loop(Music.path(music_index))
	radio.play()


func play_transmission() -> void:
	if transmission.stream == null:
		return
	transmission.play()


func stop_all() -> void:
	radio.stop()
	static_noise.stop()
	transmission.stop()
	radio_on = false


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
