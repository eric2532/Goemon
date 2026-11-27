"""The fixed gorge corridor and its rare strip retain the pinned source records."""
import base64
import hashlib
import json
from pathlib import Path
import sys
import unittest
import zlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib
from prepare_field_assets import navigation_grid
from prepare_snow_region_population import rows


class GorgeSource(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.population=json.loads((ROOT/'assets/maps/falan/sokia/population.json').read_text())
  cls.fixed=json.loads((ROOT/'assets/maps/falan/sokia/fixed/catalog.json').read_text())['maps']['BlueCrossgate/map/0/15526.dat']
 def test_entire_original_fixed_map_and_collision_mask(self):
  raw=(ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/15526.dat').read_bytes()
  self.assertEqual(zlib.decompress(base64.b64decode(self.fixed['raw'])),raw)
  self.assertEqual(self.fixed['sha256'],hashlib.sha256(raw).hexdigest())
  w,h,floor,objects,flags=lib.parse_map(raw)
  self.assertEqual((w,h),(100,20))
  opened=navigation_grid(w,h,floor,objects,lib.serial_index())
  bits=zlib.decompress(base64.b64decode(self.fixed['walk']))
  self.assertEqual([bool(bits[i>>3]&(1<<(i&7)))for i in range(w*h)],[bool(v)for v in opened])
  self.assertEqual(self.fixed['warp_cells'],[[i%w,i//w]for i,v in enumerate(flags)if v&2])
  cliffs=json.loads((ROOT/'assets/maps/falan/sokia/scenery/cliffs.json').read_text())
  self.assertEqual(cliffs['maps']['15526'],[[i%w,i//w,s+200000]for i,s in enumerate(objects)if 13080<=s<13116])
  mass=json.loads((ROOT/'assets/maps/falan/sokia/scenery/gorge-mass.json').read_text())
  self.assertEqual(mass['anchors'],[[i%w,i//w,s]for i,s in enumerate(objects)if 13080<=s<13116])
  self.assertEqual(mass['source_sha256'],hashlib.sha256(raw).hexdigest())
  self.assertEqual(mass['stair']['anchors'],[[8,7],[91,7]])
  for x,y in [(8,7),(91,7),(74,4),(74,5),(20,7)]:self.assertTrue(opened[y*w+x])
 def test_zone_bounds_priority_and_source_weighted_groups(self):
  source={int(r[0]):r for r in rows('encount.txt')if int(r[3])==15526}
  actual={z['id']:z for z in self.population['zones']if z['map']==15526}
  self.assertEqual(set(actual),{7044,7045})
  for ident,zone in actual.items():self.assertEqual(zone['raw'],source[ident])
  self.assertEqual([(actual[i]['bounds'],actual[i]['priority'],actual[i]['probability'],actual[i]['maximum'])for i in [7044,7045]],
                   [([0,0,99,19],1,[1,3],8),([74,4,74,5],10,[1,3],8)])
  self.assertEqual(actual[7044]['groups'],[['mountain:7036',1],['mountain:7033',1],['mountain:7035',1]])
  self.assertEqual(actual[7045]['groups'],[['mountain:7036',5],['mountain:7033',5],['mountain:7035',5],['mountain:7034',1]])
 def test_rare_ghost_does_not_collapse_same_appearance_source_enemy_ids(self):
  source={r[2]:r for r in rows('group.txt')}
  enemies={r[2]:r for r in rows('enemy.txt')}
  bases={r[1]:r for r in rows('enemybase.txt')}
  species=json.loads((ROOT/'assets/maps/falan/south_kili_route/population.json').read_text())['species']+self.population['extra_species']
  for gid in ['7033','7034','7035','7036']:
   group=self.population['groups']['mountain:'+gid]
   self.assertEqual(group['raw'],source[gid])
   expected=[]
   for i,eid in enumerate(source[gid][5:15]):
    if eid in ['','0']or not int(source[gid][15+i]or 0):continue
    enemy=enemies[eid];appearance=int(bases[enemy[3]][30])
    expected.append([appearance,int(enemy[4]),int(enemy[5]),int(source[gid][15+i])])
   self.assertEqual([[species[m[0]]['id'],*m[1:]]for m in group['members']],expected)
  rare=self.population['groups']['mountain:7034']
  self.assertEqual(rare['raw'][5:7],['7027','7026'])
  self.assertNotEqual(enemies['7027'],enemies['7026'])
  self.assertEqual(enemies['7027'][3],enemies['7026'][3])  # Separate level variants share base 122.
  self.assertEqual([[species[m[0]]['id'],*m[1:]]for m in rare['members']],[[101121,45,47,10],[101121,1,1,1]])
 def test_scripted_boss_resolves_encounter_before_group_and_stays_out_of_random_pool(self):
  base=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
  self.assertFalse(any(int(w[0])==15526 or int(w[3])==15526 for w in base['warps']))
  npc=next(r for r in rows('npc.txt')if r[3]=='5305')
  encounter=next(r for r in rows('encount.txt')if r[0]==npc[24].split('|')[9])
  self.assertEqual(encounter[0],'12020');self.assertEqual(encounter[14],'12098')
  group=next(r for r in rows('group.txt')if r[2]==encounter[14])
  enemy=next(r for r in rows('enemy.txt')if r[2]==group[5])
  appearance=next(r for r in rows('enemybase.txt')if r[1]==enemy[3])[30]
  self.assertEqual((npc[20],appearance),('101532','101532'))
  self.assertEqual(group[25:28],['1','1','1'])
  self.assertNotIn('12020',self.population['groups'])
  self.assertNotIn('mountain:12020',self.population['groups'])
 def test_solid_rock_paint_has_no_sprite_cutout_holes_or_foreign_family(self):
  folder=ROOT/'assets/maps/falan/sokia/scenery'
  data=json.loads((folder/'gorge-mass.json').read_text());atlas=Image.open(folder/'gorge-mass.png')
  self.assertEqual(set(data['wall_tiles']),set(data['profiles']))
  lookup=lib.serial_index()
  for family in [13080,13092,13104]:
   record=data['wall_paint_sources'][str(family)];serial=record['serial']
   self.assertTrue(family<=serial<family+12)
   original=lib.image_from_record(lookup[serial]['pack'],lookup[serial]['row'])
   self.assertEqual(record['source_rgba_sha256'],hashlib.sha256(original.tobytes()).hexdigest())
   x,y,w,h=data['wall_tiles'][str(serial)]
   self.assertEqual(atlas.crop((x,y,x+w,y+h)).getchannel('A').getextrema(),(255,255))


if __name__=='__main__':unittest.main()
