extends SceneTree
const Turns = preload("res://game/scripts/speech_turns.gd")
const Professions = preload("res://game/scripts/profession_rules.gd")
const Abilities = preload("res://game/scripts/special_abilities.gd")
const Dice = preload("res://game/scripts/survival_rules.gd")
const Content = preload("res://game/scripts/game_content.gd")
const Layout = preload("res://game/scripts/bunker_layout.gd")
const Nav = preload("res://game/scripts/room_navigation.gd")
var failures := 0
func check(value: bool, title: String) -> void:
 if not value:
  failures += 1
  push_error(title)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var turn := Turns.new()
 turn.start([0, 2, 3])
 check(not turn.tick(59) and turn.speaker() == 0, "Full minute available")
 check(turn.tick(1) and turn.speaker() == 2 and turn.remaining == 60, "Timeout advances exactly once")
 turn.pass_turn()
 check(turn.speaker() == 3, "Manual skip")
 turn.pass_turn()
 check(turn.finished and turn.speaker() == -1, "Round completed")
 var players := Content.create_players(6, "Тест")
 players[0]["cards"][0]["value"] = "Учитель"
 for key in ["radio", "food", "bed", "bed5"]:
  check(Professions.allowed(players[0], key), "Universal: " + key)
 for key in ["terminal", "medical", "kitchen", "supply", "gym"]:
  check(not Professions.allowed(players[0], key), "Profession blocks: " + key)
 for ability in Abilities.POOL:
  var powers := Abilities.new()
  powers.cards[0] = ability
  var result := powers.apply(0, players[0], players[1])
  check(result["ok"], "Ability works: " + ability)
  check(not powers.apply(0, players[0], players[1])["ok"], "Ability cannot repeat")
 for sides in [6, 20]:
  var chosen: Array = []
  for number in range(1, sides + 1):
   if number % 2 == 0:
    chosen.append(number)
  for face in range(1, sides + 1):
   var result := Dice.resolve_choice(face, sides, chosen)
   check(result["valid"] and result["survived"] == (face % 2 == 0), "Parity prediction")
  check(not Dice.valid_choice(sides, [1, 1, 2]), "Reject duplicate / invalid selection")
 for capacity in [3, 4, 5]:
  for seed_value in 12:
   var plan := Layout.generate(seed_value, capacity)
   check(plan["beds"].size() == capacity, "One bed per place")
   var nav := Nav.new(plan)
   var start := nav.nearest_walkable(Vector3.ZERO)
   check(not nav.is_walkable(plan["items"]["supply"]["goal"]), "Warehouse geometry locked")
   nav.unlock_warehouse()
   check(not nav.path_between(start, plan["items"]["supply"]["goal"]).is_empty(), "Warehouse reachable when opened")
 var room := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(room)
 room.set_physics_process(false)
 room.menu.visible = false
 room.players[0]["cards"][0]["value"] = "Учитель"
 check(not room.request_interaction("terminal"), "UI cannot bypass profession")
 check(room.med_cover.mesh == null and not room.med_cover.visible, "No black medical roof")
 check(not room.warehouse_open, "Council can leave warehouse sealed")
 for voter in room.active.slice(0, room.active.size() / 2):
  room.vote_warehouse(voter, true)
 check(not room.warehouse_open, "Tie cannot open warehouse")
 room.vote_warehouse(room.active[-1], true)
 check(room.warehouse_open, "Strict majority opens warehouse")
 room.players[1]["cards"][0]["value"] = "Повар"
 var meals_before: int = room.meals
 check(room.request_interaction("kitchen", 1), "Delegate job to qualified participant")
 for tick in 1600:
  room._physics_process(1.0 / 60)
 check(room.meals > meals_before, "Cook actually routes and prepares meals")
 check(room.request_interaction("food"), "Everyone can eat")
 for tick in 1600:
  room._physics_process(1.0 / 60)
 check(room.used_actions.get("food_0", 0) == room.round_number, "Food consumed through interaction")
 room.started = true
 room.phase = "reveal"
 room.speech.start(room.active)
 room._physics_process(60)
 check(room.speech.speaker() == room.active[1], "Integrated timed turn")
 room.survival_panel.mode.select(4)
 room.survival_panel.configure()
 room.survival_panel.number_buttons[0].button_pressed = false
 room.survival_panel.number_buttons[0].pressed.emit()
 check(room.survival_panel.roll_button.disabled, "Custom selection requires exactly half the faces")
 room.survival_panel.roll_dice()
 check(room.survival_panel.outcome.is_empty(), "Invalid custom prediction cannot roll")
 room.survival_panel.number_buttons[19].button_pressed = true
 room.survival_panel.number_buttons[19].pressed.emit()
 check(20 in room.survival_panel.chosen and 1 not in room.survival_panel.chosen, "Number callbacks use their actual face")
 room.survival_panel.roll_dice()
 check(room.survival_panel.outcome["sides"] == 20, "Selected d20 used by UI")
 var old: Dictionary = room.survival_panel.outcome.duplicate(true)
 room.survival_panel.configure()
 room.survival_panel.roll_dice()
 check(room.survival_panel.outcome == old, "Prediction and outcome immutable after roll")
 room.free()
 await process_frame
 print("Iteration 7 failures: ", failures)
 quit(1 if failures else 0)
