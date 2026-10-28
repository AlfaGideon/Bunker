class_name BunkerContent
extends RefCounted


static func create_players(count: int, nickname: String) -> Array:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var professions: Array = content["professions"].duplicate()
	professions.shuffle()
	var names := [nickname, "Мира", "Ян", "Ника", "Лев", "Соня", "Марк", "Вера", "Тим", "Рая"]
	var fields := {"age": ["Возраст", "ages"], "skill": ["Увлечение", "skills"],
		"baggage": ["Багаж", "baggage"], "health": ["Здоровье", "health"],
		"fact": ["Дополнительный факт", "facts"], "quality": ["Характер", "qualities"]}
	var players: Array = []
	for i in count:
		var cards: Array = [{"id": "profession", "label": "Профессия", "value": professions[i], "revealed": false}]
		for key in fields:
			var options: Array = content[fields[key][1]]
			cards.append({"id": key, "label": fields[key][0], "value": options.pick_random(), "revealed": false})
		players.append({"id": "local_%d" % i, "name": names[i], "cards": cards})
	return players
