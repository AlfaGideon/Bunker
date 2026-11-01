extends RefCounted

const VERSION_CODE := 51
const VERSION_NAME := "0.51.0"
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
    var digest: Variant = asset.get("digest", "")
    if not digest is String or not digest.begins_with("sha256:") or not valid_sha256(digest.trim_prefix("sha256:")):
     return {}
    return {"code": code, "url": REPOSITORY + "/releases/tag/" + tag, "apk_url": expected, "sha256": digest.trim_prefix("sha256:").to_lower(), "size": int(asset_size)}
 return {}

# SHA256SUMS fallback when the public API rate-limits the visitor.
static func valid_sha256(value: String) -> bool:
 if value.length() != 64:
  return false
 for c in value.to_lower():
  if c not in "0123456789abcdef":
   return false
 return true

static func inspect_checksums(code: int, data: String, installed: int = VERSION_CODE) -> Dictionary:
 if code <= installed or code <= 0 or data.length() > 16384:
  return {}
 var filenames := ["Bunker-Posledniy-Shlyuz-%d.apk" % code, "bunker-%d.apk" % code]
 for filename in filenames:
  var matches: Array[String] = []
  for line in data.split("\n", false):
   var bits := line.strip_edges().split(" ", false)
   if bits.size() == 2 and bits[1].trim_prefix("*") == filename and valid_sha256(bits[0]):
    matches.append(bits[0].to_lower())
  if matches.size() == 1:
   return {"code": code, "apk_url": REPOSITORY + "/releases/download/android-%d/" % code + filename, "sha256": matches[0], "size": 0}
 return {}

static func valid_apk(info: Dictionary) -> bool:
 var code := int(info.get("code", 0))
 if code <= VERSION_CODE or not valid_sha256(str(info.get("sha256", ""))):
  return false
 var root := REPOSITORY + "/releases/download/android-%d/" % code
 return info.get("apk_url", "") in [root + "Bunker-Posledniy-Shlyuz-%d.apk" % code, root + "bunker-%d.apk" % code]

static func verified_file(path: String, sha256: String, size: int = 0) -> bool:
 if not valid_sha256(sha256) or not FileAccess.file_exists(path):
  return false
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null or file.get_length() <= 0 or file.get_length() > 200 * 1024 * 1024:
  return false
 if size > 0 and file.get_length() != size:
  return false
 file.close()
 return FileAccess.get_sha256(path).to_lower() == sha256.to_lower()

static func show_updates(parent: Node, check_network: bool = true) -> Control:
 var layer := CanvasLayer.new()
 layer.layer = 100
 parent.add_child(layer)
 var dialog: Control = load("res://game/scripts/update_panel.gd").new()
 layer.add_child(dialog)
 dialog.setup(check_network)
 return dialog
