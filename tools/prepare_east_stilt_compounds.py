"""One measured Minoquier stilt-cottage candidate; no original/map edits."""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/maps/falan/east_region/stilt_compounds'
REVIEW = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Stilt Compounds'


def products():
    proof = json.loads((REVIEW/'source-contracts.json').read_text())
    catalog = ROOT/'assets/maps/original_crossgate/east/catalog.json'
    assert proof['source_catalog_sha256'] == hashlib.sha256(catalog.read_bytes()).hexdigest()
    source = next(r for r in proof['forms'] if r['graphic'] == 1233284 and r['source_cell'] == [108, 101])
    original = Image.open(REVIEW/source['native_composite']).convert('RGBA')
    painted = original.copy(); pixels = painted.load(); removed = 0
    for y in range(painted.height):
        for x in range(painted.width):
            r, g, b, alpha = pixels[x, y]
            # This gold prototype has no blue roof/glass. Keep the source RGB;
            # only water-coloured alpha changes in the separate paint derivative.
            if alpha and b > g*1.05 and g > r*1.15:
                pixels[x, y] = (r, g, b, 0); removed += 1
    box = painted.getbbox(); assert box is not None
    native = original.crop(box); front = painted.crop(box)
    def shifted(p): return [p[0]-box[0], p[1]-box[1]]
    feet = [[347, 788], [434, 737], [220, 712]]
    def floor_point(p):
        u, v = p[0]-400, p[1]-650
        return [u*3/64-v/16, u*3/64+v/16]
    a, b, c = map(floor_point, feet)
    denominator = 2*(a[0]*(b[1]-c[1])+b[0]*(c[1]-a[1])+c[0]*(a[1]-b[1]))
    squares = [sum(t*t for t in p) for p in [a, b, c]]
    cx = (squares[0]*(b[1]-c[1])+squares[1]*(c[1]-a[1])+squares[2]*(a[1]-b[1]))/denominator
    cz = (squares[0]*(c[0]-b[0])+squares[1]*(a[0]-c[0])+squares[2]*(b[0]-a[0]))/denominator
    center = [400+(cx+cz)*32/3, 650+(cz-cx)*8]
    floor_level, roof_level = 54, 146
    row = {'serial': 1233284, 'source': 43500, 'source_cell': [108, 101], 'size': list(native.size),
           'origin': [box[0]-400, box[1]-650], 'native_composite_crop': list(box),
           'source_foreground_rgba_sha256': source['foreground_rgba_sha256'], 'source_raw_sha256': proof['source_raw_sha256'],
           'source_walk_sha256': proof['source_walk_sha256'], 'background_context_tuples': source['background_context_tuples'],
           'source_foot_samples': [shifted(p) for p in feet], 'fitted_foot_ring_center_xz': [cx, cz],
           'floor_center_pixel': shifted(center), 'floor_level_pixels': floor_level,
           'body': {'base': shifted([center[0], center[1]-floor_level]), 'level_pixels': floor_level,
                    'height_pixels': roof_level-floor_level, 'diameter': 205, 'material': 'timber', 'window': 'tree_window',
                    'profile': [[0, .98], [.08, 1], [.92, 1], [1, .98]]},
           'roof': {'base': shifted([center[0], center[1]-roof_level]), 'level_pixels': roof_level,
                    'height_pixels': 112, 'diameter': 248, 'material': 'leaf_roof_gold',
                    'profile': [[0, 1], [.08, 1.02], [.27, .95], [.5, .77], [.75, .49], [.9, .24], [1, .08]]},
           'pilings': [shifted(p) for p in feet],
           'stairs': {'near': [shifted([211, 750]), shifted([226, 766])], 'far': [shifted([245, 697]), shifted([268, 714])],
                      'height_pixels': floor_level, 'steps': 7},
           'finial_outline': [shifted(p) for p in [[330, 395], [341, 397], [352, 413], [363, 419], [366, 438], [355, 451], [366, 465], [349, 480], [313, 472], [297, 451], [306, 433], [316, 431], [323, 419]]],
           'water_alpha_pixels_removed_from_paint': removed,
           'native_rgb_crop_sha256': hashlib.sha256(native.tobytes()).hexdigest(),
           'front_rgba_sha256': hashlib.sha256(front.tobytes()).hexdigest()}
    data = {'schema': 1, 'graphics': {'1233284': row}, 'status': 'Private one-form source-angle candidate; no runtime dispatch or BG skip.',
            'source_contract_sha256': hashlib.sha256((REVIEW/'source-contracts.json').read_bytes()).hexdigest(),
            'reuse': ['Existing EastArt round_body curved profiles and closed caps', 'Existing Coastal/Harbor turned timber and stairs primitives',
                      'Existing native leaf_roof_gold, timber and tree_window tiles', 'Existing Shapes closed contour extrusion for the native finial'],
            'inferred': ['A circular support ring is fitted to three manually observed native foot pixels; hidden rear piling and round depth remain inferred.',
                         '54pixel loft floor, body/eave heights, curved roof rings, seven closed treads and hidden back joinery are measured reconstruction candidates, not recovered 3D.',
                         'This prototype changes no floor/nav/warp/collider and cannot certify physical stair traversal.',
                         'The gold-only paint alpha omits blue water. All retained RGB comes from the untouched native layered source; no slate-roof masking rule is inferred.']}
    result = {'data.json': (json.dumps(data, indent=2)+'\n').encode()}
    for name, image in [('1233284-native.png', native), ('1233284-front.png', front)]:
        stream = io.BytesIO(); image.save(stream, format='PNG', optimize=True); result[name] = stream.getvalue()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    stale = []
    for name, value in products().items():
        path = OUT/name
        if args.check:
            if not path.exists() or path.read_bytes() != value: stale.append(name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_bytes() != value: path.write_bytes(value)
    if stale: raise SystemExit('Stale private stilt cottage: '+','.join(stale))
    print(('Verified' if args.check else 'Prepared')+' one private native stilt-cottage candidate; original maps/art unchanged.')


if __name__ == '__main__': main()
