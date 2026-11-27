"""Native evidence and measured profiles for bounded East-only fallback forms.

Original library records and shared tree/palm masters remain untouched.
"""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region/fallback_families'
IDS = (10474,10475,11150,11151,*range(11188,11209),*range(1235161,1235168))


def products():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    lookup=lib.serial_index()
    catalog = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())
    village = json.loads((ROOT / 'assets/maps/falan/village_street_props/data.json').read_text())
    palette = json.loads((ROOT / 'assets/maps/falan/black_prayer/region-trees.json').read_text())['palettes']['10085']
    results = {}; graphics = {}; images = {}
    for serial in IDS:
        source = catalog['graphics'].get(str(serial))
        if source is None:
            native=lookup[serial]
            source={'pack':native['pack'],'row':native['row'],'origin':[native['x'],native['y']],
                    'footprint':[max(1,native['east']),max(1,native['south'])]}
        image = lib.image_from_record(source['pack'], source['row']).convert('RGBA')
        digest = hashlib.sha256(image.tobytes()).hexdigest()
        if 'rgba_sha256' in source:assert digest == source['rgba_sha256'], (serial, digest)
        stream = io.BytesIO(); image.save(stream, format='PNG', optimize=True)
        results[f'{serial}.png'] = stream.getvalue(); images[serial] = image
        row = {key: source[key] for key in ('pack', 'row', 'origin', 'footprint')}
        row.update(size=list(image.size), bounds=list(image.getbbox()), source_rgba_sha256=digest)
        if serial in (10474,10475):
            row['structural_bounds']=[0,0,34,81] if serial==10474 else [0,0,35,82]
            pixels=[image.getpixel((x,y)) for y in range(50) for x in range(image.width) if image.getpixel((x,y))[3]>200]
            row['iron_rgb']=[sum(p[c] for p in pixels)/len(pixels)/255 for c in range(3)]
            row['reuse']='forest_falan_courtyard.gd::ironwork five bars/five caps/two rails; source-axis rotation and structural fit excludes baked ground shadow'
        elif serial in (11150,11151):
            row['leaf_rgb'] = village['graphics'][str(serial)]['leaf_rgb']
            row['base_leaf_rgb'] = palette
            row['reuse'] = 'WindMeadow cg_woodland whole Body and Canopy; existing Kili source fit'
        elif serial < 12000:
            row['reuse'] = f'forest_ruby_region_art.gd::palm_shape({serial}), existing Sokia original Trunk/fronds and native crown owner'
        else:
            # Y is physical world height. X/Z sections come directly from the native cap diamonds:
            # 64x48 ->3x3; 128x96 ->9x3 (or3x9), using32/3 horizontally and8 on the floor.
            row['section'] = [9,3] if serial==1235166 else [3,9] if serial==1235167 else [3,3]
            row['height'] = (-(source['origin'][1])-sum(row['section'])*4)*.045
            row['form'] = 'beam_post' if serial in (1235166,1235167) else 'fluted_post' if serial==1235163 else 'wall'
        graphics[str(serial)] = row
    atlas = Image.new('RGBA',(384,128))
    samples = {'stone':(1235165,(12,116,27,160)), 'gold':(1235165,(4,36,12,44)), 'cap':(1235165,(27,14,35,24))}
    for i,(name,(serial,rect)) in enumerate(samples.items()):
        patch = images[serial].crop(rect).resize((112,112),Image.Resampling.BICUBIC)
        assert patch.getchannel('A').getextrema()==(255,255), name
        # Blend opposite eight-pixel margins; preserve orientation without mirror diamonds.
        for axis in (0,1):
            original=patch.copy()
            for along in range(112):
                for edge in range(8):
                    for side in (edge,111-edge):
                        p=(side,along) if axis==0 else (along,side)
                        q=(111-side,along) if axis==0 else (along,111-side)
                        a=original.getpixel(p);b=original.getpixel(q);t=(8-edge)/16
                        patch.putpixel(p,tuple(round(a[k]*(1-t)+b[k]*t) for k in range(4)))
        for y in range(128):
            for x in range(128):
                atlas.putpixel((i*128+x,y),patch.getpixel((min(111,max(0,x-8)),min(111,max(0,y-8)))))
    stream=io.BytesIO();atlas.save(stream,format='PNG',optimize=True);results['surfaces.png']=stream.getvalue()
    data={'schema':1,'graphics':graphics,'tiles':{name:[i*128,0] for i,name in enumerate(samples)},
          'tile_samples':{name:[serial,list(rect)] for name,(serial,rect) in samples.items()},
          'scope':'Only original East object-layer final-prop fallback. No route, placement, collision, source or master changes.',
          'inferred':['Whole reused woodland crown/trunk volume within the measured native silhouette bounds; native dry-leaf palette ratio.',
                      'Closed palace backs use independent native dark-stone/gold/cap tiles. Original front/side pixels are observed paint.',
                      'Palace wall bevels, cap thickness, hidden flutes and beam braces follow measured cap/base sections; hidden surfaces are reconstruction.']}
    results['data.json']=(json.dumps(data,indent=2)+'\n').encode()
    return results


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    expected=products();bad=[]
    for name,payload in expected.items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload:bad.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(payload)
    if bad:raise SystemExit('Stale native fallback derivatives: '+', '.join(bad))
    print(('Verified' if args.check else 'Prepared')+f' {len(expected)} native fallback derivatives;{len(IDS)} graphics; originals unchanged.')


if __name__=='__main__':main()
