"""Smoke-test an explicitly supplied disposable lobby server (creates one temporary public room)."""
import asyncio
import os
from aiohttp import ClientSession, ClientTimeout

URL = os.environ['LOBBY_URL'].rstrip('/')

async def expect(ws, kind):
    for _ in range(40):
        m = await ws.receive_json(timeout=10)
        if m.get('type') == kind:
            return m
    raise AssertionError('Missing event: ' + kind)

async def main():
    async with ClientSession(timeout=ClientTimeout(total=60)) as s:
        async with s.get(URL + '/healthz') as r:
            assert r.status == 200 and (await r.json())['service'] == 'bunker-lobby'
        sockets = []
        try:
            async def connect():
                ws = await s.ws_connect(URL + '/ws', heartbeat=15)
                sockets.append(ws)
                assert (await expect(ws, 'hello'))['protocol'] == 1
                return ws
            host = await connect()
            await host.send_json({'type':'create','name':'TestHost','title':'TestLobby','capacity':6})
            room = (await expect(host, 'joined'))['room']
            async with s.get(URL + '/invite/' + room['id']) as r:
                assert r.status == 200 and 'bunkerinvite://join/' in await r.text()
            await host.send_json({'type':'add_bot'})
            while True:
                roster = (await expect(host, 'room'))['room']
                if roster['count'] == 2:
                    break
            assert sum(p.get('bot', False) for p in roster['players']) == 1
            await host.send_json({'type':'remove_bot'})
            while (await expect(host, 'room'))['room']['count'] != 1:
                pass
            await host.send_json({'type':'start'})
            assert (await expect(host, 'error'))['code'] == 'not_enough_players'
            others = []
            for n in range(5):
                ws = await connect()
                await ws.send_json({'type':'join','name':f'Test{n}','room_id':room['id']})
                assert (await expect(ws, 'joined'))['room']['count'] == n+2
                others.append(ws)
            await others[0].send_json({'type':'start'})
            assert (await expect(others[0], 'error'))['code'] == 'host_only'
            await host.send_json({'type':'start'})
            seed = (await expect(host, 'game_start'))['seed']
            for ws in others:
                assert (await expect(ws, 'game_start'))['seed'] == seed
            print('PASS: six WebSocket connections, invites, bot management, host-only start and minimum count')
        finally:
            for ws in sockets:
                await ws.close()

asyncio.run(main())
