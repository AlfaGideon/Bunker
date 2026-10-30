extends RefCounted
## The four original instrumental loops played by both radios.
##
## The camp menu cycles through all of them with no bunker chatter, while the
## bunker receiver treats them as the "АВРОРА-7" music station.

const TRACKS := [
	{"id": "campfire", "file": "music_campfire.wav", "name": "ЭХО У КОСТРА", "mood": "гитара, ветер, огонь"},
	{"id": "zone", "file": "music_zone.wav", "name": "ЗОНА", "mood": "медленные пэды и тики"},
	{"id": "bunker", "file": "music_bunker.wav", "name": "ГУДОК", "mood": "гул бункера и металл"},
	{"id": "gate", "file": "music_gate.wav", "name": "ПОСЛЕДНИЙ ШЛЮЗ", "mood": "пиано и винил"},
]


static func count() -> int:
	return TRACKS.size()


static func track(index: int) -> Dictionary:
	if TRACKS.is_empty():
		return {}
	return TRACKS[posmod(index, TRACKS.size())]


static func path(index: int) -> String:
	return "res://assets/audio/" + str(track(index).get("file", ""))


static func title(index: int) -> String:
	return str(track(index).get("name", ""))


static func mood(index: int) -> String:
	return str(track(index).get("mood", ""))


static func label(index: int) -> String:
	return title(index) + " · " + mood(index)
