"""Authenticate completed cells while preserving original client masters and flags."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from audit_explore_access import CATALOGS
from prepare_explore_missing_maps import reference_map


class PartialLayoutsTest(unittest.TestCase):
    def test_reviewed_ex_bindings_preserve_pinned_layout_and_existing_art(self):
        from prepare_explore_missing_maps import FRONTIER_EX_NAMESPACES
        catalog = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())
        baseline = {}
        for path in (ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Namespace review').glob('before-local-EX-map-bindings*.json'):
            baseline.update(json.loads(path.read_text()))
        graphics = {}
        for path in CATALOGS:
            graphics.update(json.loads((ROOT/path).read_text()).get('graphics', {}))
        self.assertEqual({row['id'] for row in baseline.values()}, set(FRONTIER_EX_NAMESPACES))
        for key, original in baseline.items():
            row = catalog['maps'][key]
            self.assertEqual(row['layout_reference']['sha256'], FRONTIER_EX_NAMESPACES[row['id']])
            self.assertTrue(all(row[field] == value for field,value in original.items() if field not in ['walk','graphic_aliases','namespace_repair']))
            self.assertTrue(all(str(alias) in graphics for alias in row['graphic_aliases'].values()))
            self.assertEqual(row['namespace_repair']['local_serial_offset'], 200000)
        from PIL import Image
        chair = catalog['graphics']['1235045']
        self.assertEqual((chair['pack'],chair['row'],chair['origin'],chair['footprint']),('ex',3590,[-34,-78],[1,1]))
        self.assertEqual(chair['rgba_sha256'],'8e72b7c7210646c38173b9de92c21460c31b0a0c52990634f54ce9cfabf33929')
        x,y,w,h = chair['rect']
        atlas = Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][chair['page']]).convert('RGBA')
        self.assertEqual(hashlib.sha256(atlas.crop((x,y,x+w,y+h)).tobytes()).hexdigest(),chair['rgba_sha256'])


    def test_completed_sokia_fits_preserve_existing_bounds(self):
        fixed = json.loads((ROOT/'assets/maps/falan/sokia/fixed/catalog.json').read_text())['maps']
        completed = json.loads((ROOT/'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())['layout_overrides']
        fitted = [row for row in completed.values() if row.get('fixed_bounds_complete')]
        self.assertEqual(len(fitted),17)
        for key,row in completed.items():
            if not row.get('fixed_bounds_complete'):continue
            for field in ['visible_bounds','solid_bounds','cap_pixels','wall_caps']:
                self.assertTrue(all(row[field][k] == value for k,value in fixed[key][field].items()))
            self.assertTrue(all(value in row['void_cliffs'] for value in fixed[key]['void_cliffs']))
        sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
        import cg_library as lib
        lookup = lib.serial_index()
        row = completed['BlueCrossgate/map/0/13014.dat']
        for serial in [12563,12680]:
            graphic = lookup[serial]
            image = lib.image_from_record(graphic['pack'],graphic['row'])
            x,y,right,bottom = image.getbbox()
            self.assertEqual(row['visible_bounds'][str(serial)],[graphic['x']+x,graphic['y']+y,right-x,bottom-y])

    def test_completed_cells_and_original_client_planes(self):
        catalog = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())
        originals = {}
        for path in CATALOGS:
            if path.endswith('explore_recovered/catalog.json'):
                continue
            data = json.loads((ROOT / path).read_text())
            originals.update({int(row['id']): row for row in list(data['maps'].values()) + list(data.get('layout_overrides', {}).values())})
        completed = catalog.get('layout_overrides', {})
        self.assertEqual(len(completed), 73)
        self.assertNotIn(4400, [row['id'] for row in completed.values()])
        for row in completed.values():
            with self.subTest(source=row['id']):
                old = originals[row['id']]
                raw = zlib.decompress(base64.b64decode(row['raw']))
                restored = zlib.decompress(base64.b64decode(row['restored_raw']))
                self.assertEqual(row['sha256'], old['sha256'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), old['sha256'])
                self.assertEqual(raw, zlib.decompress(base64.b64decode(old['raw'])))
                self.assertEqual(hashlib.sha256(restored).hexdigest(), row['restored_sha256'])
                width, height = row['size']; cells = width * height
                self.assertEqual(restored[:20], raw[:20])
                self.assertEqual(restored[20+cells*4:], raw[20+cells*4:])
                pin = row['layout_reference']
                payload = (ROOT / 'assets/references/crossgate_sokia/maps/server' / pin['file']).read_bytes()
                self.assertEqual(hashlib.sha256(payload).hexdigest(), pin['sha256'])
                self.assertEqual(hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest(), pin['git_blob_sha1'])
                rw, rh, values, _ = reference_map(payload, row['id'])
                self.assertEqual((width, height), (rw, rh))
                a = struct.unpack_from(f'<{cells*3}H', raw, 20)
                b = struct.unpack_from(f'<{cells*3}H', restored, 20)
                for i in range(cells):
                    self.assertEqual((b[i], b[cells+i]), (a[i], a[cells+i]) if a[2*cells+i] & 0xc000 else (values[i], values[cells+i]))
                walk = zlib.decompress(base64.b64decode(row['walk']))
                self.assertEqual(len(walk), (cells+7)//8)


if __name__ == '__main__':
    unittest.main()
