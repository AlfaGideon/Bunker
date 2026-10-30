extends SceneTree
const Updates = preload("res://game/scripts/app_updates.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var request := HTTPRequest.new()
 request.max_redirects = 0
 request.timeout = 20
 root.add_child(request)
 var error := request.request(Updates.LATEST, ["User-Agent: Bunker-Android", "Cache-Control: no-cache"], HTTPClient.METHOD_HEAD)
 if error != OK:
  push_error("Could not start live release check: " + str(error))
  quit(1)
  return
 var response: Array = await request.request_completed
 var info := Updates.inspect_redirect(response[1], response[2]) if response[0] in [HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED, HTTPRequest.RESULT_SUCCESS] else {}
 if info.is_empty():
  push_error("Live GitHub latest redirect failed: result=%s HTTP=%s" % [response[0], response[1]])
  quit(1)
  return
 print("Live GitHub latest redirect: Android ", info["code"])
 quit()
