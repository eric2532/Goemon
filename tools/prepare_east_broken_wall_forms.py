"""Twenty bounded native broken-wall/arch candidates; source maps remain read-only."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/broken_walls'
IDS=[11701,11702,11704,11707,11710,11711,11713,*range(11716,11723),*range(11724,11730)]
AXES={11727:'x',11728:'x',11729:'z'}


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from recover_venoa_walls import native_without_ground_shadow
    catalog={}
    for name in ['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json','assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
        catalog.update(json.loads((ROOT/name).read_text())['graphics'])
    result={};rows={}
    def png(name,image):
        stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);result[name]=stream.getvalue()
    for serial in IDS:
        g=catalog[str(serial)]
        with lib.connection() as db:
            native=dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']]
        original=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256']
        clean,shadow=native_without_ground_shadow(original)
        axis=AXES.get(serial,'x' if g['footprint'][0]>g['footprint'][1] else 'z')
        depth=1.0 if serial>=11716 else 1.2
        plane=depth*.5 if axis=='x' else -depth*.5
        def floor_y(px):
            across=(px+g['origin'][0])/(32/3)
            x,z=(across-plane,plane) if axis=='x' else (plane,across-plane)
            return (z-x)*8-g['origin'][1]
        runs=[];ground=clean.copy();pixels=ground.load()
        for y in range(clean.height):
            for x in range(clean.width):
                if y<floor_y(x)-1:pixels[x,y]=(0,0,0,0)
        # Two-native-pixel strips keep arch holes and broken crests open; they
        # are closed wall parts with independent back/cap material, not cards.
        for x in range(0,clean.width,2):
            stop=min(x+2,clean.width);mid=(x+stop)*.5;last=min(clean.height-1,int(floor_y(mid)))
            start=None
            for y in range(max(0,last+2)):
                opaque=y<=last and sum(clean.getpixel((u,y))[3]>128 for u in range(x,stop))*2>=stop-x
                if opaque and start is None:start=y
                if not opaque and start is not None:
                    if y-start>=2:runs.append([x,stop,start,y])
                    start=None
        assert len(runs)>3,(serial,'No measured wall strips')
        colors=[p[:3] for p in clean.getdata() if p[3]>128 and sum(p[:3])>90]
        rgb=[sum(p[i] for p in colors)/len(colors)/255 for i in range(3)]
        rows[str(serial)]={'serial':serial,'kit':'native_broken_wall','pack':g['pack'],'row':g['row'],'origin':g['origin'],'footprint':g['footprint'],'size':list(original.size),'visible':list(clean.getbbox()),'source_rgba_sha256':digest,'axis':axis,'plane':plane,'depth':depth,'strips':runs,'source_mean_rgb':rgb,'removed_ground_shadow_pixels':len(shadow)}
        png(f'{serial}.png',original);png(f'{serial}-front.png',clean);png(f'{serial}-ground.png',ground)
    result['data.json']=(json.dumps({'schema':1,'graphics':rows,'status':'Private source/reverse candidates; no runtime dispatch.','reuse':['Existing Tina measured native-wall source-foot contract','Existing Coastal closed quads and independent back material','Existing Tina ruin-stone tile; alpha contours preserve original arch holes'],'inferred':['Hidden1.0/1.2mwall depth and the corresponding half-depth front plane are source-footprint-bounded reconstruction.','Two-pixel native strip sampling reconstructs broken crests and existing openings; no doorway trigger or walk route is added.','Native floor-fringe pixels stay a flat ground overlay. Original map walking and collision remain unchanged.'],'scope':'Exact20native broken-wall/arch forms only; circular basin11708and horizontal fluted columns11714/15require separate compatible round parts.'},indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload:bad.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            if not path.exists() or path.read_bytes()!=payload:path.write_bytes(payload)
    if bad:raise SystemExit('Stale native broken-wall candidates: '+','.join(bad))
    print(('Verified' if args.check else 'Prepared')+'20native broken-wall/arch candidates; originals unchanged.')


if __name__=='__main__':main()
