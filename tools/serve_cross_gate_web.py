#!/usr/bin/env python3
"""Serve the Cross Gate web export and relay same-origin co-op rooms."""

from argparse import ArgumentParser
from asyncio import sleep
from dataclasses import dataclass, field
from math import isfinite
from pathlib import Path
from secrets import randbelow, token_hex
from time import monotonic
from urllib.parse import urlsplit
import json

from aiohttp import WSMsgType, web


ROOMS = web.AppKey("rooms", dict)
ROUND_HITS = 20
MAX_PLAYERS = 4


@dataclass
class Player:
    slot: int
    pose: dict = field(default_factory=dict)
    next_pose: float = 0.0
    next_hit: float = 0.0


@dataclass
class Room:
    seed: int = field(default_factory=lambda: randbelow(2**31))
    hits: int = 0
    players: dict = field(default_factory=dict)

def numbers(value, length, limit):
    return isinstance(value, list) and len(value) == length and all(
        type(number) in (int, float) and -limit <= number <= limit and isfinite(number)
        for number in value
    )


def valid_pose(data):
    area = data.get("area")
    look = data.get("look")
    if not isinstance(area, str) or len(area) > 64 or not numbers(data.get("position"), 3, 100_000):
        return False
    if not isinstance(look, list) or len(look) != 10 or not numbers(look[1:9], 8, 8192):
        return False
    atlas = look[0]
    return (
        isinstance(atlas, str)
        and len(atlas) <= 200
        and atlas.startswith("res://assets/characters/crossgate/")
        and atlas.endswith(".png")
        and ".." not in atlas
        and min(look[3:5]) > 0
        and 0 < look[7] <= 1
        and isinstance(look[9], bool)
    )


async def room_socket(request):
    origin = urlsplit(request.headers.get("Origin", ""))
    if origin.scheme not in ("http", "https") or origin.netloc != request.host:
        raise web.HTTPForbidden()

    rooms = request.app[ROOMS]
    code = request.query.get("code", "")
    if code:
        room = rooms.get(code)
        if room is None:
            raise web.HTTPNotFound(text="This room has closed.")
        if len(room.players) >= MAX_PLAYERS:
            raise web.HTTPConflict(text="This room is full.")
    else:
        if len(rooms) >= 64:
            raise web.HTTPServiceUnavailable(text="The room server is full.")
        code = token_hex(8)
        room = rooms[code] = Room()

    socket = web.WebSocketResponse(heartbeat=15, max_msg_size=2048)
    name = token_hex(4)
    slots = {other.slot for other in room.players.values()}
    slot = next(i for i in range(MAX_PLAYERS) if i not in slots)
    player = room.players[name] = Player(slot)
    try:
        await socket.prepare(request)
        await socket.send_json({"type": "ready", "code": code, "seed": room.seed, "hits": room.hits, "slot": slot})
        async for message in socket:
            if message.type != WSMsgType.TEXT:
                continue
            try:
                data = json.loads(message.data)
            except (ValueError, RecursionError):
                continue
            if not isinstance(data, dict):
                continue
            now = monotonic()
            if data.get("type") in ("pose", "view"):
                if now < player.next_pose:
                    await sleep(player.next_pose - now)
                player.next_pose = monotonic() + 0.05
                if data["type"] == "view":
                    player.pose = {}
                elif valid_pose(data):
                    player.pose = {key: data[key] for key in ("area", "position", "look")}
                # Polling gives each browser only one pending update while a tab is backgrounded.
                others = {key: other.pose for key, other in room.players.items() if key != name and other.pose}
                await socket.send_json({"type": "view", "players": others, "hits": room.hits})
            elif data.get("type") == "hit" and now >= player.next_hit and room.hits < ROUND_HITS:
                if player.pose.get("area") != "city:0":
                    continue
                player.next_hit = now + 0.12
                room.hits += 1
    finally:
        del room.players[name]
        if not room.players:
            del rooms[code]
    return socket


@web.middleware
async def isolation_headers(request, handler):
    response = await handler(request)
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    return response


def make_app(export):
    app = web.Application(middlewares=[isolation_headers])
    app[ROOMS] = {}
    app.router.add_get("/room", room_socket)

    async def index(_request):
        return web.FileResponse(export / "index.html")

    app.router.add_get("/", index)
    app.router.add_static("/", export)
    return app


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--bind", default="127.0.0.1")
    args = parser.parse_args()
    export = Path(__file__).resolve().parents[1] / "build" / "Other Files" / "Cross Gate Web"
    if not (export / "index.html").is_file():
        parser.error("Export the Cross Gate Web preset before starting the preview.")
    web.run_app(make_app(export), host=args.bind, port=args.port)
