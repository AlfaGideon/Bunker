"""In-memory public lobby service. It does not yet implement the game itself."""
import asyncio
import json
import os
import re
import secrets
import time
from dataclasses import dataclass, field
from aiohttp import WSMsgType, web

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


@dataclass
class Room:
    id: str
    host: Peer
    title: str
    capacity: int
    members: list[Peer] = field(default_factory=list)
    started: bool = False

    def public(self):
        return {'id': self.id, 'title': self.title, 'host_id': self.host.id,
                'capacity': self.capacity, 'count': len(self.members),
                'players': [{'id': p.id, 'name': p.name, 'skin': p.skin} for p in self.members],
                'started': self.started}


class Lobby:
    def __init__(self):
        self.rooms: dict[str, Room] = {}
        self.peers: set[Peer] = set()

    async def send(self, peer, payload):
        if not peer.socket.closed:
            try:
                await peer.socket.send_json(payload)
            except (ConnectionError, RuntimeError):
                pass

    async def broadcast(self, room, payload):
        await asyncio.gather(*(self.send(p, payload) for p in list(room.members)))

    async def update(self, room):
        await self.broadcast(room, {'type': 'room', 'room': room.public()})

    async def error(self, peer, code):
        await self.send(peer, {'type': 'error', 'code': code})

    async def leave(self, peer):
        room = peer.room
        if room is None:
            return
        peer.room = None
        if peer in room.members:
            room.members.remove(peer)
        if room.host is peer:
            self.rooms.pop(room.id, None)
            remaining = list(room.members)
            room.members.clear()
            for player in remaining:
                player.room = None
            await asyncio.gather(*(self.send(player, {'type': 'room_closed', 'reason': 'host_left'}) for player in remaining))
        else:
            await self.update(room)

    async def handle(self, peer, message):
        if not isinstance(message, dict):
            return await self.error(peer, 'invalid_message')
        action = message.get('type')
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


LOBBY_KEY = web.AppKey('lobby', Lobby)


async def health(request):
    return web.json_response({'status': 'ok', 'service': 'bunker-lobby', 'gameplay_sync': False})


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
    app.router.add_get('/healthz', health)
    app.router.add_get('/ws', websocket)
    return app


if __name__ == '__main__':
    web.run_app(create_app(), host='0.0.0.0', port=int(os.environ.get('PORT', '8080')))
