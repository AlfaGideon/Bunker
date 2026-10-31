extends Node

signal speech_unavailable(message: String)
const VOICE_WAIT := 15.0

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
var speech_queue: Array[Dictionary] = []
var voice_wait := VOICE_WAIT
var retry_after := 0.0
var active_speech_kind := ""


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
		speech_queue.clear()
		if has_tts():
			stop_tts()


func begin() -> void:
	if not air.playing:
		air.play()


## Syncs the cabinet with the receiver state that the player tuned.
func play_station(kind: String, track: int = 0) -> void:
	radio.stop()
	static_noise.stop()
	radio_on = not kind.is_empty()
	if kind != "broadcast" and kind != "signal":
		cancel_radio_speech()
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
	# The previous placeholder was unintelligible vocal noise, not the text.
	# The actual transmission is spoken by say_radio() instead.
	pass


func stop_all() -> void:
	radio.stop()
	static_noise.stop()
	transmission.stop()
	cancel_radio_speech()
	radio_on = false


func blip(kind: String = "click") -> void:
	effect.stream = load("res://assets/audio/" + kind + ".wav")
	effect.play()


# Wrappers make native TTS initialization and queuing testable.
func has_tts() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)

func voices() -> PackedStringArray:
	return DisplayServer.tts_get_voices_for_language("ru")

func speak(text: String, voice: String) -> void:
	DisplayServer.tts_speak(text, voice, roundi(room.profile.volume * 100), 1.0, 1.0, 1, false)

func stop_tts() -> void:
	DisplayServer.tts_stop()

func is_speaking() -> bool:
	return DisplayServer.tts_is_speaking() if has_tts() else false

func narrate() -> bool:
	return enqueue_speech(str(room.scenario["brief"]), "briefing")

func say_radio(text: String) -> bool:
	return enqueue_speech(text, "radio")

func enqueue_speech(text: String, kind: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	if not room.profile.narration or room.profile.volume <= 0:
		narration_status = "Озвучка выключена в настройках."
		return false
	if not has_tts():
		narration_status = "Системный синтез речи недоступен. Текст остаётся на экране."
		speech_unavailable.emit(narration_status)
		return false
	if speech_queue.is_empty():
		voice_wait = VOICE_WAIT
		retry_after = 0.0
	speech_queue.append({"text": text, "kind": kind})
	pump_voice()
	return true

func pump_voice() -> void:
	if speech_queue.is_empty() or is_speaking():
		return
	var available := voices()
	if available.is_empty():
		narration_status = "Ожидаем русский голос Android…"
		return
	var item: Dictionary = speech_queue.pop_front()
	active_speech_kind = str(item["kind"])
	speak(str(item["text"]), available[0])
	narration_status = "Сообщение озвучивается."
	voice_wait = VOICE_WAIT
	if active_speech_kind == "briefing" and is_instance_valid(room.menu) and room.menu.visible and room.menu.page == "briefing":
		room.menu.briefing(false)

func cancel_radio_speech() -> void:
	for i in range(speech_queue.size() - 1, -1, -1):
		if speech_queue[i]["kind"] == "radio":
			speech_queue.remove_at(i)
	if active_speech_kind == "radio" and has_tts():
		stop_tts()
		active_speech_kind = ""

func _process(delta: float) -> void:
	if speech_queue.is_empty():
		return
	if not room.profile.narration or room.profile.volume <= 0:
		speech_queue.clear()
		return
	if is_speaking():
		return
	voice_wait -= delta
	retry_after -= delta
	if retry_after <= 0:
		retry_after = 0.5
		pump_voice()
	if not speech_queue.is_empty() and voice_wait <= 0:
		speech_queue.clear()
		narration_status = "Русский голос недоступен. Установите его в настройках синтеза речи Android."
		speech_unavailable.emit(narration_status)
		if is_instance_valid(room.menu) and room.menu.visible and room.menu.page == "briefing":
			room.menu.briefing(false)

func _exit_tree() -> void:
	if has_tts():
		stop_tts()
