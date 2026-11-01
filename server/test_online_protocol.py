import asyncio
import time
import unittest
from aiohttp.test_utils import TestClient, TestServer
from app import create_app, LOBBY_KEY


class ProtocolTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.app = create_app()
        self.client = TestClient(TestServer(self.app))
        await self.client.start_server()
        self.headers = []

    async def asyncTearDown(self):
        await self.client.close()

    async def open(self):
        response = await self.client.post('/transport/open', json={})
        h = {'X-Lobby-Session': (await response.json())['session']}
        self.headers.append(h)
        return h

    async def send(self, h, message):
        response = await self.client.post('/transport/send', headers=h, json=message)
        self.assertEqual(response.status, 200)
        return (await response.json())['events']

    async def poll(self, h):
        return (await (await self.client.post('/transport/poll', headers=h, json={})).json())['events']

    async def test_six_clients_privacy_commands_and_disconnect(self):
        headers = [await self.open() for _ in range(6)]
        events = await self.send(headers[0], {'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6})
        joined = next(e for e in events if e['type'] == 'joined')
        room_id = joined['room']['id']
        ids = [joined['player_id']]
        for index, h in enumerate(headers[1:]):
            events = await self.send(h, {'type': 'join', 'room_id': room_id, 'name': f'Player {index}'})
            ids.append(next(e['player_id'] for e in events if e['type'] == 'joined'))
        self.assertEqual((await self.send(headers[1], {'type': 'online_start'}))[-1]['code'], 'host_only')
        events = await self.send(headers[0], {'type': 'online_start'})
        host = next(e['state'] for e in events if e['type'] == 'game_state')
        views = [host]
        for h in headers[1:]:
            events = await self.poll(h)
            self.assertTrue(any(e['type'] == 'online_game_start' for e in events))
            views.append(next(e['state'] for e in events if e['type'] == 'game_state'))
        self.assertEqual({view['seed'] for view in views}, {host['seed']})
        self.assertEqual({view['speaker'] for view in views}, {ids[0]})
        hidden = next(c for c in host['players'][0]['cards'] if not c['revealed'])
        self.assertIn('value', hidden)
        self.assertNotIn('value', next(c for c in views[1]['players'][0]['cards'] if c['id'] == hidden['id']))
        error = await self.send(headers[1], {'type': 'game_action', 'action': 'pass'})
        self.assertEqual(error[-1]['code'], 'not_your_turn')
        await self.send(headers[0], {'type': 'game_action', 'action': 'reveal', 'value': hidden['id']})
        state = next(e['state'] for e in await self.poll(headers[1]) if e['type'] == 'game_state')
        public_card = next(c for c in state['players'][0]['cards'] if c['id'] == hidden['id'])
        self.assertEqual(public_card['value'], hidden['value'])
        await self.send(headers[0], {'type': 'game_action', 'action': 'pass'})
        state = next(e['state'] for e in await self.poll(headers[1]) if e['type'] == 'game_state')
        self.assertEqual(state['speaker'], ids[1])
        # Timer expiry is authoritative and observed by every client.
        game = self.app[LOBBY_KEY].rooms[room_id].game
        game.deadline = time.monotonic() - 1
        await self.send(headers[2], {'type': 'game_sync'})
        states = [e['state'] for e in await self.poll(headers[0]) if e['type'] == 'game_state']
        self.assertEqual(states[-1]['speaker'], ids[2])
        # Drive the rest of the speeches and discussion by server deadlines.
        while game.phase != 'vote':
            game.deadline = time.monotonic() - 0.01
            await self.send(headers[0], {'type': 'game_sync'})
        for h in headers:
            await self.poll(h)
        for h in headers[:4]:
            await self.send(h, {'type': 'game_action', 'action': 'vote', 'value': ids[5]})
        view = next(e['state'] for e in reversed(await self.poll(headers[4])) if e['type'] == 'game_state')
        self.assertNotIn('votes', view)
        self.assertIsNone(view['my_vote'])
        game.deadline = time.monotonic() - 0.01
        await self.send(headers[0], {'type': 'game_sync'})
        views = []
        for h in headers[1:]:
            views.append(next(e['state'] for e in reversed(await self.poll(h)) if e['type'] == 'game_state'))
        self.assertTrue(all(view['phase'] == 'result' for view in views))
        self.assertTrue(all(view['result']['player'] == ids[5] for view in views))
        self.assertTrue(all(ids[5] not in view['active'] for view in views))
        # A guest dropping mid-match no longer destroys the game for everyone.
        await self.client.post('/transport/close', headers=headers[1], json={})
        events = await self.poll(headers[0])
        self.assertNotIn('room_closed', [e['type'] for e in events])
        away = next(e for e in events if e['type'] == 'player_away')
        self.assertEqual(away['player_id'], ids[1])
        self.assertIn(room_id, self.app[LOBBY_KEY].rooms)
        room = self.app[LOBBY_KEY].rooms[room_id]
        seats = {p['id']: p['away'] for p in room.public()['players']}
        self.assertTrue(seats[ids[1]])
        self.assertFalse(seats[ids[0]])
        # The abandoned seat carries on in the match view for the rest.
        view = next(e['state'] for e in reversed(events) if e['type'] == 'game_state')
        self.assertTrue(next(p for p in view['players'] if p['id'] == ids[1])['away'])
        self.assertFalse(next(p for p in view['players'] if p['id'] == ids[0])['away'])
        # The host leaving still ends the room for everybody.
        await self.client.post('/transport/close', headers=headers[0], json={})
        events = await self.poll(headers[2])
        self.assertEqual(next(e for e in events if e['type'] == 'room_closed')['reason'], 'host_left')
        self.assertNotIn(room_id, self.app[LOBBY_KEY].rooms)

    async def test_station_actions_broadcast_to_other_players(self):
        headers = [await self.open() for _ in range(6)]
        created = await self.send(headers[0], {'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6})
        joined = next(e for e in created if e['type'] == 'joined')
        room_id, player_id = joined['room']['id'], joined['player_id']
        for i, h in enumerate(headers[1:]):
            await self.send(h, {'type': 'join', 'room_id': room_id, 'name': f'P{i}'})
        await self.send(headers[0], {'type': 'online_start'})
        for h in headers[1:]:
            await self.poll(h)
        await self.send(headers[0], {'type': 'game_action', 'action': 'food'})
        other = next(e['state'] for e in await self.poll(headers[1]) if e['type'] == 'game_state')
        self.assertEqual(other['stations']['meals'], 2)
        self.assertEqual(other['stations']['stamina'][player_id], 70)
        rejected = await self.send(headers[0], {'type': 'game_action', 'action': 'food'})
        self.assertEqual(rejected[-1]['code'], 'already_ate')
        await self.send(headers[1], {'type': 'game_action', 'action': 'radio_tune', 'value': 'bunkers'})
        other = next(e['state'] for e in await self.poll(headers[0]) if e['type'] == 'game_state')
        self.assertEqual(other['stations']['radio']['station'], 'bunkers')

    async def test_kitchen_updates_all_sessions_and_rejects_wrong_role(self):
        headers = [await self.open() for _ in range(6)]
        joined = next(e for e in await self.send(headers[0], {'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6}) if e['type'] == 'joined')
        room_id = joined['room']['id']
        for i, h in enumerate(headers[1:]):
            await self.send(h, {'type': 'join', 'room_id': room_id, 'name': f'P{i}'})
        await self.send(headers[0], {'type': 'online_start'})
        game = self.app[LOBBY_KEY].rooms[room_id].game
        for player in game.players:
            player['cards'][0]['value'] = 'Повар' if player['id'] == joined['player_id'] else 'Врач'
        for h in headers[1:]:
            await self.poll(h)
        err = await self.send(headers[1], {'type': 'game_action', 'action': 'kitchen'})
        self.assertEqual(err[-1]['code'], 'wrong_profession')
        await self.send(headers[0], {'type': 'game_action', 'action': 'kitchen'})
        remote = next(e['state'] for e in await self.poll(headers[1]) if e['type'] == 'game_state')
        self.assertEqual(remote['stations']['meals'], 8)
        self.assertEqual(remote['stations']['stock']['food'], 96)
        self.assertEqual(sum(c['revealed'] for c in remote['players'][0]['cards']), 1)

    async def test_concurrent_commands_have_one_winner(self):
        headers = [await self.open() for _ in range(6)]
        events = await self.send(headers[0], {'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6})
        room = next(e['room'] for e in events if e['type'] == 'joined')
        for i, h in enumerate(headers[1:]):
            await self.send(h, {'type': 'join', 'room_id': room['id'], 'name': f'P{i}'})
        await self.send(headers[0], {'type': 'online_start'})
        game = self.app[LOBBY_KEY].rooms[room['id']].game
        # Both requests race with a host pass: only the next speaker's pass can
        # become valid, and each request is applied at most once.
        results = await asyncio.gather(
            self.send(headers[1], {'type': 'game_action', 'action': 'pass'}),
            self.send(headers[1], {'type': 'game_action', 'action': 'pass'}))
        self.assertTrue(all(any(e.get('code') == 'not_your_turn' for e in batch) for batch in results))
        self.assertEqual(game.speaker, game.active[0])
        results = await asyncio.gather(
            self.send(headers[0], {'type': 'game_action', 'action': 'pass'}),
            self.send(headers[0], {'type': 'game_action', 'action': 'pass'}))
        errors = [e for batch in results for e in batch if e.get('code') == 'not_your_turn']
        self.assertEqual(len(errors), 1)
        self.assertEqual(game.speaker, game.active[1])

    async def test_online_bots_start(self):
        h = await self.open()
        await self.send(h, {'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6})
        for _ in range(5):
            await self.send(h, {'type': 'add_bot'})
        events = await self.send(h, {'type': 'online_start'})
        self.assertTrue(any(e['type'] == 'online_game_start' for e in events))
        self.assertTrue(next(iter(self.app[LOBBY_KEY].rooms.values())).started)
