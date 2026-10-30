extends RefCounted
# Custom values extend, never replace, the shipped card pools.
const KEYS := ["ages", "health", "qualities", "professions", "skills", "baggage", "facts"]
const LABELS := ["Возраст", "Здоровье и болезни", "Характер", "Профессия", "Увлечение", "Багаж", "Дополнительный факт"]
const RESOURCES := ["water", "food", "medicine", "filters"]
const MAX_ENTRIES := 100
const MAX_LENGTH := 100

static func base() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))

static func clean(key: String, value: Variant) -> Variant:
 if key not in KEYS:
  return null
 if key == "health":
  if not value is Dictionary or not value.get("label", null) is String or not value.get("cost", null) is Dictionary:
   return null
  var label: String = value.label.strip_edges()
  if label.is_empty() or label.length() > MAX_LENGTH or "\n" in label:
   return null
  var cost := {}
  for resource in RESOURCES:
   var amount: Variant = value.cost.get(resource, 0)
   if not (amount is int) or amount < 0 or amount > 5:
    return null
   if amount > 0:
    cost[resource] = amount
  return {"label": label, "cost": cost}
 if not value is String:
  return null
 var result: String = value.strip_edges()
 if result.is_empty() or result.length() > MAX_LENGTH or "\n" in result:
  return null
 if key == "ages":
  if not result.is_valid_int() or str(result.to_int()) != result or int(result) < 18 or int(result) > 100:
   return null
 return result

static func sanitize(value: Variant) -> Dictionary:
 var result := {}
 if not value is Dictionary:
  return result
 for key in KEYS:
  var list: Variant = value.get(key, [])
  if not list is Array:
   continue
  var unique: Array = []
  for item in list:
   var valid: Variant = clean(key, item)
   if valid != null and valid not in unique and unique.size() < MAX_ENTRIES:
    unique.append(valid)
  if not unique.is_empty():
   result[key] = unique
 return result

static func age_label(number: int) -> String:
 var word := "лет"
 if number % 100 < 11 or number % 100 > 14:
  if number % 10 == 1:
   word = "год"
  elif number % 10 in [2, 3, 4]:
   word = "года"
 return "%d %s" % [number, word]

static func merged(custom: Dictionary) -> Dictionary:
 var content := base()
 var safe := sanitize(custom)
 for key in KEYS:
  for value in safe.get(key, []):
   var item: Variant = value
   if key == "ages":
    item = age_label(int(value))
   content[key].append(item)
 return content
