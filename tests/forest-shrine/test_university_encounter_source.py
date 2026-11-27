"""Guard source column meanings, complete boss chains and ice-state event transfers."""
import hashlib,json,re,sys,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import prepare_university_region_encounters as prepare

class UniversityEncounterSource(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.data=json.loads((prepare.OUT/'encounters.json').read_text())
  cls.enemies={r[2]:r for r in prepare.rows('enemy.txt')}

 def test_source_columns_and_sprite_ownership(self):
  for group in self.data['groups'].values():
   for member in group['details']:
    row=self.enemies[member['enemy']]
    self.assertEqual(member['exp_override'],int(row[9] or -1))
    self.assertNotIn('hp_override',member,'enemy.txt column nine is an experience override, never health')
    self.assertEqual(member['count'],list(map(int,row[6:8])))
  manifest=json.loads((ROOT/'assets/characters/crossgate/university_region/motions.json').read_text())
  self.assertEqual([r['id'] for r in manifest['variants']],[r['id'] for r in prepare.EXTRA])
  self.assertEqual(len(manifest['timelines']),len(prepare.EXTRA)*32*8)
  for name,digest in self.data['source_hashes'].items():self.assertEqual(hashlib.sha256((prepare.SOURCE/name).read_bytes()).hexdigest(),digest)

 def test_chained_battles_and_explicit_missing_final_form(self):
  def chain(start):
   found=[]
   while start:
    self.assertNotIn(start,found);found.append(start)
    row=self.data['bosses'][str(start)];start=row['next_encounter']
   return found
  self.assertEqual(chain(12012),[12012,12011])
  self.assertEqual(chain(12024),[12024])
  dijiro_group=self.data['bosses']['12024']['groups'][0][0]
  self.assertEqual(self.data['groups'][dijiro_group]['details'][0]['name'],'迪次郎')
  self.assertEqual(chain(308082),[308082,308083,308084])
  final=self.data['groups']['308135']['details'][0]
  actor=self.data['species'][final['species']]
  self.assertEqual((actor['id'],actor['bank']),(114063,'unavailable'))
  self.assertIn('no source attack contacts',actor['reason'])

 def test_every_ice_transfer_matches_its_source(self):
  raw=(prepare.OUT/'ice_events.gd').read_text();events=json.loads(raw.split('const EVENTS=',1)[1])
  self.assertEqual(len(events),44)
  for event in events.values():
   path=ROOT/'build/Other Files/Asset Toolkit/University Region/Source'/event['file']
   self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),event['sha256'])
   script='\n'.join(l for l in path.read_bytes().decode('gb18030').splitlines() if not l.lstrip().startswith('#'))
   if event['kind']=='candle':
    matches=re.findall(r'^\s*warp\s+0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',script,re.I|re.M)
    self.assertEqual(event['target'],list(map(int,matches[0])))
    self.assertRegex(script,r'(?i)Killitem 18574')
    self.assertRegex(script,r'(?i)Giveitem 18573')
  scale=self.data['quest_drops']['beast_scale']
  self.assertEqual((scale['raw'][16],scale['raw'][26],scale['percent']),('18446','10',10))
  for key,eid,item,rate in [('snow_alraune','12100',18567,100),('snow_mutant','12101',18579,80)]:
   drop=self.data['quest_drops'][key]
   self.assertEqual((drop['enemy'],drop['item'],drop['percent']),(eid,item,rate))
   self.assertEqual((drop['raw'][13],drop['raw'][23]),(str(item),str(rate)))

if __name__=='__main__':unittest.main()
