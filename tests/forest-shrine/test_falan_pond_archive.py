"""Keep restored city ground artwork and anchors tied to original map 1000."""
from pathlib import Path
import json
import re
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MAGIC = ROOT.parent / "Magic Power"
if not (MAGIC / "tools/cg_library.py").is_file():
    raise unittest.SkipTest("Original pond comparison needs the adjacent Magic Power archive")
sys.path[:0] = [str(ROOT / "tools"), str(MAGIC / "tools")]
import cg_library as library
from build_falan_city_streets import pond_art, MAP_ORIGIN, STRIDE, project_tile


class FalanPondArchiveTest(unittest.TestCase):
    def test_east_hospital_paving_matches_original_object_tile(self):
        with library.connection() as db:
            key = db.execute("SELECT id FROM files WHERE path = ?", ("BlueCrossgate/map/0/1000.dat",)).fetchone()[0]
        width, _, ground, objects, _ = library.parse_map(library.source_file(key)[1].read_bytes())
        self.assertEqual((ground[83*width+232], objects[83*width+232]), (0, 1004))
        entry = library.serial_index()[1004]
        expected = project_tile(library.image_from_record(entry["pack"], entry["row"]))
        with Image.open(ROOT / "assets/maps/falan/city_paving_index.png") as index:
            x, y, _, alpha = index.getpixel((83, width-1-232))
        self.assertEqual(alpha, 255)
        with Image.open(ROOT / "assets/maps/falan/city_paving_atlas.png") as atlas:
            actual = atlas.crop((x*STRIDE, y*STRIDE, (x+1)*STRIDE, (y+1)*STRIDE))
            self.assertEqual(actual.convert("RGB").tobytes(), expected.convert("RGB").tobytes())
        with Image.open(ROOT / "assets/maps/falan/city_surface.png") as surface:
            self.assertEqual(surface.getpixel((83, width-1-232)), (0, 0, 255, 255))

    def test_art_matches_native_projection(self):
        expected = pond_art(MAGIC)
        with Image.open(ROOT / "assets/maps/falan/city_pond_atlas.png") as actual:
            self.assertEqual(actual.size, expected.size)
            self.assertEqual(actual.convert("RGB").tobytes(), expected.convert("RGB").tobytes())

    def test_all_six_source_anchors(self):
        manifest = json.loads((MAGIC / "godot/assets/exploration/manifest.json").read_text())
        with library.connection() as db:
            key = db.execute("SELECT id FROM files WHERE path = ?", (manifest["map"]["source"],)).fetchone()[0]
        width, _, ground, _, _ = library.parse_map(library.source_file(key)[1].read_bytes())
        ox, oy = MAP_ORIGIN
        expected = [(3*(i//width-oy), 3*(ox-i%width)) for i, serial in enumerate(ground) if serial == 3880]
        data = (ROOT / "assets/maps/falan/city_street_data.gd").read_text().split("const LILY_TILES=[", 1)[1].split("]", 1)[0]
        actual = [(int(x), int(z)) for x, z in re.findall(r"Vector2\((-?\d+),(-?\d+)\)", data)]
        self.assertEqual(len(expected), 6)
        self.assertEqual(actual, expected)
        expected_water = [(3*(i//width-oy), 3*(ox-i%width)) for i, serial in enumerate(ground)
                          if serial == 5002 and 15 <= i//width < 21 and 140 <= i%width <= 144]
        source = (ROOT / "scripts/forest/forest_falan_gardens.gd").read_text().split("const POND_WATER=[", 1)[1].split("]", 1)[0]
        actual_water = [(int(x), int(z)) for x, z in re.findall(r"Vector2\((-?\d+),(-?\d+)\)", source)]
        self.assertEqual(set(actual_water), set(expected_water))


if __name__ == "__main__":
    unittest.main()
