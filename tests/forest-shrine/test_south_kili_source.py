"""Independent pinned-table, native-art and original warp checks for the locked route."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_snow_region_population import rows, SOURCE, ARCHIVE
from build_freyja_destinations import warp_rows
DATA=ROOT/'assets/maps/falan/south_kili_route/population.json'

class SouthKiliSource(unittest.TestCase):
 def test_venoa_undersea_all_three_source_zones(self):
  d=json.loads(DATA.read_text());zones={int(z['map']):z for z in d['zones'] if int(z['map']) in [15592,15593,15594]}
  self.assertEqual(set(zones),{15592,15593,15594})
  self.assertEqual({int(z['id']) for z in zones.values()},{5044,5045,5046})
  for z in zones.values():
   self.assertEqual(z['groups'],[['5040',1]]);self.assertEqual(z['probability'],[1,3]);self.assertEqual(z['maximum'],5)
  members=[[d['species'][m[0]]['id'],*m[1:]]for m in d['groups']['5040']['members']]
  self.assertEqual(members,[[101721,26,27,1],[101700,26,27,1]])
 def test_npc_source_cells_directions_and_native_pixels(self):
  sys.path.insert(0,str(ARCHIVE/'tools'));import cg_library as lib;import cg_assets as cg
  d=json.loads(DATA.read_text());atlas=Image.open(DATA.with_name('npc-atlas.png')).convert('RGBA')
  records={r[3]:r for r in rows('npc.txt') if len(r)>24};lookup=lib.serial_index();catalog={r['key']:r for r in cg.catalog()['entries']}
  self.assertEqual(len(d['npcs']),19)
  for n in d['npcs']:
   raw=records[n['id']]
   self.assertEqual([n['source'],*n['cell'],n['direction'],n['graphic']],[int(raw[8]),int(raw[9]),int(raw[10]),int(raw[19])%8,int(raw[20])])
   self.assertEqual(n['name'],raw[1]);self.assertTrue(n['messages'])
   art=d['art'][n['token']]
   if n['graphic']<100000:
    g=lookup[n['graphic']];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y']
   else:
    self.assertEqual(catalog[art['key']]['id'],n['graphic'])
    _,_,clips=cg.actor(art['key']);clip=next(c for c in clips if c['action']==0 and c['direction']==n['direction'])
    im,ox,oy=cg.frame_parts(art['key'],clip['index'],0)
   box=im.getbbox();expected=im.crop(box).convert('RGBA');x,y,w,h=art['rect']
   self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes())
   self.assertEqual(art['origin'],[ox+box[0],oy+box[1]])
 def test_source_group_weights_levels_and_prepared_native_banks(self):
  d=json.loads(DATA.read_text())
  for name,sha in d['source_hashes'].items():self.assertEqual(hashlib.sha256((SOURCE/name).read_bytes()).hexdigest(),sha)
  zones={int(r[0]):r for r in rows('encount.txt')}
  for z in d['zones']:
   raw=zones[z['id']]
   self.assertEqual([z['map'],*z['bounds'],*z['probability'],z['maximum'],z['priority']],list(map(int,raw[3:12])))
   expected=[[gid,int(raw[24+i])] for i,gid in enumerate(raw[14:24]) if gid and int(raw[24+i] or 0)]
   self.assertEqual(z['groups'],expected)
   self.assertNotEqual(z['map'],3200)
  enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')}
  for group in d['groups'].values():
   raw=group['raw'];expected=[]
   for i,eid in enumerate(raw[5:15]):
    if not eid or eid=='0' or not int(raw[15+i] or 0):continue
    e=enemies[eid];expected.append([int(bases[e[3]][30]),int(e[4]),int(e[5]),int(raw[15+i])])
   self.assertEqual([[d['species'][m[0]]['id'],*m[1:]] for m in group['members']],expected)
  for species in d['species']:
   bank=json.loads((ROOT/f"assets/characters/crossgate/{species['family']}/motions.json").read_text())
   self.assertEqual(bank['variants'][species['skin']]['id'],species['id'])
  old=json.loads((ROOT/'assets/characters/crossgate/habaru/motions.json').read_text());new=json.loads((ROOT/'assets/characters/crossgate/venoa_route/motions.json').read_text())
  self.assertEqual(new['variants'][:5],old['variants'])
  for i in range(5*8):
   a=old['timelines'][i*28:(i+1)*28];b=new['timelines'][i*32:(i+1)*32]
   self.assertEqual([a[0],a[1],*a[2:28:2]],[b[0],b[1],*b[2:28:2]])
 def test_oznik_gates_and_mandatory_party_identities(self):
  d=json.loads(DATA.read_text());groups=d['groups']
  self.assertEqual(groups['9033']['raw'][3:5],['-1','18403'])
  self.assertEqual(groups['9034']['raw'][3:5],['18403','-1'])
  for gid,eid in [('9033','9067'),('9034','9068')]:
   members=groups[gid]['source_members']
   self.assertEqual([m['enemy_id'] for m in members],[eid,'5013','5015'])
   self.assertEqual([m['count'] for m in members],[[1,1],[1,10],[1,10]])
   self.assertTrue(all(m['mandatory'] for m in members))
 def test_original_full_route_and_preserved_map_planes(self):
  warps=set(warp_rows(ARCHIVE))
  for row in [(1000,153,241,100,424,259),(11000,20,14,100,471,317),(11000,20,59,11001,34,14),(11001,24,81,11002,35,10),(11002,26,64,100,442,349),(15005,10,5,100,343,497),(15005,18,34,15003,49,46),(15003,27,29,15004,24,13),(15004,11,44,300,240,265),(300,274,294,3200,59,46)]:self.assertIn(row,warps)
  baseline=json.loads((ROOT/'build/Other Files/Asset Toolkit/South Gate Kili Route/baseline.json').read_text())
  for p in ['assets/maps/falan/freyja_destinations_data.gd','assets/maps/falan/freyja_npc_data.gd','scripts/forest/crowd/undersea_sprites.gd','scripts/forest/forest_freyja_regions.gd']:
   self.assertEqual(hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),baseline[p])

if __name__=='__main__':unittest.main()
