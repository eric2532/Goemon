"""Assemble Kazi's prepared motion with fixed approved head artwork, offline."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics

from PIL import Image, ImageFilter, ImageOps

import prepare_crossgate_kazi_hd as hd

WORK = hd.WORK / 'revisions/fixed-design-final'
RUN_ORDER = list(range(9))+list(range(13,18))+list(range(9,13))


def cells(image, job):
    return [image.crop((i % job['cols']*image.width//job['cols'],
                        i//job['cols']*image.height//job['rows'],
                        (i % job['cols']+1)*image.width//job['cols'],
                        (i//job['cols']+1)*image.height//job['rows']))
            for i in range(job['frames'])]


def clean_marking(image):
    """Replace olive face pigment from nearby existing skin; keep all other pixels."""
    out = image.copy()
    pixels, target = image.load(), out.load()
    marked = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a > 200 and g-b >= 10 and ((g >= r and max(r,g,b)>35) or (g-r >= -8 and max(r,g,b)>65)):
                marked.append((x, y))
    if not marked:
        return out, 0
    border=set(marked)
    for x,y in marked:
        for yy in range(max(0,y-1),min(image.height,y+2)):
            for xx in range(max(0,x-1),min(image.width,x+2)):
                r,g,b,a=pixels[xx,yy]
                if a>200 and max(r,g,b)>80 and r>=g>=b and r-b>15:border.add((xx,yy))
    marked=list(border)
    for x, y in marked:
        nearby = []
        for radius in (6, 12, 24, 48, 96):
            for yy in range(max(0,y-radius),min(image.height,y+radius+1),max(1,radius//6)):
                for xx in range(max(0,x-radius),min(image.width,x+radius+1),max(1,radius//6)):
                    r, g, b, a = pixels[xx, yy]
                    if a > 220 and r-g > 8 and g-b > 5 and r > 105:
                        nearby.append(((xx-x)**2+(yy-y)**2,(r,g,b)))
            if nearby:
                break
        if nearby:
            nearby=sorted(nearby)[:8]
            weight=sum(1/(distance+1) for distance,rgb in nearby)
            rgb=tuple(round(sum(rgb[channel]/(distance+1) for distance,rgb in nearby)/weight) for channel in range(3))
            target[x, y] = (*rgb, pixels[x,y][3])
    return out, sum(out.getpixel(p) != image.getpixel(p) for p in marked)


def head_layer(cell, height):
    region = cell.crop((0,0,cell.width,round(cell.height*.52)))
    points = set()
    for y in range(region.height):
        for x in range(region.width):
            r,g,b,a = region.getpixel((x,y))
            if a >= 100 and max(r,g,b)<185 and (max(r,g,b)-min(r,g,b)<40 or b <= min(r,g)*1.12):
                points.add((x,y))
    groups=[]
    while points:
        stack=[points.pop()];group=[]
        while stack:
            x,y=stack.pop();group.append((x,y))
            for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if p in points:
                    points.remove(p);stack.append(p)
        groups.append(group)
    group=max(groups,key=len)
    top=min(y for x,y in group)
    cut=min(cell.height,top+round(height*.34))
    region=cell.crop((0,top,cell.width,cut))
    seed=min(group,key=lambda p:p[1])
    points={(seed[0],seed[1]-top)}
    stack=list(points)
    while stack:
        x,y=stack.pop()
        for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            xx,yy=p
            if 0<=xx<region.width and 0<=yy<region.height and p not in points and region.getpixel(p)[3]>=12:
                points.add(p);stack.append(p)
    group=list(points)
    mask=Image.new('L',region.size)
    for p in group:mask.putpixel(p,255)
    mask=mask.filter(ImageFilter.MaxFilter(5))
    alpha=region.getchannel('A')
    for y in range(region.height):
        for x in range(region.width):
            if not mask.getpixel((x,y)):alpha.putpixel((x,y),0)
    region.putalpha(alpha)
    bottom=[x for x,y in group if region.height*.78<=y<=region.height*.88]
    neck=statistics.median(bottom) if bottom else statistics.median(x for x,y in group)
    return region,mask,top,neck


def violet_layer(image):
    mask=Image.new('L',image.size)
    for y in range(image.height):
        for x in range(image.width):
            r,g,b,a=image.getpixel((x,y))
            if a and b-g>25 and b>g*1.25 and b>=r*.95:mask.putpixel((x,y),255)
    near=mask.filter(ImageFilter.MaxFilter(11))
    result=image.copy();alpha=result.getchannel('A')
    for y in range(image.height):
        for x in range(image.width):
            r,g,b,a=image.getpixel((x,y))
            if not mask.getpixel((x,y)) and not (min(r,g,b)>180 and near.getpixel((x,y))):alpha.putpixel((x,y),0)
    result.putalpha(alpha)
    return result


def lock_head(cell, reference, reference_height, clip_height, attack=False):
    old,mask,top,neck=head_layer(cell,clip_height)
    source,_,_,source_neck=head_layer(reference,reference_height)
    scale=clip_height/reference_height
    source=source.resize((round(source.width*scale),round(source.height*scale)),Image.Resampling.LANCZOS)
    result=cell.copy()
    cut=top+old.height
    effect=violet_layer(cell.crop((0,0,cell.width,cut))) if attack else None
    result.paste((0,0,0,0),(0,0,cell.width,cut-3))
    if effect is not None:result.alpha_composite(effect)
    else:
        sparks=violet_layer(reference.crop((0,0,reference.width,head_layer(reference,reference_height)[2]+round(reference_height*.34))))
        sparks=sparks.resize((round(sparks.width*scale),round(sparks.height*scale)),Image.Resampling.LANCZOS)
        result.alpha_composite(sparks,(round(neck-source_neck*scale),cut-sparks.height))
    x=round(neck-source_neck*scale)
    y=top+old.height-source.height
    result.alpha_composite(source,(x,y))
    return result


def motion_master(job):
    token=job['token']
    if job['action'] not in (3,5):return Path(job['target'])
    revision=('iai-left-hip-v5' if token=='5-7' else
              'iai-left-hip-v4' if token in ('3-0','5-1') else
              'iai-left-hip-v2' if token in ('3-3','3-5','3-7','5-3','5-5') else
              'iai-left-hip-v3')
    return hd.WORK/'revisions'/revision/'masters'/f'{token}.png'


def prepare(tokens=None):
    WORK.mkdir(parents=True,exist_ok=True)
    (WORK/'masters').mkdir(exist_ok=True)
    active=json.loads((hd.WORK/'jobs.json').read_text())
    refs={}
    for direction in range(8):
        job=next(j for j in active if j['action']==0 and j['direction']==direction)
        cell=cells(Image.open(job['target']).convert('RGBA'),job)[0]
        if direction in (3,7):
            cell=Image.open(hd.WORK/'revisions/iai-left-hip/references/preferred-slash-proportions.png').convert('RGBA')
            if direction==7:cell=ImageOps.mirror(cell)
        cell,_=clean_marking(cell)
        bounds=hd.body_bounds(cell)
        refs[direction]=(cell,bounds[3]-bounds[1])
    jobs=[]
    for job in active:
        j=dict(job)
        path=motion_master(job)
        target=WORK/'masters'/f'{job["token"]}.png'
        j['target']=str(target)
        jobs.append(j)
        if tokens and job['token'] not in tokens:continue
        if target.exists():
            saved=json.loads(target.with_suffix('.json').read_text())
            assert saved['source_sha256']==hd.sha(path) and saved['preparer_sha256']==hd.sha(Path(__file__)),f'Stale prepared master: {target}'
            continue
        assert not target.exists(),f'Preserve existing master: {target}'
        image=Image.open(path).convert('RGBA')
        frames=cells(image,job)
        if job['action']==3:frames=[frames[i] for i in RUN_ORDER]
        heights=[hd.body_bounds(c)[3]-hd.body_bounds(c)[1] for c in frames]
        height=heights[0] if job['action']==5 else statistics.median(heights)
        result=Image.new('RGBA',image.size)
        changed=0
        for i,cell in enumerate(frames):
            cell,n=clean_marking(cell);changed+=n
            if job['action'] in (0,1,3,5):
                reference,ref_height=refs[job['direction']]
                cell=lock_head(cell,reference,ref_height,height,job['action']==5)
            result.alpha_composite(cell,(i%job['cols']*image.width//job['cols'],i//job['cols']*image.height//job['rows']))
        result.save(target)
        meta=dict(source=str(path),source_sha256=hd.sha(path),approved_head_direction=job['direction'],
                  removed_marking_pixels=changed,sha256=hd.sha(target),
                  preparer_sha256=hd.sha(Path(__file__)),source_frame_order=RUN_ORDER if job['action']==3 else list(range(job['frames'])),
                  method='Fixed approved head layer, uniform clip scale, existing skin palette; no new image generation')
        target.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
        print(job['token'],flush=True)
    identity=WORK/'identity-long-blade.png'
    if not identity.exists():
        clean,_=clean_marking(Image.open(hd.WORK/'identity-long-blade.png').convert('RGBA'))
        clean.save(identity)
    for job in jobs:job['identity']=str(identity)
    (WORK/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tokens',nargs='*')
    args=parser.parse_args()
    prepare(args.tokens)
