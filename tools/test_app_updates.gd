extends SceneTree
const Updates = preload("res://game/scripts/app_updates.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var release := {"tag_name": "android-14", "assets": [{"name": "bunker-14.apk", "size": 1000, "browser_download_url": Updates.REPOSITORY + "/releases/download/android-14/bunker-14.apk"}]}
 check(Updates.inspect_release(release)["code"] == 14, "Canonical newer release accepted")
 check(Updates.inspect_release(release, 14).get("current", false), "Same version is not reinstalled")
 check(Updates.inspect_release(release, 15).get("current", false), "No downgrade")
 var bad: Dictionary = release.duplicate(true)
 bad["assets"][0]["browser_download_url"] = "https://evil.example/bunker-14.apk"
 check(Updates.inspect_release(bad).is_empty(), "Foreign APK host rejected")
 bad = release.duplicate(true)
 bad["tag_name"] = "android-014"
 check(Updates.inspect_release(bad).is_empty(), "Noncanonical version rejected")
 bad = release.duplicate(true)
 bad["assets"][0]["size"] = "1000"
 check(Updates.inspect_release(bad).is_empty(), "Malformed metadata rejected")
 for field in ["draft", "prerelease"]:
  bad = release.duplicate(true)
  bad[field] = true
  check(Updates.inspect_release(bad).is_empty(), "Unpublished/preview release rejected")
 for invalid in [{}, {"tag_name": "v0.14"}, {"tag_name": "android--1"}, {"tag_name": "android-14", "assets": {}}, {"tag_name": "android-14", "assets": []}]:
  check(Updates.inspect_release(invalid).is_empty(), "Missing or unsafe release rejected")
 var dialog := Updates.show_updates(root, false)
 check(dialog.visible and dialog.get_ok_button().disabled, "Real update popup starts with download blocked")
 check(dialog.get_cancel_button().text == "Закрыть", "Offline check can be dismissed")
 dialog.canceled.emit()
 await process_frame
 check(not is_instance_valid(dialog), "Closing popup frees request and dialog")
 print("App update failures: ", failures)
 quit(1 if failures else 0)
