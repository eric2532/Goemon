"""Check the recovered city house references against original footprints and doors."""
import json
import hashlib
import math
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAGIC = ROOT.parent / "Magic Power"
if not (MAGIC / "tools/cg_library.py").is_file():
    raise unittest.SkipTest("Falan house comparison needs the adjacent Magic Power archive")
sys.path[:0] = [str(ROOT / "tools"), str(MAGIC / "tools")]
import cg_library as library
from build_freyja_destinations import load_map


class FalanHouseArchiveTest(unittest.TestCase):
    def test_shop_details_reuse_preserved_native_art(self):
        metadata = json.loads((ROOT / "assets/maps/falan/city_building_surfaces.json").read_text())
        self.assertEqual(metadata["feature_masks"]["shop_medallion"][0], 10079)
        serial, outline = metadata["feature_masks"]["shop_shield"]
        self.assertEqual(serial, 10079)
        entry = library.serial_index()[serial]
        image = library.image_from_record(entry["pack"], entry["row"])
        self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), metadata["graphics"][str(serial)]["rgba_sha256"])
        self.assertTrue(all(0 <= x < image.width and 0 <= y < image.height for x, y in outline))

    def test_recovered_families_match_original_footprints_and_doors(self):
        families = {10003, 10009, 10049, 10050, 10076, 10077, 10304, 10306, 10309, 10006, 10007, 10078, 10079}
        rows = json.loads((ROOT / "assets/maps/falan/city_building_surfaces.json").read_text())["bindings"]
        width, _, _, objects, _ = load_map(library, 1000)
        lookup = library.serial_index()
        originals = set()
        for i, serial in enumerate(objects):
            if serial not in families:
                continue
            entry = lookup[serial]
            x = 3 * (i // width - 134) - 1.5 * (entry["south"] - 1)
            z = 3 * (153 - i % width) - 1.5 * (entry["east"] - 1)
            originals.add((serial, x, z))
        text = (ROOT / "assets/maps/falan/interior_data.gd").read_text().split(" 1000:[", 1)[1].split("\n ],", 1)[0]
        doors = [(int(x), int(z)) for x, z in re.findall(r"\[Vector2\((-?\d+),(-?\d+)\),\d+,", text)]
        matched = set()
        for row in rows:
            serial = row["reference_graphic"]
            if serial not in families:
                continue
            x, z = row["source_center"]
            self.assertIn((serial, x, z), originals)
            self.assertNotIn((serial, x, z), matched)
            matched.add((serial, x, z))
            door = min(doors, key=lambda p: math.hypot(p[0] - x, p[1] - z))
            angle = math.radians(row["marker"]["rotation"])
            forward = (math.sin(angle), math.cos(angle))
            dx, dz = door[0] - x, door[1] - z
            self.assertGreater(dx * forward[0] + dz * forward[1], 6)
            self.assertLess(math.hypot(dx, dz), 10)
        self.assertEqual(len(matched), 27)

    def test_windowed_homes_have_distinct_source_footprints(self):
        families = {10081, 10082, 10083, 10084, 10305, 10308}
        rows = json.loads((ROOT / "assets/maps/falan/city_building_surfaces.json").read_text())["bindings"]
        width, _, _, objects, _ = load_map(library, 1000)
        lookup = library.serial_index()
        originals = set()
        for i, serial in enumerate(objects):
            if serial in families:
                entry = lookup[serial]
                originals.add((serial, 3 * (i // width - 134) - 1.5 * (entry["south"] - 1),
                               3 * (153 - i % width) - 1.5 * (entry["east"] - 1)))
        matched = [(row["reference_graphic"], *row["source_center"]) for row in rows
                   if row["reference_graphic"] in families]
        self.assertEqual(len(matched), 22)
        self.assertEqual(len(set(matched)), len(matched))
        self.assertTrue(set(matched).issubset(originals))

    def test_distinctive_sources_and_original_door_cells(self):
        metadata = json.loads((ROOT / "assets/maps/falan/city_building_surfaces.json").read_text())
        assemblies = metadata["composites"]
        self.assertEqual({r["reference_graphic"] for r in assemblies}, {10301, 10075, 10300, 10606, 10311, 10312, 10313, 10314})
        self.assertEqual(len(assemblies), 9)
        self.assertEqual(metadata["unresolved"], [])
        self.assertEqual(len(metadata["retired"]), 1)
        self.assertEqual((metadata["retired"][0]["marker"]["x"], metadata["retired"][0]["marker"]["z"]), (-49, -16))
        width, _, _, objects, _ = load_map(library, 1000)
        lookup = library.serial_index()
        self.assertLess(objects[36*width+185], 1000)
        self.assertGreater(metadata["retired"][0]["distance"], 15)
        self.assertEqual(objects.count(10077), sum(row["reference_graphic"] == 10077 for row in metadata["bindings"]))
        expected = set()
        for i, serial in enumerate(objects):
            if serial in (10301, 10075, 10300, 10606, 10311, 10312, 10313, 10314):
                entry = lookup[serial]
                expected.add((serial, 3 * (i // width - 134) - 1.5 * (entry["south"] - 1),
                              3 * (153 - i % width) - 1.5 * (entry["east"] - 1)))
        for row in assemblies:
            self.assertIn((row["reference_graphic"], *row["source_center"]), expected)
            entry = lookup[row["reference_graphic"]]
            self.assertEqual(row["source_footprint"], [entry["south"]*3, entry["east"]*3])
        source = (ROOT / "assets/maps/falan/interior_data.gd").read_text().split(" 1000:[", 1)[1].split("\n ],", 1)[0]
        doors = {(int(x), int(z), int(room)) for x, z, room in re.findall(r"\[Vector2\((-?\d+),(-?\d+)\),(\d+),", source)}
        self.assertTrue({(-219, 159, 1071), (-219, 141, 1071), (-168, 177, 1041)}.issubset(doors))


if __name__ == "__main__":
    unittest.main()
