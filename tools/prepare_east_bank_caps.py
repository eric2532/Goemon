"""Native alpha-derived shore lips for explicitly selected new village placements."""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import sys

from PIL import Image
from build_falan_room_art import project_tile
from recover_venoa_walls import native_without_ground_shadow

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/maps/falan/east_region/bank_caps'
STEP = .125


def hull(points):
    points = sorted(set(points))
    def turn(a, b, c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    low, high = [], []
    for p in points:
        while len(low) > 1 and turn(low[-2], low[-1], p) <= 0: low.pop()
        low.append(p)
    for p in reversed(points):
        while len(high) > 1 and turn(high[-2], high[-1], p) <= 0: high.pop()
        high.append(p)
    return low[:-1]+high[:-1]


def inside(point, polygon):
    return all((b[0]-a[0])*(point[1]-a[1])-(b[1]-a[1])*(point[0]-a[0]) >= -1e-7
               for a, b in zip(polygon, polygon[1:]+polygon[:1]))


def products():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    lookup = lib.serial_index(); result, records = {}, {}
    def png(name, image):
        stream = io.BytesIO(); image.save(stream, format='PNG', optimize=True); result[name] = stream.getvalue()
    for serial in range(12500, 12536):
        g = lookup[serial]; assert g['east'] == g['south'] == g['ground'] == 1
        original = lib.image_from_record(g['pack'], g['row']).convert('RGBA'); clean, removed_shadow = native_without_ground_shadow(original)
        paint = clean.copy(); pixels = paint.load(); points, water = [], 0
        for y in range(clean.height):
            for x in range(clean.width):
                r, green, b, alpha = pixels[x, y]
                if alpha <= 128: continue
                if b >= green*.99 and green > r*1.10:
                    pixels[x, y] = (r, green, b, 0); water += 1; continue
                u = (x+.5+g['x'])/(32/3); v = (y+.5+g['y'])/8
                xx, zz = (u-v)/2, (u+v)/2
                if not (-1.5-STEP <= xx <= 1.5+STEP and -1.5-STEP <= zz <= 1.5+STEP): continue
                for dx, dy in [(0, 0), (1, 0), (1, 1), (0, 1)]:
                    u = (x+dx+g['x'])/(32/3); v = (y+dy+g['y'])/8
                    points.append((round(max(-1.5, min(1.5, (u-v)/2)), 7), round(max(-1.5, min(1.5, (u+v)/2)), 7)))
        polygon = hull(points); assert len(polygon) >= 3, ('No source cap contour', serial)
        rectangles, active = [], {}
        for row in range(24):
            z0, z1 = -1.5+row*STEP, -1.5+(row+1)*STEP; runs = []; first = None
            for column in range(25):
                x0, x1 = -1.5+column*STEP, -1.5+(column+1)*STEP
                valid = column < 24 and all(inside(p, polygon) for p in [(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
                if valid and first is None: first = column
                if not valid and first is not None: runs.append((first, column)); first = None
            next_active = {}
            for run in runs:
                if run in active: rectangle = active[run]; rectangle[3] = z1
                else: rectangle = [-1.5+run[0]*STEP, z0, -1.5+run[1]*STEP, z1]; rectangles.append(rectangle)
                next_active[run] = rectangle
            active = next_active
        assert rectangles, ('Cap is too small for an inferred physical interior', serial)
        approaches = {}
        for direction, edge, interval in [('west', 0, (1, 3)), ('east', 2, (1, 3)), ('north', 1, (0, 2)), ('south', 3, (0, 2))]:
            boundary = -1.5 if direction in ['west', 'north'] else 1.5
            bands = sorted((r[interval[0]], r[interval[1]]) for r in rectangles if abs(r[edge]-boundary) < 1e-6)
            merged = []
            for low, high in bands:
                if merged and low <= merged[-1][1]+1e-6: merged[-1][1] = max(merged[-1][1], high)
                else: merged.append([low, high])
            if not merged: continue
            low, high = max(merged, key=lambda p: p[1]-p[0]); middle = (low+high)/2
            spans = [(r[0], r[2]) if direction in ['west', 'east'] else (r[1], r[3]) for r in rectangles if r[interval[0]] <= middle <= r[interval[1]]]
            lo, hi = min(s[0] for s in spans), max(s[1] for s in spans)
            stand = [(lo+hi)/2, middle] if direction in ['west', 'east'] else [middle, (lo+hi)/2]
            joins = {'west': [-4.5, -1.5, -1.5, 1.5], 'east': [1.5, -1.5, 4.5, 1.5], 'north': [-1.5, -4.5, 1.5, -1.5], 'south': [-1.5, 1.5, 1.5, 4.5]}
            approaches[direction] = {'stand': stand, 'entry_interval': [low, high], 'entry_radius_local': (high-low)/2, 'join_rect': joins[direction],
                                     'join_requires': 'Caller must prove this complete neighboring3mcell is original-open dryland at the same height. No water support is inferred by this template.'}
        best, clearance = None, -1
        for iz in range(49):
            for ix in range(49):
                p = (-1.5+ix*STEP*.5, -1.5+iz*STEP*.5)
                if not inside(p, polygon): continue
                gap = min(abs((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]))/math.hypot(b[0]-a[0], b[1]-a[1]) for a, b in zip(polygon, polygon[1:]+polygon[:1]))
                if gap > clearance: best, clearance = p, gap
        # Transparent gutters make native projected faces outside the original
        # canvas disappear rather than clamp a coloured edge down the whole bank.
        padded = Image.new('RGBA', (paint.width+4, paint.height+4)); padded.paste(paint, (2, 2))
        records[str(serial)] = {'serial': serial, 'pack': g['pack'], 'row': g['row'], 'origin': [g['x']-2, g['y']-2], 'size': list(padded.size),
                               'native_origin': [g['x'], g['y']], 'native_size': list(original.size), 'footprint': [1, 1],
                               'source_rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(), 'front_rgba_sha256': hashlib.sha256(padded.tobytes()).hexdigest(),
                               'cap_outline': polygon, 'support_rects': rectangles, 'support_step': STEP,
                               'approaches': approaches,
                               'deepest_stand': best, 'outline_clearance_local': clearance,
                               'shadow_pixels_removed': len(removed_shadow), 'water_alpha_pixels_removed': water}
        png(f'{serial}-native.png', original); png(f'{serial}-front.png', padded)
    atlas = Image.new('RGBA', (256, 128)); ground = lookup[5045]
    grass = project_tile(lib.image_from_record(ground['pack'], ground['row'])).convert('RGBA').resize((128, 128), Image.Resampling.BICUBIC)
    # Hidden earth reuses the existing natural-rock grain. The former building
    # stone crop contained an architectural arch/ridge repeated down the bank.
    stone_path = ROOT/'assets/textures/edo/rock.png'
    sx, sy = 0, 0
    stone = Image.open(stone_path).convert('RGBA'); assert stone.size == (128, 128)
    assert stone.getchannel('A').getextrema() == (255, 255)
    atlas.paste(grass, (0, 0)); atlas.paste(stone, (128, 0)); png('surfaces.png', atlas)
    data = {'schema': 1, 'graphics': records, 'dispatch': 'No global family owner. Only explicitly enrolled newly completed village bank placements may call this helper.',
            'reuse': ['TinaGround.bank_mesh native cap/descending bank/water separation', 'Coastal native projector and closed independent part tiles',
                      'Palace static support shape; existing Ramparts exact pieces, prepared once into local spatial buckets'],
            'surface_sources': {'grass': {'graphic': 5045, 'pack': ground['pack'], 'row': ground['row']}, 'stone': {'path': str(stone_path.relative_to(ROOT)), 'tile': [sx, sy], 'rgba_sha256': hashlib.sha256(stone.tobytes()).hexdigest()}},
            'inferred': ['Horizontal cap hull closes tiny grass-alpha holes within the original1x1footprint; source-facing RGB is untouched.',
                         'Support rectangles lie conservatively inside that hull at0.125m pitch. They never create a full3x3grass box.',
                         'Unseen bank depth continues from adjacent observed land height down to existing2mwater, using independent native stone tiles.',
                         'The native painted bank/front is projected only onto observed-facing cap/edge surfaces; hidden backs are reconstructed.']}
    result['data.json'] = (json.dumps(data, indent=2)+'\n').encode(); return result


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true'); args = parser.parse_args(); stale = []
    for name, payload in products().items():
        path = OUT/name
        if args.check:
            if not path.exists() or path.read_bytes() != payload: stale.append(name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_bytes() != payload: path.write_bytes(payload)
    if stale: raise SystemExit('Stale native bank cap derivatives: '+','.join(stale))
    print(('Verified' if args.check else 'Prepared')+'36source bank contours; no map/global bank owner changed.')


if __name__ == '__main__': main()
