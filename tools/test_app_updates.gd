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
 var release := {"tag_name": "android-14", "assets": [{"name": "bunker-14.apk", "size": 1000, "browser_download_url": Updates.REPOSITORY + "/releases/download/android-14/bunker-14.apk", "digest": "sha256:" + "a".repeat(64)}]}
 check(Updates.inspect_release(release, 13)["code"] == 14, "Canonical newer release accepted")
 check(Updates.inspect_release(release, 14).get("current", false), "Same version is not reinstalled")
 check(Updates.inspect_release(release, 15).get("current", false), "No downgrade")
 var bad: Dictionary = release.duplicate(true)
 bad["assets"][0]["browser_download_url"] = "https://evil.example/bunker-14.apk"
 check(Updates.inspect_release(bad, 13).is_empty(), "Foreign APK host rejected")
 bad = release.duplicate(true)
 bad["tag_name"] = "android-014"
 check(Updates.inspect_release(bad, 13).is_empty(), "Noncanonical version rejected")
 bad = release.duplicate(true)
 bad["assets"][0]["size"] = "1000"
 check(Updates.inspect_release(bad, 13).is_empty(), "Malformed metadata rejected")
 for field in ["draft", "prerelease"]:
  bad = release.duplicate(true)
  bad[field] = true
  check(Updates.inspect_release(bad, 13).is_empty(), "Unpublished/preview release rejected")
 for invalid in [{}, {"tag_name": "v0.14"}, {"tag_name": "android--1"}, {"tag_name": "android-14", "assets": {}}, {"tag_name": "android-14", "assets": []}]:
  check(Updates.inspect_release(invalid, 13).is_empty(), "Missing or unsafe release rejected")
 var branded := release.duplicate(true)
 branded["assets"].append({"name": "Bunker-Posledniy-Shlyuz-14.apk", "size": 1000, "browser_download_url": Updates.REPOSITORY + "/releases/download/android-14/Bunker-Posledniy-Shlyuz-14.apk", "digest": "sha256:" + "b".repeat(64)})
 check(Updates.inspect_release(branded, 13)["apk_url"] == Updates.REPOSITORY + "/releases/download/android-14/Bunker-Posledniy-Shlyuz-14.apk", "Only official APK selected")
 var canonical := Updates.REPOSITORY + "/releases/tag/android-16"
 var headers := PackedStringArray(["location: " + canonical])
 check(Updates.inspect_redirect(302, headers, 15).get("code") == 16, "Public redirect detects newer release without API")
 check(Updates.inspect_redirect(302, headers, 16).get("current", false), "Public redirect detects current version")
 check(Updates.inspect_redirect(302, headers, 17).get("current", false), "Public redirect never offers downgrade")
 for invalid_url in ["https://evil.example/releases/tag/android-16", Updates.REPOSITORY + "/releases/tag/android-016", canonical + "?evil=1", Updates.REPOSITORY + "/releases/tag/android--1", Updates.REPOSITORY + ".evil.example/releases/tag/android-16"]:
  check(Updates.inspect_redirect(302, PackedStringArray(["Location: " + invalid_url]), 15).is_empty(), "Foreign or malformed redirect rejected")
 check(Updates.inspect_redirect(200, headers, 15).is_empty(), "Non-redirect rejected")
 check(Updates.inspect_redirect(302, PackedStringArray(["Location: " + canonical, "Location: https://evil.example"]), 15).is_empty(), "Ambiguous locations rejected")
 var dialog := Updates.show_updates(root, false)
 await process_frame
 await process_frame
 await process_frame
 check(dialog.visible and dialog.action.disabled, "Update screen begins with release button blocked")
 var panel: Control = dialog.find_child("UpdateCard", true, false)
 var footer: Control = dialog.find_child("Actions", true, false)
 check(panel != null and footer != null, "Custom card and action row exist")
 check(dialog.action.size.x >= 180 and dialog.action.size.y >= 48 and dialog.action.size.x > dialog.action.size.y * 2, "Release button is horizontal and touch-sized")
 check(dialog.retry.size.x >= 180 and dialog.retry.size.y >= 48 and dialog.retry.size.x > dialog.retry.size.y * 2, "Retry button is horizontal and touch-sized")
 check(footer.get_global_rect().end.y <= panel.get_global_rect().end.y, "Actions fit within card")
 var future := Updates.VERSION_CODE + 1
 var hash := "a".repeat(64)
 var apk := Updates.REPOSITORY + "/releases/download/android-%d/Bunker-Posledniy-Shlyuz-%d.apk" % [future, future]
 var offer := {"code": future, "apk_url": apk, "sha256": hash, "size": 100}
 dialog.show_result(offer)
 check(not dialog.action.disabled and dialog.state == "available" and dialog.offer.apk_url == apk, "Verified offer enables in-app download")
 check(not Updates.valid_apk({"code": future, "apk_url": "https://evil.test/file.apk", "sha256": hash}), "Reject foreign APK")
 var checksums := hash + "  Bunker-Posledniy-Shlyuz-%d.apk\n" % future
 check(Updates.inspect_checksums(future, checksums).get("apk_url", "") == apk, "Checksums fallback selects canonical file")
 check(Updates.inspect_checksums(future, checksums + checksums).is_empty(), "Reject duplicate checksum entries")
 var path := "user://update-verification-test.apk"
 var f := FileAccess.open(path, FileAccess.WRITE)
 f.store_string("integrity test")
 f.close()
 var real_hash := FileAccess.get_sha256(path)
 check(Updates.verified_file(path, real_hash, 14), "Valid downloaded bytes pass verification")
 check(not Updates.verified_file(path, hash, 14), "Tampered file fails checksum")
 check(not Updates.verified_file(path, real_hash, 15), "Truncated file fails expected size")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 dialog.show_result(Updates.inspect_redirect(302, headers, 16))
 check(dialog.headline.text == "У вас актуальная версия", "Current release is clearly identified")
 dialog.show_error()
 check(not dialog.retry.disabled and dialog.latest.text == "Не удалось проверить", "Connection failure gives retry")
 dialog.dismiss()
 await process_frame
 check(not is_instance_valid(dialog), "Closing popup frees request, card and layer")
 print("App update failures: ", failures)
 quit(1 if failures else 0)
