extends RefCounted

const VERSION_CODE := 16
const VERSION_NAME := "0.16.0"
const REPOSITORY := "https://github.com/AlfaGideon/Bunker"
const LATEST := REPOSITORY + "/releases/latest"
const API := "https://api.github.com/repos/AlfaGideon/Bunker/releases/latest"

# Accept only numeric, canonical Android release tags from our own public repo.
static func release_code(tag: String) -> int:
 if not tag.begins_with("android-"):
  return 0
 var number := tag.trim_prefix("android-")
 if not number.is_valid_int() or number != str(number.to_int()):
  return 0
 var code := number.to_int()
 return code if code > 0 else 0

# GitHub's public latest-release redirect is independent of the unauthenticated
# API's strict shared-IP rate limit. Never follow an untrusted Location.
static func inspect_redirect(status: int, headers: PackedStringArray, installed: int = VERSION_CODE) -> Dictionary:
 if status != 301 and status != 302:
  return {}
 var location := ""
 for header in headers:
  if header.to_lower().begins_with("location:"):
   if not location.is_empty():
    return {}
   location = header.substr(header.find(":") + 1).strip_edges()
 var prefix := REPOSITORY + "/releases/tag/"
 if not location.begins_with(prefix):
  return {}
 var code := release_code(location.trim_prefix(prefix))
 if code == 0:
  return {}
 return {"code": code, "current": code <= installed, "url": location}

# Optional API fallback: only trust published releases and exact canonical assets.
static func inspect_release(release: Dictionary, installed: int = VERSION_CODE) -> Dictionary:
 if release.get("draft", false) or release.get("prerelease", false):
  return {}
 var tag := str(release.get("tag_name", ""))
 var code := release_code(tag)
 if code == 0:
  return {}
 if code <= installed:
  return {"current": true, "code": code}
 var assets: Variant = release.get("assets", [])
 if not assets is Array:
  return {}
 for filename in ["Bunker-Posledniy-Shlyuz-%d.apk" % code, "bunker-%d.apk" % code]:
  var expected: String = REPOSITORY + "/releases/download/" + tag + "/" + filename
  for asset in assets:
   if not asset is Dictionary:
    continue
   var asset_size: Variant = asset.get("size", 0)
   if not (asset_size is int or asset_size is float):
    continue
   if asset.get("name", "") == filename and asset.get("browser_download_url", "") == expected and asset_size > 0:
    return {"code": code, "url": REPOSITORY + "/releases/tag/" + tag}
 return {}

static func show_updates(parent: Node, check_network: bool = true) -> Control:
 var layer := CanvasLayer.new()
 layer.layer = 100
 parent.add_child(layer)
 var dialog: Control = load("res://game/scripts/update_panel.gd").new()
 layer.add_child(dialog)
 dialog.setup(check_network)
 return dialog
