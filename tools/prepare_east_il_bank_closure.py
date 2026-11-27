"""Prepare the whole Il shoreline candidate without enrolling it in live owners."""
import base64
import hashlib
import json
from pathlib import Path
import struct

from build_freyja_outlying import is_water

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate'


def main():
    source_path = ROOT/'assets/maps/falan/east_region/il_source_completion/data.json'
    raw_path = source_path.with_name('hybrid-map.bin')
    source = json.loads(source_path.read_text()); raw = raw_path.read_bytes()
    width, height = struct.unpack_from('<II', raw, 12); count = width*height
    values = struct.unpack_from(f'<{count*3}H', raw, 20)
    bits = base64.b64decode(source['native_walk']['after_bits'])
    cap_path = ROOT/'assets/maps/falan/east_region/bank_caps/data.json'
    caps = json.loads(cap_path.read_text())['graphics']
    rows, blocked = [], []
    directions = {'west': (-1, 0), 'east': (1, 0), 'north': (0, -1), 'south': (0, 1)}
    opened = lambda i: bool(bits[i >> 3] & (1 << (i & 7)))
    for i in range(count):
        serial = values[count+i]
        if serial not in range(12500, 12536): continue
        x, z = i % width, i // width; cap = caps[str(serial)]; joins, neighbors = [], []
        if opened(i):
            for direction, (dx, dz) in directions.items():
                nx, nz = x+dx, z+dz
                if not (0 <= nx < width and 0 <= nz < height): continue
                at = nz*width+nx
                if not opened(at) or values[at] == 0 or is_water(values[at]) or direction not in cap['approaches']: continue
                joins.append(cap['approaches'][direction]['join_rect'])
                neighbors.append({'direction': direction, 'cell': [nx, nz], 'floor': values[at], 'object': values[count+at],
                                  'original_cache_known': bool(values[count*2+at] & 0xc000), 'source_attribute_open': True})
        row = {'serial': serial, 'source_cell': [x, z], 'anchor': [(x-width//2)*3, (z-height//2)*3],
               'height': 6.0, 'water_height': 2.0, 'native_floor': values[i], 'native_marker': values[count*2+i],
               'original_cache_known': bool(values[count*2+i] & 0xc000), 'source_attribute_open': opened(i),
               'join_rects': joins, 'join_source_neighbors': neighbors,
               'support_only_rects': [[-1.5, -1.5, 1.5, 1.5]] if opened(i) else [], 'support_enabled': opened(i),
               'source_rgba_sha256': cap['source_rgba_sha256'],
               'status': 'Private exact-source candidate. Visual height and actual route equivalence remain acceptance gates.'}
        rows.append(row)
        if not opened(i): blocked.append(row)
    assert len(rows) == 393 and len(blocked) == 4
    assert sum(row['original_cache_known'] for row in rows) == 387
    assert sum(row['source_attribute_open'] for row in rows) == 389
    assert all(row['native_floor'] in range(5000, 5009) for row in rows), 'A visual underlay cut cannot hide source BG dryland'
    assert {(r['source_cell'][0], r['source_cell'][1], r['serial']) for r in blocked} == {(57, 56, 12522), (58, 56, 12523), (75, 75, 12509), (53, 86, 12509)}
    component, pending = set(), [7*width+31]
    for at in pending:
        if at in component or not opened(at): continue
        component.add(at); x, z = at % width, at // width
        for nx, nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
            if 0 <= nx < width and 0 <= nz < height and nz*width+nx not in component and opened(nz*width+nx): pending.append(nz*width+nx)
    assert len(component) == 2667
    assert all(row['source_cell'][1]*width+row['source_cell'][0] in component for row in rows if row['source_attribute_open'])
    bank_cells = {tuple(row['source_cell']) for row in rows}
    water_neighbors = {}
    for x, z in bank_cells:
        for dz in range(-1, 2):
            for dx in range(-1, 2):
                nx, nz = x+dx, z+dz
                if (nx, nz) in bank_cells or not (0 <= nx < width and 0 <= nz < height): continue
                at = nz*width+nx
                if values[at] not in range(5000, 5009): continue
                water_neighbors[(nx, nz)] = {'source_cell': [nx, nz], 'anchor': [(nx-width//2)*3, (nz-height//2)*3],
                                               'source_bg': values[at], 'source_object': values[count+at], 'native_marker': values[count*2+at],
                                               'source_attribute_open': opened(at), 'original_cache_known': bool(values[count*2+at] & 0xc000)}
    water_neighbors = [water_neighbors[cell] for cell in sorted(water_neighbors, key=lambda p: (p[1], p[0]))]
    data = {'source': 2000, 'rows': rows, 'source_blocked_controls': blocked,
            'counts': {'visual': 393, 'known_visual': 387, 'new_visual': 6, 'source_attribute_open': 389, 'source_blocked': 4,
                       'dry_seam_joins': sum(len(row['join_rects']) for row in rows)},
            'source_component_proof': {'original_open_component_seed': [31, 7], 'component_cells': len(component), 'all_389_bank_anchors_in_same_original_component': True,
                                       'all_393_underlying_BG_water': True, 'BG_water_graphics': sorted({row['native_floor'] for row in rows})},
            'underlay_source_water_neighbors': water_neighbors,
            'underlay_source_water_neighbor_counts': {'total': len(water_neighbors), 'source_attribute_open': sum(row['source_attribute_open'] for row in water_neighbors)},
            'source_hashes': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in [source_path, raw_path, cap_path]},
            'preservation': 'Source floor/object/markers, all original NPCs, doors, events and walk bits unchanged. No support for242 nonbank marker252 controls. Laruka and every other region excluded.',
            'inferred': 'Measured native grass contours remain visible. Closed hidden bank continuation6m to2m and invisible support of explicit original-open native bank cells translate source walking into3D; they add no visible land.',
            'publication_gate': ['Six current Il cap actual/native/player/pet/camera acceptance', 'Read-only actual387known owner-height inventory',
                                 'Skip physical floors/pieces for four source-blocked controls; isolated Il closure helper filters supported/visual-only rows without changing Caps',
                                 'Reuse prepared36native cap variants; exact393placement Il-only replacement, then all389anchor/source-chain equivalence and representative actual player/pet approaches']}
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch()
    (OUT/'banks.json').write_text(json.dumps(data, indent=2)+'\n')
    print('Private whole Il bank candidate:', data['counts'], 'No live assets/helpers/owners changed.')


if __name__ == '__main__': main()
