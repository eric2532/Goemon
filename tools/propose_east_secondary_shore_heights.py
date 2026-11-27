"""Pure source topology/height OPTIONS; never write Host fields or runtime data."""
from array import array
from collections import Counter, deque
import base64
import csv
import hashlib
import heapq
import json
from math import hypot, sqrt
from pathlib import Path
import sys

from prepare_east_region_maps import reference_map

ROOT=Path(__file__).resolve().parents[1]
REGION=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
HOST=REGION/'Il Source Completion/Low Source Candidate/Host'
OUT=REGION/'Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage'
PIN=REGION/'Version Expansion Source Audit/map__00100_field1'
BASE=ROOT/'assets/maps/falan/freyja_source/100.dat'
TARGETS=[(542,18),(543,18),(613,307)]

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def approved_goal(x,z):return x>=440 and (z<360 or 636<=x<726 and 312<=z<423 or 529<=x<629 and 20<=z<120)
def preferred_area(x,z):return 'north_coast' if z<100 and x>510 or x>670 and z<210 else 'east_gate'
def source_point(area,x,z):return (x*3.-1902.,z*3.-333.) if area=='north_coast' else (591.-z*3.,x*3.-1251.)
def bfs(allowed,seeds,w,h):
 distance=array('i',[-1])*(w*h);todo=deque()
 for i in seeds:
  if allowed[i] and distance[i]<0:distance[i]=0;todo.append(i)
 while todo:
  i=todo.popleft();x=i%w;z=i//w
  for other in ([i-1] if x else [])+([i+1] if x+1<w else [])+([i-w] if z else [])+([i+w] if z+1<h else []):
   if allowed[other] and distance[other]<0:distance[other]=distance[i]+1;todo.append(other)
 return distance
def groups(selected,w,h):
 remaining=set(selected);result=[]
 while remaining:
  seed=min(remaining);remaining.remove(seed);todo=[seed]
  for i in todo:
   x=i%w;z=i//w
   for other in ([i-1] if x else [])+([i+1] if x+1<w else [])+([i-w] if z else [])+([i+w] if z+1<h else []):
    if other in remaining:remaining.remove(other);todo.append(other)
  result.append(todo)
 return sorted(result,key=lambda g:(-len(g),min(g)))
def diagonal_distance(allowed,seeds,w,h,no_corner_cut):
 distance=array('d',[float('inf')])*(w*h);todo=[]
 for i in seeds:
  if allowed[i] and distance[i]!=0.:distance[i]=0.;heapq.heappush(todo,(0.,i))
 while todo:
  value,i=heapq.heappop(todo)
  if value!=distance[i]:continue
  x=i%w;z=i//w
  for dx,dz in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,1),(1,-1),(-1,-1)]:
   nx,nz=x+dx,z+dz
   if not(0<=nx<w and 0<=nz<h):continue
   other=nz*w+nx
   if not allowed[other] or dx and dz and no_corner_cut and not(allowed[z*w+nx] and allowed[nz*w+x]):continue
   candidate=value+(sqrt(2.) if dx and dz else 1.)
   if candidate<distance[other]:distance[other]=candidate;heapq.heappush(todo,(candidate,other))
 return distance
def dist_summary(g,distance):
 values=[distance[i]*3. for i in g if distance[i]>=0]
 return {'reachable_cells':len(values),'unreachable_cells':len(g)-len(values),'min_m':min(values) if values else None,'max_m':max(values) if values else None}
