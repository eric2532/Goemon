"""Fit recovered Water Dragon weapons to Shin's measured native weapon and hand pixels."""
import argparse
from collections import defaultdict
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from prepare_shin_water_dragon import ART, OUT, SIZE, ORIGIN, blue_theme, blue_waves, stitch, RECIPE, WAVE_SIZE, WAVE_ORIGIN, prepare_counter
from prepare_shin_red_lightning_run import move_blade
from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import pack_frames, ROOT

# shortcut: inventory art provides one view; replace with native directional weapon art if recovered.
KINDS = {
    'axe': ('original:2423', 251586, ((30,27),(12,12),1), .9),
    'polearm': ('original:2428', 251590, ((32,27),(3,2),1), .85),
    'staff': ('original:2427', 251598, ((30,27),(7,7),1), .85),
    'bow': ('original:2424', 251594, ((23,28),(3,2),1), 1),
    'kunai': ('original:2425', 251606, ((37,21),(1,5),1), .65),
    'boomerang': ('original:2425', 251602, ((26,20),(4,9),1), .72),
}
REPORT = ROOT/'build/Other Files/Asset Toolkit/Shin Water Dragon/All Weapons'
HAND = {(237,210,132),(192,162,99),(242,223,166),(140,121,74),(209,178,109),(230,197,111),(225,194,119),(176,146,89),(162,143,89),(239,219,140),(151,132,81),(243,218,155),(195,175,111),(237,207,133),(143,113,69)}
WOOD = {(127,97,60),(111,81,50),(94,65,40),(160,129,79),(206,186,118),(78,49,30)}
# Approved front/side samples, traced on native origin (80,116).
APPROVED = {
 ('axe',0,4,0): ((62,90),(73,111)), ('axe',5,4,4): ((60,61),(41,48)), ('axe',5,4,14): ((117,112),(135,133)),
 ('polearm',0,4,0): ((62,90),(85,130)), ('polearm',5,4,6): ((63,84),(58,116)), ('polearm',5,4,12): ((128,110),(158,126)),
 ('staff',0,4,0): ((62,90),(73,110)), ('staff',5,4,4): ((54,58),(69,32)), ('staff',5,4,12): ((117,114),(148,131)),
}

BOW_APPROVED = {(0,6,0):((85,95),(65,81),(107,84)), (5,6,4):((44,76),(49,53),(62,95)), (5,6,6):((44,76),(49,51),(62,95))}

BOW_CARRY = {0:((65,93),(61,69),(73,98)),1:((65,89),(58,95),(78,74)),
 2:((69,83),(44,83),(85,66)),3:((87,81),(59,72),(100,71)),
 4:((90,84),(95,78),(85,90)),5:((90,89),(97,75),(89,93)),
 6:((85,95),(65,81),(107,84)),7:((80,97),(60,79),(101,96))}
BOW_APPROVED.update({(0,d,0):plane for d,plane in BOW_CARRY.items()})

def native_point(p): return (p[0]+ORIGIN[0]-80,p[1]+ORIGIN[1]-116)

def axis(points):
    cx=sum(x for x,y in points)/len(points);cy=sum(y for x,y in points)/len(points)
    xx=sum((x-cx)**2 for x,y in points);yy=sum((y-cy)**2 for x,y in points);xy=sum((x-cx)*(y-cy) for x,y in points)
    a=.5*math.atan2(2*xy,xx-yy)
    return (cx,cy),(math.cos(a),math.sin(a))

def shaft(points):
    if len(points)<3:return None
    best=None;score=-1
    for i in range(48):
        a=i*math.pi/48;ux,uy=math.cos(a),math.sin(a)
        bins=defaultdict(list)
        for x,y in points:
            across=-x*uy+y*ux
            for offset in (0,1.5):bins[(offset,math.floor((across+offset)/3))].append((x*ux+y*uy,(x,y)))
        for rows in bins.values():
            rows.sort();groups=[[]]
            for row in rows:
                if groups[-1] and row[0]-groups[-1][-1][0]>9:groups.append([])
                groups[-1].append(row)
            for group in groups:
                span=group[-1][0]-group[0][0]
                value=len(group)*span
                if len(group)>=3 and span>=5 and value>score:best=[p for _,p in group];score=value
    return axis(best) if best else None

