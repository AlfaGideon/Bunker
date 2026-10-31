extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 var old = room.audio
 var voice = preload("res://tools/fixtures/fake_voice.gd").new()
 room.add_child(voice)
 voice.room = room
 room.audio = voice
 old.queue_free()
 room.profile.volume = 0.7
 room.profile.narration = true
 room.started = true
 room.radio.power(true)
 room.radio.tune("bunkers")
 room._tick_radio(30.0)
 var arrival: Dictionary = room.radio.received.back()
 var expected := str(arrival["from"]) + ". " + str(arrival["text"])
 check(voice.speech_queue.size() == 1 and voice.speech_queue[0]["text"] == expected, "Real receiver enqueues exactly the displayed broadcast")
 check(voice.spoken.is_empty(), "Wait for Android voice initialization")
 voice.ready_voice = true
 voice._process(1.0)
 check(voice.spoken == [expected], "Speech starts once the voice becomes available")
 voice.say_radio("Вторая передача")
 check(voice.spoken.size() == 1, "Do not interrupt the current transmission")
 voice.talking = false
 voice._process(1.0)
 check(voice.spoken.size() == 2 and voice.spoken[1] == "Вторая передача", "Queued transmission is spoken")
 voice.talking = false
 voice.narrate()
 check(voice.spoken.back() == room.scenario["brief"], "Disaster briefing uses same voice pipeline")
 voice.talking = false
 voice.ready_voice = false
 voice.say_radio("Тест таймаута")
 voice._process(16.0)
 check(voice.speech_queue.is_empty() and voice.narration_status.contains("недоступен"), "Unavailable voice reports failure without hanging")
 voice.ready_voice = true
 room.profile.narration = false
 check(not voice.say_radio("Тихо"), "Disabled narration stays silent")
 room.queue_free()
 await process_frame
 print("Radio speech failures: ", failures)
 quit(1 if failures else 0)