def main():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 import cg_assets as cg
 from prepare_field_assets import navigation_grid
 shore_path=HOST/'shore-interface-plan.json';shore=json.loads(shore_path.read_text())
 restore_path=OUT.parent/'field100-restore.json';restore=json.loads(restore_path.read_text());raw_path=ROOT/restore['raw_path'].removeprefix('res://')
 assert sha(raw_path)==restore['raw_sha256']
 w,h,bg,pg,active_flags=lib.parse_map(raw_path.read_bytes());n=w*h
 pw,ph,pinned,title=reference_map(PIN.read_bytes(),100);assert (pw,ph)==(w,h)
 lookup=lib.serial_index();walk=navigation_grid(w,h,bg,pg,lookup)
 bits=base64.b64decode(restore['native_walk_bits']);assert all(bool(walk[i])==bool(bits[i>>3]&(1<<(i&7))) for i in range(n))
 _,_,old_bg,old_pg,flags=lib.parse_map(BASE.read_bytes())
 primary={int(r['cell'][1])*w+int(r['cell'][0]) for r in shore['private_connected_shore_rows']}
 assert len(primary)==2989 and all(walk[i] for i in primary)
 primary_banks={i for i in primary if 12500<=pg[i]<12536}
 substrate=bytearray((bg[i] not in(0,100) and not 5000<=bg[i]<=5008) or 12500<=pg[i]<12536 for i in range(n))
 open_dry=bytearray(bool(walk[i] and substrate[i]) for i in range(n))
 restricted_open=bytearray(bool(walk[i] and approved_goal(i%w,i//w)) for i in range(n))
 used=set(bg)|set(pg);packs={row['pack'] for ident,row in lookup.items() if ident in used}
 source_paths=[Path(__file__),PIN,BASE,raw_path,restore_path,shore_path,ROOT/'tools/prepare_east_region_maps.py',Path(lib.__file__),Path(cg.__file__),Path(sys.modules['prepare_field_assets'].__file__),lib.DB]
 source_paths.extend(cg.SOURCE/cg.GAME_PACKS[pack][1] for pack in packs)
 source_paths.extend(HOST/'Reference'/(area+'-field.json') for area in ['east_gate','north_coast'])
 before={str(p):sha(p) for p in source_paths}
 graph={
  'original_open':bfs(walk,primary,w,h),
  'dry_substrate':bfs(substrate,primary_banks,w,h),
  'open_dry':bfs(open_dry,primary_banks,w,h),
  'approved_goal_open':bfs(restricted_open,primary,w,h),
 }
 sensitivities={'open8_permissive':diagonal_distance(walk,primary,w,h,False),'open8_no_corner_cut':diagonal_distance(walk,primary,w,h,True)}
 references={area:json.loads((HOST/'Reference'/(area+'-field.json')).read_text()) for area in ['east_gate','north_coast']}
 targets=[]
 for x,z in TARGETS:
  i=z*w+x;nearest=min(primary,key=lambda j:(j%w-x)**2+(j//w-z)**2);euclidean=hypot(nearest%w-x,nearest//w-z)*3.
  area=preferred_area(x,z);ref=references[area];px,pz=source_point(area,x,z);ix=round((px-ref['origin'][0])/3.);iz=round((pz-ref['origin'][1])/3.);baseline=float(ref['heights'][iz*int(ref['width'])+ix])
  distances={name:(d[i]*3. if d[i]>=0 else None) for name,d in graph.items()}
  grade=lambda d:baseline if d is None else min(baseline,2.1+max(0.,d-sqrt(18.))*.2)
  sensitivity={name:(d[i]*3. if d[i]!=float('inf') else None) for name,d in sensitivities.items()}
  targets.append({'cell':[x,z],'source_bg':bg[i],'source_pg1':pg[i],'source_open':bool(walk[i]),'dry_substrate':bool(substrate[i]),'canonical_known':bool(flags[i]&0xc000 or old_bg[i] or old_pg[i]),'nearest_primary_cell':[nearest%w,nearest//w],'euclidean_primary_m':euclidean,'geodesic_primary_m':distances,'unverified_diagonal_movement_sensitivity_m':sensitivity,'existing_inferred_baseline_height_model_m':baseline,'unapplied_inferred_height_options_model_m':{'euclidean_primary_grade':grade(euclidean),'original_open_graph_grade_or_preserve_baseline':grade(distances['original_open']),'dry_substrate_graph_grade_or_preserve_baseline':grade(distances['dry_substrate'])},'height_authority':'None in original2Dsource. Baseline and both grade formulas are3Dinference options, not new source-confirmed elevation or published edits. Diagonal sensitivities do not establish original server corner rules or Native body clearance.'})
 # Include every native-open water control. Keep non-water bank/control art
 # separate so a palette ID never silently becomes a water-height assertion.
 strict_water={i for i in range(n) if walk[i] and 5000<=bg[i]<=5008}
 universe=strict_water|{i for i in range(n) if walk[i] and (pg[i] in (250,251,252) or 12500<=pg[i]<12536)}
 all_components=groups(universe,w,h)
 primary_group=next(set(g) for g in all_components if set(g)&primary)
 assert primary_group==primary
 secondary_groups=[g for g in all_components if not set(g)&primary and any(approved_goal(i%w,i//w) for i in g)]
 goal_control_counts=Counter(pg[i] for i in strict_water if approved_goal(i%w,i//w) and pg[i] in (250,251,252))
 assert goal_control_counts=={250:179,251:359,252:1723}
 failures_path=OUT/'production-failures-current-scope.tsv';failures=[]
 if failures_path.exists():
  before[str(failures_path)]=sha(failures_path)
  with failures_path.open() as stream:failures=list(csv.DictReader(stream,delimiter='\t'))
 component_rows=[]
 for ident,g in enumerate(secondary_groups):
  counts=Counter();owners=Counter();known_outside=Counter()
  for i in g:
   x,z=i%w,i//w;inside=approved_goal(x,z);known=bool(flags[i]&0xc000 or old_bg[i] or old_pg[i]);kind='control'+str(pg[i]) if pg[i] in (250,251,252) else 'bank' if 12500<=pg[i]<12536 else 'other_open_water'
   counts[kind]+=1;counts['in_goal' if inside else 'outside_approved_goal']+=1;counts['canonical_known' if known else 'canonical_unknown']+=1
   counts['bg_water5000_5008' if i in strict_water else 'non_water_bg_bank_or_control']+=1
   counts[('in_goal' if inside else 'outside_goal')+('_known' if known else '_unknown')]+=1
   owners[preferred_area(x,z)]+=1
   if not inside:known_outside['source100_other_goal_boundary_known' if known else 'source100_other_goal_boundary_unrecorded']+=1
   if 529<=x<629 and 20<=z<120:counts['current_joined2400_rectangle_overlap']+=1
   if 636<=x<726 and 312<=z<423:counts['current_joined2000_rectangle_overlap']+=1
  members=set(g);failed=[r for r in failures if int(r['z'])*w+int(r['x']) in members or int(r['target_z'])*w+int(r['target_x']) in members]
  component_rows.append({'component':ident,'cells':len(g),'source_bounds_inclusive':[min(i%w for i in g),min(i//w for i in g),max(i%w for i in g),max(i//w for i in g)],'counts':dict(counts),'preferred_display_areas':dict(owners),'outside_known_owner_disposition':dict(known_outside),'current_selected_failed_radius_assertions_touching_component':len(failed),'primary_distance':{name:dist_summary(g,d) for name,d in graph.items()},'source_authority':'Exact merged known-preserving source100 variant. Components include their outside-goal interface cells for accounting only; no outside owner is authorized for edits. Presentation rectangles2000/2400 are distinct maps.'})
 assert len(component_rows)==17
 historical_secondary={r['cell'][1]*w+r['cell'][0] for r in shore['whole_east_shore_inventory']['other_east_shore_rows']}
 # Existing isolated grades fail even after production-byte scaling; graph
 # facts below define repair options without authorizing a height publication.
 report={'schema':2,'source_map':100,'source_title':title,'source_size':[w,h],'active_raw_sha256':sha(raw_path),'active_source_authority':'Known-preserving merged compatible variant; pinned map is a comparison reference, not permission to overwrite known client tuples.','primary_cells':len(primary),'primary_bank_seeds':len(primary_banks),'inventory':{'strict_bg_water_native_open_cells_global':len(strict_water),'all_open_water_bank_control_cells_global':len(universe),'goal_strict_water_control_counts':dict(goal_control_counts),'secondary_components_touching_goal':len(component_rows),'secondary_component_full_cells':sum(r['cells'] for r in component_rows),'secondary_goal_cells':sum(r['counts'].get('in_goal',0) for r in component_rows),'secondary_outside_goal_interface_cells':sum(r['counts'].get('outside_approved_goal',0) for r in component_rows),'pinned_vs_active_known_preserved_tuple_differences':sum((pinned[i],pinned[n+i])!=(bg[i],pg[i]) for i in range(n))},'graphs':{'original_open':'Four-neighbor active source-derived walk bit; includes every original-open control250/251/252.','dry_substrate':'Four-neighbor dryBG(excludes0/100/5000..5008) ORnative12500..12535bank. Includes blocked dry substrate underneath props; does not claim player traversal. Seeds primary bank cells only.','open_dry':'Intersection of original-open and dry-substrate; primary bank seeds only.','approved_goal_open':'Original-open constrained to the currently approved private source-context windows; outside-owner cells are never proposed for edits.'},'targets':targets,'secondary_components':component_rows,'native_source_facts':['Exact active map layers, source-derived walk/footprints, bank/control identities, connectivity, counts and distances.','There is no elevation plane in the original2Dsource. Quest/script warps are intentionally NOTterrain-distance edges.'],'unapplied_inferred_proposal':['Reject Euclidean primary-shore lowering across a disconnected original-open/dry-substrate component. Preserve compatible existing inferred heights there until a component-specific proposal is reviewed.','For a connected primary approach, compare bounded original-open/dry-substrate geodesic grade against existing terrain; expand/solve the local shared-vertex grade only inside explicitly owned source cells.','For each secondary wet component, choose one coherent reviewed bank/control datum before blending its original-open dry approaches. Every native-open250/251/252water control counts; a bank-only6m assumption based on the old252-onlyinventory is invalid.','Treat protected whole bridges and outside-goal owners independently. Counts outside approved context are interface obligations, not permission to rewrite another goal.','No fields, masks, heights, collision, source bytes, routes, material or readiness flag are written by this helper.'],'source_hashes':before,'source_changed':[p for p,d in before.items() if sha(p)!=d]}
 assert not report['source_changed']
 inventory=report['inventory']
 inventory['pinned_vs_active_all_map_tuple_differences']=inventory.pop('pinned_vs_active_known_preserved_tuple_differences')
 inventory['pinned_vs_active_canonical_known_tuple_differences']=sum(bool(flags[i]&0xc000 or old_bg[i] or old_pg[i]) and (pinned[i],pinned[n+i])!=(bg[i],pg[i]) for i in range(n))
 inventory['historical_pinned252_secondary_cells']=len(historical_secondary)
 inventory['active_native_closed_of_historical_secondary_cells']=sum(not walk[i] for i in historical_secondary)
 inventory['active_native_closed_historical_secondary_inside_goal']=sum(not walk[i] and approved_goal(i%w,i//w) for i in historical_secondary)
 assert inventory['active_native_closed_historical_secondary_inside_goal']==0
 inventory['primary_non_water_bg_role_counts']=dict(Counter('control'+str(pg[i]) if pg[i] in (250,251,252) else 'bank' for i in primary if i not in strict_water))
 OUT.mkdir(exist_ok=True);(OUT/'secondary-height-proposal.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 report['movement_model_limits']='The four-neighbor graph matches the currently tested Native cardinal adjacency contract. Eight-neighbor sensitivities test model dependence only; original server diagonal/corner-cut rules have not been verified by this helper. Disconnected means disconnected under the named graph, never a blanket source-unreachable claim.'
 (OUT/'secondary-height-proposal.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 for row in targets:print(row['cell'],'Euclidean',round(row['euclidean_primary_m'],3),'geodesic',row['geodesic_primary_m'],'diagonal_sensitivity',row['unverified_diagonal_movement_sensitivity_m'],'height_options',row['unapplied_inferred_height_options_model_m'])
 print('SECONDARY_HEIGHT_PROPOSAL',report['inventory'],'source-current; no runtime edits')
if __name__=='__main__':main()
