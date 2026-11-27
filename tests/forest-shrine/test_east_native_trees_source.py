"""Native-tree fitting may reuse originals but must not alter or substitute them."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import prepare_east_native_trees as prep

class NativeTreeSourceTest(unittest.TestCase):
    def test_foliage_sampling_keeps_blue_gray_needles(self):
        image=Image.new('RGBA',(3,3),(0,0,0,0));image.putpixel((0,0),(66,111,136,255));image.putpixel((1,0),(145,148,151,255));image.putpixel((2,0),(124,80,50,255))
        colors=prep.foliage_colors(image)
        self.assertIn((66,111,136,255),colors);self.assertIn((145,148,151,255),colors);self.assertNotIn((124,80,50,255),colors)
    def test_exact27_roles_pins_and_source_bindings(self):
        data=json.loads((prep.OUT/'data.json').read_text());table,_,_=prep.sources()
        self.assertEqual(sorted(map(int,data['graphics'])),prep.IDS)
        self.assertEqual(len(prep.IDS),27)
        for path,pin in data['source_catalogs'].items():self.assertEqual(prep.digest(ROOT/path),pin)
        for master in data['masters'].values():
            for path,pin in master['source_pins'].items():self.assertEqual(prep.digest(ROOT/path),pin)
        for token,row in data['graphics'].items():
            g,_=table[int(token)]
            self.assertEqual(row['source_rgba_sha256'],g['rgba_sha256']);self.assertEqual(row['origin'],g['origin']);self.assertEqual(row['footprint'],g['footprint'])
            self.assertTrue(all(math.isfinite(v) and v>0 for v in row['foliage_tint']+row['bark_tint']))
            self.assertEqual(len(row['visible']),4)
            self.assertGreater(row['visible'][2],row['visible'][0]);self.assertGreater(row['visible'][3],row['visible'][1])
            if int(token) in prep.IDS:
                self.assertEqual(row['kind'],'native_canopy_tree');self.assertTrue(row['branches'])
                x,y,w,h=map(int,g['rect']);source=Image.open(table[int(token)][1]).convert('RGBA').crop((x,y,x+w,y+h))
                for suffix in ['branches','foliage']:
                    prepared=Image.open(prep.OUT/f'{token}-{suffix}.png').convert('RGBA')
                    self.assertEqual(prepared.size,source.size)
                    for original,actual in zip(source.getdata(),prepared.getdata()):
                        self.assertLessEqual(actual[3],original[3])
                        if actual[3]:self.assertEqual(original[:3],actual[:3])
        self.assertFalse(set(prep.IDS)&{10053,10054,10056,10057,10075,10095,10096,10098})
if __name__=='__main__':unittest.main()
