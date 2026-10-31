"""In-memory public lobby service. It does not yet implement the game itself."""
import asyncio
import json
import os
import re
import secrets
import time
from collections import deque
from dataclasses import dataclass, field
from aiohttp import WSMsgType, web, ClientSession, ClientTimeout, ClientError
from pathlib import Path
from match_game import Match, GameError

MAX_ROOMS = 100
MAX_SOCKETS = 500
MAX_MESSAGE = 4096
ALLOWED_SIZES = (6, 8, 10)
NAME = re.compile(r'^[\w .-]{1,24}$', re.UNICODE)
ROOM_ID = re.compile(r'^[0-9a-f]{16}$')


@dataclass(eq=False)
class Peer:
    socket: web.WebSocketResponse
    id: str = field(default_factory=lambda: secrets.token_hex(8))
    name: str = ''
    skin: str = 'default'
    room: 'Room | None' = None


@dataclass(eq=False)
class Bot:
    id: str = field(default_factory=lambda: 'bot-' + secrets.token_hex(8))
    name: str = 'Бот'
    skin: str = 'male'


@dataclass
class Room:
    id: str
    host: Peer
    title: str
    capacity: int
    members: list[Peer | Bot] = field(default_factory=list)
    started: bool = False
    game: Match | None = None

    def public(self):
        return {'id': self.id, 'title': self.title, 'host_id': self.host.id,
                'capacity': self.capacity, 'count': len(self.members),
                'players': [{'id': p.id, 'name': p.name, 'skin': p.skin, 'bot': isinstance(p, Bot)} for p in self.members],
                'started': self.started}


