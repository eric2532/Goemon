"""Measure native Kili/Ghana wall silhouettes without their ground shadows."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from recover_venoa_walls import native_without_ground_shadow

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/kili_wall_proportions'


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as library
    lookup = library.serial_index()
    graphics = {}
    rows = ['extends RefCounted', '## Generated from native wall alpha excluding checkerboard ground shadow.', 'const RECTS={']
    for serial in range(11230, 11251):
        entry = lookup[serial]
        original = library.image_from_record(entry['pack'], entry['row'])
        clean, shadow = native_without_ground_shadow(original)
        x, y, right, bottom = clean.getbbox()
        rect = [entry['x']+x, entry['y']+y, right-x, bottom-y]
        graphics[serial] = {'pack': entry['pack'], 'row': entry['row'],
                            'rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(),
                            'rect': rect, 'ground_shadow_pixels': len(shadow)}
        rows.append(f' {serial}:Rect2({",".join(map(str, rect))}),')
    rows.append('}')
    return '\n'.join(rows)+'\n', {'graphics': graphics, 'method': 'Native projected silhouette bounds excluding ground shadow. Fit the existing solid kit at setup only; hidden shape and fine cap profiles remain inferred. Collision data is not generated.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    code, meta = prepare()
    if args.check:
        assert OUT.with_suffix('.gd').read_text() == code
        assert json.loads(OUT.with_suffix('.json').read_text()) == json.loads(json.dumps(meta))
        print('PASS: 21 native Kili/Ghana wall bounds and source hashes reproduce')
    else:
        OUT.with_suffix('.gd').write_text(code)
        OUT.with_suffix('.json').write_text(json.dumps(meta, indent=2)+'\n')
        print('Prepared 21 native Kili/Ghana wall silhouette bounds')


if __name__ == '__main__':
    main()
