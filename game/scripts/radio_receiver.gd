extends RefCounted
## Radio receiver state: three stations, live transmissions from other
## bunkers and a hidden beacon that only a radio specialist can read.
##
## The music station is an original procedural loop, the bunker feed is
## fictional flavour text, and the beacon hands out small finds. Nothing here
## touches the network: the whole ether is local content.

const PATH := "res://data/radio.json"
const FEED_LIMIT := 24
const Music = preload("res://game/scripts/music_library.gd")

var frequency := ""
var station_list: Array = []
var broadcast_list: Array = []
var signal_list: Array = []
var station := ""
var powered := false
var received: Array = []
var next_broadcast := 10.0
var scan_round := 0
var signal_index := 0
var track_index := 0


func _init() -> void:
	reload()


func reload() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	frequency = str(parsed.get("frequency", ""))
	station_list = parsed.get("stations", [])
	broadcast_list = parsed.get("broadcasts", [])
	signal_list = parsed.get("signals", [])


func info(id: String) -> Dictionary:
	for entry in station_list:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


func tuned() -> Dictionary:
	return info(station)


func kind() -> String:
	if not powered:
		return ""
	return str(tuned().get("kind", ""))


func tunes_all(station_id: String) -> bool:
	return str(info(station_id).get("requires", "")).is_empty()


func requirements(station_id: String) -> String:
	return str(info(station_id).get("requires", ""))


func tune(station_id: String) -> bool:
	if info(station_id).is_empty():
		return false
	station = station_id
	powered = true
	next_broadcast = 9.0
	return true


func power(on: bool) -> void:
	powered = on
	if not on:
		return
	if station.is_empty() and not station_list.is_empty():
		station = str(station_list[0]["id"])


## Music station: the dial cycles through four original instrumentals.
func next_track() -> Dictionary:
	track_index = posmod(track_index + 1, Music.count())
	return Music.track(track_index)


func current_track() -> Dictionary:
	return Music.track(track_index)


func track_title() -> String:
	return Music.title(track_index)


func track_mood() -> String:
	return Music.mood(track_index)


func track_count() -> int:
	return Music.count()


func status_text() -> String:
	if not powered:
		return "ВЫКЛЮЧЕНО"
	var entry = tuned()
	if entry.is_empty():
		return "ВКЛЮЧЕНО · НЕТ НАСТРОЙКИ"
	if str(entry.get("kind", "")) == "music":
		return "ВКЛЮЧЕНО · " + str(entry.get("name", "")) + " · " + Music.title(track_index)
	return "ВКЛЮЧЕНО · " + str(entry.get("name", "")) + " · " + str(entry.get("subtitle", ""))


## Advances the ether. Returns the transmission that just arrived, or {}.
func tick(delta: float) -> Dictionary:
	if not powered or kind() != "broadcast" or broadcast_list.is_empty():
		return {}
	next_broadcast -= maxf(0.0, delta)
	if next_broadcast > 0.0:
		return {}
	next_broadcast = randf_range(17.0, 24.0)
	var entry: Dictionary = broadcast_list[received.size() % broadcast_list.size()]
	received.append({"from": str(entry.get("source", "")), "text": str(entry.get("text", ""))})
	while received.size() > FEED_LIMIT:
		received.pop_front()
	return received[received.size() - 1]


## Reads the hidden beacon. One read per round, four reads per party.
func scan(round_number: int) -> Dictionary:
	if signal_list.is_empty():
		return {"ok": false, "reason": "empty"}
	if scan_round == round_number:
		return {"ok": false, "reason": "cooldown"}
	if signal_index >= signal_list.size():
		return {"ok": false, "reason": "exhausted"}
	var entry: Dictionary = signal_list[signal_index]
	signal_index += 1
	scan_round = round_number
	return {
		"ok": true,
		"title": str(entry.get("title", "")),
		"text": str(entry.get("text", "")),
		"effect": str(entry.get("effect", ""))
	}


func scans_left() -> int:
	return maxi(0, signal_list.size() - signal_index)


func feed_lines(count: int) -> Array:
	var lines: Array = []
	var start := maxi(0, received.size() - count)
	for index in range(start, received.size()):
		lines.append(str(received[index]["from"]) + " — " + str(received[index]["text"]))
	return lines


func signal_strength() -> int:
	match kind():
		"music":
			return 5
		"broadcast":
			return 7
		"signal":
			return 2
	return 0
