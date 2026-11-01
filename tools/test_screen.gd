extends SceneTree
## The plasma panel: three channels, a logo splash when there is nothing to show,
## a host who runs it in a lobby, and a cinema crew that can drive it too.

const Broadcast = preload("res://game/scripts/screen_broadcast.gd")
const Rules = preload("res://game/scripts/profession_rules.gd")
const Layout = preload("res://game/scripts/bunker_layout.gd")
const Navigation = preload("res://game/scripts/room_navigation.gd")
const Art = preload("res://game/scripts/profession_art.gd")

var failures := 0


func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var professions: Array = data["professions"]

	# --- the channels -------------------------------------------------------
	var holder := Node.new()
	root.add_child(holder)
	var broadcast = Broadcast.new()
	broadcast.mount(holder)
	check(broadcast.channel == 0, "A panel with nothing to play shows the splash")
	check(not broadcast.has_content(), "The splash is not content")
	check(broadcast.caption().contains("ЗАСТАВКА"), "Splash caption names the station")
	check(str(broadcast.still.texture.resource_path).ends_with("branding/logo.png"),
		"The splash is the game logo")
	check(broadcast.next() == 1, "First tap starts the anime")
	check(broadcast.has_content(), "The anime channel is content")
	check(broadcast.caption().contains("АНИМЕ"), "Anime caption names the reel")
	check(str(broadcast.still.texture.resource_path).begins_with("res://assets/tv/"),
		"The anime channel plays the generated reel")
	var first_frame = broadcast.still.texture
	for step in 60:
		broadcast.tick(0.1)
	check(broadcast.still.texture != first_frame, "The reel cuts to the next frame")
	check(broadcast.next() == 2, "Second tap opens the ad block")
	check(broadcast.caption().contains("РЕКЛАМ"), "Ad caption names the block")
	check(str(broadcast.still.texture.resource_path).ends_with("tv/ad_slot.jpg"),
		"The ad channel shows the empty billboard")
	check(broadcast.next() == 0, "Third tap returns to the splash")
	check(broadcast.screen_material() != null and broadcast.screen_material().albedo_texture != null,
		"The glass carries the live viewport texture")

	# --- the ad slot --------------------------------------------------------
	broadcast.set_channel(2)
	var pushed: Texture2D = load("res://assets/branding/logo.png")
	broadcast.set_ad(pushed, "СУХПАЁК У ЦЕХА")
	check(broadcast.has_ad(), "A real banner can be pushed into the panel")
	check(broadcast.still.texture == pushed, "The ad block shows the pushed banner")
	check(broadcast.title.text.contains("СУХПАЁК"), "The ad block names the pushed banner")
	check(broadcast.caption().contains("СУХПАЁК"), "The camp caption follows the ad")
	broadcast.clear_ad()
	check(not broadcast.has_ad(), "The panel goes back to the empty billboard")
	check(broadcast.still.texture != pushed, "The empty billboard is back on the glass")
	broadcast.set_channel(0)

	# --- the cinema crew ----------------------------------------------------
	var cinema: Array = Rules.ROLES.get("cinema", [])
	check(cinema.size() >= 3, "A whole cinema crew can run the panel")
	for name in cinema:
		check(name in professions, "Cinema profession is part of the roster: " + name)
		check(Art.PORTRAITS.has(name), "Cinema profession has its own portrait: " + name)
		var texture: Texture2D = Art.texture_for(name)
		check(texture != null and texture.get_size().y > texture.get_size().x,
			"Cinema portrait is a real vertical card: " + name)
	var projectionist := {"cards": [{"id": "profession", "value": "Киномеханик"}]}
	var cook := {"cards": [{"id": "profession", "value": "Повар"}]}
	check(Rules.allowed(projectionist, "cinema"), "A projectionist may start the reel")
	check(not Rules.allowed(cook, "cinema"), "A cook may not start the reel")
	check(Rules.requirement("cinema").contains("Киномеханик"), "The panel says who runs it")

	# --- the parked banner in the hall --------------------------------------
	var plan: Dictionary = Layout.generate(7)
	check(plan["items"].has("cinema"), "The hall plan has a plasma panel")
	var nav := Navigation.new(plan)
	check(nav.is_walkable(plan["items"]["cinema"]["goal"]), "One can walk up to the panel")

	# --- the camp -----------------------------------------------------------
	var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
	root.add_child(welcome)
	for frame in 4:
		await process_frame
	check(is_instance_valid(welcome.screen_prop), "The camp has a plasma panel")
	check(str(welcome.screen_prop.get_meta("source", "")).ends_with("assets/blender/plasma_tv.glb"),
		"The camp panel is the modelled prop")
	check(welcome.screen_prop.position.z < -0.5, "The panel stands behind the fire and the survivor")
	check(welcome.screen_prop.position.z > -4.4, "The panel stands in front of the pines")
	check(welcome.screen_prop.position.x < 0.0, "The panel stands behind the survivor")
	# The menu card owns the right of the frame: the whole banner must stay clear.
	var banner: Rect2 = welcome.screen_rect()
	var frame := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(banner.size != Vector2.ZERO, "The panel casts a silhouette in the frame")
	check(banner.position.x > 0.0 and banner.end.x < frame.size.x,
		"The panel fits the frame width: %s in %s" % [banner, frame])
	check(banner.position.y > 0.0 and banner.end.y < frame.size.y,
		"The panel fits the frame height: %s in %s" % [banner, frame])
	check(banner.end.x < welcome.panel.get_global_rect().position.x - 8.0,
		"The whole panel is visible beside the menu card: %s vs %s" % [banner, welcome.panel.get_global_rect()])
	check(banner.size.x > frame.size.x * 0.12, "The panel reads as a big banner")
	check(welcome.screen_broadcast.channel == 0, "The camp panel idles on the logo splash")
	check(is_instance_valid(welcome.screen_caption) and welcome.screen_caption.text.contains("нажми"),
		"The camp caption explains the tap")
	check(welcome.screen_operator(), "A local camp is driven by the player")
	welcome.cycle_screen()
	check(welcome.screen_broadcast.channel == 1, "The camp can start the anime")
	check(welcome.screen_caption.text.contains("АНИМЕ"), "The camp caption follows the channel")
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(bounds.encloses(welcome.screen_hotspot.get_global_rect()), "The panel tap target fits the screen")
	check(not welcome.panel.get_global_rect().intersects(welcome.screen_hotspot.get_global_rect()),
		"The panel tap target clears the menu card")
	# A lobby belongs to its host: everyone else only watches.
	welcome.lobby_room = {"host_id": "someone-else"}
	welcome.lobby_player_id = "me"
	check(not welcome.screen_operator(), "Only the host drives the panel in a lobby")
	welcome.cycle_screen()
	check(welcome.screen_broadcast.channel == 1, "A guest cannot switch the channel")
	welcome.lobby_room = {"host_id": "me"}
	check(welcome.screen_operator(), "The host drives the panel")

	print("Screen failures: ", failures)
	welcome.queue_free()
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
