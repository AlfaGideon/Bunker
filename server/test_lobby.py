import unittest
from aiohttp.test_utils import TestClient, TestServer
from app import create_app


class LobbyTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client = TestClient(TestServer(create_app()))
        await self.client.start_server()
        self.sockets = []

    async def asyncTearDown(self):
        for ws in self.sockets:
            await ws.close()
        await self.client.close()

    async def connect(self):
        ws = await self.client.ws_connect('/ws')
        self.sockets.append(ws)
        self.assertEqual((await ws.receive_json())['type'], 'hello')
        return ws

    async def expect(self, ws, event):
        for _ in range(30):
            message = await ws.receive_json(timeout=3)
            if message['type'] == event:
                return message
        self.fail(f'No {event} event')

    async def test_rooms_start_and_disconnect(self):
        response = await self.client.get('/healthz')
        self.assertFalse((await response.json())['gameplay_sync'])
        host = await self.connect()
        await host.send_json({'type': 'create', 'name': 'Ведущий', 'title': 'Костёр', 'capacity': 6, 'skin': 'young'})
        room = (await self.expect(host, 'joined'))['room']
        self.assertEqual(room['count'], 1)
        await host.send_json({'type': 'start'})
        self.assertEqual((await self.expect(host, 'error'))['code'], 'not_enough_players')
        members = []
        for i in range(5):
            ws = await self.connect()
            await ws.send_json({'type': 'join', 'room_id': room['id'], 'name': f'Игрок {i}'})
            joined = await self.expect(ws, 'joined')
            self.assertEqual(joined['room']['count'], i + 2)
            members.append(ws)
        await members[0].send_json({'type': 'start'})
        self.assertEqual((await self.expect(members[0], 'error'))['code'], 'host_only')
        await host.send_json({'type': 'start'})
        started = await self.expect(host, 'game_start')
        self.assertTrue(started['room']['started'])
        for ws in members:
            event = await self.expect(ws, 'game_start')
            self.assertEqual(event['seed'], started['seed'])
        observer = await self.connect()
        await observer.send_json({'type': 'list'})
        self.assertEqual((await self.expect(observer, 'rooms'))['rooms'], [])
        await host.close()
        for ws in members:
            self.assertEqual((await self.expect(ws, 'room_closed'))['reason'], 'host_left')

    async def test_bots_and_invitation(self):
        host = await self.connect()
        guest = await self.connect()
        await host.send_json({'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 6})
        room = (await self.expect(host, 'joined'))['room']
        response = await self.client.get('/invite/' + room['id'])
        self.assertEqual(response.status, 200)
        self.assertIn('bunkerinvite://join/', await response.text())
        self.assertEqual((await self.client.get('/invite/not-valid')).status, 404)
        await guest.send_json({'type': 'join', 'room_id': room['id'], 'name': 'Guest'})
        await self.expect(guest, 'joined')
        await guest.send_json({'type': 'add_bot'})
        self.assertEqual((await self.expect(guest, 'error'))['code'], 'host_only')
        for n in range(4):
            await host.send_json({'type': 'add_bot'})
            while True:
                snapshot = (await self.expect(host, 'room'))['room']
                if snapshot['count'] == n + 3:
                    break
            self.assertEqual(sum(p['bot'] for p in snapshot['players']), n + 1)
        await host.send_json({'type': 'add_bot'})
        self.assertEqual((await self.expect(host, 'error'))['code'], 'room_full')
        await host.send_json({'type': 'remove_bot'})
        while (await self.expect(host, 'room'))['room']['count'] != 5:
            pass
        await host.send_json({'type': 'start'})
        self.assertEqual((await self.expect(host, 'error'))['code'], 'not_enough_players')
        await host.send_json({'type': 'add_bot'})
        await host.send_json({'type': 'start'})
        self.assertEqual((await self.expect(host, 'game_start'))['room']['count'], 6)
        await host.send_json({'type': 'add_bot'})
        self.assertEqual((await self.expect(host, 'error'))['code'], 'already_started')

    async def test_http_polling_and_websocket_interoperate(self):
        opened = await self.client.post('/transport/open', json={})
        token = (await opened.json())['session']
        headers = {'X-Lobby-Session': token}
        response = await self.client.post('/transport/send', headers=headers, json={
            'type': 'create', 'name': 'HTTP Host', 'title': 'Room', 'capacity': 6})
        events = (await response.json())['events']
        room = next(e['room'] for e in events if e['type'] == 'joined')
        guest = await self.connect()
        await guest.send_json({'type': 'join', 'room_id': room['id'], 'name': 'WebSocket'})
        await self.expect(guest, 'joined')
        response = await self.client.post('/transport/poll', headers=headers, json={})
        roster = (await response.json())['events']
        self.assertEqual(roster[-1]['room']['count'], 2)
        response = await self.client.post('/transport/send', headers=headers, json={'type': 'add_bot'})
        self.assertEqual((await response.json())['events'][-1]['room']['count'], 3)
        self.assertEqual((await self.client.post('/transport/poll', json={})).status, 401)
        await self.client.post('/transport/close', headers=headers, json={})
        self.assertEqual((await self.expect(guest, 'room_closed'))['reason'], 'host_left')
        self.assertEqual((await self.client.post('/transport/poll', headers=headers, json={})).status, 401)

    async def test_list_leave_validation(self):
        host = await self.connect()
        await host.send_json({'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 7})
        self.assertEqual((await self.expect(host, 'error'))['code'], 'invalid_capacity')
        await host.send_json({'type': 'create', 'name': 'Host', 'title': 'Room', 'capacity': 8})
        room = (await self.expect(host, 'joined'))['room']
        other = await self.connect()
        await other.send_json({'type': 'list'})
        self.assertEqual((await self.expect(other, 'rooms'))['rooms'][0]['id'], room['id'])
        await other.send_json({'type': 'join', 'room_id': room['id'], 'name': 'Second'})
        await self.expect(other, 'joined')
        await other.send_json({'type': 'leave'})
        await self.expect(other, 'left')
        await host.send_json({'type': 'list'})
        self.assertEqual((await self.expect(host, 'rooms'))['rooms'][0]['count'], 1)


if __name__ == '__main__':
    unittest.main()
