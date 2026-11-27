"""Independent source/placement/atlas and preservation checks for the eleven-map pass."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/Other Files/Asset Toolkit/Snow Region Restoration'
DATA=ROOT/'assets/maps/falan/snow_region/population.json'
SOURCE=ROOT/'assets/references/crossgate_tina/events'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

class SnowPopulationSource(unittest.TestCase):
 def test_reference_identities_and_original_npc_pixels(self):
  d=json.loads(DATA.read_text());atlas=Image.open(DATA.with_name('npc-atlas.png')).convert('RGBA')
  records={r[3]:r for line in (SOURCE/'npc.txt').read_bytes().decode('gb18030').splitlines() if len(r:=line.split('\t'))>24 and not r[0].startswith('#')}
  self.assertEqual(len(d['npcs']),42)
  for n in d['npcs']:
   raw=records[n['id']]
   self.assertEqual([n['source'],*n['cell'],n['direction'],n['graphic']],[int(raw[8]),int(raw[9]),int(raw[10]),int(raw[19])%8,int(raw[20])])
   self.assertEqual(n['name'],raw[1]);self.assertTrue(n['messages'])
   art=d['art'][n['token']];x,y,w,h=art['rect']
   self.assertEqual(hashlib.sha256(atlas.crop((x,y,x+w,y+h)).tobytes()).hexdigest(),art['rgba_sha256'])
  farm=[n for n in d['skipped'] if 'walkable ground' in n['reason']]
  self.assertEqual({n['id'] for n in farm},{'2066','60212','62018','62019'})
 def test_encounter_regions_weights_and_safe_areas(self):
  d=json.loads(DATA.read_text())
  for name,value in d['source_hashes'].items():self.assertEqual(digest(SOURCE/name),value)
  rows={int(r[0]):r for line in (SOURCE/'encount.txt').read_bytes().decode('gb18030').splitlines() if len(r:=line.split('\t'))>24 and not r[0].startswith('#')}
  for z in d['zones']:
   self.assertNotIn(z['map'],[4000,4300,4400])
   if z.get('adapted'):continue
   raw=rows[z['id']]
   self.assertEqual([z['map'],*z['bounds'],*z['probability'],z['maximum'],z['priority']],list(map(int,raw[3:12])))
   self.assertEqual(z['groups'],[[gid,int(raw[24+i])] for i,gid in enumerate(raw[14:24]) if gid and int(raw[24+i] or 0)])
  self.assertEqual(d['groups']['12089']['fixed'],[[19,51],[20,49],[20,49],[20,49]])
  self.assertEqual({m[0] for g in ['8026','8023','8025'] for m in d['groups'][g]['members']},{16,17})
 def test_map_layout_travel_and_baseline_assets_preserved(self):
  before=json.loads((OUT/'baseline.json').read_text())
  protected=['scripts/forest/forest_original_maps.gd','scripts/forest/forest_explorer_travel.gd','scripts/forest/forest_original_snow.gd','scripts/forest/forest_frostpass.gd','assets/maps/original_crossgate/catalog.json','assets/maps/falan/tina/encounters.json','assets/maps/falan/snow_region/scenery.json']
  for name in protected:self.assertEqual(digest(ROOT/name),before[name],name)
  d=json.loads(DATA.read_text());motions=json.loads((ROOT/'assets/characters/crossgate/snow_region/motions.json').read_text())
  self.assertEqual([r['id'] for r in motions['variants']],[r['id'] for r in d['species']])
  self.assertEqual(len(motions['timelines']),21*8*32)

if __name__=='__main__':unittest.main()