class Lobby:
    def __init__(self):
        self.rooms: dict[str, Room] = {}
        self.peers: set[Peer] = set()
        self.http_sessions: dict[str, HttpSession] = {}
        self.game_lock = asyncio.Lock()

    async def send(self, peer, payload):
        if not peer.socket.closed:
            try:
                await peer.socket.send_json(payload)
            except (ConnectionError, RuntimeError):
                pass

    async def broadcast(self, room, payload):
        await asyncio.gather(*(self.send(p, payload) for p in list(room.members) if isinstance(p, Peer)))

    async def update(self, room):
        await self.broadcast(room, {'type': 'room', 'room': room.public()})

    async def error(self, peer, code):
        await self.send(peer, {'type': 'error', 'code': code})

    async def game_update(self, room):
        game = room.game
        if game is not None:
            await asyncio.gather(*(self.send(p, {'type': 'game_state', 'state': game.snapshot(p.id)})
                                   for p in list(room.members) if isinstance(p, Peer)))

    async def game_command(self, peer, message):
        async with self.game_lock:
            room = peer.room
            if room is None or room.game is None:
                return await self.error(peer, 'no_game')
            changed = room.game.tick()
            try:
                room.game.command(peer.id, message.get('action'), message.get('value'))
            except GameError as exc:
                if changed:
                    await self.game_update(room)
                return await self.error(peer, str(exc))
            await self.game_update(room)

    async def game_start(self, peer):
        async with self.game_lock:
            room = peer.room
            if room is None or room.host is not peer:
                return await self.error(peer, 'host_only')
            if room.started:
                return await self.error(peer, 'already_started')
            if len(room.members) != room.capacity:
                return await self.error(peer, 'not_enough_players')
            # Bot AI is not yet implemented in the authoritative match.
            if any(isinstance(p, Bot) for p in room.members):
                return await self.error(peer, 'online_bots_not_ready')
            room.game = Match(room.members)
            room.started = True
            await self.broadcast(room, {'type': 'online_game_start', 'room': room.public()})
            await self.game_update(room)

    async def leave(self, peer):
        async with self.game_lock:
            await self._leave_locked(peer)

    async def _leave_locked(self, peer):
        room = peer.room
        if room is None:
            return
        peer.room = None
        if peer in room.members:
            room.members.remove(peer)
        if room.host is peer or room.game is not None:
            self.rooms.pop(room.id, None)
            remaining = [p for p in room.members if isinstance(p, Peer)]
            room.members.clear()
            for player in remaining:
                player.room = None
            await asyncio.gather(*(self.send(player, {'type': 'room_closed', 'reason': 'player_disconnected' if room.game is not None and room.host is not peer else 'host_left'}) for player in remaining))
        else:
            await self.update(room)

    async def handle(self, peer, message):
        if not isinstance(message, dict):
            return await self.error(peer, 'invalid_message')
        action = message.get('type')
        if action == 'online_start':
            return await self.game_start(peer)
        if action == 'game_action':
            return await self.game_command(peer, message)
        if action == 'game_sync':
            async with self.game_lock:
                if peer.room is None or peer.room.game is None:
                    return await self.error(peer, 'no_game')
                if peer.room.game.tick():
                    return await self.game_update(peer.room)
                return await self.send(peer, {'type': 'game_state', 'state': peer.room.game.snapshot(peer.id)})
        if action == 'ping':
            return await self.send(peer, {'type': 'pong'})
        if action == 'list':
            rooms = [r.public() for r in self.rooms.values() if not r.started and len(r.members) < r.capacity]
            return await self.send(peer, {'type': 'rooms', 'rooms': rooms})
        if action == 'leave':
            await self.leave(peer)
            return await self.send(peer, {'type': 'left'})
        if action in ('create', 'join'):
            if peer.room is not None:
                return await self.error(peer, 'already_in_room')
            name, skin = message.get('name'), message.get('skin', 'default')
            if not isinstance(name, str) or not NAME.fullmatch(name.strip()):
                return await self.error(peer, 'invalid_name')
            if not isinstance(skin, str) or not NAME.fullmatch(skin):
                return await self.error(peer, 'invalid_skin')
            if action == 'create':
                capacity = message.get('capacity')
                title = message.get('title')
                if type(capacity) is not int or capacity not in ALLOWED_SIZES:
                    return await self.error(peer, 'invalid_capacity')
                if not isinstance(title, str) or not NAME.fullmatch(title.strip()):
                    return await self.error(peer, 'invalid_title')
                if len(self.rooms) >= MAX_ROOMS:
                    return await self.error(peer, 'server_full')
                room = Room(secrets.token_hex(8), peer, title.strip(), capacity)
                self.rooms[room.id] = room
            else:
                room_id = message.get('room_id')
                if not isinstance(room_id, str) or not ROOM_ID.fullmatch(room_id):
                    return await self.error(peer, 'invalid_room')
                room = self.rooms.get(room_id)
                if room is None or room.started or len(room.members) >= room.capacity:
                    return await self.error(peer, 'room_unavailable')
            peer.name, peer.skin, peer.room = name.strip(), skin, room
            room.members.append(peer)
            await self.send(peer, {'type': 'joined', 'player_id': peer.id, 'room': room.public()})
            return await self.update(room)
        if action in ('add_bot', 'remove_bot'):
            room = peer.room
            if room is None or room.host is not peer:
                return await self.error(peer, 'host_only')
            if room.started:
                return await self.error(peer, 'already_started')
            if action == 'add_bot':
                if len(room.members) >= room.capacity:
                    return await self.error(peer, 'room_full')
                used = {p.name for p in room.members}
                index = next(i for i in range(1, 100) if f'Бот {i}' not in used)
                skins = ('male', 'female', 'male_young', 'female_young', 'male_senior', 'female_senior')
                room.members.append(Bot(name=f'Бот {index}', skin=skins[(index - 1) % len(skins)]))
            else:
                bots = [p for p in room.members if isinstance(p, Bot)]
                if not bots:
                    return await self.error(peer, 'no_bots')
                room.members.remove(bots[-1])
            return await self.update(room)
        if action == 'start_bot_test':
            room = peer.room
            if room is None or room.host is not peer:
                return await self.error(peer, 'host_only')
            if room.started:
                return await self.error(peer, 'already_started')
            if len(room.members) < room.capacity:
                return await self.error(peer, 'not_enough_players')
            if any(p is not peer and not isinstance(p, Bot) for p in room.members):
                return await self.error(peer, 'online_game_not_ready')
            room.started = True
            await self.send(peer, {'type': 'bot_test_start', 'room': room.public()})
            return
        if action == 'start':
            room = peer.room
            if room is None or room.host is not peer:
                return await self.error(peer, 'host_only')
            if room.started:
                return await self.error(peer, 'already_started')
            if len(room.members) < room.capacity:
                return await self.error(peer, 'not_enough_players')
            room.started = True
            # This is only a start signal, not synchronized gameplay.
            await self.broadcast(room, {'type': 'game_start', 'room': room.public(), 'seed': secrets.randbelow(2**31)})
            return
        await self.error(peer, 'unknown_action')


