extends SceneTree
## The in-game right-hand menu is gone. One playing card follows the survivor
## you tap, the speaker's card is lit, and only a compact turn panel with the
## three-line menu button stays in the bottom-left corner.
const TableCard = preload("res://game/scripts/table_card.gd")
const TurnPanel = preload("res://game/scripts/turn_panel.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room := (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	for frame in 5:
		await process_frame
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var card: Control = room.table_card
	check(is_instance_valid(card), "The table card is part of the HUD")
	check(card is TableCard, "The right side is a playing card, not a menu")
	check(absf(card.size.x - TableCard.CARD_SIZE.x) < 2.0 and absf(card.size.y - TableCard.CARD_SIZE.y) < 2.0, "Card keeps the vertical playing-card size")
	check(TableCard.CARD_SIZE.y / TableCard.CARD_SIZE.x > 1.25, "Card is portrait, not square")
	check(screen.encloses(card.get_global_rect()), "The card fits the screen")
	check(card.get_global_rect().position.x > screen.size.x * 0.5, "The card sits on the right")
	check(card.showing_back, "The card starts on the profession side")
	# No old side menu: no roster selector and no dossier pager in the HUD.
	check(room.find_children("*", "ScrollContainer", true, false).is_empty(), "HUD still never scrolls")
	var choices: Array = []
	for node in room.ui_root.find_children("*", "HBoxContainer", true, false):
		if node.has_meta("touch_choice"):
			choices.append(node)
	check(choices.is_empty(), "The old roster selector is gone from the HUD")
	# The speaker's card is the one on the table.
	room.phase = "reveal"
	room.speech.start(room.active)
	room.speech.index = 1
	room._begin_speaker()
	for frame in 4:
		await process_frame
	check(room.selected == 1, "The card follows the current speaker")
	check(card.index == 1, "Card shows the speaker")
	check(card.showing_back, "Speaker card shows the profession first")
	check(card.is_speaker(), "The speaker card is lit")
	check(card.badge.visible, "Lit card carries the speaking badge")
	# Tapping another survivor only swaps the card.
	room.select_player(2)
	for frame in 3:
		await process_frame
	check(card.index == 2 and room.selected == 2, "Tapping a survivor switches the card")
	check(not card.is_speaker(), "A non-speaker card is not lit")
	check(not card.badge.visible, "No speaking badge on another survivor")
	# The card flips in place to parameters.
	card.set_side(false, false)
	check(not card.showing_back and card.front.visible and not card.back.visible, "Flip shows parameters on the card")
	check(card.rows.size() == 6, "Six parameters fit the card without scrolling")
	for row in card.rows:
		check(row["value"].text.length() > 0, "Every parameter row is filled")
		check(screen.encloses(row["value"].get_global_rect()), "Parameter row stays on screen")
	var hidden := false
	for row in card.rows:
		if row["value"].text == "••••":
			hidden = true
	check(hidden, "Foreign closed parameters stay masked on the card")
	card.set_side(true, false)
	check(card.showing_back, "Flip returns to the profession portrait")
	# Expand still reaches the full dossier with reveal locks.
	card.expand_requested.emit()
	for frame in 4:
		await process_frame
	check(room.character_card.visible and room.character_card.index == 2, "Expand opens the full dossier for the same survivor")
	room.character_card.close()
	for frame in 2:
		await process_frame
	# Compact turn panel with the three-line menu button in the bottom-left.
	var panel: Control = room.turn_panel
	check(is_instance_valid(panel) and panel is TurnPanel, "Turn panel replaces the tall right menu")
	check(screen.encloses(panel.get_global_rect()), "Turn panel fits the screen")
	check(panel.get_global_rect().position.x < 60.0, "Turn panel hugs the left edge")
	check(panel.get_global_rect().end.y > screen.size.y - 60.0, "Turn panel hugs the bottom edge")
	var menu: Button = room.menu_button
	check(is_instance_valid(menu) and menu.text == "☰", "Only the three-line menu button remains")
	check(menu.size.x <= 70.0, "Menu button stays compact")
	var menu_box := menu.get_global_rect()
	check(menu_box.position.x < 100.0 and menu_box.end.y > screen.size.y - 100.0, "Menu button moved to the bottom-left corner")
	menu.pressed.emit()
	for frame in 3:
		await process_frame
	check(room.menu.visible, "Three lines open the party menu")
	room.menu.visible = false
	# The turn panel keeps gameplay reachable: abilities, pass, next stage.
	check(panel.ability_buttons.size() == 2, "Both special abilities stay one tap away")
	check(panel.action_button.visible and panel.action_button.text.contains("Передать ход"), "Pass turn stays in the panel")
	check(panel.timer_label.text.length() > 0, "Speech timer is shown in the panel")
	room.phase = "result"
	panel.refresh()
	check(panel.action_button.text.contains("Следующий"), "The panel turns into the next-round action")
	room.phase = "reveal"
	room.speech.start(room.active)
	panel.refresh()
	# Message footer still fits above the bottom edge.
	check(room.log_label.get_global_rect().end.y <= screen.size.y + 1.0, "Message footer fits the screen")
	# The lit card follows the speaker again after a round change.
	room.speech.index = 0
	room._begin_speaker()
	for frame in 3:
		await process_frame
	check(card.index == 0 and card.is_speaker(), "New speaker relights the card")
	room.free()
	await process_frame
	print("Table card checks: ", failures, " failures")
	quit(1 if failures else 0)
