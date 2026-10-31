extends Node

signal radio_message(text: String, status: String)

const VOICE_WAIT := 15.0
const BROADCAST_INTERVAL := 60.0

var radio: AudioStreamPlayer3D
var air: AudioStreamPlayer
var effect: AudioStreamPlayer
var room: Node3D
var radio_on := false
var narration_status := ""
var pending_text := ""
var pending_is_radio := false
var pending_wait := 0.0
var retry_after := 0.0
var radio_elapsed := 0.0
var radio_message_text := ""
var broadcast_index := 0


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
	air.volume_db = -10
	add_child(air)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -1
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
	radio.volume_db = -3
	if room.profile.volume <= 0 or not room.profile.narration:
		pending_text = ""
		if has_tts():
			stop_tts()


func begin() -> void:
	if not air.playing:
		air.play()
	if not radio_on:
		radio_on = true
		radio_elapsed = 0.0
		radio.play()


func toggle_radio() -> void:
	radio_on = not radio_on
	if radio_on:
		radio.play()
		radio_elapsed = 0.0
		broadcast()
	else:
		radio.stop()
		if pending_is_radio:
			pending_text = ""
		if has_tts():
			stop_tts()


func blip(kind: String = "click") -> void:
	effect.stream = load("res://assets/audio/" + kind + ".wav")
	effect.play()


# Small wrappers make native TTS initialization and failures testable.
func has_tts() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)

func voices() -> PackedStringArray:
	return DisplayServer.tts_get_voices_for_language("ru")

func speak(text: String, voice: String) -> void:
	DisplayServer.tts_speak(text, voice, roundi(room.profile.volume * 100), 1.0, 1.0, 1, true)

func stop_tts() -> void:
	DisplayServer.tts_stop()

func is_speaking() -> bool:
	return DisplayServer.tts_is_speaking() if has_tts() else false

func narrate() -> bool:
	return say(str(room.scenario["brief"]), false)

func say(text: String, is_radio: bool = false) -> bool:
	pending_text = ""
	pending_is_radio = is_radio
	if not room.profile.narration or room.profile.volume <= 0:
		narration_status = "Озвучка выключена в настройках."
		return false
	if not has_tts():
		narration_status = "Системный синтез речи недоступен. Текст остаётся на экране."
		return false
	pending_text = text
	pending_wait = VOICE_WAIT
	retry_after = 0.0
	return try_voice()

func try_voice() -> bool:
	var available := voices()
	if available.is_empty():
		narration_status = "Ожидаем русский голос Android…"
		return false
	var text := pending_text
	pending_text = ""
	speak(text, available[0])
	narration_status = "Сообщение озвучивается."
	return true

func broadcast() -> void:
	if not radio_on:
		return
	# The visible text and the text passed to TTS are the same message.
	var description := str(room.scenario["brief"]).get_slice(".", 1).strip_edges()
	var messages := ["Радио. " + description + ".", "Радио. Оставайтесь в убежище. Следите за запасами и сообщениями совета."]
	radio_message_text = messages[broadcast_index % messages.size()]
	broadcast_index += 1
	say(radio_message_text, true)
	radio_message.emit(radio_message_text, narration_status)

func _process(delta: float) -> void:
	if radio_on:
		radio_elapsed += delta
		if radio_elapsed >= BROADCAST_INTERVAL and pending_text.is_empty() and not is_speaking():
			radio_elapsed = 0.0
			broadcast()
	if pending_text.is_empty():
		return
	if not room.profile.narration or room.profile.volume <= 0:
		pending_text = ""
		return
	pending_wait -= delta
	retry_after -= delta
	if retry_after <= 0.0:
		retry_after = 1.0
		if try_voice():
			if pending_is_radio:
				radio_message.emit(radio_message_text, narration_status)
			return
	if pending_wait <= 0.0:
		pending_text = ""
		narration_status = "Русский голос недоступен. Установите его в настройках синтеза речи Android."
		if pending_is_radio:
			radio_message.emit(radio_message_text, narration_status)
		elif is_instance_valid(room.menu) and room.menu.visible and room.menu.page == "briefing":
			room.menu.briefing(false)

func _exit_tree() -> void:
	if has_tts():
		stop_tts()
