"""Pin the sixteen native Minoquier layered cottages without changing game art."""
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw
from review_east_backgrounds import CATALOG, ROOT, Native, decode

OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Stilt Compounds'
IDS = set(range(1233283, 1233288))


def components(width, height, bits):
    left = {i for i in range(width*height) if bits[i >> 3] & (1 << (i & 7))}
    by_cell, sizes = {}, []
    while left:
        todo, found = [left.pop()], []
        while todo:
            i = todo.pop(); found.append(i); x, z = i % width, i // width
            for j in ([i-1] if x else []) + ([i+1] if x+1 < width else []) + ([i-width] if z else []) + ([i+width] if z+1 < height else []):
                if j in left:
                    left.remove(j); todo.append(j)
        by_cell.update((i, len(sizes)) for i in found); sizes.append(len(found))
    return by_cell, sizes


def run():
    catalog = json.loads(CATALOG.read_text()); source = catalog['maps']['BlueCrossgate/map/0/43500.dat']
    width, height, raw, values, bits, aliases = decode(source); cells = width*height
    native = Native(); comp, sizes = components(width, height, bits)
    routes_path = ROOT/'assets/maps/falan/east_region/routes.json'
    population_path = ROOT/'assets/maps/falan/east_region/population.json'
    routes = json.loads(routes_path.read_text()); population = json.loads(population_path.read_text())
    actors = [r for r in population['actors'] if r.get('source') == 43500]
    fixed = [r for r in routes['fixed'] if r[0] == 43500 or r[3] == 43500]
    events = [r for r in routes['event_links'] if r.get('source') == 43500 or r.get('target') == 43500]
    script_commands = [{'script': name, 'line': line, 'command': command, 'script_sha256': row['sha256']}
                       for name, row in population['scripts'].items()
                       for line, command in row.get('lines', []) if '43500' in command]
    npc_path = ROOT.parent/'Magic Power/research/jobs-sharing-20261031/source/npc-utf8.txt'
    original_npcs = [parts for line in npc_path.read_text().splitlines()
                     if len(parts := line.split('\t')) > 10 and parts[8] == '43500']
    assert len(original_npcs) == len(actors) == 48
    assert not [r for r in original_npcs if r[10].isdigit() and int(r[10]) >= 160]
    assert not [r for r in actors if r['cell'][1] >= 160]
    assert not [r for r in fixed if r[0] == 43500 and r[2] >= 160 or r[3] == 43500 and r[5] >= 160]
    assert not [r for r in events if r.get('source') == 43500 and r.get('cell', [0, 0])[1] >= 160 or r.get('target') == 43500 and r.get('landing', [0, 0])[1] >= 160]
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch()
    forms, signatures = [], defaultdict(list)
    for i in range(cells):
        serial = aliases.get(values[cells+i], values[cells+i])
        if serial not in IDS:
            continue
        x, z = i % width, i // width; background = []
        for zz in range(max(0, z-8), min(height, z+10)):
            for xx in range(max(0, x-8), min(width, x+10)):
                index = zz*width+xx; raw_serial = int(values[index])
                if not 25510 <= raw_serial <= 25793:
                    continue
                graphic = aliases.get(raw_serial, raw_serial); g = native.table[graphic][0]
                background.append({'layer': 0, 'cell': [xx, zz], 'native_graphic': raw_serial, 'graphic': graphic,
                                   'origin': g['origin'], 'rgba_sha256': g['rgba_sha256'],
                                   'original_open': bool(bits[index >> 3] & (1 << (index & 7)))})
        signatures[serial].append({(r['cell'][0]-x, r['cell'][1]-z, r['native_graphic']) for r in background})
        g = native.table[serial][0]; box = [-400, -650, 500, 350]
        image = Image.new('RGBA', (box[2]-box[0], box[3]-box[1]))
        for record in background + [{'cell': [x, z], 'graphic': serial}]:
            xx, zz = record['cell']; graphic = record['graphic']; item = native.table[graphic][0]
            image.alpha_composite(native.crop(graphic), ((xx+zz-x-z)*32+item['origin'][0]-box[0],
                                                       (zz-xx-z+x)*24+item['origin'][1]-box[1]))
        name = f'{serial}-{x}-{z}-native-layered.png'; image.save(OUT/name)
        nearby_components = Counter(sizes[comp[zz*width+xx]]
                                    for zz in range(max(0, z-6), min(height, z+9))
                                    for xx in range(max(0, x-6), min(width, x+9)) if zz*width+xx in comp)
        forms.append({'graphic': serial, 'source_layer': 1, 'source_cell': [x, z], 'native_graphic': int(values[cells+i]),
                      'foreground_origin': g['origin'], 'foreground_footprint': g['footprint'], 'foreground_rgba_sha256': g['rgba_sha256'],
                      'native_composite': name, 'composite_pixel_origin': box[:2], 'composite_size': list(image.size),
                      'background_context_tuples': background,
                      'nearby_original_walk_component_sizes': dict(nearby_components),
                      'borders_existing_town_component': 3604 in nearby_components,
                      'native_picture_limit': 'BG context includes original water and neighboring pieces. It is reference paint, not an alpha cutout or runtime skip list.'})
    assert len(forms) == 16 and sum(r['borders_existing_town_component'] for r in forms) == 11
    repeats = {str(serial): {'placements': len(rows), 'shared_relative_bg_tuples': [list(t) for t in sorted(set.intersection(*rows))],
                             'unshared_context_counts': [len(row-set.intersection(*rows)) for row in rows]}
               for serial, rows in signatures.items()}
    south = [r for r in forms if not r['borders_existing_town_component']]
    report = {'schema': 1, 'source': 43500, 'title': source['title'], 'size': [width, height], 'source_raw_sha256': hashlib.sha256(raw).hexdigest(),
              'source_walk_sha256': hashlib.sha256(bits).hexdigest(), 'source_catalog_sha256': hashlib.sha256(CATALOG.read_bytes()).hexdigest(),
              'route_sha256': hashlib.sha256(routes_path.read_bytes()).hexdigest(), 'population_sha256': hashlib.sha256(population_path.read_bytes()).hexdigest(),
              'original_npc_source_sha256': hashlib.sha256(npc_path.read_bytes()).hexdigest(), 'original_source_npc_count': len(original_npcs),
              'source_art_catalog_pins': native.pins, 'forms': forms, 'repeated_drawing_proofs': repeats,
              'original_fixed_routes': fixed, 'original_script_routes': events, 'original_source_actor_cells': [{k: a.get(k) for k in ['id', 'type', 'cell', 'script', 'generated_by']} for a in actors],
              'all_compiled_commands_naming_43500': script_commands,
              'southern_scope': {'cells': [r['source_cell'] for r in south], 'source_actor_count_south_of_160': 0, 'fixed_or_script_route_endpoint_count_south_of_160': 0,
                                 'classification': 'Disconnected native placements, with only isolated local walk scraps. No extra path/support is authorized; no claim that unseen dynamic server content has been exhaustively recovered.'},
              'limits': ['Native layered paint and route/walk ownership only; no 3D or actual-camera acceptance.',
                         '3285southern native BG is incomplete and has no exact BGtuple copy relative to its northern FGanchor. Hidden completion must be labeled reconstruction.',
                         'BG25510..25793 includes water/fringes. Whole rectangular tiles cannot be extruded or removed by a family-range rule.']}
    (OUT/'source-contracts.json').write_text(json.dumps(report, indent=2))
    canonical = {1233283: [68, 82], 1233284: [108, 101], 1233285: [67, 115], 1233286: [125, 101], 1233287: [44, 82]}
    sheet = Image.new('RGB', (1500, 1220), (34, 40, 39)); draw = ImageDraw.Draw(sheet)
    for slot, (serial, at) in enumerate(canonical.items()):
        row = next(r for r in forms if r['graphic'] == serial and r['source_cell'] == at)
        source_image = Image.open(OUT/row['native_composite']).crop((100, 220, 800, 940)); source_image.thumbnail((490, 560))
        xx, yy = slot % 3*500, slot // 3*610
        sheet.paste(source_image, (xx, yy+35), source_image); draw.text((xx+12, yy+10), f'{serial} original layered reference {at}', fill='white')
    sheet.save(OUT/'five-cottage-native-contexts.jpg', quality=95)
    print('Pinned16native layered cottages:11town-adjacent,5disconnected;0southern compiled actors/route endpoints. No game art changed.')


if __name__ == '__main__':
    run()
