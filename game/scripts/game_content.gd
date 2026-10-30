class_name BunkerContent
extends RefCounted


static func create_players(count: int, nickname: String, appearance: String = "male", custom: Dictionary = {}) -> Array:
	var content: Dictionary = preload("res://game/scripts/parameter_library.gd").merged(custom)
	var professions: Array = content["professions"].duplicate()
	professions.shuffle()
	var names := [nickname, "Мира", "Ян", "Ника", "Лев", "Соня", "Марк", "Вера", "Тим", "Рая"]
	var fields := {"skill": ["Увлечение", "skills"],
		"baggage": ["Багаж", "baggage"], "health": ["Здоровье", "health"],
		"fact": ["Дополнительный факт", "facts"], "quality": ["Характер", "qualities"]}
	var players: Array = []
	for i in count:
		var cards: Array = [{"id": "profession", "label": "Профессия", "value": professions[i], "revealed": true}]
		var sex: String = ["male", "female"].pick_random()
		var age: String = content["ages"].pick_random()
		cards.append({"id": "biology", "label": "Биология", "value": ("Мужчина, " if sex == "male" else "Женщина, ") + age, "revealed": false})
		for key in fields:
			var options: Array = content[fields[key][1]]
			var option: Variant = options.pick_random()
			if key == "health":
				cards.append({"id": key, "label": fields[key][0], "value": option["label"], "cost": option["cost"].duplicate(), "revealed": false})
			else:
				cards.append({"id": key, "label": fields[key][0], "value": option, "revealed": false})
		players.append({"id": "local_%d" % i, "name": names[i], "sex": sex, "age": int(age.get_slice(" ", 0)), "appearance": appearance if i == 0 else ["male", "female"].pick_random(), "cards": cards})
	return players


static func random_hidden_card(player: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var hidden: Array = player["cards"].filter(func(card: Dictionary): return not card["revealed"])
	if hidden.is_empty():
		return {}
	return hidden.pick_random() if rng == null else hidden[rng.randi_range(0, hidden.size() - 1)]


static func scenarios() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios.json"))


static func pick_scenario(choice: String = "random") -> Dictionary:
	var all := scenarios()
	for scenario in all:
		if scenario["id"] == choice:
			return scenario.duplicate(true)
	return all.pick_random().duplicate(true)

# Preserve card visibility and never reveal hidden values during rerolls.
static func reroll(player: Dictionary, ids: Array, custom: Dictionary = {}, used_professions: Array = []) -> Dictionary:
	var pool: Dictionary = preload("res://game/scripts/parameter_library.gd").merged(custom)
	var keys := {"profession": "professions", "health": "health", "quality": "qualities", "skill": "skills", "baggage": "baggage", "fact": "facts"}
	var result: Dictionary = player.duplicate(true)
	var changed := 0
	for card in result["cards"]:
		var id: String = card["id"]
		if id not in ids:
			continue
		var candidates: Array = []
		if id == "biology":
			for sex in ["male", "female"]:
				for age in pool["ages"]:
					var value: String = ("Мужчина, " if sex == "male" else "Женщина, ") + str(age)
					if value != card["value"]:
						candidates.append({"value": value, "sex": sex, "age": int(str(age).get_slice(" ", 0))})
		elif keys.has(id):
			for value in pool[keys[id]]:
				var label: String = str(value["label"]) if id == "health" else str(value)
				if label != card["value"] and (id != "profession" or label not in used_professions):
					candidates.append(value)
		if candidates.is_empty():
			return {}
		var chosen: Variant = candidates.pick_random()
		if id == "biology":
			card["value"] = chosen["value"]
			result["sex"] = chosen["sex"]
			result["age"] = chosen["age"]
		elif id == "health":
			card["value"] = chosen["label"]
			card["cost"] = chosen["cost"].duplicate(true)
		else:
			card["value"] = chosen
		changed += 1
	return result if changed == ids.size() and changed > 0 else {}
