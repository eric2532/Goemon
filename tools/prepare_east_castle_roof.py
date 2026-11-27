"""Pin native castle coping materials and classify observed roof-tier paint; no masters edited."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/castle_roof/data.json'


def products():
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())['beast_castle']
    text=(ROOT/'assets/maps/original_crossgate/beast-sculptures.gd').read_text()
    native=Image.open(ROOT/'assets/maps/original_crossgate/beast-castle.png').convert('RGBA')
    vertical=math.sqrt(2*((32/3)**2-8**2));bands=[]
    def point(pixel,height):
        u=(pixel[0]-catalog['origin'][0])/(32/3);v=(pixel[1]-catalog['origin'][1]+height*vertical)/8
        return ((u-v)/2,height,(u+v)/2)
    for kind,name in [('canopy','CASTLE_CANOPY'),('hall','CASTLE_HALL')]:
        rows=json.loads(re.search(r'^const '+name+r'=(.*)$',text,re.M).group(1))
        if kind=='hall':rows=rows[1:]
        for low,high in zip(rows,rows[1:]):
            colors=[]
            for side in range(4):
                p=[low['pixels'][side],high['pixels'][side],high['pixels'][(side+1)%4],low['pixels'][(side+1)%4]]
                a,b,c=[point(q,h)for q,h in [(p[0],low['height']),(p[1],high['height']),(p[2],high['height'])]]
                normal=((c[1]-a[1])*(b[2]-a[2])-(c[2]-a[2])*(b[1]-a[1]),(c[2]-a[2])*(b[0]-a[0])-(c[0]-a[0])*(b[2]-a[2]),(c[0]-a[0])*(b[1]-a[1])-(c[1]-a[1])*(b[0]-a[0]))
                center=[sum(point(q,low['height'])[j]for q in low['pixels'])/4 for j in [0,2]]
                outward=((a[0]+c[0])/2-center[0],0,(a[2]+c[2])/2-center[1])
                if sum(x*y for x,y in zip(normal,outward))<0:normal=tuple(-v for v in normal)
                if -normal[0]+1.603567*normal[1]+normal[2]<=0:continue
                mask=Image.new('L',native.size);ImageDraw.Draw(mask).polygon([tuple(q)for q in p],fill=255)
                colors.extend(px[:3]for px,m in zip(native.getdata(),mask.getdata())if m and px[3]>128)
            assert colors,(kind,low['height'])
            blue=sum(r<b*.86 and b>g*.94 for r,g,b in colors)/len(colors)
            bands.append({'kind':kind,'low':low['height'],'high':high['height'],'back_part':'blue_roof' if blue>.35 else 'plaster','observed_blue_fraction':blue,'observed_mean_rgb':[sum(p[i]for p in colors)/len(colors) for i in range(3)]})
    paths=['scripts/forest/forest_beast_castle.gd','assets/maps/original_crossgate/beast-castle.png','assets/maps/original_crossgate/beast-castle-sculpture-surfaces.png','assets/maps/original_crossgate/beast-sculptures.gd']
    data={'schema':1,'canonical_owner_y':.045*vertical,'source_door_height_pixels':90,'canonical_door_height_local':4.05,'native_canvas_rgba_sha256':hashlib.sha256(native.tobytes()).hexdigest(),'bands':bands,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'inferred':['Unobserved roof faces continue independent existing native coping/plaster paint at fixed1.8m pitch.','All source71tuples and XZ vertices remain exact. Only the East derivative receives the canonical.045pixel-height owner conversion once; Source400/West master is unchanged.'],'scope':'Only the exact31954BeastCastle derivative, never a shared-master mutation.'}
    return (json.dumps(data,indent=2)+'\n').encode()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();payload=products()
    if args.check:assert OUT.exists()and OUT.read_bytes()==payload,'Stale private castle roof/material pins'
    else:
        OUT.parent.mkdir(parents=True,exist_ok=True)
        if not OUT.exists()or OUT.read_bytes()!=payload:OUT.write_bytes(payload)
    print(('Verified'if args.check else'Prepared')+'isolated East castle roof/material contract; masters untouched.')


if __name__=='__main__':main()
