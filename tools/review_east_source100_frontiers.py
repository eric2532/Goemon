"""Read-only source-open frontiers beyond the East compiler's rectangular guard."""
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT.parent / 'Magic Power/tools'), str(ROOT / 'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid

OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Remote Views'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run():
    raw_path = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    w, h, bg, pg, flags = lib.parse_map(raw_path.read_bytes())
    walk = navigation_grid(w, h, bg, pg, lib.serial_index())
    metadata_path = ROOT / 'assets/maps/falan/freyja_residual/full/provenance.json'
    metadata = json.loads(metadata_path.read_text())
    images = {area: Image.open(ROOT / f'assets/maps/falan/freyja_residual/full/{area}-surface.png').convert('RGBA')
              for area in metadata['areas']}
    def pixel(area, p):
        row = metadata['areas'][area]; f = row['frame']
        dx, dy = p[0] * 3 - f['origin'][0], p[1] * 3 - f['origin'][1]
        det = f['x'][0] * f['y'][1] - f['x'][1] * f['y'][0]
        u = (dx * f['y'][1] - dy * f['y'][0]) / det
        v = (f['x'][0] * dy - f['x'][1] * dx) / det
        q = (round((u - row['origin'][0]) / 3), round((v - row['origin'][1]) / 3))
        if not (0 <= q[0] < images[area].width and 0 <= q[1] < images[area].height):
            return None
        rgba = images[area].getpixel(q)
        excluded = any(r[0] <= q[0] < r[0] + r[2] and r[1] <= q[1] < r[1] + r[3]
                       for r in row['safe_rectangles'])
        return dict(pixel=q, rgba=rgba, field_dry=rgba[3] >= 128 and rgba[0] < 128 and not excluded,
                    protected_context=excluded)
    def neighbors(p):
        x, y = p
        for q in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= q[0] < w and 0 <= q[1] < h and walk[q[1] * w + q[0]]:
                yield q
    seed = (475, 196); previous = {seed: None}; queue = deque([seed])
    while queue:
        p = queue.popleft()
        for q in neighbors(p):
            if q not in previous:
                previous[q] = p; queue.append(q)
    def route(tree, target):
        path = []; at = target
        if target not in tree: return None
        while at is not None:
            path.append(at); at = tree[at]
        path.reverse()
        return path
    def corners(path):
        return [p for i,p in enumerate(path) if i in (0,len(path)-1) or
                (p[0]-path[i-1][0],p[1]-path[i-1][1]) != (path[i+1][0]-p[0],path[i+1][1]-p[1])]
    audit_path = OUT.parent.parent / 'Source100 Completeness/report.json'
    audit = json.loads(audit_path.read_text())
    outliers = audit['owner_envelope_outliers_needing_boundary_classification']
    rows = []; counts = Counter()
    for row in outliers:
        p = tuple(row['cell']); opened = bool(walk[p[1]*w+p[0]])
        owners = {area: pixel(area,p) for area in images}
        owners = {area:s for area,s in owners.items() if s is not None}
        covered = sorted(area for area,s in owners.items() if s['field_dry'])
        status = 'source-open-Gate-connected' if opened and p in previous else 'source-open-other-component' if opened else 'source-closed-object-or-terrain'
        counts[status] += 1; counts['covered-by-mask' if covered else 'no-dry-field-mask-owner'] += 1
        rows.append(dict(cell=p,bg=bg[p[1]*w+p[0]],pg1=pg[p[1]*w+p[0]],classification=status,
                         compiler_side='west-x440' if p[0]<440 else 'south-y360',
                         mask_covered_owner_candidates=covered,owner_masks=owners,
                         actual_functional_handoff='Not inferred from mask or owner envelope; see exact crossing ledger.'))
    frontier = []
    for p in previous:
        inside = p[0]>=440 and p[1]<360
        if not inside: continue
        for q in neighbors(p):
            if q[0]>=440 and q[1]<360: continue
            if pixel('east_gate',p) is None and pixel('north_coast',p) is None: continue
            frontier.append(dict(source_from=p,source_to=q,bg=[bg[p[1]*w+p[0]],bg[q[1]*w+q[0]]],
                                 masks={area:[pixel(area,p),pixel(area,q)]for area in images},
                                 source_open=True,gate_connected=True,
                                 meaning='Compiler-guard frontier, not an original map/region boundary.'))
    # One complete-source BFS from the rock's south neighbor supplies exact
    # paths to current covered owner candidates and already-authored crossings.
    start = (496,360); tree={start:None}; queue=deque([start]); found={}
    exact = {(510,248):'East-to-South-trail', (510,245):'South-to-East-trail',
             (441,351):'SouthGate-to-SouthLakes', (441,348):'SouthLakes-to-SouthGate'}
    while queue:
        p=queue.popleft()
        for area in ['east_gate','south_gate','south_lakes','freyja']:
            candidate=pixel(area,p)
            if area not in found and candidate is not None and candidate['field_dry']:
                found[area]=p
        for q in neighbors(p):
            if q not in tree:tree[q]=p;queue.append(q)
    targets=[]
    for label,p in list(found.items())+[(label,p)for p,label in exact.items()]:
        path=route(tree,p)
        targets.append(dict(target=label,cell=p,source_open=bool(walk[p[1]*w+p[0]]),
                            source_connected=path is not None,source_steps=len(path)-1 if path else None,
                            path_turns=corners(path)if path else [],
                            meaning='Source-only path; current mask coverage is a candidate, not a Native route or scene transfer proof.'))
    result=dict(source_sha256=sha(raw_path),source_walk_sha256=hashlib.sha256(bytes(walk)).hexdigest(),
                input_sha256={str(p.relative_to(ROOT)):sha(p)for p in [raw_path,metadata_path,audit_path]},
                gate_seed=seed,gate_component_cells=len(previous),counts=dict(counts),outliers=rows,
                compiler_open_frontiers=sorted(frontier,key=lambda r:(r['source_from'],r['source_to'])),
                rock_continuation=dict(start=start,targets=targets),
                scope='READ ONLY source cardinal connectivity and current mask contracts. No new region, handoff, terrain, art, Native bits or route was created.',
                limits=['Mask field_dry is not a full terrain disk/Native reachability proof.',
                        'Source-original walk connectivity does not prove an existing presentation can traverse it.',
                        'x440/y360 are compiler guards. Every frontier remains open until a real functional existing owner/link is identified.'])
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'crop-open-frontiers.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(counts=result['counts'],frontier_edges=len(frontier),rock_targets=targets),indent=2))

if __name__ == '__main__':run()
