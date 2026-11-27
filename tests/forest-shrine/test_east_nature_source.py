"""Nature preparation must preserve native pixels, masters and explicit source roles."""
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import prepare_east_nature as prep

class EastNatureSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((prep.OUT/'data.json').read_text());cls.rows,cls.pages,_=prep.sources()
    def original(self,serial):
        g,page=self.rows[serial]
        if page not in self.pages:self.pages[page]=Image.open(page).convert('RGBA')
        x,y,w,h=map(int,g['rect']);return self.pages[page].crop((x,y,x+w,y+h))
    def test_exact_classified_union_and_source_pins(self):
        self.assertEqual(sorted(map(int,self.data['graphics'])),prep.ALL)
        self.assertEqual(len(prep.CACTI),44);self.assertEqual(len(prep.TREES)+len(prep.STUMPS),16)
        for name,pin in self.data['source_catalogs'].items():self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),pin,name)
    def test_native_front_rgb_and_anchor_preservation(self):
        for token,spec in self.data['graphics'].items():
            serial=int(token);source=self.original(serial);g,_=self.rows[serial]
            self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(),spec['native_rgba_sha256'])
            self.assertEqual(spec['graphic']['origin'],g['origin']);self.assertEqual(spec['graphic']['footprint'],g['footprint'])
            derivative=Image.open(prep.OUT/f'{serial}-front.png').convert('RGBA');self.assertEqual(source.size,derivative.size)
            for before,after in zip(source.getdata(),derivative.getdata()):
                self.assertLessEqual(after[3],before[3],serial)
                if after[3]:self.assertEqual(before[:3],after[:3],serial)
    def test_cactus_rounded_depth_and_independent_reverse(self):
        for serial in prep.CACTI:
            spec=self.data['graphics'][str(serial)];self.assertEqual(spec['kind'],'rounded_native_contour')
            self.assertTrue(spec['edges']);self.assertGreater(max(max(row) for row in spec['depth_grid']),.1)
            self.assertTrue(all(math.isfinite(value) and value>=0 for row in spec['depth_grid'] for value in row))
            front=Image.open(prep.OUT/f'{serial}-front.png').convert('RGBA');back=Image.open(prep.OUT/f'{serial}-back.png').convert('RGBA')
            self.assertEqual(front.getchannel('A').tobytes(),back.getchannel('A').tobytes())
            self.assertNotEqual(front.tobytes(),back.tobytes())
    def test_whole_tree_master_alpha_unchanged(self):
        for serial in [10000]:
            spec=self.data['graphics'][str(serial)];master=Image.open(ROOT/spec['palette_master']).convert('RGBA');prepared=Image.open(prep.OUT/f'{serial}-leaves.png').convert('RGBA')
            self.assertEqual(hashlib.sha256(master.tobytes()).hexdigest(),spec['palette_master_rgba_sha256'])
            self.assertEqual(master.getchannel('A').tobytes(),prepared.getchannel('A').tobytes())
    def test_typed_flowers_keep_woody_and_masonry_roles_separate(self):
        self.assertEqual(len(prep.TYPED_PLANTS),95)
        self.assertFalse(set(prep.TYPED_PLANTS)&{11701,11702,11704,11707,11708,11710})
        for serial in prep.TYPED_PLANTS:
            spec=self.data['graphics'][str(serial)]
            if serial in prep.TYPED_WOODY:
                self.assertEqual(spec['kind'],'source_canopy_tree');self.assertTrue(spec['branches'],serial)
            elif serial in prep.TYPED_STUMPS:
                self.assertEqual(spec['kind'],'source_stump');self.assertGreater(spec['profile']['height'],0,serial)
            else:self.assertEqual(spec['kind'],'native_flora')

if __name__=='__main__':unittest.main()
