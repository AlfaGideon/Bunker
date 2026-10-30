extends SceneTree
const Library = preload("res://game/scripts/parameter_library.gd")
const Profile = preload("res://game/scripts/local_profile.gd")
const Content = preload("res://game/scripts/game_content.gd")
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var original := Profile.new()
 var profile := Profile.new()
 var condition := {"label": "Тестовая болезнь", "cost": {"medicine": 2, "water": 1}}
 var custom := {"ages": ["67"], "health": [condition], "qualities": ["Заботливый тест"], "professions": ["Исследователь тест"], "skills": ["Изучает камни"], "baggage": ["Тестовый рюкзак"], "facts": ["Был на орбите"]}
 profile.custom_parameters = custom.duplicate(true)
 check(profile.save() == OK, "Library saves")
 var restored := Profile.new()
 check(restored.custom_parameters == custom, "Every category and health costs survive restart")
 var pool := Library.merged(restored.custom_parameters)
 check("67 лет" in pool.ages, "Age formatted as normal age card")
 check(condition in pool.health and pool.health.size() > 1, "Custom disease cost merges with defaults")
 for key in ["qualities", "professions", "skills", "baggage", "facts"]:
  check(custom[key][0] in pool[key], "Custom content participates: " + key)
 check(Library.clean("ages", "101") == null and Library.clean("ages", "17") == null and Library.clean("ages", "x") == null, "Age bounds and format validated")
 check(Library.clean("health", {"label": "X", "cost": {"medicine": -1}}) == null, "Reject negative health cost")
 check(Library.sanitize({"health": ["bad"], "unknown": ["bad"]}).is_empty(), "Malformed saved data ignored")
 var seen := {}
 for trial in 150:
  var players := Content.create_players(10, "Тест", "male", restored.custom_parameters)
  for player in players:
   if player.age == 67:
    seen["ages"] = true
   for card in player.cards:
    if card.get("value", "") == "Тестовая болезнь":
     check(card.cost == {"medicine": 2, "water": 1}, "Health cost used in game")
     seen["health"] = true
    if card.get("value", "") in ["Заботливый тест", "Исследователь тест", "Изучает камни", "Тестовый рюкзак", "Был на орбите"]:
     seen[card.value] = true
 check(seen.size() == 7, "Custom values actually deal into new games")
 var welcome := (load("res://game/welcome.tscn") as PackedScene).instantiate()
 root.add_child(welcome)
 welcome.settings()
 welcome.open_library()
 await process_frame
 check(welcome.page == "library" and welcome.find_children("*", "ScrollContainer", true, false).is_empty(), "Library opens in touch card deck without scrolling")
 welcome.library_editor.key = "ages"
 welcome.library_editor.show_form(-1)
 await process_frame
 check(welcome.page == "library_form" and welcome.find_children("*", "LineEdit", true, false).size() > 0, "Add form accessible")
 welcome.free()
 original.save()
 await process_frame
 print("Parameter library checks: ", failures, " failures")
 quit(1 if failures else 0)
