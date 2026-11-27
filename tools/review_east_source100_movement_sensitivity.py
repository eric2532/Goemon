"""Read-only4/8-neighbor sensitivity; no source movement-rule equivalence assumed."""
from collections import deque
import hashlib
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Display Handoff Proposal'
def sha(data):return hashlib.sha256(data).hexdigest()
def run():
    raw_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat';raw=raw_path.read_bytes();w,h,bg,pg,flags=lib.parse_map(raw)
    walk=navigation_grid(w,h,bg,pg,lib.serial_index());branch_path=OUT/'source-branch-final-ledger.json';branches=json.loads(branch_path.read_text())['branches']
    def opened(p):return 0<=p[0]<w and 0<=p[1]<h and walk[p[1]*w+p[0]]
    def flood(seed,variant):
        previous={seed:None};queue=deque([seed]);diagonals=[]
        while queue:
            p=queue.popleft();x,y=p
            for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]+([]if variant=='cardinal4'else[(-1,-1),(-1,1),(1,-1),(1,1)]):
                q=x+dx,y+dy
                if not opened(q)or q in previous:continue
                if dx and dy:
                    a,b=(x+dx,y),(x,y+dy)
                    if variant=='diagonal8_no_closed_corners'and(not opened(a)or not opened(b)):continue
                    if not opened(a)and not opened(b):diagonals.append(dict(source_from=p,source_to=q,closed_orthogonals=[a,b]))
                previous[q]=p;queue.append(q)
        return previous,diagonals
    results={};gate=(475,196);island=(445,322)
    for variant in ['cardinal4','diagonal8_permissive','diagonal8_no_closed_corners']:
        g,corner_links=flood(gate,variant);s,_=flood(island,variant);path=[]
        if island in g:
            at=island
            while at is not None:path.append(at);at=g[at]
            path.reverse()
        results[variant]=dict(gate_component_cells=len(g),island_seed_component_cells=len(s),component_intersection_cells=len(set(g)&set(s)),
                              gate_component_sha256=sha(json.dumps(sorted(g),separators=(',',':')).encode()),island_component_sha256=sha(json.dumps(sorted(s),separators=(',',':')).encode()),
                              gate_to_island_source_path=path,gate_to_island_steps=len(path)-1 if path else None,
                              closed_double_corner_discovery_edges=corner_links,
                              branches=[dict(id=b['id'],points_in_gate_component=sum(tuple(p)in g for p in b['cells']),points=len(b['cells']),
                                             cardinal_path_remains_valid=True)for b in branches])
    cardinal_gate,_=flood(gate,'cardinal4');cardinal_island,_=flood(island,'cardinal4')
    # Preserve exact diagonal contacts across the two formerly separate sets,
    # rather than implying that a newly merged component had a literal warp.
    contacts=[]
    for x,y in cardinal_island:
        for dx,dy in [(-1,-1),(-1,1),(1,-1),(1,1)]:
            q=x+dx,y+dy
            if q in cardinal_gate:contacts.append(dict(island_cell=[x,y],gate_cell=q,orthogonal_open=[bool(opened((x+dx,y))),bool(opened((x,y+dy)))]))
    result=dict(scope='READ ONLY graph sensitivity of source graphic-decoder plane. These graph variants are hypotheses, not pinned server movement/interaction rules or current Native traversal acceptance.',
                source_raw_sha256=sha(raw),source_walk_sha256=sha(bytes(walk)),gate_seed=gate,island_seed=island,variants=results,
                direct_cardinal_component_diagonal_contacts=sorted(contacts,key=lambda r:(r['island_cell'],r['gate_cell'])),
                preserved_limits=['No server movement rule is inferred from4-neighbor or8-neighbor flood alone.',
                                 'No literal warp/script/item/generator arrival into the original466cell set was previously found in the available records; diagonal movement is a separate possible entrance.',
                                 '10069remains unactivated pending source-rule/owner/visual reconciliation. No absolute unenterability claim is made.',
                                 'All four branch positive cardinal source paths remain valid in either8-neighbor model; their current Native support and scene handoff limits remain separate.'],
                input_sha256={str(raw_path.relative_to(ROOT)):sha(raw),str(branch_path.relative_to(ROOT)):sha(branch_path.read_bytes())})
    (OUT/'movement-neighbor-sensitivity.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:{n:r[n]for n in ['gate_component_cells','island_seed_component_cells','component_intersection_cells','gate_to_island_steps']}for k,r in results.items()},indent=2));print('Directcornercontacts',contacts)
if __name__=='__main__':run()
