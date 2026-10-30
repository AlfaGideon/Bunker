extends RefCounted
const Library = preload("res://game/scripts/parameter_library.gd")
const Choice = preload("res://game/scripts/card_choice.gd")
const Supplies = preload("res://game/scripts/group_supplies.gd")
var host: Node
var key := "ages"
var selection := 0

func _init(menu: Node) -> void:
 host = menu

func text(value: String, size: int = 18) -> void:
 host.column.add_info(value, size)

func show_list() -> void:
 host.page = "library"
 host.clear()
 text("БИБЛИОТЕКА ПАРАМЕТРОВ", 25)
 text("Свои значения добавляются к стандартным при создании новой локальной партии. Сетевых лобби пока нет.", 16)
 var category := Choice.new()
 for title in Library.LABELS:
  category.add_item(title)
 category.select(Library.KEYS.find(key))
 category.item_selected.connect(func(index):
  key = Library.KEYS[index]
  selection = 0
  show_list())
 host.column.add_card(category)
 var builtins: Array = Library.base()[key]
 var custom: Array = host.profile.custom_parameters.get(key, [])
 var picker := Choice.new()
 for value in builtins:
  picker.add_item("СТАНДАРТ • " + display(value))
 for value in custom:
  picker.add_item("МОЁ • " + display(value))
 picker.select(selection)
 picker.item_selected.connect(func(index): selection = index; show_list())
 host.column.add_card(picker)
 var own := selection >= builtins.size() and selection - builtins.size() < custom.size()
 text("Стандартные значения доступны только для просмотра. Свои можно добавить, изменить или удалить.", 16)
 if key == "health":
  text("У болезни можно указать расход общих запасов за раунд.", 16)
 elif key == "professions":
  text("Своя профессия пока не даёт доступ к специальным работам.", 16)
 elif key == "qualities":
  text("Свой характер пока не добавляет особых отрицательных действий.", 16)
 host.button("Добавить своё значение", func(): show_form(-1))
 if own:
  var index := selection - builtins.size()
  host.button("Изменить выбранное", func(): show_form(index))
  host.button("Удалить выбранное", func(): confirm_delete(index))
 host.button("Назад в настройки", host.settings)

func display(value: Variant) -> String:
 if value is Dictionary:
  return str(value.get("label", "")) + " • " + Supplies.cost_text(value.get("cost", {}))
 if key == "ages" and str(value).is_valid_int():
  return Library.age_label(int(value))
 return str(value)

func confirm_delete(index: int) -> void:
 host.clear()
 var value: Variant = host.profile.custom_parameters[key][index]
 text("УДАЛИТЬ СВОЙ ПАРАМЕТР?", 25)
 text(display(value), 18)
 host.button("Да, удалить", func():
  var original: Dictionary = host.profile.custom_parameters.duplicate(true)
  host.profile.custom_parameters[key].remove_at(index)
  if host.profile.save() != OK:
   host.profile.custom_parameters = original
   text("Не удалось сохранить изменения.")
   host.column.show_last()
   return
  selection = 0
  show_list())
 host.button("Отмена", show_list)

func show_form(index: int) -> void:
 host.page = "library_form"
 host.clear()
 var list: Array = host.profile.custom_parameters.get(key, [])
 var old: Variant = list[index] if index >= 0 and index < list.size() else null
 text(("НОВЫЙ ПАРАМЕТР • " if old == null else "ИЗМЕНИТЬ ПАРАМЕТР • ") + Library.LABELS[Library.KEYS.find(key)], 24)
 text("Возраст: целое число от 18 до 100." if key == "ages" else "Введите название, до 100 символов.", 16)
 var input := LineEdit.new()
 input.max_length = 3 if key == "ages" else Library.MAX_LENGTH
 input.placeholder_text = "Например, 38" if key == "ages" else "Название"
 input.text = "" if old == null else (old.label if old is Dictionary else str(old))
 if key == "ages":
  input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
 host.column.add_card(input)
 var controls := {}
 if key == "health":
  for resource in Library.RESOURCES:
   var picker := Choice.new()
   for amount in range(6):
    picker.add_item(Supplies.LABELS[resource] + " +" + str(amount), amount)
   if old is Dictionary:
    picker.select(int(old.cost.get(resource, 0)))
   host.column.add_card(picker)
   controls[resource] = picker
  text("Дополнительный расход в каждом раунде.", 16)
 var feedback := Label.new()
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 feedback.text = "Сохраняется на этом устройстве."
 host.column.add_card(feedback)
 host.button("Сохранить", func():
  var costs := {}
  for resource in controls:
   costs[resource] = controls[resource].get_selected_id()
  var raw: Variant = {"label": input.text, "cost": costs} if key == "health" else input.text
  var cleaned: Variant = Library.clean(key, raw)
  if cleaned == null:
   feedback.text = "Проверьте название или возраст (18–100)."
   return
  var updated: Array = host.profile.custom_parameters.get(key, []).duplicate(true)
  if cleaned in updated and (index < 0 or updated[index] != cleaned):
   feedback.text = "Такой вариант уже есть в вашей библиотеке."
   return
  if index < 0:
   if updated.size() >= Library.MAX_ENTRIES:
    feedback.text = "Достигнут лимит: 100 вариантов в категории."
    return
   updated.append(cleaned)
   selection = Library.base()[key].size() + updated.size() - 1
  else:
   updated[index] = cleaned
   selection = Library.base()[key].size() + index
  var original: Dictionary = host.profile.custom_parameters.duplicate(true)
  host.profile.custom_parameters[key] = updated
  if host.profile.save() != OK:
   host.profile.custom_parameters = original
   feedback.text = "Не удалось сохранить изменения."
   return
  show_list())
 host.button("Отмена", show_list)
