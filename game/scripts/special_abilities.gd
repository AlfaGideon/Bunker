extends RefCounted

const Content = preload("res://game/scripts/game_content.gd")
const POOL := ["health", "profession", "baggage", "reveal"]
const NAMES := {"health": "Новое здоровье\nвыбранной цели", "profession": "Новая профессия\nвыбранной цели", "baggage": "Обмен багажом\nс выбранной целью", "reveal": "Раскрыть карту\nвыбранной цели"}
var cards: Array = []
var used := [false, false]

func _init() -> void:
 var pool := POOL.duplicate()
 pool.shuffle()
 cards = pool.slice(0, 2)

func apply(slot: int, owner: Dictionary, target: Dictionary) -> Dictionary:
 if slot < 0 or slot >= 2 or used[slot]:
  return {"ok": false, "message": "Способность уже использована."}
 var kind: String = cards[slot]
 var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
 var category: String = "health" if kind == "health" else "profession" if kind == "profession" else "baggage"
 var target_card: Dictionary = {}
 var owner_card: Dictionary = {}
 for card in target["cards"]:
  if card["id"] == category:
   target_card = card
 for card in owner["cards"]:
  if card["id"] == category:
   owner_card = card
 if kind == "reveal":
  target_card = Content.random_hidden_card(target)
  if target_card.is_empty():
   return {"ok": false, "message": "У цели нет закрытых карт."}
  target_card["revealed"] = true
 elif kind == "baggage":
  if owner == target:
   return {"ok": false, "message": "Для обмена выберите другого участника."}
  var old: String = owner_card["value"]
  owner_card["value"] = target_card["value"]
  target_card["value"] = old
 else:
  var options: Array = content["health" if kind == "health" else "professions"].filter(func(option): return (option["label"] if kind == "health" else option) != target_card["value"])
  var replacement: Variant = options.pick_random()
  target_card["value"] = replacement["label"] if kind == "health" else replacement
  if kind == "health":
   target_card["cost"] = replacement["cost"].duplicate()
 used[slot] = true
 return {"ok": true, "message": "Использована способность: " + NAMES[kind] + ". Цель: " + str(target["name"]), "card": target_card}
