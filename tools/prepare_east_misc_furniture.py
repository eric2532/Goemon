"""Pinned native references for the remaining East branch furniture forms."""
import argparse, hashlib, io, json, sys
from pathlib import Path
from PIL import Image
from east_region_furniture_roles import ROLES
from recover_venoa_walls import native_without_ground_shadow

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region/misc_furniture'
IDS = [10035,10043,10044,10433,10497,10523,11003,11004,11005,11006,11042,
       11575,11576,11580,11730,11731,11732,16010,16013,16032,16223,16244,
       16245,16538,16646,16749,16754,16765,16766,16805,16818,16823,16824,
       16825,16828,16852,16853,16854,16855,16864,16865,16866,17044,17052,
       17063,17064,17165,17182,17183,17197,17199,17230,17528]

def products():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    graphics = {}
    for path in ['assets/maps/original_crossgate/catalog.json',
                 'assets/maps/falan/sokia/fixed/catalog.json',
                 'assets/maps/original_crossgate/university/catalog.json',
                 'assets/maps/original_crossgate/elsa/catalog.json',
                 'assets/maps/original_crossgate/east/catalog.json']:
        rows = json.loads((ROOT / path).read_text())['graphics']
        if 'sokia/fixed' in path:
            for token, g in rows.items(): graphics.setdefault(token, g)
        else: graphics.update(rows)
    files, rows = {}, {}
    for serial in IDS:
        g = graphics[str(serial)]
        original = lib.image_from_record(g['pack'], g['row']).convert('RGBA')
        digest = hashlib.sha256(original.tobytes()).hexdigest()
        assert digest == g['rgba_sha256'], serial
        clean, _ = native_without_ground_shadow(original)
        stream = io.BytesIO(); clean.save(stream, format='PNG', optimize=True)
        files[f'{serial}-front.png'] = stream.getvalue()
        rows[str(serial)] = dict(role=ROLES[serial], origin=g['origin'],
            size=list(original.size), bounds=list(clean.getbbox()),
            footprint=g['footprint'], source_rgba_sha256=digest,
            source_pack=g['pack'], source_row=g['row'])
    data = dict(schema=1, graphics=rows,
        scope='53 exact native references. Private construction studies; source references alone do not activate or certify a map.',
        inferred=['Unseen backs, joints, thickness and hidden interiors must follow compatible existing furniture construction and be reviewed separately. No source route, service, container interaction or encounter is added by scenery.'])
    files['data.json'] = (json.dumps(data, ensure_ascii=False, indent=2)+'\n').encode()
    return files

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    bad = []
    for name, value in products().items():
        path = OUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != value: bad.append(name)
        elif not path.exists() or path.read_bytes() != value:
            OUT.mkdir(parents=True, exist_ok=True); path.write_bytes(value)
    if bad: raise SystemExit('Stale East furniture references: '+', '.join(bad))
    print(('Verified' if args.check else 'Prepared')+' 53 exact native furniture references; original RGBA preserved.')

if __name__ == '__main__': main()
