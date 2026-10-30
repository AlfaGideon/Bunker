extends SceneTree
## The character card must open on tap, flip, navigate the whole roster and
## keep every parameter on one screen with stage-correct masking.

const Art = preload("res://game/scripts/profession_art.gd")
const CardScript = preload("res://game/scripts/character_card.gd")
const Library = preload("res://game/scripts/parameter_library.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func first_hidden(player: Dictionary) -> Dictionary:
	for card in player["cards"]:
		if not card["revealed"]:
			return card
	return {}


func tile_state(card: Control, parameter_id: String) -> String:
	for tile in card.tiles:
		if tile.parameter_id == parameter_id:
			return tile.state
	return ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var room := (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	for frame in 5:
		await process_frame
	var card: Control = room.character_card
	check(is_instance_valid(card), "Character card is created with the HUD")
	check(not card.visible, "Character card starts hidden")
	check(card.find_children("*", "ScrollContainer", true, false).is_empty(), "Card never scrolls")
	check(CardScript.CARD_SIZE.y > CardScript.CARD_SIZE.x, "Card uses a vertical playing-card shape")
	check(CardScript.CARD_SIZE.y / CardScript.CARD_SIZE.x > 1.25, "Card is clearly portrait, not square")
	var content: Dictionary = Library.base()
	for profession in content["professions"]:
		var art: Texture2D = Art.texture_for(str(profession))
		check(art != null, "Generated profession art is present: " + str(profession))
		if art != null:
			check(art.get_size().y > art.get_size().x, "Profession art is portrait: " + str(profession))
	for profession in Art.PORTRAITS:
		var path: String = "res://assets/professions/" + str(Art.PORTRAITS[profession]) + ".jpg"
		check(ResourceLoader.exists(path), "Individual portrait exists: " + path)
	check(Art.texture_for("Врач") != Art.texture_for("Медсестра"), "Professions inside a group use their own portraits")
	room.menu.visible = false
	room.phase = "reveal"
	room.speech.start(room.active)
	room.open_character_card(0)
	for frame in 4:
		await process_frame
	check(card.visible, "Tapping a survivor opens the card")
	check(card.index == 0, "Card opens on the requested survivor")
	check(card.front.visible and not card.back.visible, "Card opens face-up with parameters")
	check(card.tiles.size() == 6, "Six non-profession parameters share the face")
	check(card.grid.get_child_count() == 6, "All six tiles are mounted in one grid")
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(viewport.encloses(card.card_root.get_global_rect()), "Whole card fits the screen")
	check(card.grid.get_global_rect().end.y <= card.card_root.get_global_rect().end.y, "Parameter grid stays inside the card")
	for tile in card.tiles:
		check(tile.is_visible_in_tree(), "Every parameter is visible without paging")
		check(card.card_root.get_global_rect().end.y >= tile.get_global_rect().end.y, "Parameter tile fits inside the card")
		check(card.card_root.get_global_rect().end.x >= tile.get_global_rect().end.x, "Parameter tile fits the card width")
	# Face-down side.
	card.set_side(true, false)
	check(card.back.visible and not card.front.visible, "Flip shows the profession illustration")
	check(card.flip_button.text == "Параметры", "Flip button names the hidden side")
	card.set_side(false, false)
	check(card.front.visible, "Flip returns to parameters")
	# Own closed parameters are visible to the owner only.
	var own_hidden := first_hidden(room.players[0])
	check(not own_hidden.is_empty(), "Local survivor has a closed parameter")
	check(card.can_view(0, own_hidden), "Owner sees own closed parameter")
	check(card.state_for(0, own_hidden) == "own", "Owner card marks a private parameter")
	check(tile_state(card, str(own_hidden["id"])) == "own", "Private parameter renders in the private style")
	# Another survivor's closed parameter stays masked.
	var other := 1
	var other_hidden := first_hidden(room.players[other])
	card.show_for(other, false)
	check(card.index == other, "Card switches to another survivor")
	check(not card.can_view(other, other_hidden), "Closed foreign parameter is not readable")
	check(card.visible_value(other, other_hidden) == "••••", "Closed foreign value is masked")
	check(tile_state(card, str(other_hidden["id"])) == "hidden", "Closed foreign parameter renders as hidden")
	# Publication opens it on the card immediately.
	room._reveal_card(other, other_hidden)
	card.refresh()
	check(card.can_view(other, other_hidden), "Published parameter becomes readable")
	check(card.state_for(other, other_hidden) == "open", "Published parameter switches to the open style")
	check(tile_state(card, str(other_hidden["id"])) == "open", "Open tile is rendered after refresh")
	check(card.visible_value(other, other_hidden) == str(other_hidden["value"]), "Open value is shown on the card")
	# End of the party reveals the whole dossier.
	room.phase = "end"
	card.refresh()
	var still_hidden := first_hidden(room.players[other])
	if not still_hidden.is_empty():
		check(card.can_view(other, still_hidden), "Final screen reveals every parameter")
		check(tile_state(card, str(still_hidden["id"])) == "open", "Final screen has no locked tiles")
	# Owner can publish straight from the card.
	room.phase = "reveal"
	room.speech.start(room.active)
	room.speech.index = 0
	room.speech.revealed = false
	card.show_for(0, false)
	var publish := first_hidden(room.players[0])
	card.reveal_requested.emit(str(publish["id"]))
	check(publish["revealed"], "Reveal lock on the card publishes the parameter")
	check(tile_state(card, str(publish["id"])) == "open", "Card updates itself after publishing")
	# Side roster stays in sync while leafing.
	card.step(1)
	check(card.index == 1 and room.selected == 1, "Card arrows move through the roster")
	check(room.roster.selected == 1, "Side roster follows card navigation")
	card.step(-1)
	check(card.index == 0, "Card navigation wraps backwards")
	# Survivors are selectable directly in the 3D scene.
	var screen = room.camera.unproject_position(room.actors[0].global_position + Vector3(0, 0.85, 0))
	check(room._actor_at_screen(screen) == 0, "Screen tap resolves the survivor under the finger")
	check(room._actor_at_screen(Vector2(-400, -400)) == -1, "Empty floor does not select a survivor")
	card.close()
	check(not card.visible, "Card closes back to the bunker")
	room.free()
	await process_frame
	print("Character card failures: ", failures)
	quit(1 if failures else 0)
