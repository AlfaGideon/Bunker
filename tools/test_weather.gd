extends SceneTree
const Ground = preload("res://game/scripts/exterior_ground.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for seed_value in [0, 3, 17]:
  set_meta("world_seed", seed_value)
  var room := (load("res://game/main.tscn") as PackedScene).instantiate()
  room.profile.scenario_choice = "infection"
  root.add_child(room)
  room.weather.set_process(false)
  check(room.weather.walkers.size() == 8, "Eight infected only in outbreak")
  var before: Vector3 = room.weather.walkers[0].position
  for tick in 400:
   room.weather._process(0.5)
   for actor in room.weather.walkers:
    check(not Ground.covered(room.layout, Vector2(actor.position.x, actor.position.z)), "Patrol never enters bunker")
  check(before.distance_to(room.weather.walkers[0].position) > 1.0, "Infected traverse perimeter")
  check(room.weather.walkers[2].get_child(0).rotation.x < 0.0, "Infected have a hunched stance")
  var stopped: Vector3 = room.weather.walkers[0].position
  room.weather.set_reduced_motion(true)
  room.weather._process(3)
  check(room.weather.walkers[0].position == stopped, "Reduced motion freezes patrol")
  room.free()
  await process_frame
 var flood := (load("res://game/main.tscn") as PackedScene).instantiate()
 flood.profile.scenario_choice = "great_flood"
 root.add_child(flood)
 check(flood.weather.walkers.is_empty(), "No infected in flood")
 check(flood.weather.water.material_override is ShaderMaterial, "Flood uses water shader")
 flood.weather.set_reduced_motion(true)
 check(flood.weather.water.material_override.get_shader_parameter("still"), "Water respects reduced motion")
 flood.free()
 await process_frame
 print("Weather checks: ", failures, " failures")
 quit(1 if failures else 0)
