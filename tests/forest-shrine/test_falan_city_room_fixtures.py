"""Keep the six omitted city rooms tied to their original object layer."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT.parent/'Magic Power/tools')]
import cg_library as library
from build_falan_room_art import WALLS
from build_freyja_destinations import load_map


class OriginalCityFixtures(unittest.TestCase):
 def test_every_original_object_keeps_its_station_and_footprint(self):
  data=json.loads((ROOT/'assets/maps/falan/city_room_fixtures.json').read_text())
  lookup=library.serial_index();total=0
  self.assertEqual(set(map(int,data['maps'])),{1810,1811,1156,1182,1181,1172})
  for ident,row in data['maps'].items():
   w,_,_,objects,_=load_map(library,int(ident))
   expected=[(i%w,i//w,s) for i,s in enumerate(objects) if s>=1000 and s not in WALLS]
   self.assertEqual([(p['source_cell'][0],p['source_cell'][1],p['graphic']) for p in row['placements']],expected)
   for p in row['placements']:
    e=lookup[p['graphic']];x,y=p['source_cell'];ew,ns=max(1,e['east']),max(1,e['south'])
    self.assertEqual(p['cell'],[y-ns+1,w-x-ew]);self.assertEqual(p['span'],[ns,ew])
   total+=len(expected)
  self.assertEqual(total,193)
  for s,g in data['graphics'].items():
   e=lookup[int(s)];im=library.image_from_record(e['pack'],e['row'],0)
   self.assertEqual(hashlib.sha256(im.tobytes()).hexdigest(),g['rgba_sha256'])


if __name__=='__main__':unittest.main()
