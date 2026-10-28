extends SceneTree
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
 check(welcome.find_children("*", "ScrollContainer", true, false).is_empty(), "Welcome has no scrolling menu")
 check(welcome.cards.size() == 7, "Hero and six animated cards")
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
 loading.elapsed = 1.1
 loading.advance_cinematic()
 check(loading.animator.current_animation == "Running_A", "Authored run follows stand-up")
 var before_x: float = loading.runner.position.x
 loading.elapsed = 2.5
 loading.advance_cinematic()
 check(loading.runner.position.x > before_x and loading.runner.position.z < 0, "Runner moves across grass toward entrance")
 loading.elapsed = 4.7
 loading.advance_cinematic()
 check(loading.arrived and loading.runner.position.distance_to(loading.RUN_END) < 0.01, "Runner stops at door without looping")
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
