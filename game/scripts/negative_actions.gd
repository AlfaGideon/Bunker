extends RefCounted

# Only personality flaws grant these actions. Illness/disability is not villainy.
const ACTIONS := {
 "quarrel": {"title": "Устроить ссору", "traits": ["Вспыльчивый"], "cost": {"water": 3}, "effect": "В суматохе проливается 3 воды"},
 "hoard": {"title": "Испортить общий рацион, пряча еду", "traits": ["Эгоистичный"], "cost": {"food": 4}, "effect": "Общий запас теряет 4 рациона"},
 "neglect": {"title": "Пропустить обслуживание фильтра", "traits": ["Небрежный", "Упрямый"], "cost": {"filters": 1}, "effect": "Из-за пропущенного обслуживания теряется 1 фильтр"}
}

static func quality_card(player: Dictionary) -> Dictionary:
 for card in player["cards"]:
  if card["id"] == "quality":
   return card
 return {}

static func available(player: Dictionary) -> Array:
 var result := []
 var quality: String = quality_card(player).get("value", "")
 for key in ACTIONS:
  if quality in ACTIONS[key]["traits"]:
   result.append(key)
 return result

static func affordable(stock: Dictionary, key: String) -> bool:
 if not ACTIONS.has(key):
  return false
 for resource in ACTIONS[key]["cost"]:
  if stock.get(resource, 0) < ACTIONS[key]["cost"][resource]:
   return false
 return true
