"""Bounded, unmodified native PG0 / PG0+PG1 reference; never writes game art."""
import argparse,hashlib,json,math
from pathlib import Path
from PIL import Image,ImageDraw
from review_east_backgrounds import Native,decode,ROOT,OUT,CATALOG

def render(mapid,x,y,name=None):
    catalog=json.loads(CATALOG.read_text());row=catalog['maps'][f'BlueCrossgate/map/0/{mapid}.dat']
    w,h,raw,values,bits,aliases=decode(row);n=w*h;native=Native();u=(x+y)*32;v=(y-x+w)*24
    box=(u-550,v-650,u+550,v+350);background=Image.new('RGBA',(1100,1000),(20,24,22,255));objects=[];records=[]
    for yy in range(max(0,y-28),min(h,y+29)):
        for xx in range(max(0,x-28),min(w,x+29)):
            i=yy*w+xx
            for layer in [0,1]:
                rawserial=int(values[layer*n+i]);serial=aliases.get(rawserial,rawserial)
                if serial<1000 or serial not in native.table:continue
                g=native.table[serial][0];px=(xx+yy)*32+g['origin'][0]-box[0];py=(yy-xx+w)*24+g['origin'][1]-box[1]
                gw,gh=g['rect'][2:]
                if px+gw<=0 or py+gh<=0 or px>=1100 or py>=1000:continue
                entry=dict(layer=layer,cell=[xx,yy],native_graphic=rawserial,graphic=serial,origin=g['origin'],footprint=g['footprint'],source_rgba_sha256=g['rgba_sha256'],native_open=bool(bits[i>>3]&(1<<(i&7))))
                records.append(entry)
                if layer:objects.append((yy*11-xx*9,xx+yy,i,serial,px,py))
                else:background.alpha_composite(native.crop(serial),(px,py))
    combined=background.copy()
    for depth,sort_u,i,serial,px,py in sorted(objects):combined.alpha_composite(native.crop(serial),(px,py))
    label=name or f'{mapid}-{x}-{y}'
    for suffix,im in [('bg',background),('both',combined)]:im.save(OUT/f'{label}-{suffix}.png')
    pair=Image.new('RGB',(2200,1040),(24,28,30));pair.paste(background.convert('RGB'),(0,40));pair.paste(combined.convert('RGB'),(1100,40));draw=ImageDraw.Draw(pair)
    draw.text((10,12),f'{mapid} cell{x},{y} | LEFT native PG0 | RIGHT native PG0+PG1 | original pixels, black matte',fill='white');pair.save(OUT/f'{label}-layers.jpg',quality=94)
    proof=dict(map=mapid,cell=[x,y],title=row['title'],native_pixel_bounds=box,source_raw_sha256=hashlib.sha256(raw).hexdigest(),catalog_sha256=hashlib.sha256(CATALOG.read_bytes()).hexdigest(),source_catalogs=native.pins,drawings=records,limits='Original source RGBA and anchors, bounded local view only; source raster reference is not 3D or camera acceptance. PG1 uses the recorded source depth order approximation; PG0 is unmodified cell order.')
    (OUT/f'{label}-proof.json').write_text(json.dumps(proof,indent=2));print(label,len(records),flush=True)
    return proof

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('map',type=int);p.add_argument('x',type=int);p.add_argument('y',type=int);p.add_argument('--name');a=p.parse_args();render(a.map,a.x,a.y,a.name)
