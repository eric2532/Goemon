"""Add source-backed regional encounter data; reuse native sprite and companion banks."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/crossgate_tina/events'
OUT=ROOT/'assets/maps/falan/university_region'
ARCHIVE=ROOT.parent/'Magic Power'
EXTRA=[dict(id=i,key=k,name=n,height=h) for i,k,n,h in [
 (101502,'original:2898','果凍史萊姆',.7),
 (101803,'original:2947','烈風哥布林',.7),
 (101823,'original:2955','破壞狂',1.),
 (110750,'puk2:332','青龍',2.),
 (101911,'original:2969','佛利波羅',1.8),
 (100602,'original:2755','阿魯巴斯',1.1),
 (101213,'original:2845','惡魔',1.1),
 (101212,'original:2844','墮天使',1.1),
 (101420,'original:2887','綠色口臭鬼',.8),
 (101521,'original:2905','寶貝炸彈',.6),
 (101204,'original:2840','迷你石像怪',.8),
 (101241,'original:2848','掃把蝙蝠',.85),
 (105046,'ex:45','希爾弗',1.2),
 (101500,'original:2896','史萊姆',.7),
 (101501,'original:2897','液態史萊姆',.7),
 (101503,'original:2899','布丁史萊姆',.7),
 (101413,'original:2886','人魔草',.8),
]]
UNPREPARED={114063:dict(key='v3:162',reason='The final Sylph form has no source attack contacts or death clip. This is a seated rider-only sheet; classic quest references show the final phase riding a Sahagin blade. The original mount binding, offsets and contact timeline are unavailable; do not substitute an unmounted or fabricated melee actor.')}
BOSS_ENCOUNTERS=[40314,12009,12012,10009,10006,12023,12024,12025,12026,12027,308082]
GENERATED={'scientist':16001,'mountain':16003,'lizard':12010,'tunnel':16004,'permafrost':16005,'abyss':16006}

def rows(name):
 return [r.split('\t') for r in (SOURCE/name).read_bytes().decode('gb18030').splitlines() if r and not r.startswith('#')]

def build(pack=False):
 sys.path.insert(0,str(ARCHIVE/'tools'))
 import cg_assets as cg
 data=dict(schema=1,species=[],zones=[],groups={},road_scope=[],limits=[])
 bank=EXTRA.copy()
 data['species']=bank.copy()
 for i,s in enumerate(data['species']):s.update(skin=i,bank='university')
 skins={s['id']:i for i,s in enumerate(data['species'])}
 pets=json.loads((ROOT/'assets/characters/crossgate/guard_pets/motions.json').read_text())['variants']
 pet_skins={r['key']:i for i,r in enumerate(pets)}
 catalog=cg.catalog()['entries'];by_appearance={}
 for r in catalog:
  if r['key'] in pet_skins:by_appearance.setdefault(r['id'],r['key'])
 enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')};groups={r[2]:r for r in rows('group.txt')}
 fixed={r['source'] for r in json.loads((ROOT/'build/Other Files/Asset Toolkit/University Region/scope.json').read_text())['fixed']}
 # Those maps already have working encounter owners; append only missing branches.
 fixed-={400,402,14000,14001,14002,15522,*range(24008,24075)}
 generated={};bosses={};blocked=[]
 def species(base):
  appearance=int(base[30])
  if appearance not in skins:
   if appearance in UNPREPARED:
    skins[appearance]=len(data['species']);data['species'].append(dict(id=appearance,name=base[0],skin=-1,bank='unavailable',**UNPREPARED[appearance]));return skins[appearance]
   key=by_appearance.get(appearance)
   if not key:raise ValueError(('Unprepared regional actor',appearance,base[0]))
   skins[appearance]=len(data['species'])
   data['species'].append(dict(id=appearance,key=key,name=base[0],skin=pet_skins[key],bank='companion',height=1.))
  return skins[appearance]
 def group(gid):
  if gid in data['groups']:return
  g=groups[gid];members=[];details=[]
  for j,eid in enumerate(g[5:15]):
   weight=int(g[15+j] or 0)
   if eid in ['', '0'] or not weight:continue
   e=enemies[eid];b=bases[e[3]];index=species(b)
   members.append([index,int(e[4]),int(e[5]),weight])
   details.append(dict(species=index,name=b[0],enemy=eid,level=[int(e[4]),int(e[5])],count=[int(e[6]),int(e[7])],exp_override=int(e[9] or -1),drop=e[13],raw_enemy=e,raw_base=b))
  data['groups'][gid]=dict(members=members,order=g[1],raw=g,details=details)
 encounter_rows=rows('encount.txt');boss_ids=set(BOSS_ENCOUNTERS)
 while True:
  linked={int(r[12]) for r in encounter_rows if int(r[0]) in boss_ids and r[12].isdigit() and int(r[12])>0 and int(r[13] or 0)>0}
  if linked<=boss_ids:break
  boss_ids|=linked
 for r in encounter_rows:
  eid=int(r[0]);map_id=int(r[3])
  if map_id not in fixed and eid not in boss_ids and eid not in GENERATED.values():continue
  chosen=[]
  for i,gid in enumerate(r[14:24]):
   weight=int(r[24+i] or 0)
   if not gid or not weight:continue
   group(gid);chosen.append([gid,weight])
  zone=dict(id=eid,map=map_id,bounds=list(map(int,r[4:8])),probability=list(map(int,r[8:10])),maximum=int(r[10]),priority=int(r[11]),groups=chosen,raw=r)
  if eid in boss_ids:
   zone.update(next_encounter=int(r[12] or 0),next_probability=int(r[13] or 0));bosses[str(eid)]=zone
  elif eid in GENERATED.values():generated[next(k for k,v in GENERATED.items() if v==eid)]=zone
  elif chosen:data['zones'].append(zone)
  # Preserve unresolved event/item conditions as explicit evidence rather than dropping a pool.
  if any(v not in ['', '0','-1'] for v in r[12:14]):blocked.append(dict(kind='encounter_condition',id=eid,raw=r[12:14]))
 data.update(generated=generated,bosses=bosses,bank_count=len(bank),regional_conditions=blocked)
 scale=enemies['16001'];assert scale[16]=='18446' and scale[26]=='10'
 data['quest_drops']={'beast_scale':dict(enemy='16001',key='original:2935',item=18446,percent=int(scale[26]),raw=scale,
  allocation_reference='https://www.bluecg.net/blog-184941-3472.html')}
 for key,eid in [('snow_alraune','12100'),('snow_mutant','12101')]:
  enemy=enemies[eid]
  data['quest_drops'][key]=dict(enemy=eid,item=int(enemy[13]),percent=int(enemy[23]),raw=enemy)
 data['limits']+=['Source random-dungeon level ranges override level-one template rows. Existing native combat profiles adapt turn-based parameters; source spells/turn order are not reconstructed by encounter data alone.',
 'Random encounter group counts retain the existing uniform shuffle-bag adaptation up to the source maximum; original count weights are unavailable.',
 'Added sprite proportions are authored relative to Kaz; native frames, origins, contacts and cues are preserved.']
 data['source_hashes']={n:hashlib.sha256((SOURCE/n).read_bytes()).hexdigest() for n in ['encount.txt','group.txt','enemy.txt','enemybase.txt']}
 (OUT/'encounters.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'species.json').write_text(json.dumps(bank,ensure_ascii=False,indent=2)+'\n')
 if pack:
  from recover_habaru_encounter import recover
  recover(ARCHIVE,shalena=True,species_override=bank,output_override=ROOT/'assets/characters/crossgate/university_region')
 print('UNIVERSITY_ENCOUNTERS',len(bank),'sprite variants,',len(data['species']),'species,',len(data['zones']),'fixed zones,',len(generated),'generated pools,',len(bosses),'boss pools')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pack',action='store_true');a=p.parse_args();build(a.pack)
