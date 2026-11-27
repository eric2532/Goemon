"""Compile only the documented ice-prison torch/state transfers, retaining source proofs."""
import hashlib,json,re
from pathlib import Path
import prepare_university_region_population as population

def main():
 result={}
 for line in (population.TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines():
  row=line.split('\t')
  if len(row)!=25 or not row[8].isdigit() or not 20501<=int(row[8])<=20530:continue
  name=row[24]
  if name not in ['EV_aoki_6582.txt','EV_aoki_6565.txt'] and not re.fullmatch(r'EV_aoki_66\d\d.txt|EV_aoki_659\d.txt',name):continue
  source=population.review.SOURCE/name
  if not source.is_file():continue
  script=source.read_bytes().decode('gb18030')
  commands='\n'.join(line for line in script.splitlines() if not line.lstrip().startswith('#'))
  warp=re.findall(r'^\s*warp\s+0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',commands,re.I|re.M)
  if name=='EV_aoki_6582.txt':kind='torch'
  elif name=='EV_aoki_6565.txt':kind='flame'
  elif warp and '18574' in commands and '18573' in commands:kind='candle'
  else:continue
  assert len(warp)<=1,name
  result[row[3]]=dict(kind=kind,source=int(row[8]),cell=list(map(int,row[9:11])),target=list(map(int,warp[0])) if warp else [],file=name,sha256=hashlib.sha256(source.read_bytes()).hexdigest())
 out=population.OUT/'ice_events.gd'
 out.write_text('extends RefCounted\n## Source-backed torch consumption and event-state map transfers.\nconst EVENTS='+json.dumps(result,ensure_ascii=False,indent=1)+'\n')
 print('UNIVERSITY_ICE_EVENTS',len(result))

if __name__=='__main__':main()
