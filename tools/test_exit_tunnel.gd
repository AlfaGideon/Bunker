extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 await process_frame
 check(is_instance_valid(room.entrance_hatch), "Entry hatch exists")
 check(room.entrance_hatch.position.distance_to(Vector3(3.8, 0, 5.0)) < 0.01, "Hatch at hall entrance")
 var solid := false
 for child in room.entrance_hatch.get_children():
  if child is MeshInstance3D and child.mesh is BoxMesh:
   var size: Vector3 = child.mesh.size
   solid = size.x >= 1.45 and size.y >= 2.1 and size.z >= 0.1
 check(solid, "Entry hatch has an opaque full-height backing")
 var exit_index: int = room.active[1]
 room.menu.visible = false
 room._eliminate(exit_index)
 await create_timer(0.8).timeout
 check(room.entrance_hatch.position.y < -2.0, "Entry door opens during expulsion")
 check(room.exit_hatch.position.y < -1.8, "Exterior door opens during expulsion")
 for i in 600:
  room._physics_process(1.0 / 30.0)
 check(not room.actors[exit_index].visible, "Departing actor reaches exterior")
 await create_timer(0.8).timeout
 check(absf(room.entrance_hatch.position.y) < 0.02, "Entry door closes after expulsion")
 print("Exit tunnel failures: ", failures)
 room.queue_free()
 await process_frame
 quit(1 if failures else 0)