class PollSocket:
    """WebSocket-like outbound queue for clients behind an HTTP-only proxy."""
    def __init__(self):
        self.closed = False
        self.events = deque(maxlen=256)

    async def send_json(self, payload):
        if not self.closed:
            self.events.append(payload)


@dataclass
class HttpSession:
    peer: Peer
    last_seen: float = field(default_factory=time.monotonic)
    tokens: float = 30.0
    token_time: float = field(default_factory=time.monotonic)
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)


async def close_http(lobby, token):
    session = lobby.http_sessions.pop(token, None)
    if session is not None:
        session.peer.socket.closed = True
        await lobby.leave(session.peer)
        lobby.peers.discard(session.peer)


async def sweep_http(app):
    lobby = app[LOBBY_KEY]
    while True:
        await asyncio.sleep(1)
        async with lobby.game_lock:
            for room in list(lobby.rooms.values()):
                if room.game is not None and room.game.tick():
                    await lobby.game_update(room)
        expired = [token for token, session in lobby.http_sessions.items()
                   if time.monotonic() - session.last_seen > 75]
        for token in expired:
            await close_http(lobby, token)


async def start_sweeper(app):
    task = asyncio.create_task(sweep_http(app))
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


async def http_open(request):
    lobby = request.app[LOBBY_KEY]
    if len(lobby.peers) >= MAX_SOCKETS:
        raise web.HTTPServiceUnavailable()
    token = secrets.token_urlsafe(32)
    peer = Peer(PollSocket())
    lobby.peers.add(peer)
    lobby.http_sessions[token] = HttpSession(peer)
    return web.json_response({'session': token, 'protocol': 1}, headers={'Cache-Control': 'no-store'})


async def http_message(request):
    lobby = request.app[LOBBY_KEY]
    token = request.headers.get('X-Lobby-Session', '')
    session = lobby.http_sessions.get(token)
    if not session:
        raise web.HTTPUnauthorized()
    async with session.lock:
        session.last_seen = time.monotonic()
        if request.path.endswith('/close'):
            await close_http(lobby, token)
            return web.json_response({'closed': True})
        if request.path.endswith('/send'):
            now = time.monotonic()
            session.tokens = min(30.0, session.tokens + (now - session.token_time) * 5)
            session.token_time = now
            if session.tokens < 1:
                raise web.HTTPTooManyRequests()
            session.tokens -= 1
            try:
                data = await request.json()
            except (ValueError, UnicodeDecodeError):
                raise web.HTTPBadRequest()
            await lobby.handle(session.peer, data)
        events = list(session.peer.socket.events)
        session.peer.socket.events.clear()
        return web.json_response({'events': events}, headers={'Cache-Control': 'no-store'})


LOBBY_KEY = web.AppKey('lobby', Lobby)


async def health(request):
    return web.json_response({'status': 'ok', 'service': 'bunker-lobby', 'gameplay_sync': False})


