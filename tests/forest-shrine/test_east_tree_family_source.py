"""Native tree coverage, unchanged masters, palette alpha and source branch art."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from east_region_tree_families import BARE,SEASONAL,leaf_colors


class EastTreeFamilySourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=ROOT/'assets/maps/original_crossgate';cls.out=ROOT/'assets/maps/falan/east_region/landmarks'
        cls.catalog=json.loads((cls.base/'east/catalog.json').read_text());cls.data=json.loads((cls.out/'profiles.json').read_text())['graphics'];cls.pages={}

    def native(self,serial):
        g=self.catalog['graphics'][str(serial)];page=g['page']
        if page not in self.pages:self.pages[page]=Image.open(self.base/self.catalog['pages'][page]).convert('RGBA')
        x,y,w,h=g['rect'];return self.pages[page].crop((x,y,x+w,y+h))

    def test_all_reached_tree_ids_have_source_owners(self):
        usage=json.loads((ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/source-object-usage.json').read_text())['graphics']
        ids=list(SEASONAL)+BARE;self.assertEqual(len(ids),39)
        self.assertEqual(sum(usage[str(i)]['placements'] for i in ids),2925)
        for serial in ids:
            spec=self.data[str(serial)];self.assertIn(spec['kind'],('native_canopy_tree','native_branch_tree'))
            self.assertEqual(spec['native_rgba_sha256'],hashlib.sha256(self.native(serial).tobytes()).hexdigest())

    def test_bare_tree_rods_follow_native_bounds_and_keep_fine_rgb(self):
        for serial in BARE:
            source=self.native(serial);spec=self.data[str(serial)];self.assertTrue(spec['branches'],serial)
            self.assertEqual(spec['branch_segments'],sum(len(p)-1 for p in spec['branches']))
            for path in spec['branches']:
                self.assertGreaterEqual(len(path),2)
                for x,y,radius in path:self.assertTrue(0<=x<source.width and 0<=y<source.height and radius>0,(serial,x,y,radius))
            actual=Image.open(self.out/f'{serial}-branches.png').convert('RGBA');self.assertEqual(actual.size,source.size)
            for before,after in zip(source.getdata(),actual.getdata()):
                self.assertLessEqual(after[3],before[3],serial)
                if after[3]:self.assertEqual(after[:3],before[:3],serial)

    def test_native_crown_alpha_and_rgb_are_preserved(self):
        for serial in SEASONAL:
            spec=self.data[str(serial)];source=self.native(serial)
            self.assertEqual(spec['kind'],'native_canopy_tree');self.assertTrue(spec['branches'])
            self.assertIn('rejected_master',spec)
            for suffix in ['branches','foliage']:
                derivative=Image.open(self.out/f'{serial}-{suffix}.png').convert('RGBA')
                self.assertEqual(derivative.size,source.size)
                for before,after in zip(source.getdata(),derivative.getdata()):
                    self.assertLessEqual(after[3],before[3],serial)
                    if after[3]:self.assertEqual(after[:3],before[:3],serial)


if __name__=='__main__':unittest.main()
