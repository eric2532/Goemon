"""Prepare native Venoa wall paint and visible broken crowns; preserve source art."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from PIL import Image
from recover_falan_architecture import opaque_paint

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan'
LONG_X = {11253, 11254, 11256, 11257, 11258, 11259, 11260}
POSTS = {11252, 11253, 11254, 11255, 11261}
HORIZONTAL = 32 / 3
PIXEL_HEIGHT = .045  # Existing coastal building/art contract.


def native_without_ground_shadow(original):
    # Native ground shadow uses palette gray 71 on a transparent checkerboard.
    # Interior flues and dark carvings are opaque art, so never remove by luma.
    remaining = {(x, y) for y in range(original.height) for x in range(original.width)
                 if original.getpixel((x, y)) == (71, 71, 71, 255)}
    shadow = set()
    while remaining:
        component = [remaining.pop()]
        for x, y in component:
            for dx in [-1, 0, 1]:
                for dy in [-1, 0, 1]:
                    p = x + dx, y + dy
                    if p in remaining:
                        remaining.remove(p)
                        component.append(p)
        boundary = sum(sum(1 for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]
                           if not (0 <= x+dx < original.width and 0 <= y+dy < original.height)
                           or original.getpixel((x+dx, y+dy))[3] == 0) >= 2 for x, y in component)
        if len(component) >= 8 and min(y for x, y in component) > original.height * .45 and boundary / len(component) > .8:
            shadow.update(component)
    clean = original.copy()
    for x, y in shadow:
        r, g, b, _ = clean.getpixel((x, y))
        clean.putpixel((x, y), (r, g, b, 0))
    return clean, shadow


def solid_native_paint(original):
    clean, shadow = native_without_ground_shadow(original)
    paint = opaque_paint(clean)
    for y in range(original.height):
        for x in range(original.width):
            before = original.getpixel((x, y))
            if before[3] == 255 and (x, y) not in shadow:
                assert before[:3] == paint.getpixel((x, y))[:3], 'Native opaque RGB changed'
    return paint, len(shadow)


def wall_profile(original, entry, along_x, crown, lower=-1.5, upper=1.5):
    plane = .8 if along_x else -.8
    samples = []
    for step in range(17):
        along = lower + step * (upper - lower) / 16
        wx, wz = (along, plane) if along_x else (plane, along)
        px = max(0, min(original.width - 1, round(-entry['x'] + (wx + wz) * HORIZONTAL)))
        behind_post = crown and min(x for x, y in crown) - 1 <= px <= max(x for x, y in crown) + 1
        candidates = []
        if not behind_post:
            for y in range(original.height):
                r, g, b, a = original.getpixel((px, y))
                if a == 255 and min(r, g) > 100 and max(r, g, b) - min(r, g, b) < 90:
                    candidates.append(y)
        samples.append((along, min(candidates) if candidates else None, wx, wz))
    known = [s for s in samples if s[1] is not None]
    assert len(known) >= 4, entry['serial']
    profile = []
    for along, top, wx, wz in samples:
        if top is None:
            top = min(known, key=lambda s: abs(s[0] - along))[1]
        # Preserve the old wall thickness behind the visible source face.
        height = max(.12, (-entry['y'] + (wz - wx) * 8 - top - .6 * 8) * PIXEL_HEIGHT)
        profile.append([round(along, 6), round(height, 6)])
    return profile


def prepare(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_library as library
    lookup = library.serial_index()
    atlas = Image.new('RGBA', (512, 512))
    records, rows = {}, []
    for index, serial in enumerate(range(11252, 11266)):
        entry = lookup[serial]
        original = library.image_from_record(entry['pack'], entry['row'])
        paint, shadow_pixels = solid_native_paint(original)
        ax, ay = index % 7 * 72 + 2, index // 7 * 256 + 2
        assert ax + paint.width <= 512 and ay + paint.height <= 512
        atlas.paste(paint, (ax, ay))
        along_x = serial in LONG_X
        plane = .8 if along_x else -.8
        post = []
        crown = []
        if serial in POSTS:
            wood = [(x, y) for y in range(original.height // 2)
                    for x in range(original.width)
                    if (lambda p: p[3] == 255 and p[0] > p[1] * 1.18 and p[1] > p[2] * 1.25)(original.getpixel((x, y)))]
            assert wood, serial
            top = min(y for x, y in wood)
            crown = [(x, y) for x, y in wood if y < top + 12]
            px = sum(x for x, y in crown) / len(crown)
            along = (px + entry['x']) / HORIZONTAL - plane
            wx, wz = (along, plane) if along_x else (plane, along)
            height = (-entry['y'] + (wz - wx) * 8 - top) * PIXEL_HEIGHT
            radius = max(.12, (max(x for x, y in crown) - min(x for x, y in crown)) / (2 * math.sqrt(2) * HORIZONTAL))
            post = [round(along, 6), round(height, 6), round(radius, 6)]
        faces = [[False, wall_profile(original, entry, False, crown, -1.5, .8)],
                 [True, wall_profile(original, entry, True, crown, -.8, 1.5)]] if serial == 11261 else [[along_x, wall_profile(original, entry, along_x, crown)]]
        records[serial] = {'pack': entry['pack'], 'row': entry['row'],
                           'rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(), 'ground_shadow_pixels': shadow_pixels,
                           'rect': [ax, ay, original.width, original.height],
                           'origin': [-entry['x'], -entry['y']],
                           'faces': faces, 'post': post}
        face_data = ','.join('[' + str(axis).lower() + ',[' + ','.join(f'Vector2({x},{y})' for x, y in profile) + ']]' for axis, profile in faces)
        rows.append(f' {serial}:[Rect2({ax},{ay},{original.width},{original.height}),Vector2({-entry["x"]},{-entry["y"]}),['+face_data+'],'+
                    ('Vector3(%s)' % ','.join(map(str, post)) if post else 'Vector3.ZERO') + '],')
    data = '\n'.join(['extends RefCounted', '## Generated by tools/recover_venoa_walls.py; visible crowns and original paint.',
                       'const ATLAS=preload("res://assets/maps/falan/venoa_walls.png")', 'const FORMS={', *rows, '}']) + '\n'
    meta = {'graphics': records, 'height_per_pixel': PIXEL_HEIGHT,
            'method': 'Native visible paint, sampled broken crowns and round wooden posts. Hidden thickness, obscured crown interpolation and coastal vertical fit are inferred; existing collision is unchanged.'}
    return atlas, data, meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT.parent / 'Magic Power')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    atlas, data, meta = prepare(args.source.resolve())
    path = OUT / 'venoa_walls'
    if args.check:
        with Image.open(path.with_suffix('.png')) as actual:
            assert actual.tobytes() == atlas.tobytes()
        assert path.with_suffix('.gd').read_text() == data
        assert json.loads(path.with_suffix('.json').read_text()) == json.loads(json.dumps(meta))
        print('PASS: fourteen native Venoa wall derivatives reproduce exactly')
    else:
        atlas.save(path.with_suffix('.png'), optimize=True)
        path.with_suffix('.gd').write_text(data)
        path.with_suffix('.json').write_text(json.dumps(meta, indent=2) + '\n')
        print('Prepared fourteen native Venoa walls; original archives unchanged')


if __name__ == '__main__':
    main()
