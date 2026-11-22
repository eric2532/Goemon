"""Compare the playable bear-cave route with the recovered client and warp table."""
from pathlib import Path
import base64
import re
import sys
import unittest
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MAGIC = ROOT.parent / "Magic Power"
if not (MAGIC / "tools/cg_library.py").is_file():
    raise unittest.SkipTest("The original-map comparison needs the adjacent Magic Power archive")
sys.path[:0] = [str(ROOT / "tools"), str(MAGIC / "tools")]

import cg_library as library
from build_freyja_destinations import load_map, warp_rows, interior_links, VENOA_BEARS, VENOA_BEAR_COUNTS, VENOA_BOSS, venoa_bears
from build_undersea_details import SURROUNDINGS
from prepare_field_assets import navigation_grid
from build_falan_room_art import HABARU_WALLS, project_wall


class VenoaArchiveTest(unittest.TestCase):
    def test_bear_packs_keep_slots_and_fill_only_the_main_passage(self):
        data = (ROOT / "assets/maps/falan/freyja_destinations_data.gd").read_text().split("const VENOA_BEARS={", 1)[1].split("\n}", 1)[0]
        lookup = library.serial_index()
        warps = list(warp_rows(MAGIC)) + interior_links(MAGIC)
        for ident, original in VENOA_BEARS.items():
            width, height, ground, objects, _ = load_map(library, ident)
            walk = navigation_grid(width,height,ground,objects,lookup)
            stairs = {(x,z) for src,x,z,_,_,_ in warps if src == ident}
            stairs.update((tx,tz) for _,_,_,dst,tx,tz in warps if dst == ident)
            bears = venoa_bears(ident,width,height,walk,stairs)
            self.assertEqual(len(bears),VENOA_BEAR_COUNTS[ident])
            self.assertEqual(bears[:len(original)],original)
            self.assertEqual(len(bears),len(set(bears)))
            row = next(line for line in data.splitlines() if line.startswith(f" {ident}:"))
            prepared = [(int(x)//3+width//2,int(z)//3+height//2)
                        for x,z in re.findall(r"Vector2\((-?\d+),(-?\d+)\)",row)]
            self.assertEqual(prepared,bears)
            for i,(x,z) in enumerate(bears[len(original):],len(original)):
                self.assertTrue(all(walk[(z+b)*width+x+a] for b in (-1,0,1) for a in (-1,0,1)))
                self.assertTrue(all((x-a)**2+(z-b)**2 >= 6.25 for a,b in bears[:i]))
                self.assertTrue(all((x-a)**2+(z-b)**2 >= 9 for a,b in stairs))
                if ident == VENOA_BOSS[0]:
                    self.assertGreaterEqual((x-VENOA_BOSS[1])**2+(z-VENOA_BOSS[2])**2,16)

    def test_whole_bear_to_sea_corridor_uses_archived_scenery_and_walk_cells(self):
        data = (ROOT / "assets/maps/falan/undersea_entrances.gd").read_text()
        width, height, ground, objects, _ = load_map(library,100)
        lookup = library.serial_index()
        walk = navigation_grid(width,height,ground,objects,lookup)
        rows = data.split(' "south_lakes":[',2)[2].split("\n ],",1)[0]
        actual = {(int(x),int(z)):(int(serial),int(east),int(south),int(h))
                  for x,z,serial,east,south,h in re.findall(
                      r"\[Vector2i\((\d+),(\d+)\),(\d+),Vector2i\((\d+),(\d+)\),(\d+),false\]",rows)}
        expected = {}
        for left,top,w,h in SURROUNDINGS["south_lakes"][1]:
            for z in range(top,top+h):
                for x in range(left,left+w):
                    serial = objects[z*width+x]
                    if (12500 <= serial <= 12565 or 11363 <= serial <= 11372
                        or 11625 <= serial <= 11710 or 12160 <= serial <= 12180
                        or 11188 <= serial <= 11208 or 10058 <= serial <= 10074 or 10085 <= serial <= 10094):
                        entry = lookup[serial]
                        expected[x,z] = serial,max(1,entry['east']),max(1,entry['south']),entry['h']
        self.assertEqual(actual,expected)
        self.assertGreater(len(actual),2000)
        roads = data.split("const VENOA_ROADS={",1)[1].split("\n}",1)[0]
        for name,ends in {"bear_to_sea":((442,349),(343,497)),"village_undersea":((331,481),(299,538))}.items():
            row = next(line for line in roads.splitlines() if line.startswith(f' "{name}":'))
            cells = [tuple(map(int,p)) for p in re.findall(r"Vector2i\((\d+),(\d+)\)",row)]
            self.assertEqual((cells[0],cells[-1]),ends)
            self.assertTrue(all(walk[z*width+x] for x,z in cells))
            self.assertTrue(all(max(abs(x-a),abs(z-b)) <= 1 for (x,z),(a,b) in zip(cells,cells[1:])))

    def test_original_rock_faces_remain_paired_with_their_cells(self):
        data = (ROOT / "assets/maps/falan/room_art_data.gd").read_text().split("const HABARU_WALLS={", 1)[1].split("\n}", 1)[0]
        atlas = Image.open(ROOT / "assets/maps/falan/habaru_wall_faces.png").convert("RGBA")
        lookup = library.serial_index()
        reviewed = set()
        for ident, walls in HABARU_WALLS.items():
            _, _, _, objects, _ = load_map(library, ident)
            row = re.search(rf' {ident}:"([^"]+)"', data)
            grid = zlib.decompress(base64.b64decode(row[1]))
            self.assertEqual(len(grid), len(objects) * 2)
            for i, serial in enumerate(objects):
                tile = int.from_bytes(grid[i*2:i*2+2], "little")
                self.assertEqual(tile > 0, serial in walls)
                if not tile or serial in reviewed:
                    continue
                reviewed.add(serial)
                entry = lookup[serial]
                image = library.image_from_record(entry["pack"], entry["row"])
                for side in (0, 1):
                    face = tile * 2 + side
                    x, y = face % 16 * 36, face // 16 * 100
                    actual = atlas.crop((x, y, x + 36, y + 100))
                    self.assertEqual(actual.tobytes(), project_wall(image, entry, side, cave=True).tobytes())

    def test_every_collision_tile_matches_client(self):
        data = (ROOT / "assets/maps/falan/freyja_destinations_data.gd").read_text()
        lookup = library.serial_index()
        for ident in (11000, 11001, 11002, 11022):
            with self.subTest(floor=ident):
                width, height, ground, objects, _ = load_map(library, ident)
                row = re.search(rf' {ident}:\[Vector2i\((\d+),(\d+)\),Vector2\((-?\d+),(-?\d+)\),"([0-9a-f]+)"\]', data)
                self.assertIsNotNone(row)
                self.assertEqual(tuple(map(int, row.groups()[:4])),
                                 (width, height, -(width // 2) * 3, -(height // 2) * 3))
                bits = bytes.fromhex(row[5])
                actual = [bool(bits[i >> 3] & (1 << (i & 7))) for i in range(width * height)]
                self.assertEqual(actual, list(map(bool, navigation_grid(width, height, ground, objects, lookup))))

    def test_stairs_match_original_warps(self):
        data = (ROOT / "assets/maps/falan/freyja_destinations_data.gd").read_text().split("const DOORS={", 1)[1].split("\n}", 1)[0]
        floors = (11000, 11001, 11002, 11022)
        for source, x, z, dest, tx, tz in warp_rows(MAGIC):
            if source not in floors or dest not in floors:
                continue
            with self.subTest(source=source, cell=(x, z), dest=dest):
                sw, sh, *_ = load_map(library, source)
                dw, dh, *_ = load_map(library, dest)
                expected = f"[Vector2({(x-sw//2)*3},{(z-sh//2)*3}),{dest},Vector2({(tx-dw//2)*3},{(tz-dh//2)*3})]"
                row = next(line for line in data.splitlines() if line.startswith(f" {source}:"))
                self.assertIn(expected, row)


if __name__ == "__main__":
    unittest.main()
