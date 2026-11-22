"""Independent original-map, paint and isometric calibration checks."""
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
MAGIC=ROOT.parent/'Magic Power'
if not (MAGIC/'tools/cg_library.py').is_file():raise unittest.SkipTest('Needs the preserved Magic Power archive')
sys.path[:0]=[str(ROOT/'tools'),str(MAGIC/'tools')]
import cg_library as library
from build_freyja_destinations import load_map
import recover_falan_architecture as recovery

class ArchitectureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta=json.loads((ROOT/'assets/maps/falan/city_architecture.json').read_text())
        cls.lookup=library.serial_index()

    def test_all_original_stations_have_one_correct_graphic(self):
        width,_,_,objects,_=load_map(library,1000)
        originals=set()
        for i,serial in enumerate(objects):
            if str(serial)not in self.meta['graphics']:continue
            e=self.lookup[serial]
            originals.add((serial,3*(i//width-134)-1.5*(e['south']-1),3*(153-i%width)-1.5*(e['east']-1)))
        recovered={(r['reference_graphic'],*r['source_center'])for r in self.meta['bindings']+self.meta['unmarked']}
        self.assertEqual(len(self.meta['graphics']),23)
        self.assertEqual(len(self.meta['bindings']),63)
        self.assertEqual(recovered,originals)
        self.assertEqual(len(self.meta['unmarked']),9)
        self.assertEqual(len(recovered),72)

    def test_native_atlas_is_byte_preserved_and_solid_paint_keeps_visible_rgb(self):
        text=(ROOT/'assets/maps/falan/city_architecture.gd').read_text()
        with Image.open(ROOT/'assets/maps/falan/city_architecture.png')as atlas,Image.open(ROOT/'assets/maps/falan/city_architecture_solid.png')as solid:
            for serial,r in self.meta['graphics'].items():
                match=re.search(r' '+serial+r':\[Rect2\((\d+), (\d+), (\d+), (\d+)\)',text)
                self.assertIsNotNone(match)
                x,y,w,h=map(int,match.groups());rect=(x,y,x+w,y+h)
                source=library.image_from_record(r['graphic']['pack'],r['graphic']['row'])
                self.assertEqual(atlas.crop(rect).tobytes(),source.tobytes(),serial)
                self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(),r['rgba_sha256'])
                derivative=solid.crop(rect)
                self.assertEqual(derivative.getchannel('A').getextrema(),(255,255))
                for original,prepared in zip(source.getdata(),derivative.getdata()):
                    if original[3]>=128:self.assertEqual(original[:3],prepared[:3],serial)

    def test_world_to_source_projection_and_height_are_consistent(self):
        # Height follows the shared city fit; original 2D art has no measured Z scale.
        self.assertEqual(recovery.PIXEL_HEIGHT,.045)
        width,_,_,objects,_=load_map(library,1000)
        for i,serial in enumerate(objects):
            if str(serial)not in self.meta['graphics']:continue
            r=self.meta['graphics'][str(serial)];e=self.lookup[serial]
            nx,ny=i%width,i//width
            wx=3*(ny-134)-1.5*(e['south']-1)
            wz=3*(153-nx)-1.5*(e['east']-1)
            ox,oy=r['origin']
            self.assertAlmostEqual((wx-wz)*32/3-ox,(nx+ny)*32+e['x']-287*32)
            self.assertAlmostEqual((wx+wz)*8-oy,(ny-nx)*24+e['y']+19*24)
            for pixel,local in zip(r['floor_pixels'],r['floor']):
                self.assertAlmostEqual(ox+(local[0]+local[1])*32/3,pixel[0])
                self.assertAlmostEqual(oy+(local[1]-local[0])*8,pixel[1])
            profile=r['profile']
            self.assertTrue(all(math.isfinite(v)for p in profile for v in p))
            self.assertTrue(all(a[0]<b[0]for a,b in zip(profile,profile[1:])))
            self.assertGreater(min(p[1]for p in profile),r['wall'])

if __name__=='__main__':unittest.main()
