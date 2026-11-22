"""Audit the shared body attachments and render the recovered wardrobe cross product."""
import argparse
import json
import math
import struct
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

import prepare_crossgate_cosmetics as prep

ROOT=prep.ROOT
OUT=ROOT/'build/Other Files/Asset Toolkit/Sponsor Cosmetics/Alignment Review'


def anchors(folder=prep.OUT):
    tables=json.loads((folder/'anchors.json').read_text());raw=(folder/'anchors.bin').read_bytes()
    return {key:{(x,y):(hx/4,hy/4) for x,y,hx,hy in struct.iter_unpack('<HHhh',raw[at:at+n*8])} for key,(at,n) in tables.items()}


def attachment(points,folder,manifest,frame):
    route='res://'+str(prep.texture_path(folder,manifest,int(frame[0])).relative_to(ROOT))
    return points[route][tuple(frame[1:3])]


def composite(folder,manifest,frame,point,item,pose,pages):
    body=prep.frame_image(folder,manifest,frame)
    action,body_direction=map(int,pose.split(':')[-2:]);direction=0 if item['fixed_facing'] else body_direction
    clip=item['clips'].get(f'{action}:{direction}',item['clips'].get(f'0:{direction}'))
    layers=[(body,frame[5],frame[6])]
    if clip:
        f=clip['frames'][len(clip['frames'])//2]
        image=pages[f[0]].crop((f[1],f[2],f[1]+f[3],f[2]+f[4]))
        costume=(image,round(point[0]+frame[5]+f[5]),round(point[1]+frame[6]+f[6]))
        layers.insert(0 if item['kind']=='wings' and body_direction not in [0,1,2] else 1,costume)
    left=min(x for _,x,y in layers);top=min(y for _,x,y in layers)
    right=max(x+image.width for image,x,y in layers);bottom=max(y+image.height for image,x,y in layers)
    canvas=Image.new('RGBA',(right-left,bottom-top))
    for image,x,y in layers:canvas.alpha_composite(image,(x-left,y-top))
    return canvas


def render_wardrobe(records,points,catalog,reactions=False):
    pages=[Image.open(prep.OUT/f'atlas-{i}.png').convert('RGBA') for i in range(catalog['pages'])]
    marker=next(item for item in catalog['items'] if item['sprite']==119802)
    for start in range(0,len(records),8):
        board=Image.new('RGB',(960,1520),'#273a48');draw=ImageDraw.Draw(board)
        for row,record in enumerate(records[start:start+8]):
            folder=(ROOT/record['manifest']).parent;manifest=json.loads((folder/'motions.json').read_text())
            for col,pose in enumerate(['8:0','8:3','8:5','10:3','10:5','10:7'] if reactions else ['0:5','1:7','3:7','5:3','5:5','6:7']):
                clip=manifest['clips'].get(pose,manifest['clips']['0:'+pose[-1]])
                f=clip['frames'][-1 if reactions else 0 if col==0 else len(clip['frames'])//2];point=attachment(points,folder,manifest,f)
                art=composite(folder,manifest,f,point,marker,pose,pages);art.thumbnail((158,162),Image.Resampling.NEAREST)
                x=col*160;y=row*190;board.paste(art,(x+(158-art.width)//2,y+162-art.height),art)
                draw.text((x+3,y+164),record['key']+' '+pose,fill='white')
        board.save(OUT/f'skins-{start//8:02d}.png')
    owners={}
    for record in records:owners.setdefault(record['key'].split(':')[0],record)
    for owner,record in owners.items():
        folder=(ROOT/record['manifest']).parent;manifest=json.loads((folder/'motions.json').read_text())
        for start in range(0,len(catalog['items']),40):
            board=Image.new('RGB',(1600,1000),'#273a48');draw=ImageDraw.Draw(board)
            for cell,item in enumerate(catalog['items'][start:start+40]):
                x=cell%8*200;y=cell//8*200
                for col,pose in enumerate(['8:3','10:5'] if reactions else ['1:7','5:3']):
                    clip=manifest['clips'].get(pose,manifest['clips']['0:'+pose[-1]])
                    f=clip['frames'][-1 if reactions else len(clip['frames'])//2];point=attachment(points,folder,manifest,f)
                    art=composite(folder,manifest,f,point,item,pose,pages);art.thumbnail((98,172),Image.Resampling.NEAREST)
                    board.paste(art,(x+col*100+(98-art.width)//2,y+172-art.height),art)
                draw.text((x+4,y+178),str(item['sprite'])+' / '+owner,fill='white')
            board.save(OUT/f'wardrobe-{owner}-{start//40:02d}.png')
        print('WARDROBE',owner,'400 resources, hurt and death' if reactions else '400 resources, walk and attack',flush=True)


def main():
    global OUT
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--all-animations',action='store_true');args=parser.parse_args()
    if args.all_animations:OUT=OUT.parent/'Reaction Review'
    OUT.mkdir(parents=True,exist_ok=True);records,roots=prep.model_sources();points=anchors()
    baseline=points
    if (OUT/'baseline-anchors.json').exists():
        baseline_tables=json.loads((OUT/'baseline-anchors.json').read_text());raw=(OUT/'baseline-anchors.bin').read_bytes()
        baseline={key:{(x,y):(hx/4,hy/4) for x,y,hx,hy in struct.iter_unpack('<HHhh',raw[at:at+n*8])} for key,(at,n) in baseline_tables.items()}
    seen=set();counts=Counter();tracks=[];changed=[];unsupported=[]
    for root,record in roots.items():
        manifest=json.loads(root.read_text());folder=root.parent
        for si,stance in enumerate([manifest]+manifest.get('weapons',[])):
            for pose,clip in stance['clips'].items():
                positions=[];bad=[]
                for i,f in enumerate(clip['frames']):
                    route='res://'+str(prep.texture_path(folder,manifest,int(f[0])).relative_to(ROOT));key=tuple(f[1:3]);counts['frame_uses']+=1
                    point=points.get(route,{}).get(key)
                    assert point is not None,(root,pose,i,'missing attachment')
                    positions.append([point[0]+f[5],point[1]+f[6]])
                    if (route,key) in seen:continue
                    seen.add((route,key));counts['unique_frames']+=1
                    old=baseline.get(route,{}).get(key)
                    delta=math.dist(point,old) if old else 0
                    if delta>.5:
                        changed.append(dict(key=record['key'],root=str(folder.relative_to(ROOT)),stance=si,pose=pose,frame=i,before=old,after=point,delta=round(delta,2)))
                    x,y=map(round,point);image=prep.frame_image(folder,manifest,f)
                    if not image.crop((x-6,y-6,x+7,y+7)).getbbox():
                        bad.append(i);unsupported.append(dict(key=record['key'],root=str(folder.relative_to(ROOT)),stance=si,pose=pose,frame=i))
                jumps=[math.dist(a,b) for a,b in zip(positions,positions[1:])]
                tracks.append(dict(key=record['key'],root=str(folder.relative_to(ROOT)),stance=si,pose=pose,points=positions,max_jump=round(max(jumps,default=0),2),unsupported=bad))
    catalog=json.loads((prep.OUT/'catalog.json').read_text())
    moving=[row for row in unsupported if int(row['pose'].split(':')[-2]) in [1,3,5,6,7]]
    jump=[]
    for row in unsupported:
        action=int(row['pose'].split(':')[-2]);manifest=json.loads((ROOT/row['root']/'motions.json').read_text())
        stance=([manifest]+manifest.get('weapons',[]))[row['stance']];count=len(stance['clips'][row['pose']]['frames'])
        indices=[0] if action==8 else [0,2] if row['key'].startswith('35') else [round(3*(count-1)/11),round(5*(count-1)/11)]
        if action in [8,10] and row['frame'] in indices:jump.append(row)
    guards=0;guard_bad=[]
    for path,regions in points.items():
        if not path.endswith('jump-guard.png'):continue
        image=Image.open(ROOT/path.removeprefix('res://')).convert('RGBA')
        for (x,y),(hx,hy) in regions.items():
            guards+=1;x=round(x+hx);y=round(y+hy)
            if not image.crop((x-6,y-6,x+7,y+7)).getbbox():guard_bad.append([path,x,y])
    counts.update(skins=len(records),roots=len(roots),clips=len(tracks),resources=len(catalog['items']),changed=len(changed),unsupported=len(unsupported))
    counts.update(moving_attack_gaps=len(moving),jump_gaps=len(jump),guard_cells=guards,guard_gaps=len(guard_bad))
    counts['all_animation_gaps']=len(unsupported)
    prep.save_json(OUT/'alignment-audit.json',dict(counts=dict(counts),changed=changed,unsupported=unsupported,tracks=tracks))
    print(dict(counts),flush=True)
    assert not moving and not jump and not guard_bad,'Review visible movement/attack/jump attachments before accepting the preparation'
    if args.all_animations:assert not unsupported,'Review every remaining animation attachment before accepting the preparation'
    render_wardrobe(records,points,catalog,args.all_animations)


if __name__=='__main__':main()
