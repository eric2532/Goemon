"""Measure the eleven original object-layer pier/border drawings in map33608."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region/mouse_room_piers/data.json'
IDS = [1230051, 1230052, 1230054, 1230055, 1230056,
       1230122, 1230123, 1230124, 1230125, 1230127, 1230128]


def products():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    catalog = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())
    rows = {}
    files = {}
    for serial in IDS:
        g = catalog['graphics'][str(serial)]
        image = lib.image_from_record(g['pack'], g['row']).convert('RGBA')
        digest = hashlib.sha256(image.tobytes()).hexdigest()
        assert digest == g['rgba_sha256'], serial
        rows[str(serial)] = dict(size=list(image.size), bounds=list(image.getbbox()),
            origin=g['origin'], footprint=g['footprint'], source_rgba_sha256=digest,
            source_pack=g['pack'], source_row=g['row'], runtime_page=g['page'], runtime_rect=g['rect'])
        if serial == 1230127:
            rows[str(serial)]['ball_front_crop'] = [10, 0, 37, 24]
            stone = ROOT / 'assets/textures/edo/rock.png'
            rows[str(serial)]['hidden_surface_source'] = dict(path=str(stone.relative_to(ROOT)),
                sha256=hashlib.sha256(stone.read_bytes()).hexdigest(), pitch_m=1.2,
                tint_srgb=[.8, .75, 1.0], inferred=True)
    files['data.json'] = (json.dumps(dict(schema=1, graphics=rows,
        scope='Exact source measurements only. Private geometry; no map activation or completion claim.',
        reuse='Existing closed moulded profile, rounded furniture blocks, sphere primitive and Edo natural-rock texture. Native face paint references the existing East atlas. Hidden sphere uses independent triplanar natural-rock grain at1.2m, never the complete front drawing.',
        inferred=['Unseen pier backs, bevel thickness and full ball circumference. Original footprints, placements, navigation and events remain authoritative.']), ensure_ascii=False, indent=2) + '\n').encode()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, payload in products().items():
        path = OUT.parent / name
        if args.check:
            assert path.exists() and path.read_bytes() == payload, 'Stale mouse-room source product: ' + name
        elif not path.exists() or path.read_bytes() != payload:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
    print(('Verified' if args.check else 'Prepared') + ' eleven native mouse-room pier measurements; original images unchanged.')


if __name__ == '__main__':
    main()
