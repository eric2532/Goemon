"""Group source-open coverage gaps, retain their actual boundary/entry contracts."""
from collections import Counter, deque
import base64
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
BASE=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13'
OUT=BASE/'Display Handoff Proposal'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def adjacent(p):
    x,y=p
    return [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
def bbox(cells):return [min(x for x,y in cells),min(y for x,y in cells),max(x for x,y in cells),max(y for x,y in cells)]
def run():
    domains=json.loads((OUT/'branch-domain-source.json').read_text());cpu=json.loads((OUT/'branch-domain-current.json').read_text())
    halo=json.loads((OUT/'branch-halo-source.json').read_text());halo_cpu=json.loads((OUT/'branch-halo-current.json').read_text())
    for report in [cpu,halo_cpu]:
        assert not report['source_changed']
        for path,digest in report['source_hashes'].items():assert sha(ROOT/path.removeprefix('res://'))==digest,path
    support={tuple(p):v for p,v in zip(domains['cells'],base64.b64decode(cpu['supported_owner_bits']))}
    support.update({tuple(p):v for p,v in zip(halo['cells'],base64.b64decode(halo_cpu['supported_owner_bits']))})
    remaining={tuple(p)for p,v in zip(domains['cells'],base64.b64decode(cpu['supported_owner_bits']))if not v}
    groups=[]
    while remaining:
        seed=min(remaining);remaining.remove(seed);pending=deque([seed]);cells={seed}
        while pending:
            p=pending.popleft()
            for q in adjacent(p):
                if q in remaining:remaining.remove(q);pending.append(q);cells.add(q)
        groups.append(cells)
    raw_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    w,h,bg,pg,flags=lib.parse_map(raw_path.read_bytes());walk=navigation_grid(w,h,bg,pg,lib.serial_index())
    ledger=json.loads((OUT/'source-interface-ledger.json').read_text());frontier_source=json.loads((BASE/'Remote Views/crop-open-frontiers.json').read_text())
    unsupported={tuple(r['source']['cell']):r for r in ledger['outliers']if not r['Native_point_supported_owners_radius035']}
    failed_edges=[r for r in ledger['frontier_edges']if r['classification']=='no-current-Native-edge-clear']
    fixed=[];warp_path=ROOT/'build/Other Files/Asset Toolkit/Original Isometric Maps/reference-warp.txt'
    for line,text in enumerate(warp_path.read_bytes().decode('gb18030').splitlines(),1):
        try:fields=list(map(int,text.split()[:7]))
        except ValueError:continue
        if len(fields)!=7:continue
        if fields[1]==100:fixed.append(dict(line=line,warp_id=fields[0],role='entrance',cell=fields[2:4],other_map=fields[4],other_cell=fields[5:7]))
        if fields[4]==100:fixed.append(dict(line=line,warp_id=fields[0],role='return',cell=fields[5:7],other_map=fields[1],other_cell=fields[2:4]))
    actors=[];npc_path=ROOT/'build/Other Files/Asset Toolkit/Cursed Maze/Source/npc-index.txt'
    for line,text in enumerate(npc_path.read_bytes().decode('gb18030').splitlines(),1):
        f=text.split('\t')
        if len(f)==25 and not f[0].startswith('#')and f[6]=='1'and f[8]=='100':actors.append(dict(line=line,kind=f[0],id=f[3],cell=list(map(int,f[9:11])),program=f[24]))
    generators=[];dungeon_path=ROOT/'build/Other Files/Asset Toolkit/University Region/Source/dungeonconf.txt'
    for line,text in enumerate(dungeon_path.read_bytes().decode('gb18030').splitlines(),1):
        f=text.split('\t')
        if len(f)<117 or f[0].startswith('#')or not f[3].isdigit():continue
        if f[9]=='100':generators.append(dict(line=line,config=int(f[3]),role='entry_rectangle',rectangle=list(map(int,f[10:14]))))
        if f[15]=='100'and f[16].isdigit()and f[17].isdigit():generators.append(dict(line=line,config=int(f[3]),role='return',cell=list(map(int,f[16:18]))))
    gate={};queue=deque([(475,196)]);gate[(475,196)]=None
    while queue:
        p=queue.popleft()
        for q in adjacent(p):
            if 0<=q[0]<w and 0<=q[1]<h and walk[q[1]*w+q[0]]and q not in gate:gate[q]=p;queue.append(q)
    selected=[g for g in sorted(groups,key=lambda g:(-len(g),min(g)))if g.intersection(unsupported)or any(tuple(e['source_to'])in g for e in failed_edges)]
    continuation_path=OUT/'branch-continuation-current.json';continuation=json.loads(continuation_path.read_text())
    assert not continuation['source_changed']
    for path,digest in continuation['source_hashes'].items():assert sha(ROOT/path.removeprefix('res://'))==digest,path
    selected=[set(map(tuple,b['unsupported_original_open_cells']))for b in continuation['branches']]
    membership={p:f'branch-{i+1:02d}'for i,g in enumerate(selected)for p in g};branches=[]
    owner_names={1:'east_gate',2:'south_gate',4:'south_lakes',8:'freyja'}
    for i,cells in enumerate(selected):
        boundary=[];exits=[]
        for p in sorted(cells):
            for q in adjacent(p):
                if q in cells or not(0<=q[0]<w and 0<=q[1]<h and walk[q[1]*w+q[0]]):continue
                owners=[name for bit,name in owner_names.items()if support.get(q,0)&bit]
                record=dict(source_from=p,source_to=q,current_Native_supported_owners=owners,
                            measured=q in support,source_original_open=True,
                            meaning='Current Native point-supported endpoint only; no new display handoff is inferred.')
                if owners:boundary.append(record)
                else:exits.append(record)
        # The adaptive probe closes the display-envelope exits at actual
        # support/protection; do not reintroduce the old rectangular stop.
        measured=continuation['branches'][i]
        boundary=[dict(source_from=r['source_from'],source_to=r['source_to'],
                       current_Native_supported_owners=[name for bit,name in owner_names.items()if r['owner_bits']&bit],
                       measured=True,source_original_open=True,
                       meaning='Actual Native supported endpoint, still not a display handoff or player/edge acceptance.')
                  for r in measured['measured_supported_boundaries']]
        exits=[]
        protected_exits=measured['protected_original_open_boundaries']
        linked=[r for r in fixed if tuple(r['cell'])in cells]
        near=[r for r in fixed if tuple(r['cell'])not in cells and any(tuple(r['cell'])in adjacent(p)for p in cells)]
        relevant_actors=[r for r in actors if tuple(r['cell'])in cells or any(q in cells for q in adjacent(tuple(r['cell'])))]
        generated=[]
        for row in generators:
            hits=[p for p in cells if row['rectangle'][0]<=p[0]<=row['rectangle'][2]and row['rectangle'][1]<=p[1]<=row['rectangle'][3]]if'cell'not in row else [tuple(row['cell'])]if tuple(row['cell'])in cells else []
            if hits:generated.append(dict(source=row,source_open_intersection_cells=len(hits),example=hits[:5]))
        # A complete-source BFS supplies real closest fixed-route endpoints;
        # it is kept separate from the bounded current-owner boundary above.
        previous={p:None for p in cells};queue=deque(sorted(cells));targets={};endpoint_cells={tuple(r['cell'])for r in fixed};wanted=3
        while queue and len(targets)<wanted:
            p=queue.popleft()
            if p in endpoint_cells:targets[p]=[r for r in fixed if tuple(r['cell'])==p]
            for q in adjacent(p):
                if 0<=q[0]<w and 0<=q[1]<h and walk[q[1]*w+q[0]]and q not in previous:previous[q]=p;queue.append(q)
        nearest=[]
        for target,links in targets.items():
            path=[];at=target
            while at is not None:path.append(at);at=previous[at]
            path.reverse();nearest.append(dict(links=links,source_steps_from_gap=len(path)-1,path=path,scope='Original-source route only; does not authorize traversing or rebuilding an already-owned region.'))
        surface_counts=Counter('water5000..5008'if 5000<=bg[y*w+x]<=5008 else'void'if bg[y*w+x]in[0,100]else'dry'for x,y in cells)
        branches.append(dict(id=f'branch-{i+1:02d}',source_open_cells=len(cells),source_decoder_surface_counts=dict(surface_counts),cells=sorted(cells),bounds=bbox(cells),
                             gate_connected=any(p in gate for p in cells),unsupported_outlier_open_points=sum(p in unsupported for p in cells),
                             unsupported_guard_edges=[e for e in failed_edges if tuple(e['source_to'])in cells],
                             current_supported_boundary=boundary,protected_original_open_boundaries=protected_exits,unresolved_original_open_exits=exits,
                             fixed_entrances_and_returns_inside=linked,fixed_links_one_tile_adjacent=near,
                             original_actors_or_script_anchors_inside_or_adjacent=relevant_actors,
                             original_generator_entries_and_returns=generated,nearest_source_fixed_route_endpoints=nearest,
                             status='Unfinished source-ground/presentation branch. Existing supported endpoint is not a functional handoff by itself. Prefer owner reconciliation; no South/West rebuilding authorized.'))
    closed=[]
    for p,row in unsupported.items():
        if walk[p[1]*w+p[0]]:continue
        attached=sorted({membership[q]for q in adjacent(p)if q in membership})
        if not attached:
            attached=sorted({membership[(p[0]+dx,p[1]+dy)]for dx in range(-2,3)for dy in range(-2,3)if(p[0]+dx,p[1]+dy)in membership})
        closed.append(dict(cell=p,bg=row['source']['bg'],pg1=row['source']['pg1'],adjacent_gap_branches=attached,
                           association='Source artwork/closed anchor proximity only; not an open route or new encounter.'))
    unassigned=[]
    for edge in failed_edges:
        if tuple(edge['source_to'])in membership:continue
        raw=next(r for r in frontier_source['compiler_open_frontiers']if r['source_from']==edge['source_from']and r['source_to']==edge['source_to'])
        protected=[area for area,pair in raw['masks'].items()if any(s and s['protected_context']for s in pair)]
        unassigned.append(dict(edge=edge,protected_contexts=protected,
                               owner_followup='Joined Il Original100 host-remnant contract, separately from standalone2000'if protected else'Unresolved open interface; do not infer an arbitrary crop wall.'))
    assert sum(b['unsupported_outlier_open_points']for b in branches)+len(closed)==1601
    assert sum(len(b['unsupported_guard_edges'])for b in branches)+len(unassigned)==24
    result=dict(scope='READ ONLY contiguous original-open source branches with measured current Native point support. No map, ground, route, actor, Native bit or publication changed.',
                counts=dict(domain_open_cells=len(domains['cells']),halo_original_open_cells=len(halo['cells']),unsupported_outliers=1601,unsupported_closed_art_anchors=len(closed),branches=len(branches),unsupported_guard_interfaces=24,protected_or_other_unassigned_interfaces=len(unassigned)),
                branches=branches,closed_art_associations=closed,protected_or_other_interfaces=unassigned,
                source_raw_sha256=sha(raw_path),input_sha256={str(p.relative_to(ROOT)):sha(p)for p in[raw_path,warp_path,npc_path,dungeon_path,OUT/'branch-domain-source.json',OUT/'branch-domain-current.json',OUT/'branch-halo-source.json',OUT/'branch-halo-current.json',OUT/'source-interface-ledger.json',continuation_path]},
                limits=['Source-open in this ledger means the source graphic-decoder comparator returned open; native5000..5008water/control/shore roles remain explicit and do not authorize generic dry land, bridges or support.',
                        'Do not publish10069island from a direct spawn or nearest-route computation.',
                        'Global fixed warp/NPC/generator anchors are source-confirmed. Unrelated script body semantics are not expanded into another goal.',
                        'Current Native supported boundaries are candidate ownership interfaces. Existing Regions/Tour transfer proof and actual player/pet traversal remain required.'])
    (OUT/'source-branch-final-ledger.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['counts'],indent=2))
    for branch in branches:print(branch['id'],branch['bounds'],'open',branch['source_open_cells'],'outliers',branch['unsupported_outlier_open_points'],'fixed',branch['fixed_entrances_and_returns_inside'],'actors',branch['original_actors_or_script_anchors_inside_or_adjacent'],'generated',branch['original_generator_entries_and_returns'],'exits',len(branch['unresolved_original_open_exits']))

if __name__=='__main__':run()
