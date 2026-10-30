extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for frame in 4:
  await process_frame
 check(room.log_label.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Whole HUD fits screen, including message footer")
 check(room.table_card.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Table card never leaves the screen")
 check(room.turn_panel.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Turn panel never leaves the screen")
 check(room.find_children("*", "ScrollContainer", true, false).is_empty(), "No menu scrollers in game, dice or HUD")
 check(room.find_children("*", "OptionButton", true, false).is_empty(), "No scrolling native selector popups")
 for method in ["home", "new_game", "show_profile", "settings", "instructions", "briefing", "show_facility", "show_council", "show_negative_actions"]:
  room.menu.call(method)
  for frame in 3:
   await process_frame
  var deck: Control = room.menu.column
  check(not deck.pages.is_empty(), "Card pages exist: " + method)
  for page in deck.pages.size():
   deck.page_index = page
   deck.rebuild()
   for frame in 2:
    await process_frame
   check(deck.navigation.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Navigation reachable without scrolling: " + method)
   for node in deck.pages[page]:
    check(node.visible, "All cards accessible on selected page")
 room.menu.visible = false
 var dice: Control = room.survival_panel
 dice.visible = true
 dice.mode.select(4)
 dice.configure()
 for frame in 4:
  await process_frame
 dice.column.rebuild()
 dice.column.page_index = 0
 dice.column.rebuild()
 check(dice.number_grid.visible, "All d20 choices are accessible on the initial wager page")
 dice.column.page_index = dice.column.pages.size() - 1
 dice.column.rebuild()
 check(not dice.number_grid.visible, "Test also exercises an off-page number grid")
 dice.chosen.erase(1)
 dice.update_choice()
 check(dice.chosen.size() == 9 and dice.roll_button.disabled, "Dice validation uses selected mode, not off-page visibility")
 dice.chosen.append(1)
 dice.update_choice()
 check(not dice.roll_button.disabled, "A valid d20 wager remains valid across pages")
 dice.visible = false
 room.menu.visible = false
 room.phase = "reveal"
 room.speech.start(room.active)
 room.speech.remaining = 37.25
 room._refresh()
 # Reveal locks live on the full character card now, not in a side panel.
 room.open_character_card(0)
 for frame in 3:
  await process_frame
 var biology: Dictionary
 for card in room.players[0]["cards"]:
  if card["id"] == "biology":
   biology = card
 check(room.card_value_for(0, biology, 1) == "скрыто", "Other viewer cannot see closed parameter")
 var red: Button
 for node in room.find_children("*", "Button", true, false):
  if node.has_meta("parameter_lock") and node.parameter_id == "biology":
   red = node
 check(is_instance_valid(red) and not red.is_public and not red.disabled, "Small red lock opens own parameter in own speech")
 check(red.custom_minimum_size == Vector2(52, 52), "Reveal is a small lock, not a full-width button")
 red.pressed.emit()
 check(biology["revealed"], "Real lock click publishes parameter")
 check(room.card_value_for(0, biology, 1) == biology["value"], "Other viewer sees opened parameter")
 check(room.speech.remaining == 37.25, "Opening a parameter neither resets nor extends timer")
 room.speech.tick(1.25)
 check(room.speech.remaining == 36, "Remaining speech continues normally")
 check(not room.reveal_parameter("quality"), "Cannot reveal a second parameter in the same speech")
 var green := false
 for node in room.find_children("*", "Button", true, false):
  if node.has_meta("parameter_lock") and node.parameter_id == "biology":
   green = node.is_public and node.disabled
 check(green, "Published parameter has permanent green open lock")
 room.speech.pass_turn()
 room.speech.remaining = 29
 check(not room.reveal_parameter("quality") and room.speech.remaining == 29, "Another speaker's turn cannot reveal or change timer")
 room.speech.index = 0
 room.phase = "discussion"
 check(not room.reveal_parameter("quality"), "No reveal outside reveal phase")
 room.character_card.close()
 room.free()
 await process_frame
 print("Card menu and parameter lock failures: ", failures)
 quit(1 if failures else 0)
