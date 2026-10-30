extends SceneTree
# Exercise Godot's actual streaming download and GitHub's asset redirects.
const Updates = preload("res://game/scripts/app_updates.gd")
const URL := "https://github.com/AlfaGideon/Bunker/releases/download/android-24/bunker-24.apk"
const HASH := "564d4d747894439f575b1cc6f6dbd0a95aeb37e58822279fb30cc742e6beb57d"
const SIZE := 65853493
const PATH := "user://updater-transport-test.part"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var request := HTTPRequest.new()
 request.max_redirects = 5
 request.timeout = 180
 request.body_size_limit = 200 * 1024 * 1024
 request.download_file = PATH
 root.add_child(request)
 var error := request.request(URL, ["User-Agent: Bunker-Android"])
 if error != OK:
  push_error("Unable to start updater transport test: " + str(error))
  quit(1)
  return
 var response: Array = await request.request_completed
 var valid: bool = response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and Updates.verified_file(PATH, HASH, SIZE)
 if FileAccess.file_exists(PATH):
  DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
 if not valid:
  push_error("APK transport/integrity failed: result=%s HTTP=%s" % [response[0], response[1]])
  quit(1)
  return
 print("Real release APK downloaded and SHA-256 verified without opening a browser")
 quit()
