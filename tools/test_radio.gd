extends SceneTree
const Music = preload("res://game/scripts/music_library.gd")
## The receiver has three numbered stations: music, other bunkers and a hidden
## beacon. Music really plays, the bunker feed arrives over time, and only a
## radio specialist can read the beacon.
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
	for frame in 5:
		await process_frame
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var receiver = room.radio
	var panel: Control = room.radio_panel
	check(is_instance_valid(panel), "The receiver panel is part of the HUD")
	check(receiver.station_list.size() == 4, "Three stations are wired to the dial")
	check(str(receiver.station_list[0]["id"]) == "aurora", "The first item is the music station")
	check(str(receiver.station_list[0]["subtitle"]).to_lower().contains("музык"), "The first item is labelled as music")
	check(str(receiver.station_list[1]["id"]) == "bunkers", "The second item is the bunker feed")
	check(str(receiver.station_list[2]["id"]) == "beacon" and not receiver.tunes_all("beacon"), "The beacon needs a specialist")
	check(receiver.broadcast_list.size() >= 6, "Other bunkers have something to say")
	check(receiver.signal_list.size() >= 3, "The beacon carries several transmissions")
	# Music station: a real, looping, original track.
	room.begin_game()
	room.menu.visible = false
	check(receiver.powered and receiver.station == "aurora", "The party starts on the music station")
	check(room.audio.radio_on and room.audio.radio.playing, "Music actually plays on the receiver")
	check(room.audio.radio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops without a gap")
	check(room.audio.radio.stream.get_length() >= 20.0, "The music station is a full loop, not a blip")
	check(room.audio.radio.volume_db >= -12.0, "Music sits inside the mix")
	check(room.audio.radio is AudioStreamPlayer, "The cabinet is heard across the bunker, not hushed by distance")
	check(room.radio.track_count() >= 4, "The music station carries several records")
	var files := {}
	for index in Music.count():
		var track := load(Music.path(index)) as AudioStreamWAV
		check(track != null, "Music file %d loads" % index)
		if track != null:
			check(track.get_length() >= 20.0, "Music file %d is a full piece" % index)
			check(not files.has(track.get_length()), "Every record is its own file")
			files[track.get_length()] = true
	check(Music.path(0) != Music.path(1) and Music.path(1) != Music.path(2), "Records are different files")
	var first_track: int = room.radio.track_index
	var first_stream = room.audio.radio.stream
	room.radio.next_track()
	room.apply_radio_audio()
	check(room.radio.track_index != first_track, "The dial changes the record")
	check(room.audio.radio.stream != first_stream, "The player swaps the music file")
	check(room.audio.music_index == room.radio.track_index and room.audio.radio.playing, "The new record keeps playing")
	check(room.radio.status_text().contains(Music.title(room.radio.track_index)), "The receiver names the record")
	check(receiver.tick(40.0).is_empty(), "The music station does not talk")
	# Bunker feed: transmissions arrive while the station is tuned.
	room.radio.tune("bunkers")
	room.apply_radio_audio()
	check(room.audio.static_noise.playing and not room.audio.radio.playing, "The bunker feed plays static instead of music")
	var arrival: Dictionary = receiver.tick(40.0)
	check(not arrival.is_empty(), "A transmission arrives from another bunker")
	check(str(arrival["from"]).length() > 0 and str(arrival["text"]).length() > 20, "The transmission names a bunker and says something")
	check(receiver.received.size() == 1, "The feed remembers the transmission")
	check(room.audio.transmission.stream != null and room.audio.transmission.stream.get_length() > 1.0, "A voice signal accompanies the feed")
	for step in 6:
		receiver.tick(40.0)
	check(receiver.received.size() >= 4, "The ether stays alive with more broadcasts")
	check(receiver.feed_lines(4).size() == 4, "The panel shows the latest four transmissions")
	# The full loop through the real interaction path.
	room._complete_interaction("radio")
	check(panel.visible, "Tapping the receiver opens the station panel")
	check(panel.station_buttons.size() == 4, "Every station has its own item")
	check(panel.get_global_rect().size.x <= screen.size.x and panel.get_global_rect().size.y <= screen.size.y, "The receiver fits the screen")
	check(panel.find_children("*", "ScrollContainer", true, false).is_empty(), "The receiver never scrolls")
	check(panel.station_buttons[0].text.contains("АВРОРА"), "The first item on the dial is the music station")
	# Nobody in the party can decode the beacon yet.
	room.players[0]["cards"][0]["value"] = "Учитель"
	for id in room.active:
		room.players[id]["cards"][0]["value"] = "Учитель"
	check(not room.can_scan_radio(), "No specialist means no beacon")
	panel.refresh()
	check(panel.station_buttons[2].disabled, "The beacon item is locked without a specialist")
	check(not room.scan_radio(), "Scanning is refused without a specialist")
	check(room.log_label.text.to_lower().contains("связист"), "The refusal explains which professions are needed")
	# A radio specialist unlocks the beacon and a small find.
	room.players[0]["cards"][0]["value"] = "Связист"
	check(room.can_scan_radio(), "Связист can work the beacon")
	check(room.radio_operator_name().contains("Связист"), "The panel names the specialist on duty")
	panel.refresh()
	check(not panel.station_buttons[2].disabled, "The beacon unlocks for a specialist")
	room.radio.tune("beacon")
	room.apply_radio_audio()
	check(room.audio.static_noise.playing, "The beacon is heard as static")
	var filters_before: int = room.supplies.stock["filters"]
	var food_before: int = room.supplies.stock["food"]
	check(room.scan_radio(), "The specialist reads the first beacon transmission")
	check(room.supplies.stock["filters"] == filters_before + 3 and room.supplies.stock["food"] == food_before + 4, "The first transmission leads to a hidden stash")
	check(receiver.scans_left() == receiver.signal_list.size() - 1, "The transmission is spent")
	check(not room.scan_radio(), "One transmission per round")
	check(room.log_label.text.contains("раунд"), "The cooldown explains itself")
	panel.refresh()
	check(panel.scan_button.disabled, "Scanning is disabled while the round is spent")
	room.round_number += 1
	panel.refresh()
	check(not panel.scan_button.disabled, "A new round opens the beacon again")
	# Power and closing keep the HUD honest.
	panel.power_button.pressed.emit()
	check(not receiver.powered and not room.audio.radio_on, "The power button stops the receiver")
	panel.refresh()
	check(panel.power_button.text.contains("ВКЛЮЧИТЬ"), "A stopped receiver offers to turn on")
	panel.power_button.pressed.emit()
	check(receiver.powered and room.audio.radio_on, "Power comes back with the station")
	panel.close()
	check(not panel.visible, "The receiver closes back to the game")
	room._complete_interaction("radio")
	check(panel.visible, "The receiver opens again from the world")
	panel.close()
	# The feed never hijacks the party when the cabinet is off.
	receiver.power(false)
	room.apply_radio_audio()
	var quiet: Dictionary = receiver.tick(120.0)
	check(quiet.is_empty() and not room.audio.radio_on, "A switched-off receiver stays silent")
	# The whole ether is local content: no network calls anywhere in the radio.
	var source := FileAccess.get_file_as_string("res://game/scripts/radio_receiver.gd")
	check(not source.contains("HTTPRequest") and not source.contains("http"), "Radio content stays local")
	room.free()
	await process_frame
	print("Radio checks: ", failures, " failures")
	quit(1 if failures else 0)
