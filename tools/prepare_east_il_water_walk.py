"""Private source-bounded242water-floor/three-entry height proposal; no runtime publication."""
import base64
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate'
ENTRY_HEIGHT = 2.10


def main():
    source_path = ROOT/'assets/maps/falan/east_region/il_source_completion/data.json'
    raw_path = source_path.with_name('hybrid-map.bin'); raw = raw_path.read_bytes(); source = json.loads(source_path.read_text())
    width, height = source['size']; count = width*height; values = struct.unpack_from(f'<{count*3}H', raw, 20); bits = base64.b64decode(source['native_walk']['after_bits'])
    pop_path = ROOT/'assets/maps/falan/east_region/population.json'; route_path = ROOT/'assets/maps/falan/east_region/routes.json'
    actors = [r for r in json.loads(pop_path.read_text())['actors'] if r.get('source') == 2000]
    routes = json.loads(route_path.read_text()); endpoints = []
    for row in routes['fixed']:
        if row[0] == 2000: endpoints.append(row[1:3])
        if row[3] == 2000: endpoints.append(row[4:6])
    for row in routes['event_links']:
        if row.get('source') == 2000: endpoints.append(row['cell'])
        if row.get('target') == 2000: endpoints.append(row['landing'])
    protected = [a['cell'] for a in actors]+endpoints
    def valid(cell): return 0 <= cell[0] < width and 0 <= cell[1] < height
    def at(cell): return cell[1]*width+cell[0]
    def opened(cell): return valid(cell) and bool(bits[at(cell) >> 3] & (1 << (at(cell) & 7)))
    def protected_cell(cell): return any(max(abs(cell[0]-p[0]), abs(cell[1]-p[1])) <= 2 for p in protected)
    def anchor(cell): return [(cell[0]-width//2)*3, (cell[1]-height//2)*3]
    water = []
    for i in range(count):
        if values[count+i] != 252: continue
        cell = [i % width, i // width]
        assert opened(cell) and values[i] in range(5000, 5009)
        water.append({'source_cell': cell, 'anchor': anchor(cell), 'source_bg': values[i], 'source_object': 252, 'source_marker': values[count*2+i], 'height': 2.0})
    assert len(water) == 242
    ramps, changed = [], {}
    for bank, direction in [([32, 59], [0, 1]), ([58, 34], [-1, 0]), ([57, 76], [-1, 0])]:
        dx, dz = direction; side = [-dz, dx]; control = [bank[0]-dx, bank[1]-dz]
        run = [[bank[0]+dx*k, bank[1]+dz*k] for k in range(4)]
        assert values[count+at(control)] == 252 and values[count+at(bank)] in range(12500, 12536)
        assert all(opened(cell) and not protected_cell(cell) for cell in run)
        assert all(values[count+at(cell)] == 0 and values[at(cell)] not in range(5000, 5009) and values[at(cell)] for cell in run[1:])
        base = anchor(bank); a = [base[0]+dx*1.5, base[1]+dz*1.5]; b = [a[0]+dx*7.2, a[1]+dz*7.2]
        landing_end = [base[0]+dx*10.5, base[1]+dz*10.5]
        ramp = {'source_bank_cell': bank, 'source_water_cell': control, 'source_bank_graphic': values[count+at(bank)], 'source_run_cells': run,
                'direction': direction, 'a': a, 'b': b, 'landing_end': landing_end, 'half': 1.5, 'h0': ENTRY_HEIGHT, 'h1': 6.0, 'length': 7.2, 'grade': (6.0-ENTRY_HEIGHT)/7.2,
                'world_scale': 1.3, 'inferred_water_edge_jump_world': (ENTRY_HEIGHT-2.0)*1.3,
                'inferred': 'Three original-open object-free dry cells grade to a2.10m entry bank, then the existing2m visible water. The0.13m world lip respects the unchanged0.15m native step limit. No new source cell or visible bridge.'}
        ramps.append(ramp)
        for along in range(1, 3):
            for lateral in [0]:
                cell = [bank[0]+dx*along+side[0]*lateral, bank[1]+dz*along+side[1]*lateral]
                if not opened(cell) or protected_cell(cell): continue
                i = at(cell)
                if not values[i] or values[i] in range(5000, 5009) or values[count+i] != 0: continue
                grade_surface = ENTRY_HEIGHT+(along*3-1.5)*((6.0-ENTRY_HEIGHT)/7.2)
                target = 0.0
                key = tuple(cell)
                if key not in changed or target < changed[key]['after_height']:
                    changed[key] = {'source_cell': cell, 'anchor': anchor(cell), 'source_floor': values[i], 'source_object': 0,
                                    'before_height_expected': 6.0, 'after_height': target, 'original_attribute_open': True,
                                    'grade_surface_height': grade_surface,
                                    'protected_actor_or_route_within2cells': False, 'inferred': 'Hidden underlay cut below the existing Palace/Ramparts graded ground surface, reusing the canal-bridge replacement contract. Original source bytes and covered mask stay unchanged.'}
    rectangles, active = [], {}
    # The joined Source100 field already treats this native wet bank as6m land.
    # Its hidden vertex would overtake the lower entry cap, unlike local Il.
    bank = [58, 34]; i = at(bank)
    assert opened(bank) and values[i] == 5000 and values[count+i] == 12515
    changed[tuple(bank)] = {'source_cell': bank, 'anchor': anchor(bank), 'source_floor': values[i], 'source_object': values[count+i],
                            'before_height_expected': 6.0, 'after_height': 0.0, 'original_attribute_open': True,
                            'only_terrain_variant': 'east_gate', 'grade_surface_height': ENTRY_HEIGHT,
                            'protected_actor_or_route_within2cells': False,
                            'inferred': 'Joined field only: cut the hidden native wet-bank vertex below its lowered entry cap. Local Il already has wet underlay here. Covered/source bytes stay unchanged.'}
    for z in range(height):
        runs, start = [], None
        for x in range(width+1):
            blocked = x < width and not opened([x, z])
            if blocked and start is None: start = x
            if not blocked and start is not None: runs.append((start, x)); start = None
        next_active = {}
        for a, b in runs:
            if (a, b) in active: rectangle = active[a, b]; rectangle[3] += 1
            else: rectangle = [a, z, b-a, 1]; rectangles.append(rectangle)
            next_active[a, b] = rectangle
        active = next_active
    data = {'schema': 1, 'source': 2000, 'size': [width, height], 'water_floor_height': 2.0, 'water_rows': water, 'ramps': ramps,
            'height_changes': sorted(changed.values(), key=lambda r: (r['source_cell'][1], r['source_cell'][0])),
            'counts': {'source252_water_cells': 242, 'source_control_components': 3, 'original_bank_contacts': 143, 'prototype_reconnections': 3, 'height_vertices': len(changed), 'local_height_vertices': 6, 'joined_height_vertices': 7},
            'isolated_probe_original_blocked_rectangles': rectangles,
            'source_hashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [source_path, raw_path, pop_path, route_path]},
            'reuse': ['World.water_support_height existing2m water datum', 'Palace static floor shapes', 'Ramparts prepared exact floor/ramp pieces', 'Existing3m terrain height grid, copied privately'],
            'limits': ['Only a private three-entry prototype. Full143direct contact parity is not claimed.', 'Native geometry/clearance/route and actual player/pet ascent/return plus normal/second views are required.', 'Every height change is inferred3D translation. Original water/ground/object/marker/NPC/door/event/walk source bytes are unchanged.']}
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch(); (OUT/'data.json').write_text(json.dumps(data, indent=2)+'\n')
    print('Private Il252proposal:', data['counts'], 'No shared/canonical files changed.')


if __name__ == '__main__': main()
