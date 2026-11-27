from gzip import compress
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from aiohttp import WSServerHandshakeError
from aiohttp.test_utils import AioHTTPTestCase

from tools.serve_cross_gate_web import make_app, ROOMS


class CoOpRoomTest(AioHTTPTestCase):
    async def get_application(self):
        self.export = TemporaryDirectory()
        self.addCleanup(self.export.cleanup)
        return make_app(Path(self.export.name))

    async def test_export_files_and_ranges(self):
        export = Path(self.export.name)
        outside = TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        private_file = Path(outside.name) / "private.json"
        private_file.write_text("local data")
        (export / "index.html").write_text("Cross Gate")
        (export / "build-info.json").write_text('{"build_id":"test"}')
        (export / "index.pck.000").write_bytes(b"123456")
        (export / "engine.wasm").write_bytes(b"WASM")
        (export / "engine.wasm.gz").write_bytes(compress(b"WASM"))
        (export / "private.json").write_text("local data")
        (export / "hidden.wasm").symlink_to(private_file)
        (export / "other.wasm").write_bytes(b"WASM")
        (export / "other.wasm.gz").symlink_to(private_file)

        async with self.client.get("/") as response:
            self.assertEqual(await response.text(), "Cross Gate")
            self.assertEqual(response.headers["Cross-Origin-Opener-Policy"], "same-origin")
            self.assertEqual(response.headers["Cross-Origin-Embedder-Policy"], "require-corp")
            self.assertEqual(response.headers["Cache-Control"], "no-cache")
        async with self.client.get("/build-info.json") as response:
            self.assertEqual(await response.json(), {"build_id": "test"})
        async with self.client.get("/index.pck.000", headers={"Range": "bytes=2-3"}) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.headers["Content-Range"], "bytes 2-3/6")
            self.assertEqual(await response.read(), b"34")
        async with self.client.get("/engine.wasm", headers={"Accept-Encoding": "gzip"}) as response:
            self.assertEqual(response.content_type, "application/wasm")
            self.assertEqual(response.headers["Content-Encoding"], "gzip")
            self.assertEqual(await response.read(), b"WASM")
        async with self.client.get("/engine.wasm", headers={"Accept-Encoding": "identity"}) as response:
            self.assertNotIn("Content-Encoding", response.headers)
            self.assertEqual(await response.read(), b"WASM")
        for path in ("/private.json", "/hidden.wasm", "/other.wasm", "/engine.wasm.gz", "/tools/serve_cross_gate_web.py"):
            async with self.client.get(path) as response:
                self.assertEqual(response.status, 404)

    async def test_room_updates_avatars_and_shares_target_hits(self):
        origin = str(self.server.make_url("/")).rstrip("/")
        headers = {"Origin": origin}
        async with self.client.ws_connect("/room", headers=headers) as host:
            ready = await host.receive_json(timeout=2)
            self.assertEqual(ready["type"], "ready")
            invite = "/room?code=" + ready["code"]
            pose = {
                "type": "pose",
                "area": "city:0",
                "position": [0, 0, 0],
                "look": ["res://assets/characters/crossgate/kazi/atlas-0.png",
                         0, 0, 20, 20, 0, 0, 0.03, 0, False],
            }
            await host.send_json(pose)
            self.assertEqual(await host.receive_json(timeout=2), {"type": "view", "players": {}, "hits": 0})
            await host.send_json({"type": "hit"})
            await host.send_json(pose)
            self.assertEqual((await host.receive_json(timeout=2))["hits"], 1)
            async with self.client.ws_connect(invite, headers=headers) as guest:
                self.assertEqual(await guest.receive_json(timeout=2), {**ready, "hits": 1, "slot": 1})
                guest_pose = {**pose, "position": [3, 0, 2]}
                await guest.send_json(guest_pose)
                visible = next(iter((await guest.receive_json(timeout=2))["players"].values()))
                self.assertEqual(visible["look"], pose["look"])
                await host.send_json(pose)
                other = next(iter((await host.receive_json(timeout=2))["players"].values()))
                self.assertEqual(other["position"], [3, 0, 2])

                await guest.send_json({"type": "hit"})
                await guest.send_json(guest_pose)
                self.assertEqual((await guest.receive_json(timeout=2))["hits"], 2)
                await host.send_json(pose)
                self.assertEqual((await host.receive_json(timeout=2))["hits"], 2)

            await host.send_json(pose)
            self.assertEqual((await host.receive_json(timeout=2))["players"], {})
        self.assertEqual(self.app[ROOMS], {})
        with self.assertRaises(WSServerHandshakeError) as error:
            await self.client.ws_connect(invite, headers=headers)
        self.assertEqual(error.exception.status, 404)
        with self.assertRaises(WSServerHandshakeError) as error:
            await self.client.ws_connect("/room", headers={"Origin": "https://example.org"})
        self.assertEqual(error.exception.status, 403)


if __name__ == "__main__":
    unittest.main()
