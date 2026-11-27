"""Native closed door leaves, measured from their original ground edge."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from east_architecture_sections import hull

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/doors'
IDS=[10095,10096,17642]


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from recover_venoa_walls import native_without_ground_shadow
    graphics={}
    for path in ['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json','assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
        graphics.update(json.loads((ROOT/path).read_text())['graphics'])
    results={};rows={}
    def png(name,image):
        stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
    for serial in IDS:
        g=graphics[str(serial)];original=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        with lib.connection() as db:source=dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[source['x'],source['y']] and g['footprint']==[source['east'],source['south']]
        digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256']
        clean,shadow=native_without_ground_shadow(original)
        outline=hull((x,y) for y in range(clean.height) for x in range(clean.width) if clean.getpixel((x,y))[3]>128)
        candidates=[]
        for a in outline:
            for b in outline:
                dx=b[0]-a[0];dy=b[1]-a[1]
                if abs(dx)<clean.width*.55 or not .4<abs(dy/dx)<.95:continue
                candidates.append(((a[1]+b[1])/2+abs(dx)*.03,a,b))
        assert candidates,('Native ground edge needs explicit measurement',serial)
        _,a,b=max(candidates)
        def floor(pixel):
            u=(pixel[0]+g['origin'][0])/(32/3);v=(pixel[1]+g['origin'][1])/8
            return [(u-v)/2,(u+v)/2]
        pa,pb=floor(a),floor(b);delta=[pb[i]-pa[i] for i in range(2)];normal=[-delta[1],delta[0]]
        if -normal[0]+normal[1]<0:pa,pb=pb,pa
        rows[str(serial)]={'serial':serial,'kit':'native_door','size':list(original.size),'visible':list(clean.getbbox()),'origin':g['origin'],'footprint':g['footprint'],
            'pack':g['pack'],'row':g['row'],'source_rgba_sha256':digest,'source_floor_pixels':[a,b],'floor_edge':[pa,pb],'outline_pixels':outline,'depth':.18,'removed_shadow_pixels':len(shadow)}
        png(f'{serial}.png',original);png(f'{serial}-front.png',clean)
    results['data.json']=(json.dumps({'schema':1,'graphics':rows,'status':'Candidate source/reverse review, no runtime dispatch.',
       'reuse':['Existing closed Shapes.extrude door sections','Independent clean native Tina fence timber tile at fixed1.4m pitch, grain along the leaf; no mirrored knob/rear doorway'],
       'inferred':['Native outline, ground-edge endpoints, original source anchor and footprint are observed. Ground-edge height0 and the closed leaf depth/hidden wood finish are reconstructed.',
                   'Source-facing paint remains literal. These mesh-only leaves do not create a new opening, trigger, collision or route.'],
       'scope':'Only three exact East source closed door leaves; other-region owners remain unchanged.'},indent=2)+'\n').encode()
    return results


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload:bad.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            if not path.exists() or path.read_bytes()!=payload:path.write_bytes(payload)
    if bad:raise SystemExit('Stale native door leaves: '+','.join(bad))
    print(('Verified' if args.check else 'Prepared')+'3 native closed door leaves; originals unchanged.')


if __name__=='__main__':main()
