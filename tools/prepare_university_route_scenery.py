"""Source-only placement scope for the locked Jenova–university corridor."""
import hashlib
import json
import sys
from review_jenova_university_route import ROOT, OUT, review

DEST=ROOT/'assets/maps/falan/university_route'


def prepare():
    plan=json.loads((OUT/'route.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    lookup=review.lib.serial_index();maps={};graphics={}
    for stage in plan['stages']:
        data=review.decode(stage['source'],catalog);w,h=data['width'],data['height']
        near={(x+dx,y+dy) for x,y in stage['path'] for dx in range(-24,25) for dy in range(-24,25)}
        placements=[];spans=[]
        for y in sorted({y for x,y in near if 0<=y<h}):
            xs=sorted(x for x,z in near if z==y and 0<=x<w)
            if not xs:continue
            start=last=xs[0]
            for x in xs[1:]+[xs[-1]+2]:
                if x>last+1:spans.append([y,start,last]);start=x
                last=x
        for x,y in sorted(near):
            if not(0<=x<w and 0<=y<h):continue
            serial=data['objects'][y*w+x]
            if serial<1000 or serial not in lookup:continue
            placements.append([x,y,serial])
            if str(serial) in graphics:continue
            g=lookup[serial];im=review.lib.image_from_record(g['pack'],g['row'])
            mask=im.getchannel('A').point(lambda a:255 if a>=128 else 0)
            for yy in range(im.height):
                for xx in range(im.width):
                    p=im.getpixel((xx,yy))
                    if max(p[:3])<=45 or p[:3]==(71,71,71):mask.putpixel((xx,yy),0)
            bounds=mask.getbbox()
            if not bounds:continue
            graphics[str(serial)]=dict(bounds=list(bounds),origin=[g['x'],g['y']],
                rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
        maps[str(stage['source'])]=dict(spans=spans,placements=placements,
            client_sha256=stage['client_sha256'],planes_sha256=stage['rendered_planes_sha256'])
    return dict(schema=1,maps=maps,graphics=graphics,
        scope='Locked route plus 24 native tiles; presentation only. Original walk masks, NPCs and warps remain authoritative.')


if __name__=='__main__':
    result=prepare();text=json.dumps(result,separators=(',',':'))+'\n'
    if '--check' in sys.argv:assert (DEST/'scenery.json').read_text()==text
    else:
        DEST.mkdir(parents=True,exist_ok=True);(DEST/'scenery.json').write_text(text)
    print('PASS:',len(result['maps']),'native route scopes;',len(result['graphics']),'source-identified graphics')
