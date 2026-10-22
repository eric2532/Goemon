#!/usr/bin/env python3
"""Rotate the existing southern Twin Ramparts approach into four matching fronts."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT / 'assets/maps/forest_twin_ramparts.json').read_text())

def rotate(x, z, quarter):
    for _ in range(quarter):
        x, z = -z, x
    return x, z

def dimensions(item):
    w, d = {'mine': (3, 2), 'tower': (2, 2), 'wall': (item.get('span', 6), 1), 'gate': (2, 1)}[item['kind']]
    return (d, w) if item['rotation'] % 2 else (w, d)

def footprint(item):
    w, d = dimensions(item)
    return [(item['x'] + x, item['z'] + z) for x in range(w) for z in range(d)]

def rotate_building(item, quarter):
    cells = [rotate(x, z, quarter) for x, z in footprint(item)]
    return dict(item, x=min(x for x, _ in cells), z=min(z for _, z in cells), rotation=(item['rotation'] - quarter) % 4)

# Each side owns one corner, so rotated wall footprints never overlap.
south = [dict(kind='gate', x=0, z=8, rotation=0, span=0)]
for start, stop in [(-8, 0), (2, 8)]:
    for x in range(start, stop, 6):
        south.append(dict(kind='wall', x=x, z=8, rotation=0, span=min(6, stop-x)))
south += [dict(kind='tower', x=x, z=5, rotation=2, span=0) for x in [-4, 3]]
layout = {k: v for k, v in source.items() if k not in ['buildings', 'trees', 'roads', 'portals', 'ramparts']}
layout.update(title='Four Gates', buildings=[b for b in source['buildings'] if b['kind'] == 'mine'], trees=[], roads=[], portals=[], ramparts=[])
# Keep both mines inside the matching tower ring, with clear worker doors.
layout['buildings'] = [dict(b, x=(-5 if b['x'] < 0 else 3), z=0) for b in layout['buildings']]
layout['deposits'] = [dict(d, x=(-5 if d['x'] < 0 else 3), z=0) for d in source['deposits']]
roads = set()
for q in range(4):
    layout['buildings'] += [rotate_building(b, q) for b in south]
    for item in source['ramparts']:
        ax, az = rotate(item['ax'], item['az'], q)
        bx, bz = rotate(item['bx'], item['bz'], q)
        layout['ramparts'].append(dict(item, ax=ax, az=az, bx=bx, bz=bz))
    for p in source['portals']:
        x, z = rotate(p['x'], p['z'], q)
        layout['portals'].append(dict(p, x=x, z=z, rotation=(p['rotation']+q) % 4))
    roads.update(rotate(r['x'], r['z'], q) for r in source['roads'])
layout['roads'] = [dict(x=x, z=z) for x, z in sorted(roads)]
reserved = {(x, z) for x in range(-2, 3) for z in range(-2, 4)} | roads
for b in layout['buildings']:
    reserved.update(footprint(b))
for p in layout['portals']:
    dx, dz = [(0, -1), (1, 0), (0, 1), (-1, 0)][p['rotation']]
    for cx, cz in [(p['x'], p['z']), (p['x']+dx*3, p['z']+dz*3)]:
        reserved.update((cx+x, cz+z) for x in range(-2, 3) for z in range(-2, 3))

def near_wall(x, z):
    for p in layout['ramparts']:
        half = p['width'] / 2 + 1
        if p['ax'] == p['bx']:
            if abs(x-p['ax']) <= half and min(p['az'], p['bz'])-half <= z <= max(p['az'], p['bz'])+half:
                return True
        elif abs(z-p['az']) <= half and min(p['ax'], p['bx'])-half <= x <= max(p['ax'], p['bx'])+half:
            return True
    return False

trees = {}
for t in source['trees']:
    if t['z'] < abs(t['x']):
        continue
    for q in range(4):
        x, z = rotate(t['x'], t['z'], q)
        if (x, z) not in reserved and not near_wall(x, z):
            trees[x, z] = dict(t, x=x, z=z)
layout['trees'] = [trees[c] for c in sorted(trees)]
path = ROOT / 'assets/maps/forest_four_gates.json'
path.write_text(json.dumps(layout, indent=2)+'\n')
print(f'{path}: 4 gates, 8 towers, {len(layout["portals"])} portals, {len(layout["roads"])} road tiles')
