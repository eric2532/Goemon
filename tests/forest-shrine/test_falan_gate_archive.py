"""Verify complete native geography and all three exterior source placement lists."""
from collections import Counter
import json
from pathlib import Path
import re
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
MAGIC=ROOT.parent/'Magic Power'
if not(MAGIC/'tools/cg_library.py').is_file():raise unittest.SkipTest('Needs original map archive')
sys.path[:0]=[str(ROOT/'tools'),str(MAGIC/'tools')]
import cg_library as library
from build_freyja_destinations import load_map
from build_freyja_outlying import is_water
from build_falan_approaches import approach_point

class GateArchive(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.lookup=library.serial_index();cls.freyja=load_map(library,100)
  cls.gates=(ROOT/'assets/maps/falan/gate_exterior_data.gd').read_text()

 def test_all_364_city_fort_stations_match_the_original(self):
  width,_,_,objects,_=load_map(library,1000);expected=[]
  for i,s in enumerate(objects):
   if not(10640<=s<=10653 or 10655<=s<=10662):continue
   e=self.lookup[s]
   expected.append((3*(i//width-134)-1.5*(e['south']-1),3*(153-i%width)-1.5*(e['east']-1),s))
  section=(ROOT/'assets/maps/falan/city_street_data.gd').read_text().split('const FORTIFICATIONS=[')[1].split('\n]')[0]
  actual=[(float(x),float(z),int(s))for x,z,s in re.findall(r'Vector2\(([-\d.]+),([-\d.]+)\),(\d+)',section)]
  self.assertEqual(Counter(actual),Counter(expected));self.assertEqual(len(actual),364)

 def test_each_gate_exterior_matches_original_freyja_forts_and_rotation(self):
  width,_,_,objects,_=self.freyja
  for side,key in [('west','freyja'),('east','east_gate'),('south','south_gate')]:
   expected=[]
   for i,s in enumerate(objects):
    if not 10640<=s<=10662 or s==(10646 if side=='south' else 10662):continue
    x,z=approach_point(side,i%width,i//width)
    if not(-480<=x<=480 and (45 if side=='south' else 63)<z<=480):continue
    dx,dz={'west':(-3,-3),'east':(3,3),'south':(3,-3)}[side]
    serial={10640:10641,10641:10640}.get(s,s)if side=='south'else s
    expected.append((x+dx,z+dz,serial))
   section=self.gates.split(f' "{key}":{{')[1].split('  "forts":[')[1].split('\n')[0]
   actual=[tuple(map(int,row))for row in re.findall(r'Vector2\(([-\d.]+),([-\d.]+)\),(\d+)',section)]
   self.assertEqual(Counter(actual),Counter(expected),side)

 def test_native_freyja_ground_index_contains_the_whole_decoded_map(self):
  width,height,ground,_,_=self.freyja
  serials=sorted(s for s in set(ground)-{0,100}if s in self.lookup and (self.lookup[s]['w'],self.lookup[s]['h'])==(64,47))
  slots={s:(i%32,i//32,255 if is_water(s)else 0,255)for i,s in enumerate(serials)}
  with Image.open(ROOT/'assets/maps/falan/freyja_ground_index.png')as index:
   self.assertEqual(index.size,(width,height))
   for s,pixel in zip(ground,index.getdata()):self.assertEqual(pixel,slots.get(s,(0,0,0,0)))

 def test_all_three_legacy_lists_preserve_the_exact_original_markers(self):
  for side,key in [('west','freyja'),('east','east_gate'),('south','south_gate')]:
   saved=json.loads((ROOT/f'tests/forest-shrine/reference/maps/forest_freyja_{side}_gate.json').read_text())
   expected={}
   for r in saved['props']+saved['trees']:
    if 140<=r['z']*6<=240 or r.get('kind')in('wall_piece','round_gate_tower'):
     expected[(r['x'],r['z'])]=(r.get('kind','tree'),r['scale'],r['rotation'])
   section=self.gates.split(f' "{key}":{{')[1].split('  "legacy":{')[1].split('\n  },')[0]
   actual={(int(x),int(z)):(kind,float(size),float(angle))for x,z,kind,size,angle in re.findall(r'Vector2i\((-?\d+),(-?\d+)\):\["([^"]+)",([\d.]+),([\d.]+)\]',section)}
   self.assertEqual(actual,expected,side)
