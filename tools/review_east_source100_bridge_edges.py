"""Read-only original100 protected bridge/neighbor-role and exact Native snapshot audit."""
from collections import Counter, deque
import base64
import csv
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zlib

ROOT = Path(__file__).resolve().parents[1]
R = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
FIELDS = R / 'Il Source Completion/Low Source Candidate/Host/Original100 Candidate'
TRIAGE = R / 'Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage'
OUT = R / 'Runtime Audit/Source100 Bridge Edge Audit'
W, H = 840, 610
CARDINAL = [(1, 0), (0, 1), (-1, 0), (0, -1)]
DIAGONAL = [(1, 1), (-1, 1), (1, -1), (-1, -1)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    raw_path = TRIAGE.parent / '100.dat'
    restore_path = TRIAGE.parent / 'field100-restore.json'
    raw = raw_path.read_bytes()
    assert sha(raw_path) == 'c0226aeab3301dde8ab11a452bd3e2adfccf8c2659dbddb49fab7aedd272a564'
    restore = json.loads(restore_path.read_text())
    walk = base64.b64decode(restore['native_walk_bits'])
    views = {a: json.loads((FIELDS / (a + '-field.json')).read_text()) for a in ['east_gate', 'north_coast']}
    protected = set(views['east_gate']['protected_bridge_cells']) | set(views['north_coast']['protected_bridge_cells'])
    assert len(protected) == 198
    pending = set(protected)
    components, membership = [], {}
    while pending:
        todo = deque([pending.pop()]); cells = []
        while todo:
            i = todo.popleft(); cells.append(i)
            for dx, dz in CARDINAL:
                n = i + dz * W + dx
                if n in pending:
                    pending.remove(n); todo.append(n)
        number = len(components) + 1
        for i in cells:
            membership[i] = number
        components.append({'id': number, 'cells': len(cells), 'bounds': [min(i % W for i in cells), min(i // W for i in cells), max(i % W for i in cells), max(i // W for i in cells)]})

    def opened(i):
        return 0 <= i < W * H and bool(walk[i >> 3] & (1 << (i & 7)))

    scopes = {a: zlib.decompress(base64.b64decode(d['scope_bits']['deflate'])) for a, d in views.items()}

    def cell(i):
        x, z = i % W, i // W
        bg, pg, flag = [struct.unpack_from('<H', raw, 20 + (plane * W * H + i) * 2)[0] for plane in range(3)]
        water = 5000 <= bg <= 5008
        role = ('water_control_' + str(pg) if pg in [250, 251, 252] else 'native_shore' if 12500 <= pg < 12536 else 'other_water_object' if pg else 'plain_water') if water else 'void_or_unknown' if bg in [0, 100] else 'dry_land'
        owner = 'protected_existing_whole_bridge_' + str(membership[i]) if i in protected else 'source100_east_north_goal' if x >= 440 and z < 360 else 'same100_bridge_approach_outside_technical_core_no_new_owner_claim'
        return {'cell': [x, z], 'index': i, 'raw': [bg, pg, flag], 'recorded': bool(flag & 0xc000), 'source_decoder_open': opened(i), 'source_role': role, 'source_water_background': water, 'protected_bridge': i in protected, 'owner': owner, 'view_scope': {a: bool(bits[i >> 3] & (1 << (i & 7))) for a, bits in scopes.items()}, 'view_bank_enrollment': {a: i in d['bank_cells'] for a, d in views.items()}, 'inferred_water_datum_model_m': 2. if water and (pg in [250, 251, 252] or 12500 <= pg < 12536) else None}

    records, edges, diagonals, points = {}, [], [], set(protected)
    for i in sorted(protected):
        x, z = i % W, i // W
        for diagonal, offsets in [(False, CARDINAL), (True, DIAGONAL)]:
            for dx, dz in offsets:
                n = (z + dz) * W + x + dx
                points.add(n)
                row = {'bridge_cell': [x, z], 'neighbor_cell': [x + dx, z + dz], 'bridge_component': membership[i], 'both_source_open': opened(i) and opened(n), 'neighbor_protected': n in protected, 'source_edge_kind': 'diagonal_sensitivity' if diagonal else 'cardinal', 'closed_corner_rejected': diagonal and not (opened(i + dx) and opened(i + dz * W))}
                (diagonals if diagonal else edges).append(row)
    for i in sorted(points):
        assert 0 <= i < W * H
        records[str(i)] = cell(i)
    unique_edges = {}
    for row in edges:
        if row['both_source_open']:
            key = tuple(sorted((tuple(row['bridge_cell']), tuple(row['neighbor_cell']))))
            unique_edges[key] = row
    external = [e for e in unique_edges.values() if not e['neighbor_protected']]
    samples = {(float(i % W), float(i // W)) for i in points}
    for e in external:
        a, b = e['bridge_cell'], e['neighbor_cell']
        for t in [.25, .49, .5, .51, .75]:
            samples.add((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    samples = sorted(samples)
    candidates = OUT / 'native-candidates.tsv'
    candidates.write_text(''.join(f'P {n} {x:.9f} {z:.9f}\n' for n, (x, z) in enumerate(samples)) + ''.join(f'E {n} {e["bridge_cell"][0]} {e["bridge_cell"][1]} {e["neighbor_cell"][0]} {e["neighbor_cell"][1]}\n' for n, e in enumerate(unique_edges.values())))
    cpp = OUT / 'bridge-native-probe.cpp'
    cpp.write_text('''#define main prior_exact_byte_main
#include "exact_byte_probe.cpp"
#undef main
int main(int argc,char**argv){
 if(argc!=5)return2;
 try{
  auto a=load(argv[1]),b=load(argv[2]);Terrain terrain[2];terrain[0].configure(a.current);terrain[1].configure(b.current);
  std::ifstream in(argv[3]);std::ofstream out(argv[4]);out<<"kind,id,area,x,z,tx,tz,radius,height,height_to,ok,reverse_ok\\n";char kind;int id;float x,z,tx,tz;
  while(in>>kind>>id>>x>>z){
   if(kind=='E')in>>tx>>tz;else{tx=x;tz=z;}
   for(int area=0;area<2;++area){auto p=point(area,x,z),q=point(area,tx,tz);double h=terrain[area].height(p.x,p.z),k=terrain[area].height(q.x,q.z);p.y=float(h);q.y=float(k);
    for(float radius:{.25f,.35f,.38f,.4967896938f,.60f,.80f}){
     bool ok=kind=='P'?terrain[area].clear(p,radius,0):terrain[area].segment(p,q,radius,0);bool reverse=kind=='P'?ok:terrain[area].segment(q,p,radius,0);
     out<<kind<<','<<id<<','<<(area?"north_coast":"east_gate")<<','<<std::setprecision(12)<<x<<','<<z<<','<<tx<<','<<tz<<','<<radius<<','<<h<<','<<k<<','<<ok<<','<<reverse<<'\\n';
    }
   }
  }
 }catch(const std::exception&e){std::cerr<<e.what()<<'\\n';return2;}return0;
}
'''.replace('return2', 'return 2').replace('return0', 'return 0'))
    paths = [raw_path, restore_path, Path(__file__), cpp, TRIAGE / 'exact_byte_probe.cpp', FIELDS / 'Production Scaling/contract.json']
    paths += [FIELDS / (a + '-field.json') for a in views]
    paths += [TRIAGE / ('production-' + a + '-current-scope.bin') for a in views]
    native = ROOT / 'native/terrain_math/crowd'
    paths += [native / name for name in ['terrain.cpp', 'terrain.h', 'air.cpp', 'math_types.h']]
    pins = {str(p.relative_to(ROOT)): sha(p) for p in paths}
    binary = OUT / 'bridge-native-probe'
    built = subprocess.run(['clang++', '-std=c++17', '-O2', '-I', str(native), '-I', str(TRIAGE), str(cpp), str(native / 'terrain.cpp'), str(native / 'air.cpp'), '-o', str(binary)], capture_output=True, text=True)
    (OUT / 'native-build.log').write_text(built.stdout + built.stderr); assert built.returncode == 0, built.stderr
    result_path = OUT / 'native-results.csv'
    run = subprocess.run([str(binary), str(TRIAGE / 'production-east_gate-current-scope.bin'), str(TRIAGE / 'production-north_coast-current-scope.bin'), str(candidates), str(result_path)], capture_output=True, text=True)
    (OUT / 'native-run.log').write_text(run.stdout + run.stderr); assert run.returncode == 0, run.stderr
    with result_path.open() as f:
        results = list(csv.DictReader(f))
    point_lookup = {(r['area'], int(r['id'])): r for r in results if r['kind'] == 'P'}
    sample_ids = {point: i for i, point in enumerate(samples)}
    for row in records.values():
        sid = sample_ids[tuple(map(float, row['cell']))]
        row['effective_support'] = {a: {'height_world_m': point_lookup[a, sid]['height'], 'height_model_m': float(point_lookup[a, sid]['height']) / 1.3} for a in views}
    obligations = []
    for e in external:
        n = e['neighbor_cell'][1] * W + e['neighbor_cell'][0]; neighbor = records[str(n)]
        if neighbor['inferred_water_datum_model_m'] is not None:
            obligations.append({'edge': e, 'neighbor_role': neighbor['source_role'], 'neighbor_raw': neighbor['raw'], 'neighbor_current': neighbor['effective_support'], 'constraint': 'Original decoder-open direct incident edge touches protected6m bridge and water/shore with proposed2m datum. A continuous reviewed grade/effective-support solution is required; do not assume compatibility or create invisible6m water support.'})
    report = {'mode': 'READ_ONLY_ALL198_BRIDGE_INCIDENT_EDGES', 'source_raw_sha256': sha(raw_path), 'bridge_components': components, 'protected_cells_per_view': {a: len(d['protected_bridge_cells']) for a, d in views.items()}, 'protected_source_open': sum(opened(i) for i in protected), 'all_cardinal_directed_incidents': len(edges), 'both_open_cardinal_directed_incidents': sum(e['both_source_open'] for e in edges), 'unique_both_open_cardinal_edges': len(unique_edges), 'unique_external_both_open_cardinal_edges': len(external), 'external_neighbor_roles': dict(Counter(records[str(e['neighbor_cell'][1] * W + e['neighbor_cell'][0])]['source_role'] for e in external)), 'water_grade_obligations': obligations, 'diagonal_sensitivity': {'directed_incidents': len(diagonals), 'permissive_both_open': sum(e['both_source_open'] for e in diagonals), 'closed_corner_rejection_both_open': sum(e['both_source_open'] and not e['closed_corner_rejected'] for e in diagonals)}, 'cells': records, 'cardinal_incidents': edges, 'diagonal_incidents': diagonals, 'native_samples': len(samples), 'native_result_rows': len(results), 'native_segment_failures_by_view': dict(Counter(r['area'] for r in results if r['kind'] == 'E' and (r['ok'] != '1' or r['reverse_ok'] != '1'))), 'source_hashes': pins, 'source_changed': [p for p, h in pins.items() if sha(ROOT / p) != h], 'limits': ['Original-open means the available merged-client decoder bit, not unproved full server movement permission.', 'Native calls use the exact prior Godot production packed-byte snapshot/current shared C++ implementation; no live scene/player/pet proof.', 'Water2m and bridge6m are current3D adaptation constraints, not original2D altitude metadata.', 'Main bridge crosses the technical x440 crop; retain the whole existing bridge owner rather than inventing a West boundary.', 'Cardinal obligations and diagonal sensitivity are separate; no route or height/source mask was modified.']}
    assert not report['source_changed']
    (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ['cells', 'cardinal_incidents', 'diagonal_incidents', 'source_hashes', 'water_grade_obligations']}, indent=2))
    print('Water/shore bridge grade obligations:', len(obligations))


if __name__ == '__main__':
    main()
