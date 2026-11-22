import hashlib
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_freyja_destinations import KILI_HOMES, load_map, read_housing_map


class KiliHouses(unittest.TestCase):
    def test_recovered_sources_keep_archive_identity_and_distinct_plans(self):
        folder = ROOT / 'assets/references/crossgate_kili_houses'
        manifest = json.loads((folder / 'provenance.json').read_text())
        plans = []
        for item in manifest['files']:
            raw = (folder / item['name']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), item['sha256'])
            self.assertEqual(hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest(), item['sha'])
            ident = int(item['name'].split('_')[0])
            parsed = read_housing_map(raw, ident)
            self.assertEqual(parsed[:2], (20, 20))
            if ident in KILI_HOMES:
                self.assertEqual(load_map(None, ident), parsed)
                plans.append(tuple(parsed[2] + parsed[3]))
                door = manifest['source_doors'][str(ident)]
                self.assertEqual(KILI_HOMES[ident][0], tuple(door['entrance']))
                self.assertEqual(KILI_HOMES[ident][2], tuple(door['threshold']))
        self.assertEqual(len(set(plans)), 4)

    def test_rejects_foreign_truncated_or_overlong_map(self):
        raw = (ROOT / 'assets/references/crossgate_kili_houses/03801_room').read_bytes()
        for invalid, ident in [(b'', 3801), (raw, 3802), (raw[:-2], 3801), (raw+b'\0', 3801), (b'BADMAP'+raw[6:], 3801)]:
            with self.subTest(size=len(invalid), ident=ident), self.assertRaises(ValueError):
                read_housing_map(invalid, ident)

    def test_generated_furnishings_keep_every_original_anchor(self):
        data = (ROOT / 'assets/maps/falan/coastal_room_props.gd').read_text().split('const ROOMS={')[1]
        for ident in KILI_HOMES:
            w, _, _, objects, _ = load_map(None, ident)
            block = re.search(rf' {ident}:\[(.*?)\n \],', data, re.S)[1]
            rows = re.findall(r'Vector2i\((\d+),(-?\d+)\),Vector2i\((\d+),(\d+)\),"[^"]+",(\d+)', block)
            actual = [(int(x), int(z)+int(depth)-1, int(serial)) for x,z,width,depth,serial in rows]
            expected = [(i%w, i//w, serial) for i,serial in enumerate(objects) if serial>=1000]
            self.assertEqual(sorted(actual), sorted(expected), ident)


if __name__ == '__main__':
    unittest.main()
