"""Read-only bridge reference/owner/piece addendum; never writes raw or field products."""
from collections import Counter
import base64
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT.parent / 'Magic Power/tools'), str(ROOT / 'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
from build_freyja_destinations import load_map

R = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
OUT = R / 'Runtime Audit/Source100 Bridge Edge Audit'
FIELD = R / 'Il Source Completion/Low Source Candidate/Host/Original100 Candidate'
RAW = R / 'Village Props/Cliff Audit/Source Context Audit/Prototype/100.dat'
FULL = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
W, H = 840, 610
F32 = lambda x: struct.unpack('<f', struct.pack('<f', x))[0]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    base = json.loads((OUT / 'report.json').read_text())
    data = RAW.read_bytes(); reference = FULL.read_bytes()
    assert sha(RAW) == base['source_raw_sha256']
    _, _, ground, objects, flags = lib.parse_map(reference)
    ref_open = navigation_grid(W, H, ground, objects, lib.serial_index())
    rows = []
    for entry in base['cells'].values():
        i = entry['index']; target = [ground[i], objects[i]]
        if target == entry['raw'][:2]:
            continue
        assert not entry['raw'][2] & 0xc000 and entry['raw'][:2] == [0, 0]
        rows.append({'cell': entry['cell'], 'index': i, 'before': entry['raw'][:2], 'pinned_after': target, 'flags_preserved': entry['raw'][2], 'protected_bridge': entry['protected_bridge'], 'pinned_reference_open': bool(ref_open[i]), 'role': 'original_dry_paving' if ground[i] not in [0, 100] and not 5000 <= ground[i] <= 5008 else 'water_or_void', 'owner': 'existing_whole_East_bridge_source_identity' if entry['protected_bridge'] else 'existing_Falan_gate_approach_source_identity', 'no_new_graphic_activation': True})
    assert len(rows) == 24 and all(row['role'] == 'original_dry_paving' for row in rows)
    assert sum(row['protected_bridge'] for row in rows) == 12
    protected = {c['index'] for c in base['cells'].values() if c['protected_bridge']}
    ref_cardinal = [e for e in base['cardinal_incidents'] if ref_open[e['bridge_cell'][1] * W + e['bridge_cell'][0]] and ref_open[e['neighbor_cell'][1] * W + e['neighbor_cell'][0]]]
    ref_external = [e for e in ref_cardinal if not e['neighbor_protected']]
    production = json.loads((FIELD / 'Production Scaling/contract.json').read_text())
    pieces = {}; pins = {}
    for area, values in production['areas'].items():
        row = values['new']['arrays']['pieces']; path = ROOT / row['path'].removeprefix('res://'); raw = path.read_bytes()
        assert len(raw) == row['bytes'] and sha(path) == row['sha256'] and len(raw) % 40 == 0
        pieces[area] = list(struct.iter_unpack('<10f', raw)); pins[str(path.relative_to(ROOT))] = sha(path)

    def memberships(area, x, z):
        scale = F32(1.3)
        px, pz = (F32((x * 3 - 1902) * scale), F32((z * 3 - 333) * scale)) if area == 'north_coast' else (F32((591 - z * 3) * scale), F32((x * 3 - 1251) * scale))
        hits = []
        for n, p in enumerate(pieces[area]):
            ox, oz = F32(px - p[0]), F32(pz - p[1])
            along = F32(F32(ox * p[2]) + F32(oz * p[3])); side = F32(F32(-ox * p[3]) + F32(oz * p[2]))
            if p[5] <= 0 or along < p[6] - .001 or along > p[7] + .001 or abs(side) > p[4] + .001:
                continue
            top = p[8] + (p[9] - p[8]) * max(0., min(1., along / p[5]))
            hits.append({'piece_index': n, 'raw10f_world': list(p), 'top_model_m': top / 1.3})
        return hits

    canal = []
    for i in sorted(protected):
        x, z = i % W, i // W
        if not (554 <= x <= 559 and 232 <= z <= 234):
            continue
        c = base['cells'][str(i)]
        canal.append({'cell': [x, z], 'raw': c['raw'], 'effective_support': c['effective_support'], 'explicit_pieces': {a: memberships(a, x, z) for a in pieces}})
    assert len(canal) == 18
    cw, ch, _, co, _ = load_map(lib, 1000)
    owners = []
    street_text = (ROOT / 'assets/maps/falan/city_street_data.gd').read_text()
    for serial, x, z, footprint, city_at in [(10661, 437, 194, [3, 3], [-147, -288]), (10662, 437, 197, [1, 1], [-135, -285]), (10653, 437, 200, [3, 3], [-129, -288])]:
        cx, cz = x - 189, z - 108
        actual = co[cz * cw + cx]
        assert actual == serial
        point = [3 * (cz - 134) - 1.5 * (footprint[1] - 1), 3 * (153 - cx) - 1.5 * (footprint[0] - 1)]
        assert point == city_at
        assert f'[Vector2({city_at[0]},{city_at[1]}),{serial}]' in street_text
        local = [-135 - point[0], -225 - point[1]]
        native_center = [591 - z * 3 + 1.5 * (footprint[1] - 1), x * 3 - 1251 + 1.5 * (footprint[0] - 1)]
        assert local == native_center
        owners.append({'source100_cell': [x, z], 'graphic': serial, 'footprint': footprint, 'current_city1000_projection_cell': [cx, cz], 'current_city1000_raw_graphic': actual, 'compiled_city_center': point, 'exact_East_center': local, 'native_source_footprint_center': native_center, 'owner_region': 'existing_Falan_city1000_fortification_and_gate_goal', 'runtime_owner': 'Frontier.city_vista -> CityForts.build -> Parts.batch' + str(serial) if serial != 10662 else 'Current city beam filtered by city_forts; existing East gate building(0,10) -> Model.falan_gate_area -> Art.gate -> FortParts.gate_spec10662, root(3,6,60)+offset(-3,0,0)', 'original_warp_limit': 'Current presentation delta[-189,-108], not a claim that the literal original intermap warp has this offset.', 'publication': 'Preserve existing owner; no duplicate PG1 mesh, gate, building, route or collider.'})
    sources = [RAW, FULL, Path(__file__), OUT / 'report.json', FIELD / 'Production Scaling/contract.json', ROOT / 'scripts/forest/forest_freyja_art.gd', ROOT / 'scripts/forest/forest_freyja_terrain.gd', ROOT / 'scripts/forest/forest_east_road.gd', ROOT / 'scripts/forest/forest_falan_frontier.gd', ROOT / 'scripts/forest/forest_falan_fort_parts.gd', ROOT / 'scripts/forest/forest_art.gd', ROOT / 'scripts/forest/forest_model.gd', ROOT / 'assets/maps/falan/city_street_data.gd', ROOT / 'assets/maps/falan/web_adventure.json']
    pins.update({str(p.relative_to(ROOT)): sha(p) for p in sources})
    result = {'scope': 'READ_ONLY reference/owner/piece addendum; no raw merge, field regeneration, graphics or Native activation.', 'raw_completion_plan_only': {'base_sha256': sha(RAW), 'reference_sha256': sha(FULL), 'tuples': rows, 'known_overwrites': 0, 'flags_overwrites': 0, 'outside_plan_overwrites': 0, 'status': 'Only the oneHost merger may stage/apply after owner review; no separate100.dat written.'}, 'reference_sensitivity': {'merged_protected_open': base['protected_source_open'], 'full_reference_protected_open': sum(bool(ref_open[i]) for i in protected), 'reference_both_open_cardinal_directed_incidents': len(ref_cardinal), 'reference_external_both_open_cardinal_edges': len(ref_external), 'reference_external_roles': dict(Counter('water' if 5000 <= ground[e['neighbor_cell'][1] * W + e['neighbor_cell'][0]] <= 5008 else 'dry' for e in ref_external)), 'limitation': 'Reference-only outside current merged scope; no extra walking permission/activation inferred.'}, 'halo_graphic_owner_proof': owners, 'canal18_piece_support': canal, 'canal_render_owner': {'East': 'FreyjaTerrain.il_bridge_bounds -> sourceRect(1660.5,694.5,18,9); FreyjaArt.il_bridge -> IlRiverBridge/ArchivedGrassDeck/OriginalSingleArch.', 'North': 'No existing explicit bridge builder: bridge_bounds empty, il_bridge_bounds empty forNorth; all18 PG1=0. Existing plain terrain/ground is present at its independent datum; source canal deck/arch has no matching North renderer in these callers.', 'smallest_reuse_candidate': 'Reuse existing il_bridge builder in the single Host adapter only after a common6m effective surface is prepared; preserve one source bridge and avoid duplicate scenery.'}, 'legacy_Native_window': 'Exact Native CSV in report.json was completed source-clean BEFORE e31 shared apply. This addendum reads data only during the reserved library window.', 'source_hashes': pins, 'source_changed': [p for p, h in pins.items() if sha(ROOT / p) != h]}
    assert not result['source_changed']
    (OUT / 'reference-owner-piece-addendum.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'tuple_gaps': len(rows), 'protected_gaps': 12, 'reference_sensitivity': result['reference_sensitivity'], 'piece_hits_canal': {a: sum(bool(c['explicit_pieces'][a]) for c in canal) for a in pieces}, 'owners': owners}, indent=2))


if __name__ == '__main__':
    main()
