"""Source anchors and native paint for ten Komatei ruin sections; originals are read-only."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/ruin_sections'
IDS=(*range(1233270,1233276),*range(1233279,1233283))


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
    result={};graphics={};images={}
    for serial in IDS:
        g=catalog['graphics'][str(serial)]
        with lib.connection() as db:
            native=dict(db.execute('SELECT x,y,w,h,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']],('native source placement metadata',serial)
        image=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        digest=hashlib.sha256(image.tobytes()).hexdigest()
        assert digest==g['rgba_sha256'],(serial,digest)
        images[serial]=image;stream=io.BytesIO();image.save(stream,format='PNG',optimize=True)
        result[f'{serial}.png']=stream.getvalue()
        row={key:g[key] for key in ['pack','row','origin','footprint']}
        row.update(size=list(image.size),source_rgba_sha256=digest)
        if serial in (1233270,1233273,1233274,1233275):
            row.update(form='turret',x=[0,6],z=[-6,0],depth=.70,deck=8.05,
                       windows=[{'face':'west','center':-3.25,'width':.83,'bottom':5.0,'height':2.65},
                                {'face':'south','center':3.80,'width':.83,'bottom':4.15,'height':2.70}])
            # Native source cap anchors: the visible front rim is below the rear silhouette.
            # Preserve the literal source-camera height at every anchor instead of box-fitting.
            ox,oy=-g['origin'][0],-g['origin'][1]
            row['rims']={
                'west':[[ox-64,oy-242],[ox-54,oy-251],[ox-44,oy-236],[ox-34,oy-244],[ox-24,oy-225],[ox-14,oy-234],[ox-5,oy-218],[ox,oy-225]],
                'south':[[ox,oy-225],[ox+10,oy-238],[ox+20,oy-229],[ox+30,oy-246],[ox+40,oy-240],[ox+50,oy-256],[ox+59,oy-247],[ox+64,oy-252]],
                'north':[[ox-64,oy-250],[ox-54,oy-264],[ox-44,oy-257],[ox-34,oy-279],[ox-24,oy-271],[ox-14,oy-291],[ox-5,oy-281],[ox,oy-294]],
                'east':[[ox+64,oy-252],[ox+54,oy-266],[ox+44,oy-257],[ox+34,oy-279],[ox+24,oy-272],[ox+14,oy-291],[ox+5,oy-282],[ox,oy-294]]}
        elif serial in (1233271,1233272):
            along_x=serial==1233271
            row.update(form='wall',axis='x' if along_x else 'z',plane=1.30 if along_x else -.60,
                       extent=[-1.25,7.40] if along_x else [-6.55,1.85],depth=.85,cap_depth=3.8,cap_bottom=6.8,
                       windows=[{'center':2.50 if along_x else -3.20,'width':.88,'bottom':3.10,'height':2.80}])
            row['rim']=[[45,88],[54,72],[64,81],[73,58],[82,65],[92,43],[102,51],[112,30],[121,38],[131,18],[139,25]] if along_x else [[20,24],[29,34],[39,21],[48,43],[58,37],[68,58],[78,50],[88,72],[98,64],[108,84]]
        else:
            # Source origins put these decks above the ground. Their1x1 walk ownership is retained.
            row.update(form='deck',height=8.25,depth=2.5)
            row['polygon']=[[14,81],[101,18],[184,82],[99,145]] if serial in (1233279,1233281) else [[13,81],[101,18],[137,45],[99,72],[99,145],[52,111]] if serial==1233280 else [[14,81],[52,53],[99,88],[146,53],[184,82],[99,145]]
        graphics[str(serial)]=row
    # Compatible existing stone/floor textures are resampled from the actual native ruin art.
    samples={'stone':(1233270,((22,177),(40,191),(40,232),(22,218))),'cap':(1233270,(30,58,43,68)),'floor':(1233279,(65,61,88,84))}
    atlas=Image.new('RGBA',(384,128))
    for i,(name,(serial,rect)) in enumerate(samples.items()):
        if name=='stone':
            ul,ur,lr,ll=rect
            patch=images[serial].transform((112,112),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
        else:patch=images[serial].crop(rect).resize((112,112),Image.Resampling.BICUBIC)
        assert patch.getchannel('A').getextrema()==(255,255),name
        for axis in (0,1):
            original=patch.copy()
            for along in range(112):
                for edge in range(8):
                    for side in (edge,111-edge):
                        p=(side,along) if axis==0 else (along,side);q=(111-side,along) if axis==0 else(along,111-side)
                        a=original.getpixel(p);b=original.getpixel(q);t=(8-edge)/16
                        patch.putpixel(p,tuple(round(a[k]*(1-t)+b[k]*t) for k in range(4)))
        for y in range(128):
            for x in range(128):atlas.putpixel((i*128+x,y),patch.getpixel((min(111,max(0,x-8)),min(111,max(0,y-8)))))
    stream=io.BytesIO();atlas.save(stream,format='PNG',optimize=True);result['surfaces.png']=stream.getvalue()
    data={'schema':1,'graphics':graphics,'tile_samples':samples,
          'reuse':['Tina wall_mesh native source-foot/profile and independently tiled edge contract','Shapes.extrude closed modular stone sections','Existing native stone/cap/floor paint; original masters untouched'],
          'inferred':['Hidden wall depth and rear stone paint','Source-visible slender window recesses opened in render geometry only; native collision/routes unchanged','Rear rim depth and hidden deck underside','Broken crest depth and internal platform supports reconstructed from one source view']}
    result['data.json']=(json.dumps(data,indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload:bad.append(name)
        else:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(payload)
    if bad:raise SystemExit('Stale native ruin derivatives: '+','.join(bad))
    print(('Verified' if args.check else 'Prepared')+'10 native Komatei ruin sections; originals unchanged.')


if __name__=='__main__':main()
