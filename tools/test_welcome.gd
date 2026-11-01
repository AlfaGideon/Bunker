extends SceneTree
const Music = preload("res://game/scripts/music_library.gd")
var failures := 0
func check(value: bool, title: String) -> void:
 if not value:
  failures += 1
  push_error(title)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var original := preload("res://game/scripts/local_profile.gd").new()
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 for frame in 4:
  await process_frame
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/welcome.tscn", "App launches welcome, not bunker")
 check(welcome.page == "home", "Welcome home visible")
 check(is_instance_valid(welcome.radio_prop), "A radio stands in the camp")
 check(is_instance_valid(welcome.campfire_prop) and str(welcome.campfire_prop.get_meta("source", "")).ends_with("assets/blender/campfire.glb"), "Camp fire pit is a modelled prop")
 var radio_source := ""
 for child in welcome.radio_prop.get_children():
  radio_source = str(child.get_meta("source", radio_source))
 check(radio_source.ends_with("assets/blender/radio.glb"), "Camp receiver is a modelled prop")
 check(is_instance_valid(welcome.radio_music) and welcome.radio_music.playing, "Camp radio is playing music")
 check(welcome.radio_music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Camp music loops")
 check(welcome.radio_music.stream.get_length() >= 20.0, "Camp music is a real piece, not a blip")
 var first_stream = welcome.radio_music.stream
 var first_track: int = welcome.radio_track
 check(welcome.radio_caption.text.begins_with("РАДИО · "), "Caption names the current record")
 check(welcome.radio_caption.text.contains("сменить"), "Caption explains the tap")
 check(not welcome.radio_caption.text.to_upper().contains("БУНКЕР"), "Camp radio has no bunker chatter")
 check(welcome.radio_hotspot.size.x > 120.0 and welcome.radio_hotspot.size.y > 40.0, "Radio has a sizeable tap target")
 check(welcome.radio_hotspot.get_global_rect().position.x < root.get_visible_rect().size.x * 0.5, "Tap target sits over the camp, not the menu")
 var screen_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
 check(screen_rect.encloses(welcome.radio_hotspot.get_global_rect()), "Radio tap target fits the screen")
 check(screen_rect.encloses(welcome.radio_caption.get_global_rect()), "Radio caption fits the screen")
 check(not welcome.panel.get_global_rect().intersects(welcome.radio_hotspot.get_global_rect()), "Radio does not sit under the menu card")
 welcome.cycle_track()
 check(welcome.radio_track != first_track, "Tapping the camp radio switches the record")
 check(welcome.radio_music.stream != first_stream and welcome.radio_music.playing, "Another record starts playing")
 check(welcome.radio_caption.text.contains(Music.title(welcome.radio_track)), "Caption follows the record")
 for step in 3:
  welcome.cycle_track()
 check(welcome.radio_track == first_track, "Four records cycle back to the first one")
 check(welcome.find_children("*", "ScrollContainer", true, false).is_empty(), "Welcome has no scrolling menu")
 check(welcome.cards.size() == 10, "Hero, lobby controls and seven animated cards")
 for card in welcome.cards:
  check(card.get_global_rect().end.y <= root.get_visible_rect().size.y, "All cards fit vertically")
 welcome.edit_profile()
 check(is_instance_valid(welcome.name_input) and welcome.page == "profile", "Profile editable on separate page")
 for method in ["edit_profile", "game_options", "settings", "instructions"]:
  welcome.call(method)
  for frame in 3:
   await process_frame
  check(welcome.find_children("*", "ScrollContainer", true, false).is_empty(), "No scrolling in welcome subsection " + method)
  check(welcome.find_children("*", "OptionButton", true, false).is_empty(), "No scrollable selector popups in " + method)
  for page in welcome.column.pages.size():
   welcome.column.page_index = page
   welcome.column.rebuild()
   for frame in 2:
    await process_frame
   check(welcome.column.navigation.get_global_rect().end.y <= root.get_visible_rect().size.y, "Welcome card pagination fits " + method)
 welcome.home()
 check(not welcome.has_node("BunkerPrototype"), "No game generated behind welcome")
 check(welcome.profile.world_count == original.world_count, "Welcome does not generate a world")
 check(welcome.animator.current_animation == "Sit_Chair_Idle", "Real seated animation")
 var camp: Node3D = welcome.camp_assets
 check(camp.trees.size() == 13, "Imported pine forest instead of stacked cones")
 for tree in camp.trees:
  check("nature_pack_PineTree_" in tree.get_meta("source"), "Licensed pine mesh")
 check("survival_pack_Bonfire_Fire" in camp.fire_model.get_meta("source"), "Imported bonfire model")
 var animated_fire := false
 for mesh in camp.fire_model.find_children("*", "MeshInstance3D", true, false):
  for surface in mesh.mesh.get_surface_count():
   if mesh.get_surface_override_material(surface) == camp.fire_material:
    animated_fire = true
 check(animated_fire, "Flame shader actually attached to imported fire surface")
 var wind_time: float = camp.wind_materials[0].get_shader_parameter("wind_time")
 var tree_root: Transform3D = camp.trees[0].transform
 camp._process(0.5)
 check(camp.wind_materials[0].get_shader_parameter("wind_time") > wind_time, "Wind shader advances")
 check(camp.trees[0].transform == tree_root, "Tree root remains anchored")
 camp.reduced_motion = true
 camp._process(0.1)
 check(camp.wind_materials[0].get_shader_parameter("wind_strength") == 0.0, "Reduced-motion disables wind")
 check(not camp.embers.emitting and not camp.smoke.emitting, "Reduced-motion disables particles")
 camp.reduced_motion = false
 var time_before: float = welcome.animator.current_animation_position
 welcome._process(0.2)
 check(welcome.animator.current_animation_position != time_before, "Avatar animated before game")
 var old_avatar: Node3D = welcome.avatar
 welcome.profile.appearance = "female" if welcome.profile.appearance == "male" else "male"
 welcome.update_avatar()
 check(welcome.avatar != old_avatar, "Appearance changes preview immediately")
 check(welcome.animator.current_animation == "Sit_Chair_Idle", "Appearance keeps seated animation")
 welcome.draft_name = "   "
 check(not welcome.save_draft(), "Reject empty nickname")
 welcome.draft_name = "У костра"
 welcome.profile.outfit = 2
 welcome.profile.reduced_motion = false
 check(welcome.save_draft(), "Save configured welcome profile")
 var saved := preload("res://game/scripts/local_profile.gd").new()
 check(saved.nickname == "У костра" and saved.outfit == 2, "Nickname and outfit persist")
 welcome.game_options()
 check(welcome.page == "options", "Game settings reachable without a game")
 welcome.settings()
 check(welcome.page == "settings", "Settings reachable without a game")
 welcome.home()
 current_scene = welcome
 welcome.launch()
 await scene_changed
 var loading: Node3D = current_scene
 check(loading.scene_file_path == "res://game/loading.tscn", "Start opens real preparation screen")
 check(loading.animator.current_animation == "Sit_Chair_StandUp", "Character stands from the original stump")
 check(loading.camp.camp_assets.trees.size() == 13, "Preparation reuses forest and camp")
 check(loading.runner == loading.camp.avatar, "Actual seated avatar makes the journey")
 check(loading.runner.position.distance_to(loading.RUN_START) < 0.01, "Character starts on the stump")
 # Reduced effects must not teleport the character, including after a slow frame.
 loading.profile.reduced_motion = true
 var prior_elapsed: float = loading.elapsed
 loading._process(20.0)
 check(loading.elapsed - prior_elapsed <= 0.101 and not loading.arrived, "Slow load and reduced effects cannot skip the journey")
 loading.profile.reduced_motion = false
 loading.elapsed = 1.1
 loading.advance_cinematic()
 check(loading.animator.current_animation == "Running_A", "Authored run follows stand-up")
 var before_x: float = loading.runner.position.x
 var before_fire_x: float = loading.camp.camera.unproject_position(loading.camp.camp_assets.fire_model.global_position).x
 var tree: Node3D = loading.forest_extension.get_child(0)
 var before_tree_x: float = loading.camp.camera.unproject_position(tree.global_position).x
 var start_vault_x: float = loading.camp.camera.unproject_position(loading.vault.global_position).x
 check(start_vault_x > root.get_visible_rect().size.x, "Vault starts off the right side")
 check(loading.vault.get_node("CircularBlastDoor") != null, "Dedicated circular vault door")
 for old_door in loading.camp.entrance_nodes:
  check(not old_door.visible, "Rectangular game entrance hidden in cinematic")
 loading.elapsed = 2.5
 loading.advance_cinematic()
 check(loading.runner.position.x > before_x and is_equal_approx(loading.runner.position.z, 0.0), "Runner moves right across grass")
 check(loading.camp.camera.unproject_position(loading.camp.camp_assets.fire_model.global_position).x < before_fire_x, "Campfire moves left on screen")
 check(loading.camp.camera.unproject_position(tree.global_position).x < before_tree_x, "Forest moves left opposite the runner")
 check(loading.forest_extension.get_child_count() >= 100, "Forest and grass extend along route")
 loading.elapsed = 6.9
 loading.advance_cinematic()
 check(loading.arrived and loading.runner.position.distance_to(loading.RUN_END) < 0.01, "Runner stops at door without looping")
 var end_vault_x: float = loading.camp.camera.unproject_position(loading.vault.global_position).x
 check(end_vault_x > 0 and end_vault_x < root.get_visible_rect().size.x, "Vault enters and remains in view")
 check(loading.profile.nickname == "У костра", "Loading preserves nickname")
 loading.cancel_loading()
 await scene_changed
 welcome = current_scene
 check(welcome.profile.world_count == saved.world_count, "Cancel does not generate a bunker")
 welcome.launch()
 await scene_changed
 check(current_scene.scene_file_path == "res://game/loading.tscn", "Can start after cancellation")
 await scene_changed
 var room: Node3D = current_scene
 check(room.scene_file_path == "res://game/main.tscn", "Start opens bunker scene")
 check(room.started and room.menu.page == "briefing", "Start begins exactly one party and opens briefing")
 check(room.players[0]["name"] == "У костра" and room.profile.outfit == 2, "Configured profile transferred to game")
 check(not root.has_node("WelcomeCamp"), "Camp unloaded after start")
 original.save()
 room.queue_free()
 await process_frame
 print("Welcome failures: ", failures)
 quit(1 if failures else 0)
