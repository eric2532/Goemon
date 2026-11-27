"""Privately fill only unrecorded Il cells from its pinned complete native map."""
from argparse import ArgumentParser
import base64
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw
from prepare_east_region_maps import MANIFESTS, navigation_function, pinned_maps, reference_map
from build_freyja_outlying import is_road, is_water

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/maps/falan/east_region/il_source_completion'
REPORT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion'


def encoded_png(image):
    result = io.BytesIO(); image.save(result, format='PNG', optimize=True); return result.getvalue()


def products():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    with lib.connection() as db:
        record = dict(db.execute('SELECT * FROM files WHERE path=?', ('BlueCrossgate/map/0/2000.dat',)).fetchone())
    original_path = lib.SOURCE/record['path']; original = original_path.read_bytes()
    proof, reference = pinned_maps(MANIFESTS)[0][2000]
    width, height, source, title = reference_map(reference, 2000); cells = width*height
    assert original[:4] == b'MAP\x01' and struct.unpack_from('<II', original, 12) == (width, height)
    values = struct.unpack_from(f'<{cells*3}H', original, 20); flags = values[cells*2:]
    known = [i for i, marker in enumerate(flags) if marker & 0xc000]
    unknown = [i for i, marker in enumerate(flags) if not marker & 0xc000]
    hybrid = bytearray(original); writes = []
    for i in unknown:
        for plane in range(2):
            at = plane*cells+i; struct.pack_into('<H', hybrid, 20+at*2, source[at])
            if values[at] != source[at]: writes.append([plane, i % width, i // width, values[at], source[at]])
    assert hybrid[:20] == original[:20] and hybrid[20+cells*4:] == original[20+cells*4:]
    assert all(hybrid[20+(plane*cells+i)*2:22+(plane*cells+i)*2] == original[20+(plane*cells+i)*2:22+(plane*cells+i)*2] for i in known for plane in range(2))
    final = struct.unpack_from(f'<{cells*3}H', hybrid, 20)
    variants = []
    for i in known:
        if (values[i], values[cells+i]) == (source[i], source[cells+i]): continue
        kind = 'water_animation_frame' if values[cells+i] == source[cells+i] and is_water(values[i]) and is_water(source[i]) else 'recorded_tree_position' if 10088 in [values[cells+i], source[cells+i]] else 'recorded_flower_presence'
        variants.append({'cell': [i % width, i // width], 'client': [values[i], values[cells+i]], 'reference': [source[i], source[cells+i]], 'kind': kind, 'decision': 'Keep the recorded client tuple unchanged.'})
    assert Counter(r['kind'] for r in variants) == {'water_animation_frame': 56, 'recorded_tree_position': 2, 'recorded_flower_presence': 1}
    lookup = lib.serial_index(); navigation = navigation_function(lib)
    before_walk = navigation(width, height, values[:cells], values[cells:cells*2], lookup)
    after_walk = navigation(width, height, final[:cells], final[cells:cells*2], lookup)
    added_walk = [{'cell': [i % width, i // width], 'client_floor': values[i], 'client_object': values[cells+i],
                   'client_marker': flags[i], 'source_floor': final[i], 'source_object': final[cells+i],
                   'original_cache_known': i in known, 'native_attribute_walkable': True}
                  for i in range(cells) if after_walk[i] and not before_walk[i]]
    assert len(added_walk) == 12 and not any(a and not b for a, b in zip(before_walk, after_walk))
    assert not any(before_walk[i] != after_walk[i] for i in known)
    def packed_walk(walk):
        packed = bytearray((len(walk)+7)//8)
        for i, opened in enumerate(walk):
            if opened: packed[i >> 3] |= 1 << (i & 7)
        return base64.b64encode(packed).decode()
    additions = [[i % width, i // width, final[cells+i], ''] for i in unknown if final[cells+i] >= 1000]
    assert len(additions) == 6 and all(12500 <= row[2] <= 12535 for row in additions)
    bank_caps = []
    caps = json.loads((ROOT/'assets/maps/falan/east_region/bank_caps/data.json').read_text())['graphics']
    for x, z, serial, _ in additions:
        neighbor = z*width+x-1
        assert x > 0 and neighbor in known and after_walk[neighbor]
        approach = caps[str(serial)]['approaches']['west']
        dry_west = not is_water(final[neighbor])
        land_z = 70 if z == 69 else 73 if z == 74 else z
        land = land_z*width+x-1
        assert land in known and after_walk[land] and not is_water(final[land])
        if z == 69:
            source_stand = [-.625, .8125]
        elif z == 74:
            source_stand = [-.6875, -.75]
        else:
            source_stand = approach['stand']
        anchor = [(x-width//2)*3, (z-height//2)*3]
        land_at = [(x-1-width//2)*3, (land_z-height//2)*3]
        path = [land_at, [anchor[0]+source_stand[0], land_at[1]], [anchor[0]+source_stand[0], anchor[1]+source_stand[1]]]
        bank_caps.append({'serial': serial, 'source_cell': [x, z], 'anchor': [(x-width//2)*3, (z-height//2)*3],
                          'height': 6.0, 'water_height': 2.0, 'join_rects': [approach['join_rect']] if dry_west else [],
                          'support_only_rects': [[-1.5, -1.5, 1.5, 1.5]],
                          'source_dry_neighbor': {'cell': [x-1, z], 'bg': final[neighbor], 'object': final[cells+neighbor],
                                                  'cached_cell_known': True, 'native_attribute_open': True, 'dry_land': dry_west},
                          'source_approach_land': {'cell': [x-1, land_z], 'bg': final[land], 'object': final[cells+land],
                                                   'cached_cell_known': True, 'native_attribute_open': True, 'dry_land': True},
                          'approach_via_new_cap': [x, land_z] if not dry_west else None,
                          'source_stand': source_stand, 'source_path_points': path,
                          'approach': approach, 'scope': 'Visible grass follows native alpha; invisible support on the exact original-open bank tile preserves native source anchor/route semantics. Four proven dry-cell joins only; ordinary water is not supported.'})
    buildings = {10603, 10607, 11268, 11269, 11271, 11272, 11273, 11275}
    assert not any(final[cells+i] in buildings for i in unknown)
    index_path = ROOT/'assets/maps/falan/il_village_ground_index.png'; mask_path = ROOT/'assets/maps/falan/freyja_il_village.png'
    index = Image.open(index_path).convert('RGBA'); mask = Image.open(mask_path).convert('RGBA')
    assert index.size == mask.size == (width, height)
    # Reconstruct the unrecorded cache baseline, so publishing these two Il-only
    # derivatives does not change the preparer's inputs on its next --check.
    assert all(values[i] == values[cells+i] == 0 for i in unknown)
    for i in unknown:
        index.putpixel((i % width, i // width), (0, 0, 0, 0))
        mask.putpixel((i % width, i // width), (255, 0, 0, 255))
    original_index, original_mask = index.copy(), mask.copy(); slots = {}
    for i in known:
        rgba = index.getpixel((i % width, i // width))
        if not rgba[3]: continue
        assert values[i] not in slots or slots[values[i]] == rgba
        slots[values[i]] = rgba
    for i in unknown:
        graphic = final[i]
        if graphic:
            assert graphic in slots, ('An unknown cell needs an existing native Il floor tile', graphic)
            index.putpixel((i % width, i // width), slots[graphic])
        if graphic and not is_water(graphic):
            mask.putpixel((i % width, i // width), (0, 220 if is_road(graphic) else 0, 220 if 1000 <= graphic <= 1099 or 5954 <= graphic <= 5988 else 0, 255))
    assert all(index.getpixel((i % width, i // width)) == original_index.getpixel((i % width, i // width)) and mask.getpixel((i % width, i // width)) == original_mask.getpixel((i % width, i // width)) for i in known)
    index_changes = [i for i in range(cells) if index.getpixel((i % width, i // width)) != original_index.getpixel((i % width, i // width))]
    mask_changes = [i for i in range(cells) if mask.getpixel((i % width, i // width)) != original_mask.getpixel((i % width, i // width))]
    assert len(index_changes) == 1406 and len(mask_changes) == 6
    route_path = ROOT/'assets/maps/falan/east_region/routes.json'; population_path = ROOT/'assets/maps/falan/east_region/population.json'
    routes = json.loads(route_path.read_text()); population = json.loads(population_path.read_text())
    actors = [a for a in population['actors'] if a.get('source') == 2000]
    fixed = [r for r in routes['fixed'] if r[0] == 2000 or r[3] == 2000]
    events = [a for a in routes['event_links'] if a.get('source') == 2000 or a.get('target') == 2000]
    at_known = lambda at: bool(flags[at[1]*width+at[0]] & 0xc000)
    assert len(actors) == 16 and all(at_known(a['cell']) for a in actors)
    assert len(fixed) == 16 and all((r[0] != 2000 or at_known(r[1:3])) and (r[3] != 2000 or at_known(r[4:6])) for r in fixed)
    assert len(events) == 4 and all((r.get('source') != 2000 or at_known(r['cell'])) and (r.get('target') != 2000 or at_known(r['landing'])) for r in events)
    native_npc_path = ROOT.parent/'Magic Power/research/jobs-sharing-20261031/source/npc-utf8.txt'
    native_npcs = [r for line in native_npc_path.read_text().splitlines() if len(r := line.split('\t')) > 10 and r[8] == '2000']
    active_npcs = [r for r in native_npcs if not r[0].startswith('#')]
    assert len(native_npcs) == 21 and len(active_npcs) == 16 and all(at_known([int(r[9]), int(r[10])]) for r in native_npcs)
    data = {'schema': 1, 'source': 2000, 'title': title, 'size': [width, height], 'status': 'Bounded live Il mask/index/row hooks; actual cap/route/visual acceptance pending.',
            'original_path': record['path'], 'original_sha256': hashlib.sha256(original).hexdigest(), 'pinned_reference': proof,
            'hybrid_sha256': hashlib.sha256(hybrid).hexdigest(), 'original_marker_plane_sha256': hashlib.sha256(original[20+cells*4:]).hexdigest(),
            'coverage': {'cells': cells, 'original_known': len(known), 'original_unknown': len(unknown), 'source_covered_after_hybrid': cells,
                         'preserved_known_variants': len(variants), 'written_plane_cells': len(writes)}, 'preserved_known_variants': variants,
            'unknown_only_writes': writes, 'additional_scenery_rows': additions, 'new_bank_caps': bank_caps,
            'unknown_source_floor_counts': dict(Counter(final[i] for i in unknown)), 'unknown_source_object_counts': dict(Counter(final[cells+i] for i in unknown)),
            'native_walk': {'before_open': sum(before_walk), 'after_open': sum(after_walk), 'added_open_cells': added_walk, 'closed_cells': 0,
                            'before_bits': packed_walk(before_walk), 'after_bits': packed_walk(after_walk),
                            'known_cell_changes': 0, 'limit': 'Exact existing graphic-attribute navigation helper, not actual native physics/height clearance or permission to open new routes.'},
            'presentation': {'ground_index_changed_cells': [[i % width, i // width] for i in index_changes], 'terrain_mask_changed_cells': [[i % width, i // width] for i in mask_changes],
                             'water_continuation_cells': 1400, 'shore_ground_cells': 6, 'zero_floor_marker2_cells': 2701,
                             'zero_presentation': 'Keep the existing Il wet mask for pinned zero-floor/object2 cells; no blank land or invented structure.',
                             'geometry_owner': 'Il-only six source cap silhouettes through forest_east_bank_caps, retaining original anchors/paint; inferred hidden continuation descends6m land to2m water. Actual review pending.'},
            'preserved_actors': [{k: a.get(k) for k in ['id', 'type', 'cell', 'script']} for a in actors], 'preserved_fixed_routes': fixed, 'preserved_event_routes': events,
            'original_npc_rows': [{'id': r[3], 'type': r[0], 'cell': [int(r[9]), int(r[10])], 'commented_in_source': r[0].startswith('#')} for r in native_npcs],
            'source_hashes': {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [route_path, population_path, native_npc_path, ROOT/'assets/maps/falan/il_village_ground_atlas.png']},
            'preserved_known_rgba_sha256': {'ground_index': hashlib.sha256(bytes(v for i in known for v in original_index.getpixel((i % width, i // width)))).hexdigest(),
                                           'mask': hashlib.sha256(bytes(v for i in known for v in original_mask.getpixel((i % width, i // width)))).hexdigest()},
            'closure_plan': ['Publish only these private Il mask/index derivatives after review; all existing Il ground-atlas pixels remain reused.',
                             'Append the exact six shore rows through Il-only existing-owner plan/build_exterior calls, preserving all existing row order and material caches.',
                             'Use both ordinary Il and joined East Gate presentation through the existing shared Il mask/index paths. Never rebuild Laruka/West or approved houses.',
                             'Validate source/current geometry at the northern six shore cells and right-bank gap; prove physical/native clearance separately from the12attribute-open cells.',
                             'After publication, verify normal village exit, source ship/harbor events and original returns, all six Il house round trips, plus normal/second reachable cameras.'],
            'limits': ['No source cache/reference/artwork is overwritten.', 'No road, major building, actor or route endpoint is added by these unknown cells.',
                       '56native water-frame choices, two records for the moved tree and one flower choice are preserved client variants, not source blockers.',
                       'Original third-plane markers remain exact; supplemental pinned reference evidence supplies full source coverage without falsifying original cache history.']}
    result = {'data.json': (json.dumps(data, indent=2)+'\n').encode(), 'hybrid-map.bin': bytes(hybrid), 'ground-index.png': encoded_png(index), 'mask.png': encoded_png(mask)}
    return result, original, bytes(hybrid), data


def main():
    parser = ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    result, original, hybrid, data = products(); stale = []
    for name, value in result.items():
        path = OUT/name
        if args.check:
            if not path.exists() or path.read_bytes() != value: stale.append(name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_bytes() != value: path.write_bytes(value)
    if stale: raise SystemExit('Stale private Il source completion: '+','.join(stale))
    REPORT.mkdir(parents=True, exist_ok=True); (REPORT/'.gdignore').touch()
    (REPORT/'source-closure.json').write_text(json.dumps(data, indent=2)+'\n')
    print(('Verified' if args.check else 'Prepared')+f" private Il source closure:6693known preserved/4107unknown filled;6shore placements,12native attribute-open cells. Runtime/actual review pending.")


if __name__ == '__main__': main()
