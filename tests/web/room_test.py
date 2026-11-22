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
