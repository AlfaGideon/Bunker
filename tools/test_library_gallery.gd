extends SceneTree
## The main-menu library is two blocks: a picture catalogue of professions and
## the editable parameter lists. This checks both are real pages in the touch
## deck, that every profession has a picture, and that nothing is clipped.
const Art = preload("res://game/scripts/profession_art.gd")
const GalleryTile = preload("res://game/scripts/profession_gallery_card.gd")
const Portrait = preload("res://game/scripts/profession_art_view.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func press_card(welcome: Node, prefix: String) -> void:
	for item in welcome.column.card_nodes:
		if item is Button and item.text.begins_with(prefix):
			item.pressed.emit()
			return
	check(false, "Button found: " + prefix)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
	root.add_child(welcome)
	await process_frame
	welcome.settings()
	welcome.open_library()
	for frame in 4:
		await process_frame
	check(welcome.page == "library", "Library hub opens from the main menu")
	check(welcome.find_children("*", "ScrollContainer", true, false).is_empty(), "Library still uses the touch deck, no scrolling")
	var has_professions := false
	var has_parameters := false
	var strip: HBoxContainer = null
	for item in welcome.column.card_nodes:
		if item is Button:
			if item.text.begins_with("ПРОФЕССИИ"):
				has_professions = true
			if item.text.begins_with("ПАРАМЕТРЫ"):
				has_parameters = true
		if item is HBoxContainer and not item.has_meta("touch_choice") and item.custom_minimum_size.y >= 120:
			strip = item
	check(has_professions, "Profession block is offered on the library hub")
	check(has_parameters, "Parameter block is offered on the library hub")
	check(strip != null and strip.get_child_count() >= 4, "Hub shows a strip of profession pictures")
	if strip != null:
		var textured := 0
		for child in strip.get_children():
			if child is TextureRect and child.texture != null:
				textured += 1
		check(textured == strip.get_child_count(), "Every hub thumbnail has a real portrait")
	press_card(welcome, "ПРОФЕССИИ")
	for frame in 4:
		await process_frame
	check(welcome.page == "library_professions", "Profession catalogue is its own page")
	var expected: Array = welcome.library_editor.profession_names()
	var tiles: Array = []
	var filter: Node = null
	for item in welcome.column.card_nodes:
		if item is GalleryTile:
			tiles.append(item)
		if item is HBoxContainer and item.has_meta("touch_choice"):
			filter = item
	check(tiles.size() == expected.size(), "Catalogue lists every profession: %d of %d" % [tiles.size(), expected.size()])
	var missing: Array = []
	for tile in tiles:
		if Art.texture_for(str(tile.profession)) == null:
			missing.append(str(tile.profession))
	check(missing.is_empty(), "Every catalogue entry has a picture: " + ", ".join(missing))
	check(filter != null and filter.entries.size() >= Art.GROUPS.size() + 1, "Group filter covers all sixteen groups")
	var pages: int = maxi(1, welcome.column.pages.size())
	for index in pages:
		welcome.column.page_index = index
		welcome.column.rebuild()
		for frame in 2:
			await process_frame
		check(welcome.column.navigation.get_global_rect().end.y <= root.get_visible_rect().size.y + 1.0, "Catalogue navigation stays on screen")
	welcome.column.page_index = 0
	welcome.column.rebuild()
	for frame in 3:
		await process_frame
	var target := str(expected[0])
	press_card(welcome, "← Библиотека")
	for frame in 3:
		await process_frame
	check(welcome.page == "library", "Catalogue returns to the library hub")
	welcome.library_editor.show_profession(target)
	for frame in 4:
		await process_frame
	check(welcome.page == "library_profession", "Profession opens a large portrait page")
	var portraits: Array = []
	for node in welcome.find_children("*", "Control", true, false):
		if node is Portrait:
			portraits.append(node)
	check(portraits.size() == 1 and str(portraits[0].profession) == target, "Large page draws the chosen profession")
	check(welcome.column.navigation.get_global_rect().end.y <= root.get_visible_rect().size.y + 1.0, "Portrait page navigation stays on screen")
	press_card(welcome, "← К списку")
	for frame in 3:
		await process_frame
	check(welcome.page == "library_professions", "Portrait page returns to the catalogue")
	welcome.library_editor.show_list()
	for frame in 3:
		await process_frame
	check(welcome.page == "library", "Parameter block is still reachable")
	var parameter_titles: Array = []
	for item in welcome.column.card_nodes:
		if item is Button:
			parameter_titles.append(item.text)
	check("Добавить своё значение" in parameter_titles, "Parameter editing controls are unchanged")
	press_card(welcome, "← Библиотека")
	for frame in 3:
		await process_frame
	check(welcome.page == "library", "Parameters return to the library hub")
	welcome.free()
	await process_frame
	print("Library gallery checks: ", failures, " failures")
	quit(1 if failures else 0)