async def invite_page(request):
    room_id = request.match_info['room_id']
    if not ROOM_ID.fullmatch(room_id):
        raise web.HTTPNotFound()
    page = Path(__file__).with_name('invite.html').read_text(encoding='utf-8')
    return web.Response(text=page, content_type='text/html', headers={
        'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"})


async def invite_background(request):
    return web.FileResponse(Path(__file__).with_name('invite-bg.jpg'))


async def download_apk(request):
    # Stream the signed latest APK through this site, never buffer it in RAM.
    # Restrict both release tag and first download URL to our repository.
    base = 'https://github.com/AlfaGideon/Bunker/releases'
    timeout = ClientTimeout(total=600, connect=30, sock_read=60)
    try:
        async with ClientSession(timeout=timeout, headers={'User-Agent': 'Bunker-Invite/1.0'}) as client:
            async with client.get(base + '/latest', allow_redirects=False) as latest:
                location = latest.headers.get('Location', '')
                match = re.fullmatch(r'https://github\.com/AlfaGideon/Bunker/releases/tag/android-([0-9]+)', location)
                if latest.status not in (301, 302) or not match:
                    raise web.HTTPServiceUnavailable(text='Обновление пока недоступно')
                version = match.group(1)
            url = base + '/download/android-' + version + '/bunker-' + version + '.apk'
            async with client.get(url, allow_redirects=True) as upstream:
                if upstream.status != 200:
                    raise web.HTTPServiceUnavailable(text='APK пока недоступен')
                size = upstream.content_length
                if size is not None and (size <= 0 or size > 200 * 1024 * 1024):
                    raise web.HTTPBadGateway(text='Неверный размер APK')
                headers = {'Content-Type': 'application/vnd.android.package-archive',
                           'Content-Disposition': 'attachment; filename="bunker-' + version + '.apk"',
                           'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'}
                if size is not None:
                    headers['Content-Length'] = str(size)
                response = web.StreamResponse(status=200, headers=headers)
                await response.prepare(request)
                async for chunk in upstream.content.iter_chunked(65536):
                    await response.write(chunk)
                await response.write_eof()
                return response
    except (ClientError, asyncio.TimeoutError) as exc:
        raise web.HTTPServiceUnavailable(text='Не удалось загрузить APK, попробуйте позже') from exc


async def websocket(request):
    lobby: Lobby = request.app[LOBBY_KEY]
    if len(lobby.peers) >= MAX_SOCKETS:
        return web.json_response({'error': 'server_full'}, status=503)
    ws = web.WebSocketResponse(heartbeat=25, max_msg_size=MAX_MESSAGE)
    await ws.prepare(request)
    peer = Peer(ws)
    lobby.peers.add(peer)
    await lobby.send(peer, {'type': 'hello', 'protocol': 1})
    tokens, last = 30.0, time.monotonic()
    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                now = time.monotonic()
                tokens = min(30.0, tokens + (now - last) * 5)
                last = now
                if tokens < 1:
                    await ws.close(code=1008, message=b'rate limit')
                    break
                tokens -= 1
                try:
                    data = json.loads(msg.data)
                except (ValueError, RecursionError):
                    await lobby.error(peer, 'invalid_json')
                    continue
                await lobby.handle(peer, data)
            elif msg.type == WSMsgType.ERROR:
                break
    finally:
        await asyncio.shield(lobby.leave(peer))
        lobby.peers.discard(peer)
    return ws


def create_app():
    app = web.Application(client_max_size=MAX_MESSAGE)
    app[LOBBY_KEY] = Lobby()
    app.cleanup_ctx.append(start_sweeper)
    app.router.add_post('/transport/open', http_open)
    app.router.add_post('/transport/send', http_message)
    app.router.add_post('/transport/poll', http_message)
    app.router.add_post('/transport/close', http_message)
    app.router.add_get('/healthz', health)
    app.router.add_get('/invite-background.jpg', invite_background)
    app.router.add_get('/download', download_apk)
    app.router.add_get('/invite/{room_id}', invite_page)
    app.router.add_get('/ws', websocket)
    return app


if __name__ == '__main__':
    web.run_app(create_app(), host='0.0.0.0', port=int(os.environ.get('PORT', '8080')))
