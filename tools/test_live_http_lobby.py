"""End-to-end HTTPS-polling smoke test against the selected live server."""
import asyncio
import os
from aiohttp import ClientSession, ClientTimeout

URL = os.environ['LOBBY_URL'].rstrip('/')

async def main():
    async with ClientSession(timeout=ClientTimeout(total=100)) as client:
        sessions = []
        async def call(path, token='', data=None):
            headers = {'X-Lobby-Session': token} if token else {}
            async with client.post(URL + '/transport/' + path, json=data or {}, headers=headers) as response:
                text = await response.text()
                assert response.status == 200, f'{path}: HTTP {response.status}: {text[:200]}'
                import json
                return json.loads(text)
        try:
            host = (await call('open'))['session']
            sessions.append(host)
            events = (await call('send', host, {'type':'create','name':'TestHost','title':'TestLobby','capacity':6}))['events']
            room = next(e['room'] for e in events if e['type'] == 'joined')
            async with client.get(URL + '/invite/' + room['id']) as response:
                assert response.status == 200 and 'bunkerinvite://join/' in await response.text()
            events = (await call('send', host, {'type':'add_bot'}))['events']
            assert events[-1]['room']['count'] == 2 and events[-1]['room']['players'][-1]['bot']
            await call('send', host, {'type':'remove_bot'})
            assert (await call('send', host, {'type':'start'}))['events'][-1]['code'] == 'not_enough_players'
            for i in range(5):
                token = (await call('open'))['session']
                sessions.append(token)
                events = (await call('send', token, {'type':'join','name':f'Test{i}','room_id':room['id']}))['events']
                assert next(e['room']['count'] for e in events if e['type'] == 'joined') == i + 2
            assert (await call('send', sessions[1], {'type':'start'}))['events'][-1]['code'] == 'host_only'
            events = (await call('send', host, {'type':'start'}))['events']
            seed = next(e['seed'] for e in events if e['type'] == 'game_start')
            for token in sessions[1:]:
                events = (await call('poll', token))['events']
                assert any(e.get('type') == 'game_start' and e['seed'] == seed for e in events)
            print('PASS: six HTTPS sessions, bots, invitations and host-only start')
        finally:
            for token in sessions:
                try:
                    await call('close', token)
                except Exception:
                    pass

asyncio.run(main())
