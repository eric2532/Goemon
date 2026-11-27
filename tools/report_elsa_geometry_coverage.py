"""Inventory every island/journey FG group without treating a mesh as art approval."""
from collections import Counter, defaultdict, deque
import base64
import hashlib
import json
from pathlib import Path
import zlib

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Elsa Island'
ASSETS = ROOT / 'assets/maps/falan/elsa'
TAGS = ['floor_only', 'banyan', 'pedestal', 'furniture', 'tree', 'rock', 'bridge', 'source_surface',
        'grounded', 'columns', 'wall_parts', 'column', 'wall']


def owned_distances(record):
    """Chebyshev cell distance for review priority, never a visibility test."""
    width, height = record['size']
    bits = zlib.decompress(base64.b64decode(record['open']))
    assert len(bits) == (width * height + 7) // 8
    field = [-1] * (width * height)
    queue = deque()
    for i in range(len(field)):
        if bits[i >> 3] & (1 << (i & 7)):
            field[i] = 0
            queue.append(i)
    assert queue, 'Review distance needs at least one owned walking cell'
    while queue:
        i = queue.popleft()
        x, y = i % width, i // width
        for yy in range(max(0, y - 1), min(height, y + 2)):
            for xx in range(max(0, x - 1), min(width, x + 2)):
                j = yy * width + xx
                if field[j] < 0:
                    field[j] = field[i] + 1
                    queue.append(j)
    assert min(field) == 0 and all(v >= 0 for v in field)
    return field


def build():
    path = ASSETS / 'props/data.json'
    props = json.loads(path.read_text())
    scope = json.loads((REPORT / 'scope.json').read_text())['maps']
    ownership = json.loads((ASSETS / 'ownership.json').read_text())
    gates = json.loads((ASSETS / 'scenery/gate/data.json').read_text())
    rails = json.loads((ASSETS / 'scenery/temple-steps/data.json').read_text())['rails']
    owners = {}
    for item in props.get('spires', []):
        for member in item['members']:
            owners[(member['group'], tuple(member['anchor']))] = 'dedicated_spire'
    for item in [gates] + gates.get('others', []):
        for member in item['members']:
            owners[(member['group'], tuple(member['anchor']))] = 'dedicated_gate'
    rail_groups = {r['group'] for r in rails}
    groups = defaultdict(list)
    maps = []
    totals = Counter()
    for ident in scope:
        counts = Counter()
        owned = ownership.get(str(ident))
        distances = owned_distances(owned) if owned else None
        for row in props['maps'].get(str(ident), []):
            group = props['groups'][row['group']]
            kind = next((tag for tag in TAGS if tag in group), 'generic_relief')
            if row.get('empty_cut', False):
                kind = 'nonvisual_empty_cut'
            elif ident == 59535 and group['master'] in [301052, 301053]:
                kind = 'dedicated_inner_hall'
            elif ident == 59520:
                kind = owners.get((row['group'], tuple(row['anchor'])), kind)
                if row['group'] in rail_groups:
                    kind = 'dedicated_temple_rail'
            counts[kind] += 1
            placement = dict(map=ident, anchor=row['anchor'], cells=row['cells'], geometry=kind)
            if distances is not None:
                width, height = owned['size']
                assert all(0 <= x < width and 0 <= y < height for x, y in row['cells'])
                placement['nearest_owned_walk_cells'] = min(distances[y * width + x] for x, y in row['cells'])
            groups[row['group']].append(placement)
        totals.update(counts)
        maps.append(dict(map=ident, placements=sum(counts.values()), geometry=dict(counts),
                         groups=sorted({r['group'] for r in props['maps'].get(str(ident), [])}, key=int)))
    result = dict(source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), maps=maps,
                  totals=dict(totals), groups={token:dict(master=props['groups'][token]['master'],
                  origin=props['groups'][token]['origin'], size=props['groups'][token]['size'],
                  source_rgba_sha256=props['groups'][token]['rgba_sha256'], placements=rows)
                  for token, rows in sorted(groups.items(), key=lambda item:int(item[0]))},
                  limits=['FG ownership/geometry inventory only. It does not certify visual fidelity.',
                          'Generic relief may be appropriate for small surface art; fixed gameplay views must establish that. Large architecture/furniture needs source fitting.',
                          'nearest_owned_walk_cells measures source member cells against the island-only ownership mask. It is review priority, not camera visibility or permission to omit scenery. The four journey maps have no island ownership mask.',
                          'BG-only architecture, shore, floors and the tower remain separate items in CHECKLIST.md. No inventory label marks an area complete.'])
    (REPORT / 'geometry-coverage.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    lines = ['# Elsa FG geometry coverage', '',
             f'{len(maps)} maps; {len(groups)} used source groups; {sum(totals.values())} original placements.', '',
             'These are current geometry owners, not visual acceptance. BG-only architecture, terrain, shore and floors remain in CHECKLIST.md.', '',
             '| Map | FG placements | Generic relief to review | Dedicated model inputs |',
             '|---:|---:|---:|---:|']
    for row in maps:
        lines.append('| %d | %d | %d | %d |' % (row['map'], row['placements'],
            row['geometry'].get('generic_relief', 0),
            sum(v for k, v in row['geometry'].items() if k.startswith('dedicated_'))))
    (REPORT / 'geometry-coverage.md').write_text('\n'.join(lines) + '\n')
    print('ELSA_GEOMETRY_COVERAGE', len(maps), 'maps;', len(groups), 'used groups;',
          sum(totals.values()), 'placements;', totals['generic_relief'], 'generic-relief placements to review')


if __name__ == '__main__':
    build()
