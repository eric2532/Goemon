"""Read-only native100/2400 shoreline ownership and directed-adjacency census."""
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

from audit_east_alyut_water_overlap import labels
from prepare_east_region_maps import reference_map

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
OUT = REPORT / 'Village Props/Cliff Audit/Source Context Audit'
FULL = ROOT / 'assets/maps/falan/east_region/alyut_source_completion'
OFFSET = (529, 20)
STEPS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    interface = REPORT / 'Il Source Completion/Low Source Candidate/Host/shore-interface-plan.json'
    protected = json.loads(interface.read_text())['protected_context_rows']
    selected = {tuple(row['cell']) for row in protected}
    assert len(selected) == len(protected) == 430
    source_path = REPORT / 'Version Expansion Source Audit/map__00100_field1'
    source_refs = REPORT / 'Version Expansion Source Audit/references.json'
    reference = next(row for row in json.loads(source_refs.read_text()) if row['file'] == source_path.name)
    raw = source_path.read_bytes()
    assert digest(source_path) == reference['sha256']
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == reference['git_blob']
    w, h, planes, title = reference_map(raw, 100); count = w * h
    bg, pg = planes[:count], planes[count:]
    lookup = lib.serial_index(); walk = navigation_grid(w, h, bg, pg, lookup)
    active_path = ROOT / 'assets/maps/falan/freyja_source/100.dat'
    aw, ah, abg, apg, flags = lib.parse_map(active_path.read_bytes())
    assert (aw, ah) == (w, h)
    for row in protected:
        x, y = row['cell']; i = y * w + x
        assert (bg[i], pg[i]) == (abg[i], apg[i]) == (row['floor'], row['object']) and walk[i]
    full = json.loads((FULL / 'map-data.json').read_text())
    assert full['size'] == [100, 100]
    tbg = struct.unpack('<10000H', zlib.decompress(base64.b64decode(full['ground_u16le_deflate'])))
    tpg = struct.unpack('<10000H', zlib.decompress(base64.b64decode(full['objects_u16le_deflate'])))
    twalk = zlib.decompress(base64.b64decode(full['walk_bits']))
    town_labels, town_sizes = labels(100, 100, [bool(twalk[i >> 3] & (1 << (i & 7))) for i in range(10000)], set())
    banks = {tuple(row['source_cell']): row for row in json.loads((FULL / 'banks.json').read_text())['rows']}
    exceptions = {tuple(row['field_cell']) for name, key in [('gate-handoffs.json', 'handoff_cells'), ('source-overlaps.json', 'source100_overlap_cells')]
                  for row in json.loads((FULL / name).read_text())[key]}
    assert not selected & exceptions
    routes_path = ROOT / 'assets/maps/falan/east_region/routes.json'; routes = json.loads(routes_path.read_text())
    stops = {(row[1], row[2]) for row in routes['fixed'] if row[0] == 100}
    field_labels, field_sizes = labels(w, h, walk, stops)

    def state(cell):
        x, y = cell; i = y * w + x; tx, ty = x - OFFSET[0], y - OFFSET[1]
        inside = 0 <= tx < 100 and 0 <= ty < 100
        label = field_labels[i]
        result = {'field_cell': [x, y], 'field_bg': int(bg[i]), 'field_pg1': int(pg[i]), 'field_native_open': bool(walk[i]),
                  'field_recorded': bool(flags[i] & 0xc000), 'field_static_warp': cell in stops,
                  'field_portal_stopped_component': label, 'field_component_cells': field_sizes[label] if label >= 0 else 0,
                  'inside_village_rectangle': inside, 'village_cell': [tx, ty], 'protected430': cell in selected}
        if inside:
            ti = ty * 100 + tx; tl = town_labels[ti]; bank = banks.get((tx, ty))
            result.update({'town_bg': int(tbg[ti]), 'town_pg1': int(tpg[ti]), 'town_native_open': tl >= 0,
                           'town_component': tl, 'town_component_cells': town_sizes[tl] if tl >= 0 else 0,
                           'raw_pair_equal': (bg[i], pg[i]) == (tbg[ti], tpg[ti]),
                           'published_bank': bank is not None, 'published_bank_is_new': bank is not None and not bank['cached_cell_known'],
                           'town_bank_graphic': int(bank['serial']) if bank else None,
                           'current_logical_owner_expected': 100 if cell in exceptions else 2400})
        else: result['current_logical_owner_expected'] = 100
        return result

    rows = [state(cell) for cell in sorted(selected, key=lambda p: (p[1], p[0]))]
    incident = []
    for x, y in sorted(selected):
        for dx, dy in STEPS:
            other = (x + dx, y + dy)
            if not (0 <= other[0] < w and 0 <= other[1] < h): continue
            if other in selected and other < (x, y): continue
            a, b = state((x, y)), state(other)
            incident.append({'a': a, 'b': b, 'original100_open_edge': a['field_native_open'] and b['field_native_open'],
                             'corresponding2400_open_edge': a.get('town_native_open', False) and b.get('town_native_open', False),
                             'crosses_village_rectangle': a['inside_village_rectangle'] != b['inside_village_rectangle']})
    boundary = []
    for ty in range(100):
        for tx in range(100):
            for dx, dy in STEPS:
                nx, ny = tx + dx, ty + dy
                if 0 <= nx < 100 and 0 <= ny < 100: continue
                a, b = state((tx + OFFSET[0], ty + OFFSET[1])), state((nx + OFFSET[0], ny + OFFSET[1]))
                boundary.append({'a': a, 'b': b, 'original100_open_edge': a['field_native_open'] and b['field_native_open'],
                                 'town_native_open_inside': a['town_native_open'],
                                 'original_gate_at_either_cell': a['field_static_warp'] or b['field_static_warp']})
    pairs = {'fixed': [row for row in routes['fixed'] if row[0] != row[3] and {row[0], row[3]} == {100, 2400}]}
    for name in ['inline_warps', 'event_links', 'automatic', 'gated_static_rows']:
        pairs[name] = [row for row in routes[name] if row.get('source') != row.get('target') and {row.get('source'), row.get('target')} == {100, 2400}]
    graph_proof = []
    for record in routes['source_graphs']:
        path = ROOT / record['path']; assert digest(path) == record['sha256']
        graph = json.loads(path.read_text()); links = graph.get('links', graph.get('edges', []))
        found = [row for row in links if row.get('source') != row.get('target') and {row.get('source'), row.get('target')} == {100, 2400}]
        graph_proof.append({'path': record['path'], 'sha256': record['sha256'], 'cross_map_links': found})
    population_path = ROOT / 'assets/maps/falan/east_region/population.json'
    population = json.loads(population_path.read_text()); source_actors = [a for a in population['actors'] if a['source'] in [100, 2400]]
    field_rectangle_actors = [a for a in source_actors if a['source'] == 100 and 529 <= a['cell'][0] < 629 and 20 <= a['cell'][1] < 120]
    script_hits = []
    for actor in source_actors:
        program = population['scripts'].get(actor['script'], {})
        for line, command in program.get('lines', []):
            match = re.search(r'^\s*Warp\s+[^,]+,\s*(100|2400)\s*,', command, re.I)
            if match and int(match[1]) != actor['source']: script_hits.append({'actor': actor['id'], 'source': actor['source'], 'script': actor['script'], 'line': line, 'command': command})
    item_path = ROOT / 'assets/maps/falan/east_region/items.json'; item_hits = []
    for ident, item in json.loads(item_path.read_text())['items'].items():
        for line, command in (item.get('program') or {}).get('lines', []):
            if re.search(r'^\s*Warp\s+[^,]+,\s*(100|2400)\s*,', command, re.I):
                item_hits.append({'item': ident, 'line': line, 'command': command, 'source_context': 'Any held-item context satisfying this original program; not a proved100-to2400gate.'})
    bank_edges = []
    for tx, ty in sorted(banks):
        for dx, dy in STEPS:
            nx, ny = tx + dx, ty + dy
            if not (0 <= nx < 100 and 0 <= ny < 100): continue
            a, b = state((tx + OFFSET[0], ty + OFFSET[1])), state((nx + OFFSET[0], ny + OFFSET[1]))
            bank_edges.append({'a': a, 'b': b, 'original2400_open_edge': a['town_native_open'] and b['town_native_open'],
                               'original100_open_edge': a['field_native_open'] and b['field_native_open'],
                               'bank_to_source_closed_water': not b['town_native_open'] and 5000 <= b['town_bg'] <= 5008})
    all_points = {tuple(row['field_cell']) for edge in incident + boundary + bank_edges for row in [edge['a'], edge['b']]}
    all_points.update(tuple(a['cell']) for a in field_rectangle_actors)
    for gate in pairs['fixed']:
        all_points.add(tuple(gate[1:3]) if gate[0] == 100 else (gate[1] + OFFSET[0], gate[2] + OFFSET[1]))
        all_points.add(tuple(gate[4:6]) if gate[3] == 100 else (gate[4] + OFFSET[0], gate[5] + OFFSET[1]))
    paths = [Path(__file__), interface, source_path, source_refs, active_path, routes_path, population_path, item_path,
             *[FULL / name for name in ['map-data.json', 'hybrid-map.bin', 'banks.json', 'gate-handoffs.json', 'source-overlaps.json']]]
    prepared_manifest = json.loads((FULL / 'prepared-source-manifest.json').read_text())
    for name, expected in prepared_manifest['runtime_files'].items():
        path = FULL / name; assert digest(path) == expected
        if path not in paths: paths.append(path)
    paths.append(FULL / 'prepared-source-manifest.json')
    whole_rectangle = [state((x + OFFSET[0], y + OFFSET[1])) for y in range(100) for x in range(100)]
    whole_counts = {'cells': len(whole_rectangle), 'equal_raw_pairs': sum(r['raw_pair_equal'] for r in whole_rectangle),
                    'field_open_town_closed': sum(r['field_native_open'] and not r['town_native_open'] for r in whole_rectangle),
                    'field_closed_town_open': sum(not r['field_native_open'] and r['town_native_open'] for r in whole_rectangle),
                    'both_open': sum(r['field_native_open'] and r['town_native_open'] for r in whole_rectangle),
                    'both_closed': sum(not r['field_native_open'] and not r['town_native_open'] for r in whole_rectangle),
                    'active100_unknown': sum(not r['field_recorded'] for r in whole_rectangle)}
    counts = {'protected_cells': len(rows), 'exact_raw_pairs': sum(r['raw_pair_equal'] for r in rows),
              'town_open': sum(r['town_native_open'] for r in rows), 'town_closed': sum(not r['town_native_open'] for r in rows),
              'town_closed_void': sum(not r['town_native_open'] and r['town_bg'] == 0 for r in rows),
              'town_closed_water': sum(not r['town_native_open'] and 5000 <= r['town_bg'] <= 5008 for r in rows),
              'published_banks': sum(r['published_bank'] for r in rows), 'published_new_banks': sum(r['published_bank_is_new'] for r in rows),
              'incident_edges': len(incident), 'original100_open_incident_edges': sum(e['original100_open_edge'] for e in incident),
              'original100_open_edges_not2400_open': sum(e['original100_open_edge'] and not e['corresponding2400_open_edge'] for e in incident),
              'rectangle_perimeter_edges': len(boundary), 'original100_open_perimeter_edges': sum(e['original100_open_edge'] for e in boundary),
              'all_published_banks': len(banks), 'bank_directed_edges': len(bank_edges),
              'bank_directed_town_open_edges': sum(e['original2400_open_edge'] for e in bank_edges),
              'bank_directed_closed_water_edges': sum(e['bank_to_source_closed_water'] for e in bank_edges)}
    assert counts['exact_raw_pairs'] == 34 and counts['town_open'] == 267 and counts['town_closed'] == 163
    OUT.mkdir(parents=True, exist_ok=True)
    result = {'scope': 'READ ONLY. Distinct original100 and2400 source layouts, not a permission to merge or erase either. Cells and adjacency edges are counted separately;163closed town cells are not163independent routes.',
              'source100': reference, 'source2400_hybrid_sha256': full['source']['sha256'], 'joined_source_offset': OFFSET,
              'counts': counts, 'whole_rectangle_counts': whole_counts, 'protected_rows': rows, 'incident_edges': incident, 'perimeter_edges': boundary, 'published_bank_edges': bank_edges,
              'fixed_and_compiled_gate_pairs': pairs, 'all_source_graph_gate_proof': graph_proof,
              'active_source_actor_count': len(source_actors), 'source100_actors_inside_village_overlay': field_rectangle_actors,
              'raw_script_cross_map_warp_hits': script_hits,
              'held_item_program_warp_hits': item_hits,
              'source_hashes': {str(p.relative_to(ROOT)): digest(p) for p in paths},
              'limits': ['Native orthogonal source walk adjacency is authoritative here. Runtime terrain/caps sampled separately; no assembled native-actor movement claimed.',
                         'Current seamless source owner takes2400inside the rectangle except18explicit handoff/overlap cells. Physical support and logical ownership can disagree.',
                         'The four100-to2400and four2400-to100fixed transfers occur inside the overlaid rectangle, not at its outer perimeter.']}
    (OUT / 'native-shore-context.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    probe = {'source_audit_sha256': digest(OUT / 'native-shore-context.json'), 'rows': [state(cell) for cell in sorted(all_points)],
             'incident_edges': [[edge['a']['field_cell'], edge['b']['field_cell']] for edge in incident if edge['original100_open_edge']],
             'perimeter_edges': [[edge['a']['field_cell'], edge['b']['field_cell']] for edge in boundary],
             'bank_edges': [[edge['a']['field_cell'], edge['b']['field_cell']] for edge in bank_edges],
             'source_hashes': result['source_hashes']}
    (OUT / 'probe-input.json').write_text(json.dumps(probe, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(counts, indent=2)); print('gate pairs', {k: len(v) for k, v in pairs.items()}, 'raw actor script hits', len(script_hits), 'held-item hits', len(item_hits))


if __name__ == '__main__': main()
