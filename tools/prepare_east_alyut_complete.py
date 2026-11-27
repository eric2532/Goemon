"""Private compatible2400 completion for the existing authored Alyut owner."""
import argparse
import base64
import collections
import hashlib
import json
import struct
import sys
import tempfile
import zlib
from pathlib import Path

from PIL import Image

from build_freyja_destinations import load_map
from build_freyja_outlying import is_road, is_water
from prepare_east_region_maps import active_raw, reference_map, render_reference
from build_falan_room_art import COLS, STRIDE, project_tile
from recover_sokia import rectangles
import prepare_east_field_cliffs as cliffs
import prepare_east_village_props as props

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
OUT = REPORT / 'Village Props/Cliff Audit/Alyut Complete Candidate'
SOURCE = REPORT / 'Version Expansion Source Audit'


def sha(body):
    return hashlib.sha256(body).hexdigest()


def packed_bits(values):
    bits = bytearray((len(values) + 7) // 8)
    for i, value in enumerate(values):
        if value: bits[i >> 3] |= 1 << (i & 7)
    return base64.b64encode(zlib.compress(bits)).decode()


def components(width, height, walk):
    labels = [-1] * len(walk); sizes = []
    for i, opened in enumerate(walk):
        if not opened or labels[i] >= 0: continue
        pending = collections.deque([i]); labels[i] = len(sizes); size = 0
        while pending:
            at = pending.popleft(); size += 1; x, y = at % width, at // width
            for nx, ny in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
                if not 0 <= nx < width or not 0 <= ny < height: continue
                other = ny * width + nx
                if walk[other] and labels[other] < 0:
                    labels[other] = labels[i]; pending.append(other)
        sizes.append(size)
    return labels, sizes


def prepare(out, native_preview=True):
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    manifest_path = SOURCE / 'references.json'
    record = next(row for row in json.loads(manifest_path.read_text()) if row['file'] == 'map__02400_aryurt')
    raw = (SOURCE / record['file']).read_bytes()
    assert sha(raw) == record['sha256']
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == record['git_blob']
    width, height, planes, title = reference_map(raw, 2400); count = width * height
    pinned_ground, pinned_objects = list(planes[:count]), list(planes[count:])
    native = load_map(lib, 2400); assert native[:2] == (width, height)
    with lib.connection() as db:
        client_record = dict(db.execute('SELECT * FROM files WHERE path=?', ('BlueCrossgate/map/0/2400.dat',)).fetchone())
    client_raw = (lib.SOURCE / client_record['path']).read_bytes()
    known = [i for i, flags in enumerate(native[4]) if flags & 0xc000]
    differences = [{'cell': [i % width, i // width], 'cached': [native[2][i], native[3][i]],
                    'pinned': [pinned_ground[i], pinned_objects[i]]} for i in known
                   if (native[2][i], native[3][i]) != (pinned_ground[i], pinned_objects[i])]
    assert differences == [{'cell': [36, 73], 'cached': [5039, 11497], 'pinned': [5039, 0]}]
    hybrid = bytearray(client_raw)
    for i, flags in enumerate(native[4]):
        if flags & 0xc000: continue
        struct.pack_into('<H', hybrid, 20 + i * 2, pinned_ground[i])
        struct.pack_into('<H', hybrid, 20 + (count + i) * 2, pinned_objects[i])
    assert hybrid[:20] == client_raw[:20] and hybrid[20 + count * 4:] == client_raw[20 + count * 4:]
    final = struct.unpack_from(f'<{count * 3}H', hybrid, 20)
    ground, objects = list(final[:count]), list(final[count:count * 2])
    assert all((ground[i], objects[i]) == (native[2][i], native[3][i]) for i in known)
    catalog_row = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())['maps']['BlueCrossgate/map/0/2400.dat']
    assert bytes(hybrid) == active_raw(catalog_row), 'Independent Alyut hybrid must match the shared active fixed-map source'
    lookup = lib.serial_index(); walk = navigation_grid(width, height, ground, objects, lookup)
    old_walk = navigation_grid(width, height, native[2], native[3], lookup)
    labels, sizes = components(width, height, walk)
    source_meta = {'path': str((OUT / 'hybrid-map.bin').relative_to(ROOT)), 'sha256': sha(hybrid),
                   'client_path': client_record['path'], 'client_sha256': sha(client_raw),
                   'pinned_path': record['path'], 'pinned_sha256': sha(raw), 'pinned_git_blob': record['git_blob'],
                   'pinned_url': record['url'], 'selected_variant': 'recorded-client-with-compatible-reference-completion'}
    def selected(library, ident):
        return (width, height, ground, objects, list(native[4])) if ident == 2400 else load_map(library, ident)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'hybrid-map.bin').write_bytes(hybrid)
    for directory, products in [('props', props.prepare(selected, {2400: source_meta})),
                                ('cliffs', cliffs.products(selected, {2400: source_meta}))]:
        folder = out / directory; folder.mkdir(exist_ok=True)
        for name, body in products.items(): (folder / name).write_bytes(body)
    prop_data = json.loads((out / 'props/data.json').read_text())
    cliff_data = json.loads((out / 'cliffs/data.json').read_text())
    graph_path = SOURCE / 'graph.json'; graph = json.loads(graph_path.read_text())
    links = [row for row in graph['links'] if row['source'] == 2400 or row['target'] == 2400]
    actors = [row for row in graph['actors'] if row['map'] == 2400]
    with Image.open(ROOT / 'assets/maps/falan/freyja_alyut.png') as image: mask = image.convert('RGBA')
    with Image.open(ROOT / 'assets/maps/falan/alyut_ground_index.png') as image: index = image.convert('RGBA')
    with Image.open(ROOT / 'assets/maps/falan/alyut_ground_atlas.png') as image: original_atlas = image.convert('RGB')
    assert mask.size == index.size == (width, height)
    original_mask, original_index = mask.copy(), index.copy(); slots = {}
    for i in known:
        pixel = index.getpixel((i % width, i // width))
        if pixel[3]:
            assert native[2][i] not in slots or slots[native[2][i]] == pixel
            slots[native[2][i]] = pixel
    # Append outside the complete old image, including its unused padding slots.
    next_slot = max((original_atlas.height // STRIDE) * COLS,
                    max(pixel[0] + pixel[1] * COLS for pixel in slots.values()) + 1)
    added_floor_tiles = []
    for graphic in sorted(set(ground) - set(slots) - {0, 100}):
        g = lookup[graphic]; image = lib.image_from_record(g['pack'], g['row']).convert('RGBA')
        assert image.size == (64, 47), ('An additional floor needs explicit source projection', graphic, image.size)
        slots[graphic] = (next_slot % COLS, next_slot // COLS, 255 if is_water(graphic) else 0, 255)
        added_floor_tiles.append({'graphic': graphic, 'slot': next_slot, 'rgba_sha256': sha(image.tobytes())}); next_slot += 1
    atlas = Image.new('RGB', (COLS * STRIDE, max(original_atlas.height, ((next_slot + COLS - 1) // COLS) * STRIDE)))
    atlas.paste(original_atlas, (0, 0))
    for row in added_floor_tiles:
        g = lookup[row['graphic']]; tile = project_tile(lib.image_from_record(g['pack'], g['row']))
        atlas.paste(tile, (row['slot'] % COLS * STRIDE, row['slot'] // COLS * STRIDE)); row['projected_tile_sha256'] = sha(tile.tobytes())
    assert atlas.crop((0, 0, original_atlas.width, original_atlas.height)).tobytes() == original_atlas.tobytes()
    mask_pixels = mask.load()
    for i, tile in enumerate(ground):
        if native[4][i] & 0xc000: continue
        if tile in slots: index.putpixel((i % width, i // width), slots[tile])
        paving = 220 if 1000 <= tile <= 1099 or 5954 <= tile <= 5988 else 0
        mask_pixels[i % width, i // width] = (255 if is_water(tile) else 0, 220 if is_road(tile) else 0,
                                             paving, 255 if tile else 0)
    assert all(mask.getpixel((i % width, i // width)) == original_mask.getpixel((i % width, i // width)) and index.getpixel((i % width, i // width)) == original_index.getpixel((i % width, i // width)) for i in known)
    mask.save(out / 'mask.png', optimize=True)
    index.save(out / 'ground-index.png', optimize=True); atlas.save(out / 'ground-atlas.png', optimize=True)
    Image.frombytes('L', (width, height), bytes(255 if value else 0 for value in walk)).save(out / 'walk.png')
    audits = {tuple(row['cell']): row for row in prop_data['audit'] if row['map'] == 2400}
    placements = []
    for i, graphic in enumerate(objects):
        if graphic < 1000: continue
        cell = [i % width, i // width]; g = lookup[graphic]; audit = audits[tuple(cell)]
        placements.append({'cell': cell, 'graphic': graphic, 'footprint': [max(1, g['east']), max(1, g['south'])],
                           'owner': audit['status'], 'prop_mode': audit['mode'],
                           'cached_cell_known': bool(native[4][i] & 0xc000)})
    endpoints = []
    for row in links:
        cell = row.get('cell') if row['source'] == 2400 else row.get('landing')
        if cell is None:
            endpoints.append({'link': row, 'source_context': 'arrival coordinate absent in original inline handler; not guessed'})
            continue
        x, y = cell; index = y * width + x
        endpoints.append({'link': row, 'cell': cell, 'native_walk': bool(walk[index]), 'component': labels[index]})
    new_objects = [row for row in placements if not row['cached_cell_known']]
    gate_cells = [[58, 31], [59, 31], [66, 64], [67, 64]]
    assert all(walk[y * width + x] for x, y in gate_cells)
    counts = collections.Counter(row['owner'] for row in placements)
    assert len(cliff_data['alyut']['placements']) == 204
    buildings = json.loads((ROOT / 'assets/maps/falan/east_region/village_buildings/data.json').read_text())['maps']['2400']
    assert {(row['graphic'], *row['cell']) for row in buildings['placements']} == {
        (row['graphic'], *row['cell']) for row in placements if row['owner'] == 'existing_building_owner'}
    building_cells = {(row['cell'][0] + x, row['cell'][1] - z) for row in buildings['placements']
                      for x in range(row['footprint'][0]) for z in range(row['footprint'][1])}
    blocked_land = {(i % width, i // width) for i in range(count) if ground[i] and not is_water(ground[i]) and not walk[i]
                    and (i % width, i // width) not in building_cells}
    blocks = rectangles(blocked_land)
    assert {(x, y) for a, b, rw, rh in blocks for x in range(a, a + rw) for y in range(b, b + rh)} == blocked_land
    added_walk = [{'cell': [i % width, i // width], 'bg': ground[i], 'pg1': objects[i],
                   'class': 'water' if is_water(ground[i]) else 'void' if not ground[i] else 'land'}
                  for i in range(count) if walk[i] and not old_walk[i]]
    payload = {'schema': 1, 'source_map': 2400, 'title': title, 'source': source_meta, 'size': [width, height],
               'ground_u16le_deflate': base64.b64encode(zlib.compress(struct.pack(f'<{count}H', *ground))).decode(),
               'objects_u16le_deflate': base64.b64encode(zlib.compress(struct.pack(f'<{count}H', *objects))).decode(),
               'walk_bits': packed_bits(walk), 'walk_sha256': sha(bytes(walk)), 'placements': placements,
               'original_marker_plane_sha256': sha(client_raw[20 + count * 4:]),
               'blocked_land_rectangles': blocks, 'blocked_land_cells': len(blocked_land),
               'actors': actors, 'connections': links, 'building_placements': buildings['placements'],
               'protected_gate_cells': gate_cells, 'door_cells': [row['source_cell'] for row in buildings['doors']],
               'scope': 'Private compatible source completion for the existing authored Alyut owner. All known client BG/PG1 bytes and the complete marker plane are unchanged; pinned source fills only unrecorded cells. No canonical map, join, collision, route, NPC, quest, art or save mutation.'}
    (out / 'map-data.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n')
    report = {'source': source_meta, 'cached_source': json.loads((ROOT / 'assets/maps/falan/east_field_cliffs/data.json').read_text())['alyut']['source_sha256'],
              'selection': 'Recorded-client compatible completion, byte-identical to shared active_raw2400. Preserve the known flower and entire original marker plane; fill only unrecorded BG/PG1 from pinned source.',
              'known_cells': len(known), 'unknown_cached_cells': count - len(known), 'known_disagreements': differences,
              'owner_counts': dict(counts), 'art_placements': len(placements), 'new_art_placements': len(new_objects),
              'new_graphic_counts': dict(collections.Counter(row['graphic'] for row in new_objects)),
              'marker_counts': dict(collections.Counter(value for value in objects if 0 < value < 1000)),
              'additional_ground_cells': sum(bool(ground[i]) and not (native[4][i] & 0xc000) for i in range(count)),
              'walk_cells': sum(walk), 'cached_walk_cells': sum(old_walk), 'components': sizes,
              'cached_walk_opened': sum(bool(walk[i]) and not old_walk[i] for i in range(count)),
              'cached_walk_closed': sum(bool(old_walk[i]) and not walk[i] for i in range(count)),
              'added_walk_semantics': {'counts': dict(collections.Counter(row['class'] for row in added_walk)), 'cells': added_walk,
                                       'limit': 'The99new wet-BG shore cells require native cap geometry and actual physical support review. Attribute-open bits alone do not authorize land conversion.'},
              'ground_atlas': {'original_rgb_sha256': sha(original_atlas.tobytes()), 'original_pixels_preserved': True, 'appended_source_tiles': added_floor_tiles},
              'tall_cliffs': 204, 'cached_tall_cliffs': 125, 'added_cliffs_all_previously_unknown': all(not row['cached_cell_known'] for row in new_objects if 12536 <= row['graphic'] < 12548),
              'source_connections': len(links), 'source_actors': len(actors), 'endpoint_contracts': endpoints,
              'unchanged_major_buildings': len(buildings['placements']), 'unchanged_static_house_doors': buildings['doors'],
              'source_inputs': {name: sha((ROOT / name).read_bytes()) for name in ['tools/prepare_east_alyut_complete.py', 'tools/prepare_east_village_props.py', 'tools/prepare_east_field_cliffs.py']},
              'graph_sha256': sha(graph_path.read_bytes()), 'status': 'Private exact source contract; runtime whole-source enrollment and actual assembled-map/door/NPC/route review remain unfinished.'}
    (out / 'source-contract.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    if native_preview:
        wrapped = b'MAP\x01' + bytes(8) + struct.pack('<II', width, height) + struct.pack(f'<{count * 3}H', *ground, *objects, *([0xc000] * count))
        render_reference(wrapped, lib, lookup, 1800).convert('RGB').save(out / 'native-whole2400.png')
    print('EAST_ALYUT_COMPLETE_PRIVATE', len(placements), 'art placements;', len(new_objects), 'uncached;',
          'cliffs204; walk', sum(walk), '; actors', len(actors), '; connections', len(links))


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix='east-full-alyut-', dir='/private/tmp') as temporary:
            folder = Path(temporary); prepare(folder, False)
            stale = [str(path.relative_to(folder)) for path in folder.rglob('*') if path.is_file()
                     and (not (OUT / path.relative_to(folder)).exists() or (OUT / path.relative_to(folder)).read_bytes() != path.read_bytes())]
            assert not stale, 'Stale private Alyut products: ' + ','.join(stale)
        print('EAST_ALYUT_COMPLETE_PRIVATE_CHECK PASS')
    else: prepare(OUT)


if __name__ == '__main__':
    main()
