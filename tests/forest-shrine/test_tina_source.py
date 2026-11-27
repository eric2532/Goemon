"""Verify Tina's completed planes against client bytes and pinned map references."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import zlib
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from recover_original_crossgate_maps import TINA_SOURCE, complete_recorded_map


class TinaSourceTest(unittest.TestCase):
    def test_prepared_wall_contours_keep_the_original_graphics(self):
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
        outlines=json.loads((ROOT/'assets/maps/falan/tina/wall-outlines.json').read_text())
        self.assertEqual(outlines['schema'],1)
        self.assertEqual(len(outlines['graphics']),32)
        for serial,row in outlines['graphics'].items():
            g=catalog['graphics'][serial]
            self.assertEqual(row['source_rgba_sha256'],g['rgba_sha256'])
            self.assertGreaterEqual(len(row['outline']),3)
            for x,y in row['outline']:
                self.assertTrue(0<=x<=g['rect'][2] and 0<=y<=g['rect'][3],serial)

    def test_prepared_graves_preserve_visible_components_and_stone_pigment(self):
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
        rows=json.loads((ROOT/'assets/maps/falan/tina/wall-outlines.json').read_text())['graves']
        self.assertEqual(set(rows),set(map(str,[11048,11050,11051,11053,11056,11058,11062,11470,11471,11473,11474])))
        for serial,row in rows.items():
            g=catalog['graphics'][serial]
            self.assertEqual(row['source_rgba_sha256'],g['rgba_sha256'])
            self.assertTrue(row['outlines'])
            self.assertTrue(row['parts'])
            if serial=='11050':self.assertTrue(all(p['flat'] for p in row['parts']))
            if serial=='11062':self.assertEqual({p['flat'] for p in row['parts']},{True,False})
            for outline in row['outlines']:
                self.assertGreaterEqual(len(outline),3)
                for x,y in outline:self.assertTrue(0<=x<=g['rect'][2] and 0<=y<=g['rect'][3],serial)
            with Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]) as atlas:
                x,y=row['edge_pixel'];pixel=atlas.convert('RGBA').getpixel((g['rect'][0]+int(x),g['rect'][1]+int(y)))
            self.assertEqual(pixel[3],255)
            self.assertNotEqual(pixel[:3],(71,71,71))

    def test_shared_roof_paint_is_snow_not_a_blue_shadow(self):
        surfaces=json.loads((ROOT/'assets/maps/original_crossgate/building-surfaces.json').read_text())
        serial,quad,*_=surfaces['patches']['snowroof']
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
        g=catalog['graphics'][str(serial)]
        x,y,w,h=g['rect']
        with Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]) as atlas:
            source=atlas.crop((x,y,x+w,y+h))
        pixels=source.crop((quad[0][0],quad[0][1],quad[2][0],quad[2][1]))
        mean=ImageStat.Stat(pixels).mean
        self.assertEqual(pixels.getchannel('A').getextrema(),(255,255))
        self.assertGreater(min(mean[:3]),210)
        self.assertLess(max(mean[:3])-min(mean[:3]),12)

    def test_missing_art_is_marked_in_each_linked_area(self):
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
        for ident in (32181,32183,32193,32194):
            row=catalog['maps'][f'BlueCrossgate/map/0/{ident}.dat']
            self.assertTrue(row['artwork_approximation'])
            self.assertTrue(row['unavailable_graphics'])
            for serial in row['unavailable_graphics']:
                graphic=catalog['graphics'][str(serial)]
                self.assertIn(graphic['fallback_serial'],(8155,16727))
                self.assertEqual(graphic['family'],'floor' if graphic['fallback_serial']==8155 else 'room_wall')

    def test_every_recorded_cell_and_unrecorded_completion(self):
        catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())
        references = json.loads((TINA_SOURCE / "references.json").read_text())
        for proof in references:
            ident = int(proof.get("map_id", proof["file"].split("_")[0].split(".")[0]))
            row = catalog["maps"][f"BlueCrossgate/map/0/{ident}.dat"]
            reference = (TINA_SOURCE / proof["file"]).read_bytes()
            self.assertEqual(hashlib.sha256(reference).hexdigest(), proof["sha256"])
            self.assertEqual(hashlib.sha1(b"blob " + str(len(reference)).encode() + b"\0" + reference).hexdigest(), proof["git_blob"])
            raw = zlib.decompress(base64.b64decode(row["raw"]))
            restored = zlib.decompress(base64.b64decode(row["restored_raw"]))
            w, h = row["size"]
            cells = w * h
            self.assertEqual(struct.unpack_from(">HH", reference, 40), (w, h))
            expected = struct.unpack_from(f">{cells*2}H", reference, 44)
            old = struct.unpack_from(f"<{cells*3}H", raw, 20)
            actual = struct.unpack_from(f"<{cells*3}H", restored, 20)
            for i in range(cells):
                for plane in (0, 1):
                    offset = plane * cells + i
                    self.assertEqual(actual[offset], old[offset] if old[2*cells+i] & 0xC000 else expected[offset], (ident, i, plane))
            self.assertEqual(actual[2*cells:], old[2*cells:])
            self.assertEqual(restored, complete_recorded_map(f"BlueCrossgate/map/0/{ident}.dat", raw, self)[0])
            if row.get("reference_only", False):
                self.assertTrue(row["reference_only"])
            else:
                client = ROOT.parent / "Magic Power/data/crossgate/source/BlueCrossgate/map/0" / f"{ident}.dat"
                self.assertEqual(raw, client.read_bytes())
        self.assertEqual(catalog["maps"]["BlueCrossgate/map/0/4200.dat"]["preserved_client_variations"], 3)
        self.assertEqual(catalog["maps"]["BlueCrossgate/map/0/4200.dat"]["restored_cells"], 5703)
        self.assertEqual(catalog["maps"]["BlueCrossgate/map/0/4201.dat"]["restored_cells"], 5874)

    @staticmethod
    def parse_map(raw):
        w, h = struct.unpack_from("<II", raw, 12)
        n = w*h
        values = struct.unpack_from(f"<{n*3}H", raw, 20)
        return w, h, values[:n], values[n:n*2], values[n*2:]


if __name__ == "__main__":
    unittest.main()
