extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 for id in room.active:
  room.players[id]["cards"][0]["value"] = "Учитель"
 room.players[1]["cards"][0]["value"] = "Врач"
 room._open_medical(1)
 check(not room.medical_open, "Doctor cannot open during first round")
 room.round_number = 2
 room._open_medical(0)
 check(not room.medical_open, "Non-doctor cannot open")
 room._open_medical(1)
 check(room.medical_open and room.navigation.is_walkable(room.layout["items"]["medical"]["goal"]), "Doctor opens after first round")
 room.actors[2].position = room.layout["items"]["medical"]["goal"]
 room._eliminate(1)
 check(not room.medical_open and not room.navigation.is_walkable(room.layout["items"]["medical"]["goal"]), "Excluding last doctor closes room")
 check(room.navigation.is_walkable(room.actors[2].position), "Occupant returned to accessible hall")
 room.free()
 await process_frame
 print("Medical doctor checks: ", failures, " failures")
 quit(1 if failures else 0)
