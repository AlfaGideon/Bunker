extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 var skin := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--skin="):
   skin = arg.trim_prefix("--skin=")
 if not skin.is_empty():
  welcome.profile.appearance = skin
  welcome.update_avatar()
  welcome.edit_profile()
 if OS.get_cmdline_user_args().has("--update"):
  var update = preload("res://game/scripts/app_updates.gd").show_updates(welcome, false)
  var next: int = preload("res://game/scripts/app_updates.gd").VERSION_CODE + 1
  update.show_result({"code": next, "apk_url": "https://github.com/AlfaGideon/Bunker/releases/download/android-%d/Bunker-Posledniy-Shlyuz-%d.apk" % [next, next], "sha256": "a".repeat(64), "size": 64000000})
 if OS.get_cmdline_user_args().has("--female"):
  welcome.profile.appearance = "female"
  welcome.profile.outfit = 1
  welcome.draft_name = "Мира"
  welcome.update_avatar()
  welcome.home()
 if OS.get_cmdline_user_args().has("--profile"):
  welcome.edit_profile()
 if OS.get_cmdline_user_args().has("--settings"):
  welcome.settings()
 if OS.get_cmdline_user_args().has("--library") or OS.get_cmdline_user_args().has("--library-form") or OS.get_cmdline_user_args().has("--library-professions"):
  welcome.settings()
  welcome.open_library()
  if OS.get_cmdline_user_args().has("--library-form"):
   welcome.library_editor.key = "health"
   welcome.library_editor.show_form(-1)
  if OS.get_cmdline_user_args().has("--library-professions"):
   welcome.library_editor.show_professions()
 for frame in 25:
  await process_frame
 await create_timer(0.9).timeout
 if OS.get_cmdline_user_args().has("--library-form") or OS.get_cmdline_user_args().has("--library-professions"):
  for page in welcome.column.pages.size():
   welcome.column.page_index = page
   welcome.column.rebuild()
   for frame in 4:
    await process_frame
   if welcome.column.navigation.get_global_rect().end.y > root.get_visible_rect().size.y:
    print("::error::Library navigation clipped on page " + str(page))
    quit(1)
    return
  welcome.column.page_index = 0
  welcome.column.rebuild()
  for frame in 4:
   await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.resize(800, roundi(image.get_height() * 800.0 / image.get_width()))
 var bytes := image.save_jpg_to_buffer(0.6)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.3)
 if bytes.size() > 22000:
  bytes = image.save_jpg_to_buffer(0.15)
 DirAccess.make_dir_recursive_absolute("res://builds")
 var file := FileAccess.open("res://builds/scene.jpg", FileAccess.WRITE)
 file.store_buffer(bytes)
 var encoded := Marshalls.raw_to_base64(bytes)
 var prefix := "WELCOMEAVATARSHOT" if OS.get_cmdline_user_args().has("--female") else "MENUSHOT"
 if OS.get_cmdline_user_args().has("--profile"):
  prefix = "CARDPROFILESHOT"
 if OS.get_cmdline_user_args().has("--settings"):
  prefix = "CARDSETTINGSHOT"
 if OS.get_cmdline_user_args().has("--update"):
  prefix = "UPDATESHOT"
 if OS.get_cmdline_user_args().has("--library"):
  prefix = "LIBRARYSHOT"
 if OS.get_cmdline_user_args().has("--library-form"):
  prefix = "LIBFORMHOTSHOT"
 if OS.get_cmdline_user_args().has("--library-professions"):
  prefix = "LIBPROFSHOT"
 if OS.get_cmdline_user_args().has("--camp-radio"):
  prefix = "CAMPRADIOSHOT"
 if not skin.is_empty():
  prefix = "SKIN" + skin.replace("_", "").to_upper() + "SHOT"
 for index in ceili(encoded.length() / 3500.0):
  print("::notice::" + prefix + "_%02d:" % index + encoded.substr(index * 3500, 3500))
 quit()
