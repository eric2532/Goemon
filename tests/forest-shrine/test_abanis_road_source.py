"""Check the western crossing against the read-only client, including its cave."""
import base64
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest
import zlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
import cg_library as lib

STAGES = [(400, (196, 443), (235, 338)),
          (14000, (8, 41), (45, 9)),
          (14001, (14, 68), (57, 13)),
          (14002, (30, 44), (36, 7)),
          (402, (258, 180), (183, 161))]


class AbanisRoadSource(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())

    def test_client_planes_and_recorded_corridors(self):
        for ident, entry, exit in STAGES:
            path = f"BlueCrossgate/map/0/{ident}.dat"
            row = self.catalog["maps"][path]
            with lib.connection() as db:
                source_id = db.execute("SELECT id FROM files WHERE path=?", (path,)).fetchone()[0]
            original = lib.source_file(source_id)[1].read_bytes()
            self.assertEqual(zlib.decompress(base64.b64decode(row["raw"])), original)
            self.assertEqual(hashlib.sha256(original).hexdigest(), row["sha256"])
            current = zlib.decompress(base64.b64decode(row.get("restored_raw", row["raw"])))
            w, h, floors, objects, flags = lib.parse_map(original)
            _, _, new_floors, new_objects, new_flags = lib.parse_map(current)
            self.assertEqual(flags, new_flags)
            for i, flag in enumerate(flags):
                if flag & 0xC000:
                    self.assertEqual((floors[i], objects[i]), (new_floors[i], new_objects[i]))
            if ident in (14000, 14001, 14002):
                self.assertEqual(current, original)
            bits = zlib.decompress(base64.b64decode(row["walk"]))
            queue = deque([entry]); previous = {entry: None}
            while queue and exit not in previous:
                x, y = queue.popleft()
                for point in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                    xx, yy = point; i = yy*w+xx
                    if 0 <= xx < w and 0 <= yy < h and point not in previous and bits[i >> 3] & (1 << (i & 7)):
                        previous[point] = (x, y); queue.append(point)
            self.assertIn(exit, previous, ident)
            point = exit
            while point is not None:
                self.assertTrue(flags[point[1]*w+point[0]] & 0xC000, (ident, point))
                point = previous[point]

    def test_original_western_cave_connections(self):
        warps = self.catalog["warps"]
        for edge in [(400,235,338,14000,8,41), (14000,45,9,14001,14,68),
                     (14001,57,13,14002,30,44), (14002,36,7,402,258,180)]:
            self.assertIn(list(edge), warps)
            self.assertIn(list(edge[3:]+edge[:3]), warps)
        self.assertIn([402,183,161,4300,37,70], warps)
        self.assertIn([4300,37,71,402,183,162], warps)

    def test_prepared_cliffs_keep_native_dimensions_and_art(self):
        sys.path.insert(0, str(ROOT / "tools"))
        from prepare_abanis_cliffs import prepare
        prepared = json.loads((ROOT / "assets/maps/original_crossgate/cliff-profiles.json").read_text())
        rebuilt, paint = prepare()
        self.assertEqual(prepared, rebuilt)
        self.assertEqual(Image.open(ROOT / "assets/maps/original_crossgate/cliff-paint.png").convert("RGBA").tobytes(), paint.tobytes())
        self.assertEqual(len(prepared["profiles"]), 120)
        for serial, row in prepared["profiles"].items():
            g = self.catalog["graphics"][serial]
            self.assertEqual(row["rgba_sha256"], g["rgba_sha256"])
            self.assertEqual(len(row["vertices"]), row["sides"]*row["levels"])
            self.assertEqual(len(row["uv_pixels"]), len(row["vertices"]))
            self.assertGreaterEqual(row["crown"][1]+.001,max(v[1] for v in row["vertices"][-row["sides"]:]))
            self.assertGreater(row["pixel_height"], 0)
            x,y,w,h = row["paint_rect"]
            for u,v in row["uv_pixels"]:
                self.assertTrue(.5 <= u <= w-.5 and .5 <= v <= h-.5)
            original = lib.image_from_record(g["pack"],g["row"])
            for v in range(h):
                for u in range(w):
                    r,gg,b,a = original.getpixel((u,v))
                    if a >= 128 and max(r,gg,b) > 45:
                        self.assertEqual(paint.getpixel((x+u,y+v)), (r,gg,b,255))
            fx, fz = g["footprint"]
            for x, y, z in row["vertices"]:
                self.assertTrue(all(map(math.isfinite, (x,y,z))))
                self.assertTrue(-1.501 <= x <= fx*3-1.499)
                self.assertTrue(1.499-fz*3 <= z <= 1.501)
                self.assertTrue(0 <= y <= row["height"]+.001)

    def test_cliff_extension_preserves_enclosed_dark_crevices(self):
        sys.path.insert(0, str(ROOT / "tools"))
        from prepare_abanis_cliffs import edge_paint
        image = Image.new("RGBA", (7,7), (20,20,20,255))
        for y in range(1,6):
            for x in range(1,6):image.putpixel((x,y),(91+x,78+y,50,255))
        image.putpixel((3,3),(12,12,12,255))
        result = edge_paint(image)
        self.assertEqual(result.getpixel((3,3)),image.getpixel((3,3)))
        for y in range(1,6):
            for x in range(1,6):self.assertEqual(result.getpixel((x,y)),image.getpixel((x,y)))
        self.assertNotEqual(result.getpixel((0,0)), image.getpixel((0,0)))


if __name__ == "__main__":
    unittest.main()
