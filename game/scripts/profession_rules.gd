extends RefCounted

const ROLES := {
 "terminal": ["Электрик", "Инженер-механик", "Связист", "Программист", "Техник вентиляции", "Энергетик", "Радиотехник", "Слесарь"],
 "gate": ["Врач"],
 "medical": ["Врач", "Фельдшер", "Медсестра", "Фармацевт", "Ветеринар", "Инструктор первой помощи"],
 "kitchen": ["Повар", "Пекарь", "Технолог пищевого производства"],
 "supply": ["Логист", "Спасатель", "Водитель", "Слесарь", "Электрик", "Инженер-механик"],
 "gym": ["Тренер", "Спасатель", "Пожарный", "Инструктор первой помощи"],
 "workshop": ["Инженер-механик", "Сварщик", "Слесарь", "Плотник", "Электрик"],
 "greenhouse": ["Агроном", "Биолог", "Эколог", "Оператор теплицы", "Зоотехник"]
}

static func profession(player: Dictionary) -> String:
 for card in player["cards"]:
  if card["id"] == "profession":
   return card["value"]
 return ""

static func allowed(player: Dictionary, item: String) -> bool:
 if item.begins_with("bed") or item in ["radio", "food"]:
  return true
 return profession(player) in ROLES.get(item, [])

static func requirement(item: String) -> String:
 if item.begins_with("bed") or item in ["radio", "food"]:
  return "Доступно всем"
 return "Профессии: " + ", ".join(ROLES.get(item, []))
