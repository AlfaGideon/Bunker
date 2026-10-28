extends RefCounted

const LABELS := {"water": "вода", "food": "рацион", "medicine": "лекарства", "filters": "фильтры"}
var stock := {"water": 100, "food": 100, "medicine": 32, "filters": 24}
var charged_rounds := {}
var shortage := false
var last_report := "Расход запасов учитывается при переходе в следующий раунд."


static func health_cost(player: Dictionary) -> Dictionary:
	for card in player["cards"]:
		if card["id"] == "health":
			return card.get("cost", {}).duplicate()
	return {}


static func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in LABELS:
		if cost.get(key, 0) > 0:
			parts.append("%s +%d" % [LABELS[key], cost[key]])
	return "без дополнительного расхода" if parts.is_empty() else ", ".join(parts) + " / раунд"


func charge_round(number: int, players: Array, active: Array, weather: String) -> void:
	if charged_rounds.has(number):
		return
	charged_rounds[number] = true
	var cost := {"water": active.size() * 2, "food": active.size() * 2, "medicine": 0, "filters": 0}
	if weather == "heat":
		cost["water"] += active.size()
	if weather in ["radiation", "toxic", "volcano", "sand"]:
		cost["filters"] += 2
	for index in active:
		var extra := health_cost(players[index])
		for key in extra:
			cost[key] += int(extra[key])
	var parts := PackedStringArray()
	shortage = false
	for key in stock:
		if cost[key] > stock[key]:
			shortage = true
		stock[key] = maxi(0, stock[key] - cost[key])
		parts.append("%s −%d" % [LABELS[key], cost[key]])
	last_report = "Расход группы: " + ", ".join(parts) + (". Дефицит: отдых и осмотр восстанавливают меньше бодрости." if shortage else ".")


func summary() -> String:
	return "Вода %d • Рацион %d • Лекарства %d • Фильтры %d" % [stock["water"], stock["food"], stock["medicine"], stock["filters"]]
