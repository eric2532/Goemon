"""Cross-check local NPC transfers and terminal generated actors without treating labels as entrances."""
import hashlib,json,re
from pathlib import Path
import prepare_university_region_population as population

ROOT=population.ROOT
OUT=population.review.OUT
NATIVE_OWNERS={**{str(n):'existing native cursed guardian/seal owner' for n in range(6402,6407)},
               '6337':'existing native Beast/seal owner','6400':'original blade-consuming stone crossing',
               '808122':'source five-stamp campus portal to the local Sylph chamber'}
NATIVE_OWNERS.update({n:'existing campus doors select32269 only for the exact source item qualifications' for n in ['1102307','1102309','1102310','1102311']})
SPECIFIC_BLOCKERS={
 '6215':'Original job/skill/title/paid-material examination conditions are not represented by Explore; do not replace them with a free classroom entrance.',
 '6216':'Original second examination career/material conditions are not represented by Explore; no free pass to4421.',
 '6217':'Original second examination career/material conditions are not represented by Explore; no free pass to4421.',
 '6250':'Campus4400 has no compatible recovered ground for the original grave approach; do not move the grave or fill from another version.',
 '1102644':'Azure post-fight32154 layout is unavailable; the whole Azure trigger is withheld.',
}

def main():
 scope=json.loads((OUT/'scope.json').read_text());maps={r['source'] for r in scope['fixed']}
 prepared={}
 for folder in ['snow_region','university_region']:
  for r in json.loads((ROOT/'assets/maps/falan'/folder/'population.json').read_text())['npcs']:
   if r.get('quest_action'):prepared[r['id']]=r['quest_action']
 records=[];by_id={}
 tree={r['path']:r for r in json.loads((population.review.SOURCE/'tree-index.json').read_text())['tree']}
 for line in (population.TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines():
  row=line.split('\t')
  if len(row)!=25:continue
  by_id[row[3]]=row
  if not row[8].isdigit() or int(row[8]) not in maps or row[0].startswith('#') or row[6]!='1':continue
  if row[8]=='59752' and row[3] not in ['808112','808113']:continue
  x,y=map(int,row[9:11])
  if row[8]=='400' and not(110<=x<620 and 170<=y<480):continue
  if row[8]=='4100' and not(45<=x<78 and 115<=y<140):continue
  if not row[24].endswith('.txt'):continue
  script=population.review.SOURCE/row[24]
  record=dict(actor=row[3],name=row[1],source=int(row[8]),cell=list(map(int,row[9:11])),type=row[0],file=row[24],
              runtime_action=prepared.get(row[3],population.QUEST_ACTIONS.get(row[3],'')),native_owner=NATIVE_OWNERS.get(row[3],''))
  if not script.is_file():
   available=[p for p in tree if p.endswith('/'+row[24])]
   record['source_gap']='UNFETCHED pinned script: '+available[0] if available else 'Script absent from the pinned repository tree'
   records.append(record);continue
  raw=script.read_bytes();commands='\n'.join(l for l in raw.decode('gb18030').splitlines() if not l.lstrip().startswith('#'))
  record.update(sha256=hashlib.sha256(raw).hexdigest(),conditions=re.findall(r'^\s*block\s+(.+)$',commands,re.M|re.I),
                transfers=[list(map(int,m)) for m in re.findall(r'^\s*warp\s+0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',commands,re.I|re.M)],
                encounters=re.findall(r'^\s*encount\s+(.+)$',commands,re.M|re.I))
  if row[3] in SPECIFIC_BLOCKERS:record['blocker']=SPECIFIC_BLOCKERS[row[3]]
  elif record['transfers'] and not record['runtime_action'] and not record['native_owner']:
   record['limit']='One-line NPC restored; optional transaction/quest details have not been implemented. Inspect before certifying its transfer.'
  records.append(record)
 terminals=[]
 for line in (population.review.SOURCE/'dungeonconf.txt').read_bytes().decode('gb18030').splitlines():
  row=line.split('\t')
  if len(row)<101 or row[3] not in ['400','401','402','403','404','406','407']:continue
  record=dict(config=int(row[3]),name=row[0],stand_enemy=row[97],count=row[98],replacement_npc=row[99],placement=row[100])
  for key in ['stand_enemy','replacement_npc']:
   if record[key] and record[key] in by_id:record[key+'_raw']=by_id[record[key]]
  terminals.append(record)
 result=dict(fixed_maps=len(scope['fixed']),event_actors=records,generated_terminal_fields=terminals,
             limits=['Script audit only. Actual controller movement/F entry, source layout, native combat and post-fight exit are independent requirements.',
                     'Map59752 includes only the two local Sylph rooms; holding-map777 terminal actor coordinates are templates, not new regional fixed maps.',
                     'A one-line NPC is authorized for ordinary residents; missing examination conditions remain specific blockers, not free entrances.'])
 (OUT/'event-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 unfetched=[r['file'] for r in records if r.get('source_gap','').startswith('UNFETCHED')]
 if unfetched:raise RuntimeError('Fetch available pinned evidence before declaring a source blocker: '+', '.join(unfetched))
 print('UNIVERSITY_EVENT_AUDIT',len(records),'scripted actors,',len(terminals),'dungeon configurations')
 for r in records:
  if r.get('blocker') or r.get('limit'):print(r['source'],r['actor'],r['name'],r.get('blocker',r.get('limit')))

if __name__=='__main__':main()
