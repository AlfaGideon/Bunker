extends RefCounted
const Library = preload("res://game/scripts/parameter_library.gd")
const Choice = preload("res://game/scripts/card_choice.gd")
const Supplies = preload("res://game/scripts/group_supplies.gd")
const Art = preload("res://game/scripts/profession_art.gd")
const Tile = preload("res://game/scripts/profession_gallery_card.gd")
const Portrait = preload("res://game/scripts/profession_art_view.gd")
const Style = preload("res://game/scripts/card_style.gd")
# Russian names for the sixteen profession groups of the illustrated catalogue.
const GROUP_TITLES := {
 "medical": "Медицина", "science": "Наука", "engineering": "Механика",
 "electrical": "Энергия и связь", "construction": "Мастерская", "food": "Пища",
 "nature": "Природа", "rescue": "Спасение", "mind": "Знания",
 "logistics": "Снабжение", "security": "Охрана", "culture": "Сцена",
 "care": "Тело и забота", "nightlife": "Ночь", "craft": "Ремесло", "show": "Праздник"
}
var host: Node
var key := "ages"
var selection := 0
var group_filter := ""

func _init(menu: Node) -> void:
 host = menu

func text(value: String, size: int = 18) -> void:
 host.column.add_info(value, size)

func ensure_deck() -> void:
 # The library always lives in the paginated touch deck, never in a scroll box.
 if not host.column.has_method("add_card"):
  host.subpage()

# The library is two blocks: a picture catalogue of every profession and the
# editable parameter lists. The hub page shows both, each on its own page.
func show_home() -> void:
 ensure_deck()
 host.page = "library"
 host.clear()
 host.column.columns = 1
 host.column.page_height = 480.0
 text("БИБЛИОТЕКА", 25)
 var strip := HBoxContainer.new()
 strip.add_theme_constant_override("separation", 8)
 strip.custom_minimum_size.y = 128
 strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
 for name in showcase():
  var thumb := TextureRect.new()
  thumb.texture = Art.texture_for(name)
  thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
  thumb.tooltip_text = name
  strip.add_child(thumb)
 host.column.add_card(strip)
 host.button("ПРОФЕССИИ • " + str(profession_names().size()) + " портретов\nОбезличенные манекены в снаряжении каждой профессии", show_professions)
 host.button("ПАРАМЕТРЫ • стандарт и свои\nВозраст, болезни, характер, профессия, увлечение, багаж и факт", show_list)
 host.button("Назад в меню", host.home)

func profession_names() -> Array:
 var names: Array = []
 for value in Library.base().get("professions", []):
  names.append(str(value))
 for value in host.profile.custom_parameters.get("professions", []):
  var own := str(value)
  if own not in names:
   names.append(own)
 return names

func showcase() -> Array:
 var available := profession_names()
 var picks: Array = []
 for name in ["Врач", "Пожарный", "Инженер-механик", "Повар", "Диджей", "Кузнец"]:
  if name in available:
   picks.append(name)
 for name in available:
  if picks.size() >= 6:
   break
  if name not in picks:
   picks.append(name)
 return picks

func filters() -> Array:
 var entries: Array = [{"id": "", "title": "Все группы", "names": profession_names()}]
 var known := {}
 for group in Art.GROUPS:
  var names: Array = []
  for name in profession_names():
   if name in Art.GROUPS[group]:
    names.append(name)
    known[name] = true
  if not names.is_empty():
   entries.append({"id": str(group), "title": str(GROUP_TITLES.get(group, group)), "names": names})
 var own: Array = []
 for name in profession_names():
  if not known.has(name):
   own.append(name)
 if not own.is_empty():
  entries.append({"id": "own", "title": "Свои профессии", "names": own})
 return entries

func show_professions() -> void:
 ensure_deck()
 host.page = "library_professions"
 host.clear()
 host.column.columns = 2
 host.column.page_height = 440.0
 var entries := filters()
 var index := 0
 for i in entries.size():
  if str(entries[i]["id"]) == group_filter:
   index = i
 if index == 0:
  group_filter = ""
 var names: Array = entries[index]["names"]
 if names.is_empty():
  index = 0
  group_filter = ""
  names = entries[0]["names"]
 text("ПРОФЕССИИ • " + str(profession_names().size()), 25)
 var filter := Choice.new()
 for entry in entries:
  filter.add_item(str(entry["title"]) + " • " + str(entry["names"].size()))
 filter.select(index)
 filter.item_selected.connect(func(value):
  group_filter = "" if value == 0 else str(entries[value]["id"])
  show_professions())
 host.column.add_card(filter)
 for name in names:
  var tile = Tile.new()
  tile.setup(str(name))
  tile.pressed.connect(show_profession.bind(str(name)))
  host.column.add_card(tile)
 host.button("← Библиотека", show_home)

func show_profession(name: String) -> void:
 ensure_deck()
 host.page = "library_profession"
 host.clear()
 host.column.columns = 2
 host.column.page_height = 440.0
 var look := Art.style(name)
 var ratio := AspectRatioContainer.new()
 ratio.ratio = 2.0 / 3.0
 ratio.custom_minimum_size.y = 356
 var portrait = Portrait.new()
 portrait.set_profession(name)
 ratio.add_child(portrait)
 host.column.add_card(ratio)
 var info := VBoxContainer.new()
 info.add_theme_constant_override("separation", 8)
 info.size_flags_vertical = Control.SIZE_EXPAND_FILL
 var title := Label.new()
 title.text = name
 title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title.add_theme_font_size_override("font_size", 22)
 title.add_theme_color_override("font_color", Color("edf1e8"))
 info.add_child(title)
 var tag := Label.new()
 tag.text = str(look["tag"])
 tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 tag.add_theme_font_size_override("font_size", 12)
 tag.add_theme_color_override("font_color", look["accent"])
 info.add_child(tag)
 var group := Label.new()
 group.text = "Группа: " + str(GROUP_TITLES.get(str(look["group"]), str(look["group"])))
 group.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 group.add_theme_font_size_override("font_size", 14)
 group.add_theme_color_override("font_color", Color("b6c8c9"))
 info.add_child(group)
 var hint := Label.new()
 hint.text = "Это оборотная сторона карточки персонажа в партии. Портрет 768 × 1152 без лица: снаряжение говорит о профессии само."
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 hint.add_theme_font_size_override("font_size", 13)
 hint.add_theme_color_override("font_color", Color("8ea6ab"))
 info.add_child(hint)
 var frame := PanelContainer.new()
 frame.add_theme_stylebox_override("panel", Style.panel())
 frame.custom_minimum_size.y = 200
 frame.add_child(info)
 host.column.add_card(frame)
 host.button("← К списку", show_professions)
 host.button("← Библиотека", show_home)

func show_list() -> void:
 ensure_deck()
 host.page = "library"
 host.clear()
 host.column.columns = 2
 host.column.page_height = 480.0
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
 host.button("← Библиотека", show_home)

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
