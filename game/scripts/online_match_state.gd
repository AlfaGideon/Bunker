extends RefCounted
## View-model for personalized authoritative snapshots. It does not own the
## transport or apply game rules; the server remains the source of truth.
signal changed

var player_id := ""
var revision := -1
var seed := 0
var scenario := {}
var players: Array = []
var active: Array[int] = []
var phase := ""
var round_number := 0
var capacity := 0
var speaker := -1
var revealed_this_turn := false
var remaining := 0.0
var candidates: Array[int] = []
var second_ballot := false
var my_vote := -1
var result := {}
var ids: Array[String] = []

func setup(id: String) -> void:
 player_id = id

func index_for(id: String) -> int:
 return ids.find(id)

func apply_snapshot(state: Dictionary) -> bool:
 var incoming_players: Variant = state.get("players")
 var new_revision: int = int(state.get("revision", -1))
 if player_id.is_empty() or not incoming_players is Array or incoming_players.is_empty() or new_revision < revision:
  return false
 if not state.get("active", []) is Array or not state.get("candidates", []) is Array or not state.get("scenario", {}) is Dictionary:
  return false
 var ordered: Array = []
 var own: Dictionary = {}
 var seen := {}
 for entry in incoming_players:
  if not entry is Dictionary or not entry.has("id") or not entry.get("cards") is Array:
   return false
  var id := str(entry.id)
  if id.is_empty() or seen.has(id):
   return false
  seen[id] = true
  if id == player_id:
   own = entry
  else:
   ordered.append(entry)
 if own.is_empty():
  return false
 ordered.push_front(own)
 var next_players: Array = []
 var next_ids: Array[String] = []
 for entry in ordered:
  var item: Dictionary = entry.duplicate(true)
  next_ids.append(str(item.id))
  for card in item.cards:
   if not card is Dictionary:
    return false
   # A UI placeholder is not a secret: hidden values never arrived over the wire.
   if not card.has("value"):
    card["value"] = "скрыто"
  next_players.append(item)
 var next_active: Array[int] = []
 for id in state.get("active", []):
  var index := next_ids.find(str(id))
  if index < 0 or next_active.has(index):
   return false
  next_active.append(index)
 var next_candidates: Array[int] = []
 for id in state.get("candidates", []):
  var index := next_ids.find(str(id))
  if index < 0 or not next_active.has(index):
   return false
  next_candidates.append(index)
 var next_phase := str(state.get("phase", ""))
 if next_phase not in ["reveal", "discussion", "vote", "result", "end"]:
  return false
 var next_speaker := next_ids.find(str(state.get("speaker", "")))
 if next_phase == "reveal" and (next_speaker < 0 or not next_active.has(next_speaker)):
  return false
 revision = new_revision
 ids = next_ids
 players = next_players
 active = next_active
 candidates = next_candidates
 phase = next_phase
 speaker = next_speaker
 seed = int(state.get("seed", 0))
 scenario = state.get("scenario", {}).duplicate(true)
 round_number = int(state.get("round", 1))
 capacity = int(state.get("capacity", 0))
 remaining = maxf(0.0, float(state.get("remaining", 0)))
 revealed_this_turn = bool(state.get("revealed_this_turn", false))
 second_ballot = bool(state.get("second_ballot", false))
 my_vote = ids.find(str(state.get("my_vote", "")))
 result = state.get("result", {}).duplicate(true) if state.get("result") is Dictionary else {}
 changed.emit()
 return true

func tick(delta: float) -> void:
 # Display-only clock. Never advance phases on the client.
 remaining = maxf(0.0, remaining - maxf(delta, 0.0))
