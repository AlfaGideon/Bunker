extends Control
const Cards = preload("res://game/scripts/card_style.gd")
const Deck = preload("res://game/scripts/card_deck.gd")
var room: Node3D
var title: Label
var timer: Label
var selection: Label
var deck: Deck
var skip: Button

func setup(game: Node3D) -> void:
 room = game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade := ColorRect.new()
 shade.color = Color(0.015, 0.035, 0.045, 0.84)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(center)
 var panel := PanelContainer.new()
 panel.name = "VoteCard"
 panel.custom_minimum_size = Vector2(940, 620)
 panel.add_theme_stylebox_override("panel", Cards.panel())
 center.add_child(panel)
 var margin := MarginContainer.new()
 for side in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 20)
 panel.add_child(margin)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 8)
 margin.add_child(column)
 var header := HBoxContainer.new()
 column.add_child(header)
 title = room._label("ГОЛОСОВАНИЕ", 28)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 timer = room._label("20 сек.", 25)
 header.add_child(timer)
 var hint: Label = room._label("Выберите участника. Если пропустить или не успеть — голос за себя.", 17)
 column.add_child(hint)
 selection = room._label("", 18)
 column.add_child(selection)
 deck = Deck.new()
 deck.columns = 2
 deck.page_height = 340
 deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(deck)
 skip = Button.new()
 skip.text = "Пропустить — голос за себя"
 Cards.button(skip, true)
 skip.custom_minimum_size.y = 52
 skip.pressed.connect(func(): room.cast_vote(0))
 column.add_child(skip)
 visible = false

func open_ballot() -> void:
 visible = true
 deck.clear_cards()
 title.text = "ПОВТОРНОЕ ГОЛОСОВАНИЕ" if room.vote_second else "ГОЛОСОВАНИЕ"
 for id in room.active:
  if not room.vote_candidates.is_empty() and not room.vote_candidates.has(id):
   continue
  var target: int = id
  var button := Button.new()
  button.text = room.players[id]["name"] + (" • ВЫ" if id == 0 else "")
  Cards.button(button, true)
  button.custom_minimum_size.y = 52
  button.disabled = not room.active.has(0)
  button.pressed.connect(func(): room.cast_vote(target))
  deck.add_card(button)
 skip.disabled = not room.active.has(0)
 update_state()
 Cards.animate(self)

func update_state() -> void:
 timer.text = "%d сек." % ceili(room.vote_remaining)
 if not room.active.has(0):
  selection.text = "Вы наблюдаете. Участники — локальный тестовый сценарий."
 elif room.ballots.has(0):
  var target: int = room.ballots[0]
  selection.text = "Ваш голос: " + room.players[target]["name"] + (" (за себя)" if target == 0 else "")
 else:
  selection.text = "Голос пока не выбран • при пропуске он пойдёт за вас."
