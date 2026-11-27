"""Source-anchored visual scope supplement; no new placements or gameplay data."""
import hashlib
import json
import sys
from PIL import Image, ImageFilter, ImageEnhance
import review_snow_region as region

ROOT=region.ROOT
DEST=ROOT/'assets/maps/falan/snow_region'


def remember(serial,catalog,graphics,pages):
    g=catalog['graphics'][str(serial)]
    if g['page'] not in pages:pages[g['page']]=Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]).convert('RGBA')
    a,b,ww,hh=g['rect'];im=pages[g['page']].crop((a,b,a+ww,b+hh))
    assert hashlib.sha256(im.tobytes()).hexdigest()==g['rgba_sha256'],serial
    mask=im.getchannel('A').point(lambda a:255 if a>=128 else 0)
    pixels=im.load();alpha=mask.load()
    for yy in range(im.height):
        for xx in range(im.width):
            if max(pixels[xx,yy][:3])<=45 or pixels[xx,yy][:3]==(71,71,71):alpha[xx,yy]=0
    bounds=mask.getbbox()
    if bounds:
        opaque=[p[:3] for p in im.getdata() if p[3]>=128 and max(p[:3])>55 and p[:3]!=(71,71,71)]
        colored=[p for p in opaque if max(p)-min(p)>25 and min(p)<150]
        samples=colored or opaque
        color=[round(sum(p[c] for p in samples)/len(samples)/255,4) for c in range(3)]
        snow=sum(min(p)>175 and max(p)-min(p)<40 for p in opaque)/len(opaque)
        graphics[str(serial)]=dict(bounds=list(bounds),origin=g['origin'],rgba_sha256=g['rgba_sha256'],color=color,snow_fraction=round(snow,4))


def prepare():
    plan=json.loads((region.OUT/'boundary.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    maps={};graphics={};pages={}
    previous=json.loads((ROOT/'assets/maps/falan/university_route/scenery.json').read_text())
    for serial in previous['graphics']:remember(int(serial),catalog,graphics,pages)
    for stage in plan['stages']:
        number=stage['source']
        if number is None or number in [14000,14001,14002]:continue
        data=region.source.decode(number,catalog);w,h=data['width'],data['height']
        # These sectors are all reached from the unchanged entrances. Include nearby
        # silhouettes, while stopping at the existing map crop and local road boundary.
        near=set()
        for sector in stage['sectors']:
            _,_,sx,sy=sector['key'].split('-')
            sx,sy=int(sx)*20,int(sy)*20
            near.update((x,y) for y in range(sy-8,sy+28) for x in range(sx-8,sx+28))
        x0,y0,bw,bh=stage['bounds']
        near={(x,y) for x,y in near if x0<=x<x0+bw and y0<=y<y0+bh}
        spans=[]
        for y in sorted({y for x,y in near}):
            xs=sorted(x for x,z in near if z==y);start=last=xs[0]
            for x in xs[1:]+[xs[-1]+2]:
                if x>last+1:spans.append([y,start,last]);start=x
                last=x
        placements=[]
        for x,y in sorted(near):
            serial=data['objects'][y*w+x]
            if serial<1000:continue
            placements.append([x,y,serial])
            if str(serial) in graphics:continue
            remember(serial,catalog,graphics,pages)
        maps[str(number)]=dict(spans=spans,placements=placements,client_sha256=stage['client_sha256'])
    return dict(schema=1,maps=maps,graphics=graphics,
                scope='All reachable snow-region sectors plus eight source cells of visible scenery; current map crops and travel remain authoritative.')


def surfaces(check=False):
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    floors=set()
    for number,_,_,_ in region.MAPS:
        if number is not None:floors.update(s for s in region.source.decode(number,catalog)['floor'] if s>=1000)
    # Generated mountain snow uses the same native floor family.
    floors.update([8174,8175,8176,8177])
    floors=sorted(s for s in floors if str(s) in catalog['graphics'] and catalog['graphics'][str(s)]['rect'][2:]==[64,47])
    atlas=Image.new('RGBA',(16*80,((len(floors)+15)//16)*64));records={};pages={}
    for i,s in enumerate(floors):
        g=catalog['graphics'][str(s)]
        if g['page'] not in pages:pages[g['page']]=Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]).convert('RGBA')
        a,b,w,h=g['rect'];tile=pages[g['page']].crop((a,b,a+w,b+h))
        assert hashlib.sha256(tile.tobytes()).hexdigest()==g['rgba_sha256']
        # Extend diamond edge colour for filtered 3D sampling, as the existing
        # village ground preparers do; mesh footprints remain the original tiles.
        for yy in range(h):
            occupied=[xx for xx in range(w) if tile.getpixel((xx,yy))[3]>127]
            if not occupied:continue
            for xx in range(w):tile.putpixel((xx,yy),tile.getpixel((min(occupied[-1],max(occupied[0],xx)),yy))[:3]+(255,))
        for yy in range(h):
            if tile.getpixel((32,yy))[3]:continue
            row=min((r for r in range(h) if tile.getpixel((32,r))[3]),key=lambda r:abs(r-yy))
            tile.paste(tile.crop((0,row,w,row+1)),(0,yy))
        # Preserve native coverage/colour boundaries, remove magnified palette dithering.
        rgb=ImageEnhance.Color(tile.convert('RGB').filter(ImageFilter.GaussianBlur(.8))).enhance(.85)
        rgb.putalpha(tile.getchannel('A'))
        x,y=i%16*80+8,i//16*64+8
        atlas.paste(rgb,(x,y))
        for yy in range(-8,55):
            for xx in range(-8,72):
                p=(min(63,max(0,xx)),min(46,max(0,yy)))
                atlas.putpixel((x+xx,y+yy),rgb.getpixel(p))
        records[str(s)]=dict(rect=[x,y,64,47],source_rgba_sha256=g['rgba_sha256'])
    earth_mask=Image.new('L',atlas.size)
    for serial,record in records.items():
        if not 8000<=int(serial)<10000:continue
        x,y,w,h=record['rect'];earth_mask.paste(255,(x-8,y-8,x+w+8,y+h+8))
    if check:assert Image.open(DEST/'earth-mask.png').tobytes()==earth_mask.tobytes()
    else:earth_mask.save(DEST/'earth-mask.png')
    cliff_path=ROOT/'assets/maps/original_crossgate/cliff-paint.png' 
    cliff=ImageEnhance.Color(Image.open(cliff_path).convert('RGB').filter(ImageFilter.GaussianBlur(1.3))).enhance(.55)
    manifest=dict(floors=records,cliff_source_sha256=region.digest(cliff_path),
                  floor_pixels_sha256=hashlib.sha256(atlas.tobytes()).hexdigest(),cliff_pixels_sha256=hashlib.sha256(cliff.tobytes()).hexdigest())
    if check:
        assert json.loads((DEST/'surfaces.json').read_text())==manifest
        for name,im in [('ground.png',atlas),('cliff-paint.png',cliff)]:
            assert Image.open(DEST/name).tobytes()==im.tobytes(),name
    else:
        atlas.save(DEST/'ground.png');cliff.save(DEST/'cliff-paint.png')
        (DEST/'surfaces.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')


if __name__=='__main__':
    text=json.dumps(prepare(),separators=(',',':'))+'\n'
    if '--check' in sys.argv:assert (DEST/'scenery.json').read_text()==text
    else:
        DEST.mkdir(parents=True,exist_ok=True);(DEST/'scenery.json').write_text(text)
    surfaces('--check' in sys.argv)
    print('PASS snow region source graphics, placements and bounded scenery')
