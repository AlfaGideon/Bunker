extends SceneTree
const Catalog = preload("res://game/scripts/avatar_catalog.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const Style = preload("res://game/scripts/avatar_style.gd")
var failures := 0
func check(value: bool, title: String) -> void:
 if not value:
  failures += 1
  push_error(title)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var original := Profile.new()
 var profile := Profile.new()
 var welcome = (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 welcome.edit_profile()
 check(welcome.appearance_picker.entries.size() == 6, "All six skins selectable")
 for index in Catalog.IDS.size():
  var id: String = Catalog.IDS[index]
  profile.appearance = id
  check(profile.save() == OK and Profile.new().appearance == id, "Skin persists: " + id)
  welcome.appearance_picker.select(index)
  welcome.appearance_picker.item_selected.emit(index)
  check(welcome.profile.appearance == id, "Selector changes skin: " + id)
  check(welcome.avatar.get_meta("source").ends_with(Catalog.model(id).trim_prefix("kaykit_") + ".glb"), "Expected model: " + id)
  check(welcome.animator.has_animation("Sit_Chair_Idle") and welcome.animator.has_animation("Sit_Chair_StandUp") and welcome.animator.has_animation("Running_A"), "Seated and running clips: " + id)
  if id == "female_senior":
   var heads: Array[Node] = welcome.avatar.find_children("*Rogue_Head*", "MeshInstance3D", true, false)
   check(not heads.is_empty() and heads[0].material_override != null, "Silver-haired head material applied")
 check(Catalog.biology("male", 63) == "male_senior", "Senior male biology")
 check(Catalog.biology("female", 63) == "female_senior", "Senior female biology")
 check(Catalog.biology("female", 26) == "female", "Young female biology")
 welcome.queue_free()
 await process_frame
 var room = (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for id in Catalog.IDS:
  room._change_appearance(0, id)
  var visual = room.actors[0].get_child(0)
  check(visual.skeletons.size() > 0 and visual.animation_player != null, "Game rig and animation for " + id)
  visual.animate(0.1, true, 0.0)
  check(visual.current_clip == "Walking_C", "Walking animation for " + id)
 room.players[0]["sex"] = "female"
 room.players[0]["age"] = 63
 room._reveal_card(0, room.players[0]["cards"][1])
 check(room.actors[0].get_meta("appearance") == "female_senior", "Revealed age and sex override chosen cosmetic")
 room.profile.appearance = "male_young"
 room.apply_settings()
 check(room.actors[0].get_meta("appearance") == "female_senior", "Revealed biology cannot be overwritten")
 room.queue_free()
 original.save()
 await process_frame
 print("Skin test failures: ", failures)
 quit(1 if failures else 0)
