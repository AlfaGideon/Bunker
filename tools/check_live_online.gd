extends SceneTree
## End-to-end test against a local aiohttp server, using the real HTTPS-polling
## transport implementation (HTTP is allowed only in this test harness).
const Client = preload("res://game/scripts/lobby_client.gd")
const Session = preload("res://game/scripts/online_session.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func wait_event(events: Array, kind: String, seconds := 15.0) -> Dictionary:
 var until := Time.get_ticks_msec() + int(seconds * 1000)
 while Time.get_ticks_msec() < until:
  for index in events.size():
   if events[index].get("type") == kind:
    return events.pop_at(index)
  await create_timer(0.05).timeout
 push_error("Timed out waiting for " + kind)
 failures += 1
 return {}
func wait_revision(session: Node, revision: int, seconds := 15.0) -> bool:
 var until := Time.get_ticks_msec() + int(seconds * 1000)
 while Time.get_ticks_msec() < until:
  if session.state.revision >= revision:
   return true
  await create_timer(0.05).timeout
 push_error("Timed out waiting for state revision %d" % revision)
 failures += 1
 return false
func new_client(events: Array, initial: Dictionary) -> Node:
 var node := Client.new()
 root.add_child(node)
 node.event_received.connect(func(item): events.append(item))
 node.http_mode = true
 node.http_root = "http://127.0.0.1:8080"
 node.pending = initial
 node.connecting = true
 node._http_call("open", {})
 return node
func run() -> void:
 var host_events: Array = []
 var guest_events: Array = []
 var host := new_client(host_events, {"type":"create", "name":"Host", "title":"Room", "capacity":6, "skin":"male"})
 var joined: Dictionary = await wait_event(host_events, "joined")
 if joined.is_empty(): quit(1); return
 var room_id: String = joined.room.id
 var host_id: String = joined.player_id
 var guest := new_client(guest_events, {"type":"join", "room_id":room_id, "name":"Guest", "skin":"female"})
 var guest_joined: Dictionary = await wait_event(guest_events, "joined")
 if guest_joined.is_empty(): quit(1); return
 for i in 4:
  host.send({"type":"add_bot"})
 var full := false
 for i in 8:
  var event: Dictionary = await wait_event(host_events, "room")
  if event.is_empty(): quit(1); return
  if int(event.room.count) == 6:
   full = true
   break
 check(full, "Full room reached")
 host.send({"type":"online_start"})
 if (await wait_event(host_events, "online_game_start")).is_empty(): quit(1); return
 if (await wait_event(guest_events, "online_game_start")).is_empty(): quit(1); return
 var hs := Session.new()
 var gs := Session.new()
 root.add_child(hs)
 root.add_child(gs)
 hs.adopt(host, host_id)
 gs.adopt(guest, str(guest_joined.player_id))
 hs.request_state()
 gs.request_state()
 if not await wait_revision(hs, 1) or not await wait_revision(gs, 1): quit(1); return
 check(hs.state.seed == gs.state.seed and hs.state.scenario == gs.state.scenario, "Same world and catastrophe")
 var hidden := ""
 for card in hs.state.players[0].cards:
  if not card.revealed:
   hidden = card.id
   break
 var guest_view: Dictionary = gs.state.players[gs.state.index_for(host_id)]
 for card in guest_view.cards:
  if card.id == hidden:
   check(card.value == "скрыто", "Other player's secret not transmitted")
 set_meta("online_session", hs)
 set_meta("start_game", true)
 var first := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(first)
 first.set_physics_process(false)
 set_meta("online_session", gs)
 set_meta("start_game", true)
 var second := (load("res://game/main.tscn") as PackedScene).instantiate()
 root.add_child(second)
 second.set_physics_process(false)
 check(first.reveal_parameter(hidden), "Host sends reveal from actual bunker scene")
 if not await wait_revision(gs, 2): quit(1); return
 var found := false
 for card in second.players[gs.state.index_for(host_id)].cards:
  if card.id == hidden:
   found = card.revealed and card.value != "скрыто"
 check(found, "Guest scene receives revealed characteristic")
 first.pass_speech()
 if not await wait_revision(gs, 3): quit(1); return
 check(second.speech.speaker() == 0, "Guest receives their turn")
 check(second.players[0].id == str(guest_joined.player_id) and first.players[0].id == host_id, "Local player mapping")
 first.queue_free()
 second.queue_free()
 await process_frame
 print("Live online scene failures: ", failures)
 quit(1 if failures else 0)
