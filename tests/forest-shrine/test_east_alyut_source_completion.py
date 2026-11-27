"""Whole2400 completion provenance/owner contracts, separate from physical/visual review."""
import base64
import collections
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate'
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_east_region_maps import active_raw, reference_map


class AlyutSourceCompletion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
        import cg_library as lib
        from prepare_field_assets import navigation_grid
        cls.lib = lib; cls.navigation = staticmethod(navigation_grid)
        cls.data = json.loads((FOLDER / 'map-data.json').read_text())
        cls.report = json.loads((FOLDER / 'source-contract.json').read_text())
        with lib.connection() as db:
            row = db.execute('SELECT id FROM files WHERE path=?', ('BlueCrossgate/map/0/2400.dat',)).fetchone()
        cls.original = lib.source_file(row[0])[1].read_bytes()
        cls.hybrid = (FOLDER / 'hybrid-map.bin').read_bytes()
        cls.count = 10000
        cls.before = struct.unpack_from('<30000H', cls.original, 20)
        cls.after = struct.unpack_from('<30000H', cls.hybrid, 20)
        cls.known = [i for i in range(cls.count) if cls.before[20000 + i] & 0xc000]

    def test_unknown_only_bytes_and_shared_active_variant(self):
        self.assertEqual(self.original[:20], self.hybrid[:20])
        self.assertEqual(self.original[40020:], self.hybrid[40020:], 'The entire original marker plane is immutable')
        for i in self.known:
            self.assertEqual((self.before[i], self.before[10000+i]), (self.after[i], self.after[10000+i]))
        catalog = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())
        self.assertEqual(active_raw(catalog['maps']['BlueCrossgate/map/0/2400.dat']), self.hybrid)
        reference = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__02400_aryurt'
        _, _, values, _ = reference_map(reference.read_bytes(), 2400)
        for i in range(self.count):
            if i not in self.known:
                self.assertEqual((values[i], values[10000+i]), (self.after[i], self.after[10000+i]))
        self.assertEqual(11497, self.after[10000 + 73*100 + 36])
        self.assertEqual(hashlib.sha256(self.hybrid).hexdigest(), self.data['source']['sha256'])

    def test_native_mask_and_index_known_pixels_preserved_and_water_separate(self):
        with Image.open(FOLDER / 'mask.png') as source: mask = source.convert('RGBA')
        with Image.open(ROOT / 'assets/maps/falan/freyja_alyut.png') as source: old_mask = source.convert('RGBA')
        with Image.open(FOLDER / 'ground-index.png') as source: index = source.convert('RGBA')
        with Image.open(ROOT / 'assets/maps/falan/alyut_ground_index.png') as source: old_index = source.convert('RGBA')
        for i in self.known:
            cell = (i % 100, i // 100)
            self.assertEqual(old_mask.getpixel(cell), mask.getpixel(cell))
            self.assertEqual(old_index.getpixel(cell), index.getpixel(cell))
        added = self.report['added_walk_semantics']['cells']
        self.assertEqual({'land': 2311, 'water': 99}, dict(collections.Counter(row['class'] for row in added)))
        for row in added:
            if row['class'] == 'water':
                self.assertTrue(5000 <= row['bg'] <= 5008)
                self.assertTrue(12500 <= row['pg1'] <= 12535)
                self.assertEqual(255, mask.getpixel(tuple(row['cell']))[0], 'A walk bit alone must not promote wet BG to physical land')

    def test_existing_atlas_and_each_appended_original_tile(self):
        from build_falan_room_art import COLS, STRIDE, project_tile
        with Image.open(FOLDER / 'ground-atlas.png') as source: atlas = source.convert('RGB')
        with Image.open(ROOT / 'assets/maps/falan/alyut_ground_atlas.png') as source: old = source.convert('RGB')
        self.assertEqual(old.tobytes(), atlas.crop((0, 0, old.width, old.height)).tobytes())
        rows = self.report['ground_atlas']['appended_source_tiles']; self.assertEqual(17, len(rows))
        lookup = self.lib.serial_index()
        for row in rows:
            graphic = lookup[row['graphic']]
            original = self.lib.image_from_record(graphic['pack'], graphic['row']).convert('RGBA')
            self.assertEqual(row['rgba_sha256'], hashlib.sha256(original.tobytes()).hexdigest())
            x, y = row['slot'] % COLS * STRIDE, row['slot'] // COLS * STRIDE
            self.assertGreaterEqual(y, old.height)
            self.assertEqual(project_tile(original).tobytes(), atlas.crop((x, y, x+STRIDE, y+STRIDE)).tobytes())

    def test_every_original_object_has_exact_source_owner_and_endpoints(self):
        expected = {(self.after[10000+i], i % 100, i // 100) for i in range(self.count) if self.after[10000+i] >= 1000}
        actual = [(row['graphic'], *row['cell']) for row in self.data['placements']]
        self.assertEqual(753, len(actual)); self.assertEqual(len(actual), len(set(actual)))
        self.assertEqual(expected, set(actual))
        self.assertEqual(204, sum(12536 <= row[0] < 12548 for row in actual))
        self.assertEqual(5, len(self.data['building_placements']))
        self.assertEqual(14, len(self.data['actors'])); self.assertEqual(27, len(self.data['connections']))
        walk = self.navigation(100, 100, self.after[:10000], self.after[10000:20000], self.lib.serial_index())
        for x, y in self.data['door_cells'] + self.data['protected_gate_cells']:
            self.assertTrue(walk[y*100+x], (x, y))
        self.assertFalse(walk[73*100+36], 'Keep the source HouseMaster/flower cell blocked; interaction uses its open neighbours')

    def test_native_navigation_and_exact_blocked_land_union(self):
        from build_freyja_outlying import is_water
        walk = self.navigation(100, 100, self.after[:10000], self.after[10000:20000], self.lib.serial_index())
        bits = zlib.decompress(base64.b64decode(self.data['walk_bits']))
        self.assertEqual(4597, sum(walk))
        self.assertTrue(all(bool(bits[i>>3] & (1 << (i&7))) == bool(walk[i]) for i in range(10000)))
        building_cells = {(row['cell'][0]+x, row['cell'][1]-z) for row in self.data['building_placements']
                          for x in range(row['footprint'][0]) for z in range(row['footprint'][1])}
        expected = {(i % 100, i // 100) for i in range(10000) if self.after[i] and not is_water(self.after[i]) and not walk[i]
                    and (i % 100, i // 100) not in building_cells}
        actual = [(x, y) for a, b, width, height in self.data['blocked_land_rectangles']
                  for x in range(a, a+width) for y in range(b, b+height)]
        self.assertEqual(len(actual), len(set(actual)))
        self.assertEqual(expected, set(actual))
        self.assertTrue(all(not walk[y*100+x] for x, y in actual))


if __name__ == '__main__':
    unittest.main()
