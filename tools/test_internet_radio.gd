extends SceneTree
var failures := 0
class FakeBridge extends RefCounted:
 var url := ""
 var state := "stopped"
 var volume := 0.0
 func play(value: String, level: float) -> void:
  url = value
  volume = level
  state = "connecting"
 func stop() -> void:
  state = "stopped"
 func setVolume(level: float) -> void:
  volume = level
 func getState() -> String:
  return state
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
 for i in 4: await process_frame
 var fake := FakeBridge.new()
 room.audio.internet.bridge = fake
 room.radio.tune("internet")
 room.apply_radio_audio()
 check(room.audio.internet.status == "connecting" and fake.url == room.radio.internet_stream().url, "Internet stream goes to native player")
 check(not room.audio.radio.playing and not room.audio.static_noise.playing, "No local audio overlays the internet stream")
 fake.state = "playing"
 room.audio.internet._process(1.0)
 check(room.audio.internet.status == "playing", "Player status reaches the game")
 var previous := fake.url
 room.radio_panel._tune(3)
 check(fake.url != previous and fake.url == room.radio.internet_stream().url, "Repeated tap selects next live mix")
 fake.state = "error"
 room.audio.internet._process(1.0)
 previous = fake.url
 room.radio_panel._tune(3)
 check(fake.url == previous and fake.state == "connecting", "Failed stream retries without changing station")
 room.radio.tune("bunkers")
 room.apply_radio_audio()
 check(fake.state == "stopped" and room.audio.static_noise.playing, "Switching back stops the network and restores local radio")
 check(not room.radio.tick(30.0).is_empty(), "Fictional broadcast remains functional")
 room.radio.tune("beacon")
 check(room.radio.kind() == "signal", "Beacon remains accessible")
 room.radio.power(false)
 room.apply_radio_audio()
 check(fake.state == "stopped", "Power off stops stream")
 room.queue_free()
 await process_frame
 print("Internet radio failures: ", failures)
 quit(1 if failures else 0)
