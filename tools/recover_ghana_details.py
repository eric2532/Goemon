"""Prepare Ghana's native well paint without changing archived artwork."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
from recover_venoa_walls import solid_native_paint

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan'


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as library
    entry = library.serial_index()[11229]
    original = library.image_from_record(entry['pack'], entry['row'])
    paint, shadows = solid_native_paint(original)
    dark = min(((x, y) for y in range(45, 75) for x in range(28, 64)
                if original.getpixel((x, y))[3] == 255),
               key=lambda p: sum(original.getpixel(p)[:3]))
    meta = {'graphic': 11229, 'pack': entry['pack'], 'row': entry['row'],
            'source_rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(),
            'paint_rgba_sha256': hashlib.sha256(paint.tobytes()).hexdigest(),
            'ground_shadow_pixels': shadows,
            'origin': [-entry['x'], -entry['y'] - 24], 'dark_pixel': list(dark),
            'method': 'Native opaque RGB preserved. Shared round-profile and rod geometry fits the visible open ring, two posts, windlass and bucket; rear faces remain inferred.'}
    return paint, meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    paint, meta = prepare()
    path = OUT / 'ghana_well'
    if args.check:
        assert Image.open(path.with_suffix('.png')).convert('RGBA').tobytes() == paint.tobytes()
        assert json.loads(path.with_suffix('.json').read_text()) == meta
        print('PASS: native Ghana well paint and source hash reproduce')
    else:
        paint.save(path.with_suffix('.png'))
        path.with_suffix('.json').write_text(json.dumps(meta, indent=2) + '\n')
        print('Prepared native Ghana well paint; archived original unchanged')


if __name__ == '__main__':
    main()