def features(body,bare=None):
    pixels=list(body.getdata());hair=[(i%SIZE[0],i//SIZE[0])for i,(r,g,b,a)in enumerate(pixels)if a and r>60 and r>g*3 and b<10 and i//SIZE[0]<ORIGIN[1]-35]
    box=(min(x for x,y in hair)-2,min(y for x,y in hair),max(x for x,y in hair)+2,max(y for x,y in hair)+12) if hair else (0,0,0,0)
    wood=[];hands=[]
    for i,(r,g,b,a)in enumerate(pixels):
        if not a:continue
        x,y=i%SIZE[0],i//SIZE[0]
        face=box[0]<=x<=box[2] and box[1]<=y<=box[3]
        if not face and (r,g,b)in WOOD and (bare is None or body.getpixel((x,y))!=bare.getpixel((x,y))):wood.append((x,y))
        if not face and (r,g,b)in HAND:hands.append((x,y))
    return wood,hands

def hand_groups(points):
    remaining=set(points);groups=[]
    while remaining:
        start=remaining.pop();group=[start];pending=[start]
        while pending:
            x,y=pending.pop()
            for xx in range(x-2,x+3):
                for yy in range(y-2,y+3):
                    if (xx,yy)in remaining:remaining.remove((xx,yy));group.append((xx,yy));pending.append((xx,yy))
        if len(group)>=2:groups.append((sum(x for x,y in group)/len(group),sum(y for x,y in group)/len(group)))
    return groups

def measured(body,kind,bare=None):
    wood,hands=features(body,bare);line=shaft(wood)
    if line is None:return None
    center,u=line;ux,uy=u
    def along(p):return (p[0]-center[0])*ux+(p[1]-center[1])*uy
    def across(p):return -(p[0]-center[0])*uy+(p[1]-center[1])*ux
    chain=[p for p in wood if abs(across(p))<3]
    if len(chain)<3:return None
    low,high=min(map(along,chain)),max(map(along,chain))
    head=[]
    for i,(r,g,b,a)in enumerate(body.getdata()):
        if not a:continue
        p=(i%SIZE[0],i//SIZE[0]);t=along(p)
        if abs(across(p))>(8 if kind=='axe' else 10) or not low-30<t<high+30:continue
        good=(70<r<225 and r<=g<b and b-r<36) if kind=='axe' else (g>110 and g>r*1.2 and g>b*1.2)
        if good and (bare is None or body.getpixel(p)!=bare.getpixel(p)):head.append(p)
    # Native metal/orb pixels determine which shaft end carries the head.
    end=1 if head and sum(along(p)for p in head)/len(head)>(low+high)/2 else -1
    head=[p for p in head if end*(along(p)-(low+high)/2)>0]
    target_t=sum(along(p)for p in head)/len(head) if head else (high+14 if end>0 else low-14)
    candidates=[p for p in hands if abs(across(p))<4 and low-8<along(p)<high+8]
    if candidates:
        nearest=min(candidates,key=lambda p:abs(along(p)-(low+high)*.5)+abs(across(p))*2)
        palm=[p for p in candidates if math.dist(p,nearest)<3]
        grip=(sum(p[0]for p in palm)/len(palm),sum(p[1]for p in palm)/len(palm))
    else:grip=(center[0]+ux*(low*.5+high*.5),center[1]+uy*(low*.5+high*.5))
    tip=(center[0]+ux*target_t,center[1]+uy*target_t)
    signed=sum(across(p)for p in head)/len(head) if head else 0
    # Axe's silver head follows its native projected face; symmetric heads keep their art.
    flip=kind=='axe' and signed*end<-.25
    width=min(1,max(.25,(max(map(across,head))-min(map(across,head)))/(8 if kind=='axe' else 5))) if head else .4
    return dict(grip=grip,tip=tip,tail=(center[0]+ux*low,center[1]+uy*low),far=(center[0]+ux*high,center[1]+uy*high),visible=bool(head),flip=flip,width=width)

def clean(body,pose,bare=None):
    band=Image.new('L',SIZE);d=ImageDraw.Draw(band)
    d.line((pose['tail'],pose['far']),fill=255,width=8);d.line((pose['grip'],pose['tip']),fill=255,width=19)
    gx,gy=pose['grip'];d.ellipse((gx-3,gy-3,gx+3,gy+3),fill=0)
    mask=Image.new('L',SIZE);values=[]
    for i,pixel in enumerate(body.getdata()):
        r,g,b,a=pixel;x,y=i%SIZE[0],i//SIZE[0]
        erase=a and band.getpixel((x,y)) and (bare is None or pixel!=bare.getpixel((x,y))) and ((r,g,b)in WOOD or max(r,g,b)<60 or min(r,g,b)>70 and max(r,g,b)-min(r,g,b)<43 or g>r*1.2 and g>b*1.2 or 70<r<225 and r<=g<b and b-r<36)
        values.append(255 if erase else 0)
    mask.putdata(values);result=body.copy();result.putalpha(ImageChops.subtract(body.getchannel('A'),mask));return result

def affine(source,target):
    (x0,y0),(x1,y1),(x2,y2)=target;dx1,dy1,dx2,dy2=x1-x0,y1-y0,x2-x0,y2-y0;det=dx1*dy2-dx2*dy1
    if abs(det)<.01:return None
    result=[]
    for coord in (0,1):
        s0,s1,s2=[p[coord]for p in source];a=((s1-s0)*dy2-(s2-s0)*dy1)/det;b=(dx1*(s2-s0)-dx2*(s1-s0))/det;result.extend((a,b,s0-a*x0-b*y0))
    return tuple(result)

def bow_fit(body,item,bare,override=None,previous=None):
    _,hands=features(body,bare)
    palette=WOOD|{(62,32,20),(45,16,10),(15,34,17),(23,52,26),(31,69,34)}
    palette-={(206,186,118),(160,129,79)}
    hair=[(i%SIZE[0],i//SIZE[0])for i,(r,g,b,a)in enumerate(body.getdata())if a and r>60 and r>g*3 and b<10 and i//SIZE[0]<ORIGIN[1]-35]
    face=(min(x for x,y in hair)-2,max(x for x,y in hair)+2,max(y for x,y in hair)+12) if hair else (0,0,0)
    wood=[]
    for i,p in enumerate(body.getdata()):
        x,y=i%SIZE[0],i//SIZE[0]
        if p[3] and (p[:3]in palette or p[1]>40 and p[1]>p[0]*.9 and p[2]<p[1]*.8) and not(face[0]<=x<=face[1] and y<=face[2]) and (bare is None or p!=bare.getpixel((x,y))):wood.append((x,y))
    wood=[p for p in wood if p[1]<ORIGIN[1]-12]
    if override:grip,top,bottom=map(native_point,override)
    else:
        groups=hand_groups([p for p in hands if p[1]<ORIGIN[1]-8])
        if not groups or not wood:return blue_theme(body),None
        # The extended bow palm is near the stave; knees and the drawing hand are excluded.
        grip=min(groups,key=lambda p:math.dist(p,previous)+min(math.dist(p,w)for w in wood)*.4) if previous else min(groups,key=lambda p:min(math.dist(p,w)for w in wood))
        if previous and math.dist(grip,previous)>22:grip=previous
        visible=[p for p in wood if math.dist(p,grip)<33]
        if len(visible)<2:return blue_theme(body),None
        center,u=axis(visible);ux,uy=u
        projections=sorted(((x-center[0])*ux+(y-center[1])*uy,(x,y))for x,y in visible)
        top,bottom=projections[0][1],projections[-1][1]
        if top[1]>bottom[1]:top,bottom=bottom,top
    wood=[p for p in wood if math.dist(p,grip)<33]
    coef=affine([(23,28),(3,2),(58,46)],[grip,top,bottom])
    if coef is None:
        dx,dy=bottom[0]-top[0],bottom[1]-top[1];length=math.hypot(dx,dy)
        if length<1:return blue_theme(body),None
        # Preserve the native edge-on projection while keeping the actual palm fixed.
        top=(top[0]-dy/length*.5,top[1]+dx/length*.5);bottom=(bottom[0]-dy/length*.5,bottom[1]+dx/length*.5)
        coef=affine([(23,28),(3,2),(58,46)],[grip,top,bottom])
    mask=Image.new('L',SIZE);d=ImageDraw.Draw(mask)
    for x,y in wood:d.ellipse((x-1,y-1,x+1,y+1),fill=255)
    gx,gy=grip;d.ellipse((gx-3,gy-3,gx+3,gy+3),fill=0)
    original=body.copy();original.putalpha(ImageChops.subtract(body.getchannel('A'),mask))
    fitted=item.transform(SIZE,Image.Transform.AFFINE,coef,Image.Resampling.NEAREST)
    return Image.alpha_composite(fitted,blue_theme(original)),dict(grip=grip,top=top,bottom=bottom)

# Native throw drawings 0,1,2,5,7. None means the throwing hand is behind the body.
THROW_HANDS = {
 0:[(65,86),(68,65),(75,43),None,(89,42)],
 1:[(68,81),None,(96,49),None,(101,51)],
 2:[None,(96,64),(105,56),(110,61),None],
 3:[(90,81),(99,70),(99,64),(99,70),(80,60)],
 4:[(64,87),(55,85),(48,73),(75,79),(64,62)],
 5:[(69,81),(73,78),(61,69),(63,73),(60,51)],
 6:[(77,96),(61,79),(55,59),(95,61),(64,45)],
 7:[(66,92),(58,71),(61,52),(59,53),None],
}

def throw_grip(body,direction,drawing):
    seed=THROW_HANDS[direction][drawing]
    if seed is None:return None
    sx,sy=native_point(seed);palm=[];arm=[]
    for y in range(max(0,round(sy)-12),min(SIZE[1],round(sy)+13)):
        for x in range(max(0,round(sx)-12),min(SIZE[0],round(sx)+13)):
            r,g,b,a=body.getpixel((x,y))
            if not a:continue
            if math.hypot(x-sx,y-sy)<=9 and ((r,g,b)in HAND or r>=g*.95 and g>130 and b<g*.85):palm.append((x,y))
            if math.hypot(x-sx,y-sy)<12 and r>45 and r>=g*.95 and g>b*1.2 and not(r>g*3 and b<10):arm.append((x,y))
    if palm:
        nearest=min(palm,key=lambda p:math.hypot(p[0]-sx,p[1]-sy));palm=[p for p in palm if math.dist(p,nearest)<3]
    grip=(sum(x for x,y in palm)/len(palm),sum(y for x,y in palm)/len(palm)) if palm else (sx,sy)
    if len(arm)<4:return None
    center,u=axis(arm)
    if u[0]*(grip[0]-center[0])+u[1]*(grip[1]-center[1])<0:u=(-u[0],-u[1])
    return grip,(grip[0]+u[0]*24,grip[1]+u[1]*24)


def prepare(source,only=None):
    sys.path.insert(0,str(source/'tools'));import cg_assets as cg;import cg_library;import cg_sounds
    REPORT.mkdir(parents=True,exist_ok=True);prepare_counter();waves=blue_waves();recipe=json.loads(RECIPE.read_text());report=json.loads((OUT/'weapon-fits.json').read_text()) if (OUT/'weapon-fits.json').exists() else {};drawings={};clean_cache={}
    sword=json.loads((OUT/'motions.json').read_text());basic=json.loads((ART/'100050/motions.json').read_text());sword_source=basic['weapons'][0]
    raw_cache={}
    def raw(key,action,direction,index):
        k=(key,action,direction,index)
        if k not in raw_cache:
            c=next(c for c in cg.actor(key)[2]if c['action']==action and c['direction']==direction and c['frames']);im,x,y=cg.frame_parts(key,c['index'],index);can=Image.new('RGBA',SIZE);can.alpha_composite(im,(ORIGIN[0]+x,ORIGIN[1]+y));raw_cache[k]=can
        return raw_cache[k]
    for kind,(key,row,source_axis,width)in KINDS.items():
        if only and kind not in only:continue
        folder=OUT/kind;folder.mkdir(exist_ok=True);item=Image.new('RGBA',SIZE);icon=cg_library.image_from_record('original',row);item.alpha_composite(icon);icon.save(folder/'item.png')
        if kind=='bow':
            mask=Image.new('L',SIZE);ImageDraw.Draw(mask).polygon([(0,0),(13,4),(20,21),(25,25),(34,31),(51,36),(60,45),(58,49),(47,43),(32,41),(19,35),(12,31),(11,14),(8,8),(0,5)],fill=255);item.putalpha(ImageChops.multiply(item.getchannel('A'),mask))
        thrown=kind in ('kunai','boomerang');body_key=sword_source['key'] if thrown else key
        original_clips={(c['action'],c['direction']):c for c in cg.actor(body_key)[2]if c['frames']}
        unique={};clips={};poses={};review={};anchors={}
        for (action,direction),native in original_clips.items():
            if action not in (0,1,3,5,6,8,9,10):continue
            retimed=kind in ('axe','staff') and action==5
            carry=retimed or kind in ('axe','polearm','staff') and (action in (1,3,6,8,9,10) or action==0 and direction!=4)
            actual=cg.actor(key)[2] if thrown and action==5 else None
            c=next(c for c in actual if c['action']==7 and c['direction']==direction and c['frames']) if actual else native
            selected_key=key if actual else sword_source['key'] if carry else body_key
            if carry and not retimed:c=next(c for c in cg.actor(selected_key)[2]if c['action']==action and c['direction']==direction and c['frames'])
            source_action=7 if actual else action;clip=dict(duration=c['duration']/1000,source_clip=c['index'],source_action=source_action,source_frames=c['frames'],source_key=selected_key,frames=[])
            release=next((i for i,f in enumerate(c['frames'])if 10000<=f[-1]<20000),len(c['frames'])//2)
            if action==5:
                cues=cg_sounds.clip_cues(c);contacts=[cue for cue in cues if 10000<=cue['flag']<20000];swings=[cue for cue in cues if cue['flag']<10000]
                clip.update(contact=release/len(c['frames']),swing=max(0,release-1)/len(c['frames']),contacts=[release*clip['duration']/len(c['frames'])],contact_cues=[contacts[0]['id'] if contacts else 134],sounds=swings)
                if kind=='bow' or thrown:clip.update(release=clip['contacts'][0],draw=clip['contacts'][0] if thrown else swings[0]['atMs']/1000 if swings else max(0,clip['contacts'][0]-.12))
            body_frames=c['frames'];body_indices=list(range(len(body_frames)))
            if retimed:
                donor=next(c for c in cg.actor(selected_key)[2]if c['action']==5 and c['direction']==direction and c['frames'])
                donor_contact=round(sword_source['clips'][f'5:{direction}']['contact']*len(donor['frames']))
                body_indices=[round(i*donor_contact/max(1,release)) if i<=release else donor_contact+round((i-release)*(len(donor['frames'])-1-donor_contact)/max(1,len(c['frames'])-1-release))for i in range(len(c['frames']))]
                body_frames=[donor['frames'][i]for i in body_indices];clip['source_frames']=deepcopy(body_frames)
                clip['retimed_contact_source']=key
            ids=list(dict.fromkeys(f[0]for f in body_frames));prepared={};previous=None
            if kind=='bow':previous=native_point(BOW_CARRY[direction][0])
            if thrown and action==5:
                resting=recipe[f'0:{direction}:0'];previous=native_point((resting['grip'][0]-16,resting['grip'][1])) if resting else ORIGIN
            for index,frame in enumerate(c['frames']):
                body_index=body_indices[index];ident=body_frames[index][0];posekey=f'{action}:{direction}:{ids.index(ident)}'
                if ident not in prepared:
                    body=raw(selected_key,source_action,direction,body_index);bare=raw('original:2425',action,direction,index) if not thrown and action in (0,1,3) else None
                    fitted=None
                    if (thrown and action!=5) or carry:
                        native_frames=sword_source['clips'].get(f'{action}:{direction}',{}).get('frames',[])
                        if native_frames:
                            body_ids=list(dict.fromkeys(tuple(f)for f in native_frames));sp=recipe.get(f'{action}:{direction}:{body_ids.index(tuple(native_frames[body_index]))}')
                        else:sp=recipe.get(f'9:{direction}:0')
                        if sp and sp.get('body_pose'):
                            bp,bi=sp['body_pose'].rsplit(':',1);ba,bd=map(int,bp.split(':'));bc=next(c for c in cg.actor(selected_key)[2]if c['action']==ba and c['direction']==bd and c['frames']);body=raw(selected_key,ba,bd,int(bi));clip['source_frames'][index]=bc['frames'][int(bi)]
                        cache_key=(action,direction,body_index,sp.get('body_pose')if sp else None)
                        if cache_key not in clean_cache:
                            clean_cache[cache_key]=stitch(blue_theme(body),Image.new('RGBA',SIZE),sp,blue_theme(raw('original:2425',action,direction,body_index)) if action in (0,1,3) else None)[0]
                        clean_body=clean_cache[cache_key]
                        if sp:
                            grip=tuple(sp['grip'][i]+ORIGIN[i]-(96,116)[i]for i in (0,1));factor={'axe':.65,'polearm':1.25,'staff':.85}.get(kind,.9);tip=tuple(grip[i]+(sp['tip'][i]-sp['grip'][i])*factor for i in (0,1));flip=bool(sp.get('edge_flip'))^(kind in ('axe','kunai'));fitted=move_blade(item,source_axis,(grip,tip,-width if flip else width),SIZE);review[posekey]=dict(grip=grip,tip=tip,flip=flip)
                        result=Image.alpha_composite(fitted,clean_body) if fitted else clean_body
                    elif thrown:
                        result=blue_theme(body)
                        if index<release:
                            measured_hand=throw_grip(body,direction,ids.index(ident))
                            if measured_hand:
                                grip,tip=measured_hand
                                result=Image.alpha_composite(move_blade(item,source_axis,(grip,tip,width),SIZE),result);review[posekey]=dict(grip=grip,tip=tip)
                            else:review[posekey]=None
                    elif kind=='bow':
                        result,review[posekey]=bow_fit(body,item,bare,BOW_APPROVED.get((action,direction,index)),previous)
                        if review[posekey]:previous=review[posekey]['grip']
                    else:
                        fit=measured(body,kind,bare)
                        approved=APPROVED.get((kind,action,direction,index))
                        if fit and approved:fit.update(grip=native_point(approved[0]),tip=native_point(approved[1]),flip=False,width=1,visible=True)
                        if fit:
                            clean_body=blue_theme(clean(body,fit,bare));source_item=item
                            if not fit['visible']:
                                source_item=item.copy();a,b,_=source_axis;vx,vy=b[0]-a[0],b[1]-a[1]
                                source_item.putdata([p if (i%SIZE[0]-a[0])*vx+(i//SIZE[0]-a[1])*vy<math.hypot(vx,vy)*5 else(0,0,0,0)for i,p in enumerate(item.getdata())])
                            fitted=move_blade(source_item,source_axis,(fit['grip'],fit['tip'],width*fit['width']*(-1 if fit['flip']else 1)),SIZE);result=Image.alpha_composite(fitted,clean_body);review[posekey]=fit
                        else:result=blue_theme(body);review[posekey]=None
                    prepared[ident]=result;poses[posekey]=result
                result=prepared[ident];origin=ORIGIN
                if action==5 and kind!='boomerang':
                    # Align the existing blue Gold Lightning wave to this weapon's actual contact/release.
                    phase=index/max(1,len(c['frames'])-1);contact=release/len(c['frames']);mapped=phase*.44/max(.001,contact) if phase<contact else .44+(phase-contact)*.56/max(.001,1-contact);wave=waves[f'5:{direction}'][min(24,round(mapped*24))]
                    if wave:
                        combined=Image.new('RGBA',WAVE_SIZE);combined.alpha_composite(wave[0],(WAVE_ORIGIN[0]+wave[1],WAVE_ORIGIN[1]+wave[2]));combined.alpha_composite(result,(WAVE_ORIGIN[0]-ORIGIN[0],WAVE_ORIGIN[1]-ORIGIN[1]));result=combined;origin=WAVE_ORIGIN
                clip['frames'].append(packed_frame(result,-origin[0],-origin[1],unique))
            if retimed:
                donor_ids=list(dict.fromkeys(f[0]for f in donor['frames']))
                for i,f in enumerate(body_frames):
                    sp=recipe[f'5:{direction}:{donor_ids.index(f[0])}']
                    if sp and sp.get('body_pose'):
                        bp,bi=sp['body_pose'].rsplit(':',1);ba,bd=map(int,bp.split(':'));bc=next(c for c in cg.actor(selected_key)[2]if c['action']==ba and c['direction']==bd and c['frames']);clip['source_frames'][i]=bc['frames'][int(bi)]
            clips[f'{action}:{direction}']=clip
        pages=pack_frames(clips,unique,folder)
        for file in folder.glob('atlas-*.png'):
            if int(file.stem.split('-')[-1])>=pages:
                file.unlink();file.with_suffix('.png.import').unlink(missing_ok=True)
        manifest=dict(key=key,id=900050,source_id=cg.actor(key)[0],weapon=kind,pages=pages,clips=clips,water_dragon=True,body_source=body_key,item_row=row,wave_source='puk2:1108',source_weapons={kind:key})
        if kind=='boomerang':
            manifest['wave_on_contact']=True
            # Keep the recovered wave pixels separate from the caster's throw drawings.
            cell=296;wave_atlas=Image.new('RGBA',(cell*3,cell*8))
            for facing in range(8):
                # These are the three wave samples already shown by this twelve-frame throw.
                for frame,source_frame in enumerate((13,17,20)):
                    wave=waves[f'5:{facing}'][source_frame]
                    assert wave is not None and max(wave[0].size)<cell
                    image=wave[0]
                    wave_atlas.alpha_composite(image,(frame*cell+(cell-image.width)//2,facing*cell+(cell-image.height)//2))
            wave_atlas.save(folder/'contact-wave.png')
        (folder/'motions.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n');report[kind]=review;drawings[kind]=poses
        if thrown:
            sheet=Image.new('RGBA',(96*16,96))
            for i in range(16):
                # Source pixels only: centre, rotate and pack once for all projectile copies.
                can=Image.new('RGBA',(96,96));can.alpha_composite(icon,((96-icon.width)//2,(96-icon.height)//2));angle=math.degrees(math.atan2(source_axis[1][1]-source_axis[0][1],source_axis[1][0]-source_axis[0][0])) if kind=='kunai' else 0;can=can.rotate(angle-i*22.5,resample=Image.Resampling.NEAREST);sheet.alpha_composite(can,(i*96,0))
            sheet.save(folder/'projectile.png')
        for file in folder.glob('*.png'):
            settings=file.with_suffix('.png.import')
            if settings.exists():settings.write_text(settings.read_text().replace('process/fix_alpha_border=false','process/fix_alpha_border=true'))
            else:settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+str(file.relative_to(ROOT))+'"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')
        print(f'{kind}: {len(clips)} clips, {len(unique)} drawings, {pages} pages; {sum(v is None for v in review.values())} occluded/unmeasurable poses',flush=True)
    (OUT/'weapon-fits.json').write_text(json.dumps(report,indent=2)+'\n')
    routes={k:{'root':'res://'+str((OUT/k).relative_to(ROOT))+'/'}for k in KINDS if k!='boomerang'}
    routes['water-dragon-boomerang']={'root':'res://'+str((OUT/'boomerang').relative_to(ROOT))+'/', 'base_weapon':'boomerang','projectile':'water_dragon_boomerang'}
    sword['prepared_weapons']=routes;(OUT/'motions.json').write_text(json.dumps(sword,separators=(',',':'))+'\n')
    catalog_path=ART.parent/'weapons/catalog.json';catalog=json.loads(catalog_path.read_text());catalog['37']['900050'].update(routes);catalog_path.write_text(json.dumps(catalog,indent=2)+'\n')
    font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',17)
    for kind,poses in drawings.items():
        for action,label in [(0,'idle'),(1,'walk'),(3,'run'),(5,'attack-counter')]:
            selected=[(key,im)for key,im in poses.items()if key.startswith(str(action)+':')];cols=8;board=Image.new('RGB',(cols*200,math.ceil(len(selected)/cols)*240),'#26323b');d=ImageDraw.Draw(board)
            for n,(key,im)in enumerate(selected):
                crop=im.crop((70,78,256,224)).resize((198,198),Image.Resampling.NEAREST);at=((n%cols)*200,(n//cols)*240);board.paste(crop,(at[0],at[1]+28),crop);d.text((at[0]+4,at[1]+4),kind+' '+key,font=font,fill='white')
            board.save(REPORT/f'{kind}-{label}.png')
    print('Prepared runtime weapon routes and frame-review boards.',flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--weapon',action='append',choices=KINDS);args=p.parse_args();prepare(args.source.resolve(),args.weapon)
