extends Control
const Choice = preload("res://game/scripts/card_choice.gd")
const Deck = preload("res://game/scripts/card_deck.gd")
const Cards = preload("res://game/scripts/card_style.gd")
const Rules = preload("res://game/scripts/survival_rules.gd")
var column: Deck
var room: Node3D
var face_label: Label
var result_label: Label
var roll_button: Button
var continue_button: Button
var mode: Choice
var prediction: Choice
var number_grid: GridContainer
var choice_label: Label
var number_buttons: Array[Button] = []
var chosen: Array = [1, 2, 3]
var sides := 6
var outcome: Dictionary = {}

func setup(game: Node3D) -> void:
 room = game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade := ColorRect.new()
 shade.color = Color(0.015, 0.04, 0.075, 0.85)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(center)
 var panel := PanelContainer.new()
 panel.custom_minimum_size = Vector2(980, 650)
 center.add_child(panel)
 var margin := MarginContainer.new()
 for edge in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + edge, 20)
 panel.add_child(margin)
 var shell := VBoxContainer.new()
 shell.add_theme_constant_override("separation", 10)
 margin.add_child(shell)
 column = Deck.new()
 column.page_height = 400
 shell.add_child(column)
 var footer := HBoxContainer.new()
 footer.add_theme_constant_override("separation", 10)
 shell.add_child(footer)
 column.add_card(room._label("ВЫ ПОКИНУЛИ БУНКЕР", 28))
 column.add_card(room._label(room.scenario["exile_prompt"], 18))
 column.add_card(room._label("Выберите кубик и выигрышные числа ДО броска. Везде шанс 50%: половина граней. Бросок один, прогноз после него изменить нельзя.", 17))
 mode = Choice.new()
 for label in ["d6: 1–3 или 4–6", "d6: чётное / нечётное", "d6: свои три числа", "d20: 1–10 или 11–20", "d20: свои десять чисел"]:
  mode.add_item(label)
 mode.custom_minimum_size.y = 48
 column.add_card(mode)
 mode.item_selected.connect(func(_index): configure())
 prediction = Choice.new()
 prediction.custom_minimum_size.y = 48
 column.add_card(prediction)
 prediction.item_selected.connect(func(_index): update_choice())
 choice_label = room._label("", 18)
 column.add_card(choice_label)
 number_grid = GridContainer.new()
 number_grid.columns = 5
 column.add_card(number_grid)
 face_label = room._label("?", 48)
 face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 column.add_card(face_label)
 roll_button = room._button("Бросить выбранный кубик", roll_dice, footer)
 result_label = room._label("Исход ещё не определён.", 18)
 column.add_card(result_label)
 continue_button = room._button("Продолжить наблюдателем", func():
  visible = false
  room.restore_camera(), footer)
 continue_button.disabled = true
 roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 configure()
 visible = false

func configure() -> void:
 if not outcome.is_empty():
  return
 sides = 20 if mode.selected >= 3 else 6
 prediction.clear()
 if mode.selected == 1:
  prediction.add_item("Нечётное: 1, 3, 5")
  prediction.add_item("Чётное: 2, 4, 6")
 else:
  prediction.add_item("1–3" if sides == 6 else "1–10")
  prediction.add_item("4–6" if sides == 6 else "11–20")
 column.set_card_shown(prediction, mode.selected not in [2, 4])
 chosen.clear()
 for number in range(1, sides / 2 + 1):
  chosen.append(number)
 for child in number_grid.get_children():
  number_grid.remove_child(child)
  child.queue_free()
 number_buttons.clear()
 column.set_card_shown(number_grid, mode.selected in [2, 4])
 if mode.selected in [2, 4]:
  for number in range(1, sides + 1):
   var value: int = number
   var button := Button.new()
   button.text = str(number)
   Cards.button(button, true)
   button.toggle_mode = true
   button.button_pressed = value in chosen
   button.custom_minimum_size = Vector2(70, 52)
   number_grid.add_child(button)
   number_buttons.append(button)
   button.pressed.connect(func():
    if not outcome.is_empty():
     return
    if button.button_pressed:
     chosen.append(value)
    else:
     chosen.erase(value)
    update_choice())
 update_choice()

func update_choice() -> void:
 if not outcome.is_empty():
  return
 if mode.selected not in [2, 4]:
  chosen.clear()
  for number in range(1, sides + 1):
   if (mode.selected == 1 and number % 2 == (1 if prediction.selected == 0 else 0)) or (mode.selected != 1 and (number <= sides / 2) == (prediction.selected == 0)):
    chosen.append(number)
 choice_label.text = "Ваш прогноз: %s. Нужно выбрать %d чисел." % [str(chosen), sides / 2]
 roll_button.disabled = not Rules.valid_choice(sides, chosen)

func roll_dice() -> void:
 if not outcome.is_empty() or not Rules.valid_choice(sides, chosen):
  return
 outcome = Rules.roll(null, sides, chosen)
 roll_button.disabled = true
 mode.disabled = true
 prediction.disabled = true
 for button in number_buttons:
  button.disabled = true
 var tween := create_tween()
 for index in (1 if room.profile.reduced_motion else 8):
  tween.tween_callback(func(): face_label.text = str(randi_range(1, sides)))
  tween.tween_interval(0.1)
 tween.tween_callback(show_result)

func show_result() -> void:
 face_label.text = str(outcome["face"])
 result_label.text = ("ВЫ ВЫЖИЛИ. " + room.scenario["survived_text"]) if outcome["survived"] else ("ВЫ НЕ ВЫЖИЛИ. " + room.scenario["failed_text"])
 continue_button.disabled = false
 column.show_last()
