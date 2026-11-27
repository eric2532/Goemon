"""Isolated original water props add art without reclassifying their source water."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_venoa_southwest_scenery import prepare,lib,load_map


class WaterFlowerSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=prepare()

    def test_published_data_and_old_strip_stay_exact(self):
        data=self.data
        self.assertEqual(json.loads((ROOT/'assets/maps/falan/venoa_field/scenery.json').read_text()),data)
        original=json.loads((ROOT/'assets/maps/falan/venoa_field/provenance.json').read_text())['new_source_art_anchors']
        self.assertEqual([[*r['cell'],r['serial']]for r in data['placements']],original)
        self.assertEqual(data['counts'],dict(shore=49,tree=22,flowers=8,stump=1))

    def test_five_source_identities_keep_water_and_original_paint(self):
        w,h,ground,objects,flags=load_map(lib,100);lookup=lib.serial_index()
        rows=self.data['offshore_placements']
        self.assertEqual([[*r['cell'],r['serial']]for r in rows],[[x,7,12175+x-20]for x in range(20,25)])
        for row in rows:
            x,y=row['cell'];i=y*w+x;source=lookup[row['serial']]
            image=lib.image_from_record(source['pack'],source['row'])
            self.assertEqual((row['ground'],row['flags'],row['serial']),(ground[i],flags[i],objects[i]))
            self.assertIn(ground[i],range(5000,5009))
            self.assertEqual(row['flags'],49152)
            self.assertEqual(row['placement_surface'],'existing_source_water')
            self.assertEqual(self.data['graphics'][str(row['serial'])]['rgba_sha256'],hashlib.sha256(image.tobytes()).hexdigest())


if __name__=='__main__':unittest.main()
