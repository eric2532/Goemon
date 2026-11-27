"""Summarize the read-only native/composite shoreline audit; publish no runtime files."""
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    native_path, runtime_path = OUT / 'native-shore-context.json', OUT / 'runtime-shore-context.json'
    native, runtime = [json.loads(p.read_text()) for p in [native_path, runtime_path]]
    assert runtime['source_audit_sha256'] == sha(native_path)
    assert runtime['source_changed_during_run'] == []
    stale = [p for p, value in runtime['source_snapshot'].items() if sha(ROOT / p) != value]
    assert not stale, stale
    log = (OUT / 'runtime-probe.log').read_text()
    assert not any(token in log for token in ['SCRIPT ERROR', 'Parse Error', 'Assertion failed'])
    radius = 1
    selected = [r for r in runtime['rows'] if r['protected430']]
    assert len(selected) == 430
    row_lookup = {tuple(r['field_cell']): r for r in runtime['rows']}
    perimeter = {(tuple(e['a']['field_cell']), tuple(e['b']['field_cell'])): e for e in native['perimeter_edges']}
    bank_edges = {(tuple(e['a']['field_cell']), tuple(e['b']['field_cell'])): e for e in native['published_bank_edges']}
    clear = lambda edge: edge['terrain_caps_plus_published_village_plan_clear'][radius]
    perimeter_open = [e for e in runtime['rectangle_perimeter_edges'] if perimeter[(tuple(e['a']), tuple(e['b']))]['original100_open_edge']]
    perimeter_closed = [e for e in runtime['rectangle_perimeter_edges'] if not perimeter[(tuple(e['a']), tuple(e['b']))]['original100_open_edge']]
    bank_open = [e for e in runtime['published_bank_directed_edges'] if bank_edges[(tuple(e['a']), tuple(e['b']))]['original2400_open_edge']]
    bank_closed = [e for e in runtime['published_bank_directed_edges'] if not bank_edges[(tuple(e['a']), tuple(e['b']))]['original2400_open_edge']]
    counts = {'source430_current_logical_owners': dict(Counter(r['current_source'] for r in selected)),
              'source430_supported_centers': sum(r['terrain_caps_clear'][radius] for r in selected),
              'source430_unsupported_centers': sum(not r['terrain_caps_clear'][radius] for r in selected),
              'town_open430_unsupported_centers': sum(r['town_native_open'] and not r['terrain_caps_clear'][radius] for r in selected),
              'protected_published_bank_centers': sum(r['published_bank'] for r in selected),
              'protected_published_bank_centers_supported': sum(r['published_bank'] and r['terrain_caps_clear'][radius] for r in selected),
              'original100_open_incident_segments': len(runtime['incident_original100_open_edges']),
              'original100_open_incident_segments_clear': sum(clear(e) for e in runtime['incident_original100_open_edges']),
              'original100_open_perimeter_segments': len(perimeter_open), 'original100_open_perimeter_segments_clear': sum(clear(e) for e in perimeter_open),
              'original100_closed_perimeter_segments': len(perimeter_closed), 'original100_closed_perimeter_segments_terrain_clear': sum(clear(e) for e in perimeter_closed),
              'original2400_bank_open_directed_segments': len(bank_open), 'original2400_bank_open_directed_segments_clear': sum(clear(e) for e in bank_open),
              'original2400_bank_closed_directed_segments': len(bank_closed), 'original2400_bank_closed_directed_segments_terrain_clear': sum(clear(e) for e in bank_closed)}
    assert counts['original2400_bank_open_directed_segments_clear'] == 351
    clear_closed = []
    for edge in bank_closed:
        if not clear(edge): continue
        original = bank_edges[(tuple(edge['a']), tuple(edge['b']))]
        clear_closed.append({'from_town': original['a']['village_cell'], 'to_town': original['b']['village_cell'],
                             'target_source100': original['b']['field_cell'], 'town_layers': [original['b']['town_bg'], original['b']['town_pg1']],
                             'field_layers': [original['b']['field_bg'], original['b']['field_pg1']],
                             'current_logical_owner': original['b']['current_logical_owner_expected'],
                             'disposition': 'Existing six-cell source100 overlap handoff' if original['b']['current_logical_owner_expected'] == 100 else 'Distinct original100 dry route, currently assigned2400; requires separate context review'})
    actors = []
    for actor in native['source100_actors_inside_village_overlay']:
        sampled = row_lookup[tuple(actor['cell'])]
        actors.append({'id': actor['id'], 'type': actor['type'], 'source100_cell': actor['cell'],
                       'town_cell': sampled['village_cell'], 'current_source': sampled['current_source'],
                       'current_terrain_caps_clear': sampled['terrain_caps_clear'], 'script': actor['script'],
                       'automatic_source_context_conflict': actor['type'].lower() == 'warp' and sampled['current_source'] != 100})
    summary = {'status': 'READ_ONLY_SOURCE_ROUTE_DIAGNOSIS; no runtime publication', 'native_counts': native['counts'],
               'whole_rectangle_counts': native['whole_rectangle_counts'], 'runtime_counts': counts,
               'actor_contexts': actors, 'bank_closed_clear_segments': clear_closed,
               'source_gate_pairs': native['fixed_and_compiled_gate_pairs'],
               'freshness': {'native_audit_sha256': sha(native_path), 'runtime_audit_sha256': sha(runtime_path), 'source_changed_during_run': [], 'current_snapshot_mismatches': stale,
                             'runtime_snapshot_paths': len(runtime['source_snapshot']), 'engine': 'Godot4.6.1 stable official14d19694e',
                             'platform_note': 'macOS get_system_ca_certificates ret!=noErr warning; no ScriptError, ParseError or assertion failure.'},
               'limits': runtime['scope']}
    (OUT / 'review-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    image = Image.new('RGB', (1050, 600), '#181d24'); draw = ImageDraw.Draw(image)
    draw.text((20, 15), 'SCHEMATIC SOURCE WALK COMPARISON — not source artwork or a rendered gameplay view', fill='white')
    for panel, label in enumerate(['Original100 wet/control cells (430)', 'Original2400 walk at those same joined positions']):
        ox, oy, pitch = 20 + panel * 520, 65, 5
        draw.text((ox, 40), label, fill='white')
        draw.rectangle((ox, oy, ox + 500, oy + 500), fill='#313943')
        for row in native['protected_rows']:
            x, y = row['village_cell']; color = '#8cd9b3' if panel == 0 or row['town_native_open'] else '#df6d70'
            draw.rectangle((ox + x*pitch, oy + y*pitch, ox + (x+1)*pitch-1, oy + (y+1)*pitch-1), fill=color)
        for gate in native['fixed_and_compiled_gate_pairs']['fixed']:
            if gate[0] != 2400: continue
            x, y = gate[1:3]; draw.ellipse((ox + x*pitch-3, oy + y*pitch-3, ox + x*pitch+3, oy + y*pitch+3), outline='#ffe26c', width=2)
        tx, ty = 20, 23; draw.line((ox + tx*pitch-4, oy + ty*pitch-4, ox + tx*pitch+4, oy + ty*pitch+4), fill='white', width=2)
        draw.line((ox + tx*pitch-4, oy + ty*pitch+4, ox + tx*pitch+4, oy + ty*pitch-4), fill='white', width=2)
    draw.text((20, 575), 'Green: native open. Red: native2400 closed. Yellow circles:2400 return gates. White X:100 tide entrance549,43.', fill='white')
    image.save(OUT / 'source-walk-comparison.png')
    print(json.dumps(counts, indent=2))


if __name__ == '__main__': main()
