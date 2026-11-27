"""Native post/lamp/weather-vane candidates using existing round and lamp masters."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/posts'
IDS=[10419,10424,10429,10707,10709,10712,10713,10715,10718,10719,10720,10721]


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from recover_venoa_walls import native_without_ground_shadow
    catalog={}
    for path in ['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json','assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
        catalog.update(json.loads((ROOT/path).read_text())['graphics'])
    results={};graphics={}
    def png(name,image):
        stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
    for serial in IDS:
        g=catalog[str(serial)]
        with lib.connection() as db:
            native=dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']]
        original=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256']
        clean,shadow=native_without_ground_shadow(original)
        cut=0
        if serial>=10700:
            broad=[y for y in range(round(clean.height*.42)) if sum(clean.getpixel((x,y))[3]>128 for x in range(clean.width))>=8]
            cut=max(broad)+2
        floor=min(clean.height-1,-g['origin'][1]);levels=[]
        for y in sorted(set([cut,floor]+list(range(cut,floor+1,2))),reverse=True):
            xs=[x for dy in [-1,0,1] if 0<=y+dy<clean.height for x in range(clean.width) if clean.getpixel((x,y+dy))[3]>128]
            if xs:levels.append([round(max(.035,(max(xs)-min(xs)+1)/(2*2**.5*(32/3))),6),round((floor-y)*.045,6)])
        xs=[x for x in range(clean.width) if clean.getpixel((x,floor))[3]>128]
        center=((sum(xs)/len(xs) if xs else -g['origin'][0])+g['origin'][0])/(2*(32/3))
        runs=[]
        for y in range(cut):
            start=None
            for x in range(clean.width+1):
                opaque=x<clean.width and clean.getpixel((x,y))[3]>128
                if opaque and start is None:start=x
                elif not opaque and start is not None:runs.append([start,x,y]);start=None
        candidates=[]
        for y in range(max(cut+2,round(clean.height*.45)),min(clean.height-6,round(clean.height*.8))):
            for x in range(clean.width-2):
                crop=clean.crop((x,y,x+2,y+6))
                if min(p[3] for p in crop.getdata())<255:continue
                candidates.append((abs((x+1)/clean.width-.5)+abs((y+3)/clean.height-.65),(x,y,x+2,y+6)))
        assert candidates,serial
        _,rect=min(candidates);atlas=clean.crop(rect).resize((128,128),Image.Resampling.BICUBIC)
        row={'serial':serial,'kit':'native_post','style':'whole_lamp' if serial in [10424,10429] else 'measured_post',
             'size':list(original.size),'origin':g['origin'],'footprint':g['footprint'],'source_rgba_sha256':digest,'pack':g['pack'],'row':g['row'],
             'visible':list(clean.getbbox()),'removed_ground_shadow_pixels':len(shadow),'profile':levels,'center':[center,center],
             'ornament_cut_y':cut,'ornament_runs':runs,'native_material_sample':list(rect),'metal_rgb':[sum(pixel[i] for pixel in clean.crop(rect).getdata())/(12*255) for i in range(3)]}
        graphics[str(serial)]=row;png(f'{serial}.png',original);png(f'{serial}-front.png',clean);png(f'{serial}-surfaces.png',atlas)
    results['data.json']=(json.dumps({'schema':1,'graphics':graphics,'status':'Candidate source-only, no runtime dispatch.',
        'inferred':['Native shaft/base silhouette, weather-vane outline/holes, lamp count and source anchor are observed.',
                    '10424/10429reuse complete compatible Falan lamp masters. Other shafts use the existing16-sided coastal ring part.',
                    'Unseen post circumference and metal-vane plate thickness are reconstructed. Hidden metal uses the existing Falan lamp metal shader with measured native sample mean color; the tiny native patch is not enlarged across the back.',
                    'Weather-vane row runs form closed thin metal with native holes; they are not opaque rectangular cards.'],
        'scope':'Exact12 original post/lamp graphics only; no placement/collision/route changes.'},indent=2)+'\n').encode()
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
    if bad:raise SystemExit('Stale native post candidates: '+','.join(bad))
    print(('Verified' if args.check else 'Prepared')+'12 native post/lamp candidates; originals unchanged.')


if __name__=='__main__':main()
