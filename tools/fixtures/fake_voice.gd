extends "res://game/scripts/bunker_audio.gd"
var ready_voice := false
var talking := false
var spoken: Array[String] = []
func has_tts() -> bool:
 return true
func voices() -> PackedStringArray:
 return PackedStringArray(["test-ru"]) if ready_voice else PackedStringArray()
func speak(text: String, _voice: String) -> void:
 spoken.append(text)
 talking = true
func stop_tts() -> void:
 talking = false
func is_speaking() -> bool:
 return talking
