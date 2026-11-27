"""Read-only original100Il-gate topology and all locally available incoming cues."""
import hashlib,json,re,struct,sys
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region';OUT=B/'Il Source Completion/Water Walk Candidate'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def inside(p):return p is not None and 636<=int(p[0])<=725 and 312<=int(p[1])<=422
def run():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib;from prepare_field_assets import navigation_grid
 source=B/'Version Expansion Source Audit/map__00100_field1';raw=source.read_bytes();w,h=struct.unpack_from('>HH',raw,40);n=w*h;ground=struct.unpack_from('>'+str(n)+'H',raw,44);objects=struct.unpack_from('>'+str(n)+'H',raw,44+n*2);walk=navigation_grid(w,h,ground,objects,lib.serial_index());rows=[]
 warpath=B/'Source Audit/warp.txt'
 for line,s in enumerate(warpath.read_bytes().decode('gb18030').splitlines(),1):
  try:f=list(map(int,s.split()[:7]))
  except ValueError:continue
  if len(f)==7:rows.append(dict(line=line,id=f[0],source=f[1],cell=f[2:4],target=f[4],landing=f[5:7],kind='fixed warp'))
 npcpath=B/'Source Audit/npc-index.txt';actors=[];inline=[]
 for line,s in enumerate(npcpath.read_bytes().decode('gb18030').splitlines(),1):
  f=s.split('\t')
  if len(f)!=25 or not f[8].isdigit()or not f[3].isdigit():continue
  active=not f[0].startswith('#')and f[6]=='1'
  if not active:continue
  actor=dict(line=line,id=int(f[3]),kind=f[0],name=f[1],map=int(f[8]),cell=list(map(int,f[9:11])),program=f[24]);actors.append(actor)
  for hit in re.findall(r'(?:^|\|)0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',f[24]):
   target,x,y=map(int,hit)
   if target==100 and inside((x,y)):inline.append(dict(actor=actor,target=target,landing=[x,y],kind='inline tuple; original actor conditions retained'))
  if f[0]=='Warp':
   values=f[24].split('|')
   if len(values)>3 and all(v.isdigit()for v in values[1:4])and int(values[1])==100 and inside(values[2:4]):inline.append(dict(actor=actor,target=100,landing=list(map(int,values[2:4])),kind='inline Warp'))
 fixed=[r for r in rows if r['target']==100 and inside(r['landing'])];outgoing=[r for r in rows if r['source']==100];trigger={r['cell'][1]*w+r['cell'][0]for r in outgoing};il=343*w+681
 def component(removed):
  start=196*w+475;assert walk[start];seen=bytearray(n);seen[start]=1;queue=deque([start])
  while queue:
   i=queue.popleft();x=i%w;y=i//w
   for j in([i-1]if x else[])+([i+1]if x<w-1 else[])+([i-w]if y else[])+([i+w]if y<h-1 else[]):
    if walk[j]and not seen[j]and j not in removed:seen[j]=1;queue.append(j)
  return seen
 single=component({il});allfixed=component(trigger);samples=[];control=[];stats={}
 for y in range(312,423):
  for x in range(636,726):
   i=y*w+x;r=dict(cell=[x,y],ground=ground[i],object=objects[i],native_walk=bool(walk[i]),reachable_without_il_trigger=bool(single[i]),reachable_without_all_fixed_triggers=bool(allfixed[i]));samples.append(r)
   if objects[i]==252:control.append(r)
 # Scan every SHA-pinned script actually present across the current audited
 # goals, then explicitly record that scope rather than assert unseen scripts.
 scripts={}
 for manifest in (ROOT/'build/Other Files/Asset Toolkit').rglob('references.json'):
  try:refs=json.loads(manifest.read_text())
  except (ValueError,OSError):continue
  if not isinstance(refs,list):continue
  for r in refs:
   if not isinstance(r,dict)or not r.get('path','').startswith('gmsv/data/npc/')or not r.get('file'):continue
   p=manifest.parent/r['file']
   if p.is_file():scripts[r['path']]=p
 incoming_scripts=[]
 for name,p in scripts.items():
  for line,s in enumerate(p.read_bytes().decode('gb18030',errors='replace').splitlines(),1):
   if s.lstrip().startswith(('#','//',';')):continue
   for x,y in re.findall(r'(?:\b|\|)0\s*,\s*100\s*,\s*(\d+)\s*,\s*(\d+)',s):
    if inside((x,y)):incoming_scripts.append(dict(script=name,line=line,command=s.strip(),landing=[int(x),int(y)],script_sha256=sha(p.read_bytes()),actor_instances=[a for a in actors if a['program']==Path(name).name]))
 dungeonpath=B/'Source Audit/dungeonconf.txt';dungeons=[]
 for line,s in enumerate(dungeonpath.read_bytes().decode('gb18030').splitlines(),1):
  f=s.split('\t')
  if len(f)<117 or f[0].startswith('#')or not f[3].isdigit():continue
  if f[15].isdigit()and int(f[15])==100 and all(v.isdigit()for v in f[16:18])and inside(f[16:18]):dungeons.append(dict(line=line,config=int(f[3]),title=f[0],target=100,landing=list(map(int,f[16:18]))))
 for name,field in [('native_open','native_walk'),('outside_reachable_without_il_trigger','reachable_without_il_trigger'),('outside_reachable_without_all_fixed_triggers','reachable_without_all_fixed_triggers')]:stats[name]=sum(r[field]for r in samples)
 def landed(p):
  x,y=map(int,p);i=y*w+x;return dict(cell=[x,y],native_walk=bool(walk[i]),outside_reachable_without_il_trigger=bool(single[i]),outside_reachable_without_all_fixed_triggers=bool(allfixed[i]))
 for r in fixed+inline+dungeons:r['component']=landed(r['landing'])
 for r in incoming_scripts:r['component']=landed(r['landing'])
 result=dict(scope='Read-only complete840x610original100ground+PG1cardinal graph using the existing original graphic-attribute/footprint navigation_grid. Instant gate trigger removed; also a separate all-fixed-trigger lower-bound graph. No game changes/runs.',source_map_sha256=sha(raw),source_size=[w,h],source_npc_sha256=sha(npcpath.read_bytes()),source_warp_sha256=sha(warpath.read_bytes()),navigation_contract='Magic Power/tools/prepare_field_assets.py::navigation_grid; server/event conditions and actor physical collision remain separate.',outside_seed=[475,196],window=[636,312,725,422],stats=stats,original_control252=control,all_window_cells=samples,global_fixed_incoming=fixed,global_inline_incoming=inline,global_generator_end_incoming=dungeons,pinned_script_file_count=len(scripts),available_script_incoming=incoming_scripts,active_actor_spawns_inside=[a for a in actors if a['map']==100 and inside(a['cell'])],instant_field_triggers=len(trigger),gate_cells=[landed([681,343]),landed([682,343]),landed([680,343])],limits='Global fixed/inline/generator tables were scanned completely. Event-script scan covers only the explicit SHA-pinned script files present locally across current goals; dynamic/unfetched external-region scripts are not claimed absent. Reachability is static cardinal source terrain/prop evidence, not a quest-state or rendered runtime proof.')
 OUT.mkdir(parents=True,exist_ok=True);(OUT/'100-il-trigger-topology.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('IL_HOST_TOPOLOGY',stats,'control252',len(control),'fixed',len(fixed),'inline',len(inline),'generator',len(dungeons),'scripts',len(incoming_scripts),'actors',len(result['active_actor_spawns_inside']))
if __name__=='__main__':run()
