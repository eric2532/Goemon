"""Verify measured exterior references independently of the runtime fits."""
import json
import math
from pathlib import Path
import re
import sys
import unittest
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
MAGIC=ROOT.parent/'Magic Power'
if not(MAGIC/'tools/cg_library.py').is_file():raise unittest.SkipTest('Needs original map archive')
sys.path[:0]=[str(ROOT/'tools'),str(MAGIC/'tools')]
import cg_library as library
from build_freyja_destinations import load_map

class SourceProportions(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data=json.loads((ROOT/'assets/maps/falan/city_proportion_references.json').read_text())
 def test_source_camera_is_orthographic_at_native_tile_scale(self):
  p=self.data['projection'];h=p['horizontal_pixels_per_unit'];f=p['floor_pixels_per_unit'];v=p['vertical_pixels_per_unit']
  self.assertAlmostEqual(2*h*h,2*f*f+v*v)
  self.assertAlmostEqual(math.sin(math.asin(f/h)),.75)
 def test_villa_clock_recovery_excludes_the_neighboring_balcony_rail(self):
  from recover_falan_buildings import PATCHES, FEATURE_MASKS
  alias,quad,*_=PATCHES['10313_emblem']
  self.assertLess(math.dist(tuple(sum(p[k]for p in quad)/4 for k in [0,1]),(312,417)),2)
  entry=library.serial_index()[10313]
  original=library.image_from_record(entry['pack'],entry['row'])
  mask=Image.new('L',original.size);ImageDraw.Draw(mask).polygon(FEATURE_MASKS[alias][1],fill=255)
  self.assertEqual(mask.getpixel((310,417)),255)
  self.assertEqual(mask.getpixel((258,427)),0)
 def test_laundry_masks_fit_their_native_quads(self):
  from recover_falan_buildings import PATCHES,FEATURE_MASKS
  for name in ['10311_cloth','10311_stripes','10311_shirt','10311_socks','10311_trousers']:
   alias,q,*_=PATCHES[name];a=(q[1][0]-q[0][0],q[1][1]-q[0][1]);b=(q[3][0]-q[0][0],q[3][1]-q[0][1]);det=a[0]*b[1]-a[1]*b[0]
   for p in FEATURE_MASKS[alias][1]:
    x,y=p[0]-q[0][0],p[1]-q[0][1];u=(x*b[1]-y*b[0])/det;v=(a[0]*y-a[1]*x)/det
    self.assertTrue(0<=u<=1 and 0<=v<=1,(name,p,u,v))
 def test_laundry_top_uses_visible_alpha_instead_of_tile_margin(self):
  text=(ROOT/'assets/maps/falan/city_building_surfaces.gd').read_text()
  tops=dict((name,float(top)) for name,top in re.findall(r'"(10311_[^"]+)":([.0-9]+),',text.split('const CLOTH_TOP={')[1].split('}')[0]))
  with Image.open(ROOT/'assets/maps/falan/city_building_surfaces.png') as atlas:
   for name,top in tops.items():
    x,y=map(int,re.search('"'+name+r'":Vector2\((\d+),(\d+)\)',text).groups())
    actual=atlas.crop((x,y,x+128,y+128)).getchannel('A').getbbox()[1]/128
    self.assertAlmostEqual(top,actual)
    height=2.8;center=3-(.5-top)*height
    self.assertAlmostEqual(center+height*.5-actual*height,3)
 def test_single_building_dimensions_and_anchors_match_native_graphics(self):
  width,_,_,objects,_=load_map(library,1000);lookup=library.serial_index()
  records=self.data['records'];self.assertEqual(len(records),41)
  for key,r in records.items():
   if key in ['civic_1201','civic_1301','civic_1400']:continue
   s=r['graphic'];e=lookup[s];im=library.image_from_record(e['pack'],e['row']);bbox=im.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
   candidates=[]
   for i,serial in enumerate(objects):
    if serial!=s:continue
    x=3*(i//width-134)-1.5*(e['south']-1);z=3*(153-i%width)-1.5*(e['east']-1)
    candidates.append(((x-r['center'][0])**2+(z-r['center'][1])**2,i))
   i=min(candidates)[1];sx=(r['center'][0]-r['center'][1])*32/3;sy=sum(r['center'])*8
   expected=[(i%width+i//width)*32+e['x']-287*32+bbox[0]-sx,(i//width-i%width)*24+e['y']+19*24+bbox[1]-sy,bbox[2]-bbox[0],bbox[3]-bbox[1]]
   for a,b in zip(expected,r['source_rect']):self.assertAlmostEqual(a,b,msg=key)
 def test_compound_civics_include_original_ground_facades(self):
  for key in ['civic_1201','civic_1301','civic_1400']:
   r=self.data['records'][key];self.assertGreater(r['parts'],25)
   self.assertGreater(len(r['rgba_hashes']),20)
   self.assertGreater(r['source_rect'][3],600)
  mansion=self.data['records']['civic_1301'];parts=mansion['components']
  self.assertEqual(len(parts),3)
  self.assertEqual(sorted(p[2:]for p in parts),[[188,234],[188,234],[368,422]])
  left=min(p[0]for p in parts);top=min(p[1]for p in parts)
  self.assertEqual(mansion['source_rect'],[left,top,max(p[0]+p[2]for p in parts)-left,max(p[1]+p[3]for p in parts)-top])
 def test_native_paint_derivative_retains_visible_rgb(self):
  text=(ROOT/'assets/maps/falan/city_proportion_references.gd').read_text()
  with Image.open(ROOT/'assets/maps/falan/city_civic_source_paint.png')as atlas:
   for key in self.data['records']:
    if key.startswith('house_'):continue
    x,y,w,h=map(int,re.search('"'+key+r'":Rect2\((\d+),(\d+),(\d+),(\d+)\)',text.split('const PAINT={')[1]).groups())
    with Image.open(ROOT/'build/Other Files/Asset Toolkit/Falan Proportions'/f'original-{key}.png')as source:
     paint=atlas.crop((x,y,x+w,y+h));self.assertEqual(source.size,paint.size)
     self.assertEqual(paint.getchannel('A').getextrema(),(255,255))
     for original,prepared in zip(source.getdata(),paint.getdata()):
      if original[3]>=128:self.assertEqual(original[:3],prepared[:3],key)
if __name__=='__main__':unittest.main()
