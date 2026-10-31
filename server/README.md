# Bunker lobby server — initial prototype

Python 3.11+ / aiohttp; a single in-memory instance. `PORT` is supplied by Render. No database, accounts, gameplay logic, reconnection, or persistent rooms yet. Do not treat this as production-ready or use it to claim the APK supports multiplayer.

## Back4app Containers

Back4app advertises a free container plan without a payment card and WebSocket support. Select the repository and the branch containing the root `Dockerfile`; after this change is merged use `main`. The container exposes port 8080 and accepts `PORT` from the environment. If requested, set the exposed port to 8080 and the health check path to `/healthz`. No secrets are needed. The service URL is supplied by Back4app after deployment; append `/healthz` for the health check or connect to `/ws` via `wss://`.

This is a prototype with a single in-memory process: restarts erase rooms and active sessions; the free tier's actual availability, connection limits, and behavior in players' networks need testing. The Godot client and online gameplay are not yet implemented.

## Render

Use the GitHub Bunker repo, stable branch `main` **after this code is merged**. Python 3, Root Directory blank, Free web service, region Frankfurt, build `pip install -r server/requirements.txt`, start `python server/app.py`, health check `/healthz`; no environment variables or secrets needed. The endpoint `https://<service>.onrender.com/healthz` reports `gameplay_sync: false`. WebSocket endpoint `wss://<service>.onrender.com/ws`. The placeholder domain must be replaced with the real URL from Render.

Free service sleep and restarts interrupt all sessions and erase lobby data. Starting a room broadcasts a signal only: actual multiplayer gameplay and the Godot client are not implemented. Lobby data and names are public. The process has basic per-connection message and resource limits but has not had a full security review.

## Local test

```
python3 -m venv .venv
.venv/bin/pip install -r server/requirements.txt
.venv/bin/python -m unittest discover -s server -p 'test_*.py' -v
.venv/bin/python server/app.py
```

## Protocol v1 (JSON WebSocket messages)

Server sends `hello` on connection. Client sends `list`, `create` (name, title, capacity: 6/8/10, optional skin), `join` (room_id, name, optional skin), `leave`, `add_bot`, `remove_bot`, `start` or `ping`. Only the host can add or remove bots, which count toward capacity. Successful create/join returns `joined` including player_id; all participants receive `room` snapshots on roster changes. `rooms` lists open non-full rooms only. Host may start only with the selected number of players; then all participants receive `game_start` with a common seed. Host leaving or disconnecting closes the room and sends `room_closed`. Errors return an `error` code. A client should send regular `ping`, handle connection loss and never assume session state survives a server restart.
