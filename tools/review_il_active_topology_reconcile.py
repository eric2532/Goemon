import sys,json,hashlib,struct
from pathlib import Path
from collections import Counter,deque
R=Path(__file__).resolve().parents[1];sys.path[:0]=[str(R/'tools'),str(R.parent/'Magic Power/tools')]
import cg_library as lib
from build_freyja_destinations import load_map
from prepare_field_assets import navigation_grid
B=R/'build/Other Files/Asset Toolkit/East Gate Region';out=B/'Il Source Completion/Water Walk Candidate/100-il-trigger-topology.json';d=json.loads(out.read_text());w,h,g,o,flags=load_map(lib,100);n=w*h;nav=navigation_grid(w,h,g,o,lib.serial_index());source=R.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/100.dat';arch=lib.parse_map(source.read_bytes());rows=d['all_window_cells'];diff=[];counts=Counter();controls=[];archive_diffs={label:sum(x!=y for x,y in zip(a,b))for label,a,b in zip(['ground','object','client_flags'],(g,o,flags),arch[2:])}
triggers={343*w+681}
seen=bytearray(n);start=196*w+475;seen[start]=1;q=deque([start])
while q:
 i=q.popleft();x=i%w;y=i//w
 for j in([i-1]if x else[])+([i+1]if x<w-1 else[])+([i-w]if y else[])+([i+w]if y<h-1 else[]):
  if nav[j]and not seen[j]and j not in triggers:seen[j]=1;q.append(j)
for r in rows:
 x,y=r['cell'];i=y*w+x;known=bool(flags[i]&0xc000);active=[g[i],o[i]];pinned=[r['ground'],r['object']];counts['recorded'if known else'unknown']+=1;counts['active_open']+=bool(nav[i]);counts['active_outside_reachable_without_il_trigger']+=bool(seen[i])
 if active!=pinned or bool(nav[i])!=r['native_walk']:
  status='recorded_tuple_variant'if known and active!=pinned else'unknown_tuple'if not known and active!=pinned else'neighbor_footprint_walk_only';counts[status]+=1;diff.append(dict(cell=[x,y],active=active,pinned=pinned,client_flags=int(flags[i]),recorded=known,active_open=bool(nav[i]),pinned_open=r['native_walk'],status=status))
 if r['native_walk']and not nav[i]:counts['pinned_extra_open']+=1;counts['extra_open_recorded'if known else'extra_open_unknown']+=1
 if nav[i]and not r['native_walk']:counts['active_extra_open']+=1
 if o[i]==252:controls.append(dict(cell=[x,y],native_walk=bool(nav[i]),outside_reachable_without_il_trigger=bool(seen[i])))
# Same original control drawing in the translated native Il map; this selects
# the requested overlap, not every252marker in the much larger previewwindow.
ilrow=json.loads((R/'assets/maps/original_crossgate/east/catalog.json').read_text())['maps']['BlueCrossgate/map/0/2000.dat'];from review_east_backgrounds import decode
iw,ih,iraw,values,bits,aliases=decode(ilrow);total=iw*ih;matching=[]
for c in controls:
 x,y=c['cell'];xx=x-636;yy=y-312
 if 0<=xx<iw and 0<=yy<ih and values[total+yy*iw+xx]==252:matching.append(c)
assert not counts['recorded_tuple_variant'], 'Do not silently substitute a pinned source variant'
d['control252_summary']={'count':len(d['original_control252']),'native_open':sum(r['native_walk']for r in d['original_control252']),'outside_reachable_without_il_trigger':sum(r['reachable_without_il_trigger']for r in d['original_control252'])}
d['active100_reconciliation']=dict(active_vs_archive_plane_differences=archive_diffs,active_owner='build_freyja_destinations.load_map(lib,100) (prepared100 remains inactive)',archive_path=str(source),archive_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),active_equals_archived=all(list(a)==list(b)for a,b in zip((g,o,flags),arch[2:])),counts=dict(counts),tuple_or_walk_differences=diff,active_control252_count=len(controls),active_control252_outside_connected=sum(c['outside_reachable_without_il_trigger']for c in controls),translated_il_control252_overlap=matching,overlap_count=len(matching),overlap_outside_connected=sum(c['outside_reachable_without_il_trigger']for c in matching),limits='Pinned topology above is a separate source version/completion study. No recorded active100 tuple may be replaced from this report. Static graph preserves original prop attributes and footprints; script/quest/actor collision constraints remain separate.')
out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(json.dumps(d['active100_reconciliation']|{'tuple_or_walk_differences':'omitted','translated_il_control252_overlap':matching},ensure_ascii=False))
