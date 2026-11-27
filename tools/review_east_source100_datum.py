"""Join current CPU datum/collision measurements to the complete pinned source."""
from collections import Counter
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

def prepare():
    datum = json.loads((OUT / 'datum.json').read_text())
    contracts = json.loads((OUT / 'closed-cell-current.json').read_text())
    raw_path = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    raw = raw_path.read_bytes()
    w, h, ground, objects, flags = lib.parse_map(raw)
    walk = navigation_grid(w, h, ground, objects, lib.serial_index())
    base = ROOT / 'assets/maps/falan'
    current_index = Image.open(base / 'freyja_ground_index.png').convert('RGBA')
    candidate_index = Image.open(OUT.parent.parent / 'Source100 Candidate/freyja_ground_index.png').convert('RGBA')
    mask = Image.open(base / 'freyja_residual/full/east_gate-surface.png').convert('RGBA')
    metadata = json.loads((base / 'freyja_residual/full/provenance.json').read_text())
    images = {area: Image.open(base / f'freyja_residual/full/{area}-surface.png').convert('RGBA')
              for area in metadata['areas'] if area not in ['east_gate', 'north_coast', 'east_coast']}

    def owner_envelopes(x, y):
        result = []
        for area, image in images.items():
            row = metadata['areas'][area]
            frame = row['frame']
            dx, dy = x * 3 - frame['origin'][0], y * 3 - frame['origin'][1]
            det = frame['x'][0] * frame['y'][1] - frame['x'][1] * frame['y'][0]
            u = (dx * frame['y'][1] - dy * frame['y'][0]) / det
            v = (frame['x'][0] * dy - frame['x'][1] * dx) / det
            px, py = round((u - row['origin'][0]) / 3), round((v - row['origin'][1]) / 3)
            if 0 <= px < image.width and 0 <= py < image.height:
                result.append(dict(area=area, pixel=[px, py], mask_rgba=list(image.getpixel((px, py))),
                                   meaning='Envelope/mask only; not original BGart or actual Native support proof.'))
        return result

    cells = []
    for row in datum['rows']:
        if row['graphic'] not in [10074, 10089, 12226]:
            continue
        x, y = map(int, row['source_cell'])
        vertices = {}
        for sample in row['lowest_wood_or_boulder_samples']:
            for vertex in sample['field_vertices']:
                gx, gz = map(int, vertex['grid'])
                px, pz = -675 + gx * 3, -204 + gz * 3
                sx, sy = round((pz + 1251) / 3), round((591 - px) / 3)
                index = sy * w + sx
                dry = ground[index] not in [0, 100] and not 5000 <= ground[index] <= 5008
                outside = sy >= 360 or sx < 440
                vertices[gx, gz] = dict(
                    grid=[gx, gz], model_position=[px, pz], source_cell=[sx, sy],
                    bg=ground[index], pg1=objects[index], source_open=bool(walk[index]),
                    current_height=vertex['height'], current_covered=vertex['covered'],
                    source_kind='dry' if dry else 'water' if 5000 <= ground[index] <= 5008 else 'void',
                    must_preserve_zero_void=bool(ground[index] in [0, 100] and vertex['height'] == 0),
                    outside_current_core=outside, other_owner_envelopes=owner_envelopes(sx, sy) if outside else [])
        contract = next(c for c in contracts['rows'] if list(map(int, c['source_cell'])) == [x, y])
        center = [591 - y * 3, x * 3 - 1251]
        zero_vertices = [v for v in vertices.values() if v['current_height'] == 0]
        assert zero_vertices
        cells.append(dict(
            source=100, cell=[x, y], bg=ground[y * w + x], pg1=objects[y * w + x],
            source_open=bool(walk[y * w + x]), source_extent=[x - .5, y - .5, 1, 1],
            model_rect=[center[0] - 1.5, center[1] - 1.5, 3, 3], unscaled_area_m2=9,
            current_anchor=row['anchor'], measured_wood_bottom=row['mesh_local_bottom'],
            root_sample_source_cells=sorted({tuple(s['source_cell']) for s in row['lowest_wood_or_boulder_samples']}),
            current_gap_range=[min(s['vertical_gap'] for s in row['lowest_wood_or_boulder_samples']),
                               max(s['vertical_gap'] for s in row['lowest_wood_or_boulder_samples'])],
            native_BG_index_rgba=list(current_index.getpixel((x, y))),
            private_native_BG_index_rgba=list(candidate_index.getpixel((x, y))),
            current_source_mask_rgba=list(mask.getpixel((422 - y, x - 349))),
            field_vertices=list(vertices.values()), zero_vertex_source_kinds=dict(Counter(v['source_kind'] for v in zero_vertices)),
            current_source_collision_records=contract['exact_source_block_records'],
            current_friendly_anchor_obstacles=contract['friendly_obstacles_containing_anchor'],
            current_source_cell_terrain_contains_samples=sum(s['contains'] for s in contract['terrain_samples']),
            current_support_predicate_samples=contract['terrain_samples'],
            proposal='Exact source-cell-local BGmesh under ONEHost. Preserve truevoid. Rock496359boundary coordinates need other-goal reconciliation; no outside-core height/raw change authorized. OriginalclosedPG1authority needs independent proof.'))
    assert len(cells) == 3
    tree_cells = [c for c in cells if c['pg1'] != 12226]
    assert all(c['zero_vertex_source_kinds'] == {'void': 2} for c in tree_cells)
    rock = next(c for c in cells if c['pg1'] == 12226)
    assert rock['zero_vertex_source_kinds'] == {'dry': 3}
    result = dict(
        status='PRIVATE proposal only; no canonical/render/height/native/collision write',
        cells=cells, cell_count=3, total_unscaled_area_m2=27,
        source_raw_sha256=hashlib.sha256(raw).hexdigest(),
        source_changed_during_cpu_runs=datum['source_changed'] + contracts['source_changed'],
        correction='The earlier core-only13candidate neighborhood left outside-corey360unrecorded. Complete pinned reference proves12226neighbors495360/496360/497360areDRY5034/5030/5348, not void. Candidatezeros are not originalsource.',
        acceptance_required=[
            'Only the two tree-cell footprints may proceed privately; their neighboring BG100void stays unchanged. Rock12226 is held: complete source proves dry/open y360 continuation, while actual East/South/Lakes samplers have a coverage gap and no existing handoff there.',
            'Currentfriendly obstaclescontainnoneoftheseclosedanchors. OriginalclosedPG1physics/native, all original-open/radius/edge/route/landing support and wholebridge ownership require proof.',
            'Native27sources/wood/originsunchanged; foliage/camera quality is separately unfinished.'],
        input_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in [OUT / 'datum.json', OUT / 'closed-cell-current.json', raw_path, Path(__file__)]})
    (OUT / 'three-cell-ground-ledger.json').write_text(json.dumps(result, indent=2) + '\n')
    print([(c['cell'], c['zero_vertex_source_kinds']) for c in cells])

if __name__ == '__main__':
    prepare()
