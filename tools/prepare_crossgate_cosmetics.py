"""Prepare recovered wardrobe pixels and offline head attachments for Cross Gate models."""
import argparse
import ast
import ctypes
from collections import Counter, defaultdict
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import subprocess
import sys

from PIL import Image, ImageDraw, ImageEnhance

from recover_crossgate_kazi import pack_frames

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/crossgate/cosmetics'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sponsor Cosmetics/Preparation'
SOURCE = ROOT.parent / 'Magic Power'
HEADS = ROOT / 'assets/ui/portraits/crossgate/model-head-provenance.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'))+'\n')


@lru_cache(maxsize=24)
def atlas(path):
    return Image.open(path).convert('RGBA')


def texture_path(folder, manifest, page):
    if 'art_pages' in manifest:
        return ROOT / manifest['art_pages'][page].removeprefix('res://')
    return folder / (f'atlas-{page}.png' if page < manifest['pages'] else f'cast-{page-manifest["pages"]}.png')


def frame_image(folder, manifest, frame):
    page, x, y, w, h, _, _ = frame
    return atlas(texture_path(folder, manifest, page)).crop((x, y, x+w, y+h))


def features(image, anchor, radius=13):
    """Exact color neighborhoods from the selected skin's own head pixels."""
    raw=image.tobytes();stride=image.width*4
    result={};samples=[]
    for y in range(max(1,round(anchor[1])-6),min(image.height,round(anchor[1])+radius)):
        for x in range(max(1,round(anchor[0])-radius),min(image.width-1,round(anchor[0])+radius)):
            at=y*stride+x*4
            if raw[at+3]<128:continue
            if (x+y)%3==0:samples.extend([x-round(anchor[0]),y-round(anchor[1]),*raw[at:at+3]])
            token=raw[at-4:at+8]+raw[at-stride:at-stride+4]
            point=(x-anchor[0],y-anchor[1])
            if token in result:result[token]=None
            else:result[token]=point
    return {k:v for k,v in result.items() if v is not None},samples


@lru_cache(maxsize=1)
def head_fitter():
    source=Path(__file__).with_name('crossgate_head_fit.c');library=REPORT/'head-fit.dylib'
    subprocess.run(['/usr/bin/clang','-O3','-dynamiclib',str(source),'-o',str(library)],check=True)
    function=ctypes.CDLL(str(library)).fit_head
    function.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_void_p,ctypes.c_int,ctypes.c_double,ctypes.c_double,ctypes.c_void_p]
    function.restype=ctypes.c_double
    return function


@lru_cache(maxsize=1)
def head_masker():
    head_fitter()
    function=ctypes.CDLL(str(REPORT/'head-fit.dylib')).fit_head_mask
    function.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_void_p,ctypes.c_double,ctypes.c_double,ctypes.c_void_p]
    function.restype=ctypes.c_double
    return function


def track_head(image, patterns, expected):
    patterns,samples=patterns
    if not samples:return list(expected),0
    raw=image.tobytes();stride=image.width*4
    colors={token[4:8] for token in patterns}
    votes=Counter()
    for y in range(1,image.height):
        for x in range(1,image.width-1):
            at=y*stride+x*4
            if raw[at:at+4] not in colors:continue
            point=patterns.get(raw[at-4:at+8]+raw[at-stride:at-stride+4])
            if point is not None:votes[(round(x-point[0]),round(y-point[1]))]+=1
    if not votes or max(votes.values())<8:
        points=(ctypes.c_int*2)();values=(ctypes.c_int*len(samples))(*samples)
        error=head_fitter()(raw,image.width,image.height,values,len(samples)//5,*expected,points)
        return list(points),max(0,round(255-error))
    point=max(votes,key=lambda p:(votes[p],-((p[0]-expected[0])**2+(p[1]-expected[1])**2)))
    return list(point),votes[point]


def head_error(image, pattern, point):
    raw=image.tobytes();samples=pattern[1];x,y=map(round,point);error=0
    if not samples:return 765.0
    for at in range(0,len(samples),5):
        dx,dy,r,g,b=samples[at:at+5];px=x+dx;py=y+dy
        if not (0<=px<image.width and 0<=py<image.height):error+=765;continue
        k=(py*image.width+px)*4
        error+=765 if raw[k+3]<128 else abs(raw[k]-r)+abs(raw[k+1]-g)+abs(raw[k+2]-b)
    return error/(len(samples)//5 or 1)


def fit_clip(frames, get_image, native, standing, expected):
    """Use this pose's visible heads; native tables also contain stale off-body points."""
    valid={};patterns={}
    for i,(frame,point) in enumerate(zip(frames,native)):
        if point is None:continue
        x,y=point[0]-frame[5],point[1]-frame[6]
        if not (-6<x<frame[3]+6 and -6<y<frame[4]+6):continue
        image=get_image(i)
        if image.crop((round(x)-6,round(y)-6,round(x)+7,round(y)+7)).getbbox():valid[i]=point
    if len(valid)==len(frames):
        return [([point[0]-frame[5],point[1]-frame[6]],'native',0) for frame,point in zip(frames,native)]
    for i,point in valid.items():
        frame=frames[i];local=[point[0]-frame[5],point[1]-frame[6]]
        if head_error(get_image(i),standing,local)<160:
            patterns[i]=features(get_image(i),local)
    first=min(patterns,default=None)
    result=[];previous=None
    for i,frame in enumerate(frames):
        point=valid.get(i)
        if point is not None:
            result.append(([point[0]-frame[5],point[1]-frame[6]],'native',0));previous=point;continue
        before=max((k for k in patterns if k<i),default=first)
        after=min((k for k in patterns if k>i),default=first)
        guide=list(expected)
        if before is not None:
            fraction=(i-before)/(after-before) if after!=before else 0
            fraction=max(0,min(1,fraction))
            guide=[valid[before][j]*(1-fraction)+valid[after][j]*fraction for j in range(2)]
        elif previous is not None:guide=list(previous)
        candidates=[]
        references=[patterns[k] for k in dict.fromkeys([before,after,first]) if k is not None]+[standing]
        image=get_image(i)
        guides=[guide]
        if previous is not None and math.dist(previous,guide)>16:guides.append(previous)
        for pattern in references:
            for origin in guides:
                local=[origin[0]-frame[5],origin[1]-frame[6]]
                fitted,score=track_head(image,pattern,local)
                error=head_error(image,pattern,fitted)
                candidates.append((error,fitted))
                if score>=8 and error<35:break
            if candidates[-1][0]<35:break
        error,fitted=min(candidates,key=lambda candidate:candidate[0])
        score=max(0,round(255-error))
        if score<4:
            fitted=[guide[0]-frame[5],guide[1]-frame[6]];method='pose interpolation'
        else:method='native repair' if native[i] is not None else 'pose tracking'
        result.append((fitted,method,score));previous=[fitted[0]+frame[5],fitted[1]+frame[6]]
    return result


def fit_turning_head(image, patterns, old):
    """A spinning head can use another view and move beyond the standing search window."""
    best=(765.0,list(old));raw=image.tobytes()
    for pattern in patterns:
        if not pattern[1]:continue
        values=(ctypes.c_int*len(pattern[1]))(*pattern[1])
        for y in range(16,image.height+42,64):
            for x in range(16,image.width+32,48):
                point=(ctypes.c_int*2)()
                head_fitter()(raw,image.width,image.height,values,len(pattern[1])//5,min(x,image.width-1),min(y,image.height-1),point)
                point=list(point)
                if not image.crop((point[0]-6,point[1]-6,point[0]+7,point[1]+7)).getbbox():continue
                error=head_error(image,pattern,point)+.002*math.dist(point,old)**2
                if error<best[0]:best=(error,point)
    return best


def local_recipe(text):
    names={'features','head_fitter','track_head','head_error','fit_clip','frame_image','atlas','texture_path'}
    return {node.name:ast.dump(node,include_attributes=False) for node in ast.parse(text).body if isinstance(node,ast.FunctionDef) and node.name in names}


def reviewed_head(fit,frame,image):
    if fit['layout']!=frame[3:] or fit['sha256']!=hashlib.sha256(image.tobytes()).hexdigest():
        raise ValueError('Reviewed cosmetic head pixels changed; inspect '+fit['root']+' '+fit['pose'])
    point=fit['head']
    assert len(point)==2 and all(math.isfinite(v) for v in point) and 0<=point[0]<image.width and 0<=point[1]<image.height,'Invalid reviewed head point'
    return point


def silhouette_head(alpha,mask,expected):
    rows=[mask[y*29:(y+1)*29] for y in range(20)]
    transitions=[sum(a!=b for a,b in zip(row,row[1:])) for row in rows]
    if max(transitions)<2:return None
    row_index=max(range(len(rows)),key=lambda y:transitions[y]);needle=rows[row_index]
    padded=Image.new('L',(alpha.width+28,alpha.height+19));padded.paste(alpha,(14,8))
    raw=padded.tobytes();stride=padded.width;at=raw.find(needle);matches=[]
    while at>=0:
        x=at%stride;y=at//stride-row_index
        if 0<=x<alpha.width and 0<=y<alpha.height and all(raw[(y+i)*stride+x:(y+i)*stride+x+29]==row for i,row in enumerate(rows)):
            matches.append([x,y])
        at=raw.find(needle,at+1)
    if matches:return min(matches,key=lambda p:math.dist(p,expected))
    # Some palette exports change a few outline pixels; compare the head shape, not its clothing colors.
    point=(ctypes.c_int*2)()
    error=head_masker()(alpha.tobytes(),alpha.width,alpha.height,mask,*expected,point)
    return list(point) if error/len(mask)<=.06 else None


def reviewed_pose_head(image,frame,references,current):
    """Reuse an inspected pose only when its head pixels or exact silhouette agree."""
    alpha=image.getchannel('A')
    x,y=map(round,current);current_mask=alpha.crop((x-14,y-8,x+15,y+12)).tobytes()
    if any(mask==current_mask and head_error(image,pattern,current)<80 for _,pattern,mask in references):return None
    for world,pattern,mask in references:
        point=[world[0]-frame[5],world[1]-frame[6]]
        error=head_error(image,pattern,point)
        x,y=map(round,point)
        # Palette variants retain the exact head silhouette even when their colors differ.
        same_mask=mask is not None and alpha.crop((x-14,y-8,x+15,y+12)).tobytes()==mask
        if same_mask:return point if math.dist(point,current)>.5 else None
        if error<20 and head_error(image,pattern,current)>error+30:
            return point
    for world,pattern,mask in references:
        if mask is not None:
            point=[world[0]-frame[5],world[1]-frame[6]]
            shifted=silhouette_head(alpha,mask,point)
            if shifted is not None:return shifted if math.dist(shifted,current)>.5 else None
    return None


def model_sources():
    records=json.loads(HEADS.read_text())
    owners={str(r['key']):r for r in records}
    roots={ROOT/r['manifest']:r for r in records}
    weapons=json.loads((ROOT/'assets/characters/crossgate/weapons/catalog.json').read_text())
    for character, skins in weapons.items():
        for skin, routes in skins.items():
            key=character+(':'+skin if skin!='0' else '')
            record=owners.get(key)
            if record is None:continue
            for route in routes.values():
                if 'root' in route:roots.setdefault(ROOT/route['root'].removeprefix('res://')/'motions.json',record)
            beast_master=ROOT/'assets/characters/crossgate/weapons/beast_master'/f'{character}-{skin}'/'motions.json'
            if beast_master.is_file():roots.setdefault(beast_master,record)
    for folder, owner in [('kazi/qi-punch','34:102488'),('ruby/qi-punch','35')]:
        roots[ROOT/'assets/characters/crossgate'/folder/'motions.json']=owners[owner]
    return records,roots


def prepare_items(cg, wardrobe):
    items=[];unique={};clips={};icons=Image.new('RGBA',(1280,1344));omissions=[]
    for item in wardrobe.items():
        icon_ready=False
        ident,_,native=cg.actor(item['key'])
        assert ident==item['sprite']
        entry=dict(id=f'cosmetic:{ident}',sprite=ident,key=item['key'],name=item['name'],kind=item['category'],clips={},fixed_facing=bool(item.get('fixedFacing')))
        for clip in native:
            if not clip['frames']:continue
            frames=[]
            for index in range(len(clip['frames'])):
                try:image,x,y=cg.frame_parts(item['key'],clip['index'],index)
                except (ValueError,OSError) as error:
                    if item.get('facings') and clip['direction'] not in item['facings']:
                        omissions.append([ident,clip['action'],clip['direction'],'authored hidden facing']);frames=[];break
                    raise ValueError((item['key'],clip['index'],index,str(error))) from error
                visible=image.getbbox()
                box=visible or (0,0,1,1)
                image=image.crop(box)
                if clip['action']==10 and image.width<=12 and image.height<=12:
                    omissions.append([ident,10,clip['direction'],'fall marker; use standing visual']);frames=[];break
                token=(image.size,hashlib.sha256(image.tobytes()).hexdigest())
                unique.setdefault(token,image)
                frames.append((token,x+box[0],y+box[1]))
                if visible and not icon_ready and clip['action']==0 and clip['direction']==(0 if entry['fixed_facing'] else 5):
                    icon=image.copy();icon.thumbnail((60,60),Image.Resampling.NEAREST)
                    cell=len(items);icons.alpha_composite(icon,(cell%20*64+(64-icon.width)//2,cell//20*64+(64-icon.height)//2))
                    icon_ready=True
            if frames:
                pose=f'{clip["action"]}:{clip["direction"]}'
                motion=dict(duration=clip['duration']/1000,frames=frames)
                entry['clips'][pose]=motion;clips[f'{ident}:{pose}']=motion
        assert any(k.startswith('0:') for k in entry['clips']),ident
        assert icon_ready,ident
        items.append(entry)
        if len(items)%50==0:print('ITEMS',len(items),flush=True)
    assert len(items)==400
    OUT.mkdir(parents=True,exist_ok=True)
    pages=pack_frames(clips,unique,OUT)
    entry, page, icon = water_dragon_cross(pages)
    page.save(OUT/f'atlas-{pages}.png')
    icons.alpha_composite(icon,(len(items)%20*64,len(items)//20*64))
    items.append(entry);pages+=1
    icons.save(OUT/'icons.png')
    for path in OUT.glob('*.png'):
        settings=Path(str(path)+'.import')
        text=settings.read_text() if settings.exists() else ('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+str(path.relative_to(ROOT))+'"\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=false\n')
        settings.write_text(text.replace('process/fix_alpha_border=false','process/fix_alpha_border=true'))
    save_json(OUT/'catalog.json',dict(pages=pages,items=items))
    save_json(REPORT/'authored-visibility.json',omissions)
    print('PACKED',len(items),'items',len(unique),'unique frames',pages,'shared pages',flush=True)


def water_dragon_cross(page):
    from prepare_shin_red_lightning_run import move_blade
    folder=ROOT/'assets/characters/crossgate/shin/900050'
    cross=Image.new('RGBA',(128,128));layers=[]
    for kind,source,target,depth in [
        ('polearm',((32,27),(3,2),1),((68,68),(29,22),1.55),-4),
        ('axe',((30,27),(12,12),1),((67,69),(91,42),1.55),4),
    ]:
        with Image.open(folder/kind/'item.png') as image:
            fitted=move_blade(image.convert('RGBA'),source,target,cross.size)
        # Keep the smaller fit and chosen B placement, four pixels below the old mount.
        layer=Image.new('RGBA',cross.size)
        layer.alpha_composite(fitted.resize((87,87),Image.Resampling.NEAREST),(21,26))
        grip,tip=[(point[0]*87/128+21,point[1]*87/128+26) for point in target[:2]]
        layers.append((layer,grip,tip,depth));cross.alpha_composite(layer)
    icon=Image.new('RGBA',(64,64));small=cross.crop(cross.getbbox())
    small.thumbnail((60,60),Image.Resampling.NEAREST)
    icon.alpha_composite(small,((64-small.width)//2,(64-small.height)//2))
    atlas=Image.new('RGBA',(1024,128));clips={}
    for direction in range(8):
        angle=(direction-1)*math.pi/4
        cosine,sine=math.cos(angle),math.sin(angle)
        image=Image.new('RGBA',cross.size)
        for layer,grip,tip,depth in (reversed(layers) if sine<0 else layers):
            if abs(sine)<.001:
                projected=layer if cosine>0 else layer.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            else:
                # Separate mounts and blade faces retain volume when the X turns edge-on.
                points=[(64+(point[0]-64)*cosine+sine*depth,point[1]) for point in [grip,tip]]
                projected=move_blade(layer,(grip,tip,1),(*points,math.copysign(.6+.4*abs(cosine),cosine)),cross.size)
            image.alpha_composite(projected)
        if abs(sine)>.001:
            edge=ImageEnhance.Brightness(image).enhance(.65)
            volume=Image.new('RGBA',cross.size)
            volume.alpha_composite(edge,(-round(sine*2),1));volume.alpha_composite(image)
            image=volume
        left,_,right,_=image.getbbox()
        image=image.crop((left,0,right,128))
        x=direction*128+left
        atlas.alpha_composite(image,(x,0))
        clips[f'0:{direction}']=dict(duration=1.0,frames=[[page,x,0,image.width,128,
            left-64-sine*16,-38]])
    entry=dict(id='cosmetic:water-dragon-cross',name='水龍 · Crossed Spear & Axe',kind='wings',
               description='Back cosmetic: 水龍 spear on the left and axe on the right, crossed in an X.',
               fixed_facing=False,clips=clips)
    return entry,atlas,icon


def prepare_anchors(cg, wardrobe, sample=False, previous_heads=None):
    records,roots=model_sources()
    review_path=OUT/'head-fits.json'
    reviewed=json.loads(review_path.read_text())['frames'] if review_path.exists() else []
    reviewed={(fit['root'],fit['stance'],fit['pose'],fit['frame']):fit for fit in reviewed}
    pose_references=defaultdict(list);reviewed_regions={}
    for (root,stance,pose,index),fit in reviewed.items():
        path=ROOT/root/'motions.json'
        if path not in roots:raise ValueError('Reviewed cosmetic model is missing: '+root)
        manifest=json.loads(path.read_text());clip=([manifest]+manifest.get('weapons',[]))[stance]['clips'][pose]
        frame=clip['frames'][index];image=frame_image(path.parent,manifest,frame)
        point=reviewed_head(fit,frame,image)
        region=('res://'+str(texture_path(path.parent,manifest,int(frame[0])).relative_to(ROOT)),f'{frame[1]}:{frame[2]}')
        previous=reviewed_regions.setdefault(region,fit)
        if math.dist(previous['head'],point)>.01:raise ValueError('Conflicting cosmetic heads for shared atlas region: '+str(region))
        if int(pose.split(':')[-2]) not in [8,10]:continue
        pattern=features(image,point)
        group=(roots[path]['key'].split(':')[0],':'.join(pose.split(':')[-2:]))
        x,y=map(round,point);mask=image.getchannel('A').crop((x-14,y-8,x+15,y+12))
        mask_bytes=mask.tobytes() if .2<sum(mask_bytes_value>127 for mask_bytes_value in mask.tobytes())/(29*20)<.95 else None
        reference=([point[0]+frame[5],point[1]+frame[6]],pattern,mask_bytes)
        if reference not in pose_references[group]:pose_references[group].append(reference)
    cache_path=REPORT/'pose-fit-cache.json'
    cache=json.loads(cache_path.read_text()) if cache_path.exists() else {};used_cache=set()
    code=local_recipe(Path(__file__).read_text())
    # The unchanged color fitter keeps its raw-pose cache when outline matching changes.
    helper=hashlib.sha256(Path(__file__).with_name('crossgate_head_fit.c').read_text().split('\n/* Palette-independent')[0].encode()).hexdigest()
    recipe=hashlib.sha256(json.dumps(code,sort_keys=True).encode()).hexdigest()+helper
    # Calibrate head centers from existing native coordinates and approved original head crops.
    ratios=defaultdict(list)
    for record in records:
        manifest=json.loads((ROOT/record['manifest']).read_text())
        if not manifest.get('key'):continue
        ident,_,clips=cg.actor(manifest['key'])
        clip=next((c for c in clips if c['action']==0 and c['direction']==5 and c['frames']),None)
        point=wardrobe.head_coordinates(ident).get(clip['frames'][0][0]) if clip else None
        if point:
            crop=record['crop'];bounds=record['bounds'];left=crop[0]+bounds[0];top=crop[1]+bounds[1]
            ratios[record['name']].append(((point[0]-left)/(bounds[2]-bounds[0]),(point[1]-top)/(bounds[3]-bounds[1])))
    output={};audit=[];dependencies={str(HEADS.relative_to(ROOT)):digest(HEADS)}
    # Reused atlases keep their verified attachment points; changed pixels are fitted again.
    preservation=OUT/'preservation.json'
    if preservation.exists() and (OUT/'anchors.json').exists() and (OUT/'anchors.bin').exists():
        previous=json.loads(preservation.read_text())['inputs']
        reviewed_inputs=[str(HEADS.relative_to(ROOT)),'tools/crossgate_head_fit.c']
        if previous_heads is not None:
            name=str(HEADS.relative_to(ROOT))
            assert digest(previous_heads)==previous[name], 'Previous heads must match the preserved attachment source'
            current={record['key']:record for record in records}
            old=json.loads(previous_heads.read_text())
            assert all(current.get(record['key'])==record for record in old), 'Existing head crops changed; rebuild all attachments'
            reviewed_inputs.remove(name)
            # Preserve verified existing attachment art; the fitter applies to added/changed atlases.
            preserved=json.loads(preservation.read_text())['outputs']
            for filename in ('anchors.json','anchors.bin'):
                artifact=OUT/filename
                assert preserved[str(artifact.relative_to(ROOT))]==digest(artifact), 'Existing attachment output changed'
            reviewed_inputs.remove('tools/crossgate_head_fit.c')
        if review_path.exists():reviewed_inputs.append(str(review_path.relative_to(ROOT)))
        if all(previous.get(name)==digest(ROOT/name) for name in reviewed_inputs):
            tables=json.loads((OUT/'anchors.json').read_text());packed=(OUT/'anchors.bin').read_bytes()
            for route,(start,count) in tables.items():
                name=route.removeprefix('res://');path=ROOT/name
                if name not in previous or not path.exists() or digest(path)!=previous[name]:continue
                dependencies[name]=previous[name]
                output[route]={}
                for i in range(count):
                    x,y,hx,hy=struct.unpack_from('<HHhh',packed,start+i*8)
                    output[route][f'{x}:{y}']=[hx/4,hy/4]
    if review_path.exists():dependencies[str(review_path.relative_to(ROOT))]=digest(review_path)
    for count,(path,record) in enumerate(roots.items()):
        if sample and record['key'] not in ['34:102488','38:118993','37:100181']:continue
        manifest=json.loads(path.read_text());folder=path.parent
        dependencies[str(path.relative_to(ROOT))]=digest(path)
        if previous_heads is not None:
            covered=all(f'{frame[1]}:{frame[2]}' in output.get('res://'+str(texture_path(folder,manifest,int(frame[0])).relative_to(ROOT)),{})
                        for stance in [manifest]+manifest.get('weapons',[])
                        for clip in stance['clips'].values() for frame in clip['frames'])
            guard=folder/'jump-guard.png'
            if covered and (not guard.exists() or 'res://'+str(guard.relative_to(ROOT)) in output):
                continue
        front=record['crop'];bounds=record['bounds']
        ratios_for_skin=ratios.get(record['name']) or [(.5,.38)]
        ratio=[statistics.median(p[i] for p in ratios_for_skin) for i in range(2)]
        expected=[front[0]+bounds[0]+(bounds[2]-bounds[0])*ratio[0],front[1]+bounds[1]+(bounds[3]-bounds[1])*ratio[1]]
        templates={};stances=[manifest]+manifest.get('weapons',[])
        for stance in stances:
            for pose,clip in stance['clips'].items():
                if not pose.startswith('0:'):continue
                frame=clip['frames'][0];image=frame_image(folder,manifest,frame)
                point=[expected[0]-frame[5],expected[1]-frame[6]]
                if stance.get('key'):
                    ident,_,native=cg.actor(stance['key'])
                    source_clip=next((c for c in native if c['action']==0 and c['direction']==int(pose[-1]) and c['frames']),None)
                    native_point=wardrobe.head_coordinates(ident).get(source_clip['frames'][0][0]) if source_clip else None
                    if native_point:point=[native_point[0]-frame[5],native_point[1]-frame[6]]
                templates.setdefault(int(pose[-1]),features(image,point))
        if not templates:
            base=json.loads((ROOT/record['manifest']).read_text());base_folder=(ROOT/record['manifest']).parent
            for direction in range(8):
                frame=base['clips'][f'0:{direction}']['frames'][0]
                templates[direction]=features(frame_image(base_folder,base,frame),[expected[0]-frame[5],expected[1]-frame[6]])
        template_keys={direction:hashlib.sha256(repr(pattern).encode()).hexdigest() for direction,pattern in templates.items()}
        for stance_index,stance in enumerate(stances):
            ident=0;native={};coordinates={}
            if stance.get('key'):
                ident,_,native_clips=cg.actor(stance['key']);native={(c['action'],c['direction']):c for c in native_clips}
                coordinates=wardrobe.head_coordinates(ident)
            for pose,clip in stance['clips'].items():
                if not isinstance(clip,dict) or not clip.get('frames'):continue
                if all(f'{f[1]}:{f[2]}' in output.get('res://'+str(texture_path(folder,manifest,int(f[0])).relative_to(ROOT)),{}) for f in clip['frames']):continue
                direction=int(pose[-1]);action=int(pose.split(':')[-2]) if ':' in pose else 5
                original=native.get((action,direction),{})
                source_points=[]
                original_frames=clip.get('source_frames',original.get('frames',[]))
                for index,frame in enumerate(clip['frames']):
                    source_frame=original_frames[index] if len(original_frames)==len(clip['frames']) else []
                    if isinstance(source_frame,int):
                        source_frame=original.get('frames',[])[source_frame] if source_frame<len(original.get('frames',[])) else []
                    source_points.append(coordinates.get(source_frame[0]) if source_frame else None)
                images={}
                def image_at(index):
                    if index not in images:images[index]=frame_image(folder,manifest,clip['frames'][index])
                    return images[index]
                source_images=[]
                for page in sorted({int(f[0]) for f in clip['frames']}):
                    texture=texture_path(folder,manifest,page);dependency=str(texture.relative_to(ROOT))
                    if dependency not in dependencies:dependencies[dependency]=digest(texture)
                    source_images.append([dependency,dependencies[dependency]])
                token=json.dumps([recipe,source_images,clip['frames'],source_points,template_keys[direction],expected],separators=(',',':'))
                cache_key=hashlib.sha256(token.encode()).hexdigest()
                if cache_key not in cache:cache[cache_key]=fit_clip(clip['frames'],image_at,source_points,templates[direction],expected)
                used_cache.add(cache_key)
                fitted=cache[cache_key]
                for index,frame in enumerate(clip['frames']):
                    texture=texture_path(folder,manifest,int(frame[0]))
                    dependency=str(texture.relative_to(ROOT))
                    if dependency not in dependencies:dependencies[dependency]=digest(texture)
                    route='res://'+str(texture.relative_to(ROOT));key=f'{frame[1]}:{frame[2]}'
                    if key in output.get(route,{}):continue
                    point,method,score=fitted[index]
                    review=reviewed_regions.get((route,key))
                    if review:
                        point=review['head'];method='reviewed fit';score=255
                    elif method!='native':
                        image=image_at(index);x,y=map(round,point)
                        if not image.crop((x-6,y-6,x+7,y+7)).getbbox():
                            error,turned=fit_turning_head(image,templates.values(),point)
                            if error<250:point=turned;method='turning head';score=round(255-error)
                    if not review and action in [8,10]:
                        references=pose_references.get((record['key'].split(':')[0],':'.join(pose.split(':')[-2:])),[])
                        if references:
                            repaired=reviewed_pose_head(image_at(index),frame,references,point)
                            if repaired is not None:point=repaired;method='reviewed pose match';score=255
                    output.setdefault(route,{})[key]=[round(point[0],2),round(point[1],2)]
                    audit.append(dict(root=str(folder.relative_to(ROOT)),stance=stance_index,pose=pose,frame=index,method=method,score=score))
        # Prepared jump/guard cells use the same original head pixels, not atlas top edges.
        guard=folder/'jump-guard.png'
        if guard.exists():
            kaz=folder.name=='kazi';w,h=(100,112) if kaz else (120,132);origin=(50,91) if kaz else (62,100)
            image=atlas(guard);route='res://'+str(guard.relative_to(ROOT));dependencies[str(guard.relative_to(ROOT))]=digest(guard)
            for y in range(0,image.height,h):
                for direction in range(8):
                    cell=image.crop((direction*w,y,direction*w+w,y+h))
                    if not cell.getbbox():continue
                    point,score=track_head(cell,templates[direction],[expected[0]+origin[0],expected[1]+origin[1]])
                    output.setdefault(route,{})[f'{direction*w}:{y}']=point
        if count%25==0:
            save_json(cache_path.with_suffix('.tmp'),cache);cache_path.with_suffix('.tmp').replace(cache_path)
            print('ANCHORS',count+1,'/',len(roots),len(audit),'unique regions',flush=True)
    save_json(REPORT/('sample-anchors.json' if sample else 'anchor-methods.json'),dict(counts=dict(Counter(r['method'] for r in audit)),frames=audit))
    if sample:save_json(REPORT/'sample-frame-anchors.json',output)
    else:
        tables={};packed=bytearray()
        for texture,regions in output.items():
            tables[texture]=[len(packed),len(regions)]
            for region,point in regions.items():
                x,y=map(int,region.split(':'))
                packed.extend(struct.pack('<HHhh',x,y,round(point[0]*4),round(point[1]*4)))
        (OUT/'anchors.bin').write_bytes(packed)
        save_json(OUT/'anchors.json',tables)
    if not sample:save_json(OUT/'model-sources.json',dependencies)
    save_json(cache_path.with_suffix('.tmp'),cache if sample else {key:cache[key] for key in used_cache});cache_path.with_suffix('.tmp').replace(cache_path)
    print('ATTACHMENTS',dict(Counter(r['method'] for r in audit)),flush=True)


def check_local():
    errors=[];path=OUT/'preservation.json'
    if not path.exists():return ['Missing recovered cosmetic preparation']
    saved=json.loads(path.read_text())
    for group in ['inputs','outputs']:
        for file,expected in saved[group].items():
            path=ROOT/file
            if not path.exists() or digest(path)!=expected:errors.append('Stale cosmetic '+group+': '+file+'; rebuild with prepare_crossgate_cosmetics.py')
    for image in OUT.glob('*.png'):
        settings=Path(str(image)+'.import')
        if not settings.exists() or 'process/fix_alpha_border=true' not in settings.read_text():errors.append('Cosmetic transparent-edge correction is missing: '+str(image))
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true');parser.add_argument('--sample',action='store_true')
    parser.add_argument('--extend-heads-from',type=Path,help='Reuse preserved attachments only when every previous head record is unchanged')
    args=parser.parse_args()
    if args.check:
        errors=check_local();print('\n'.join(errors) if errors else 'Cosmetic source/atlas preservation passed.');raise SystemExit(bool(errors))
    sys.path.insert(0,str(SOURCE/'tools'))
    import cg_assets as cg
    import cg_wardrobe as wardrobe
    REPORT.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    if not args.sample:prepare_items(cg,wardrobe)
    prepare_anchors(cg,wardrobe,args.sample,args.extend_heads_from)
    if not args.sample:
        inputs=json.loads((OUT/'model-sources.json').read_text());inputs[str(Path(__file__).relative_to(ROOT))]=digest(Path(__file__))
        inputs['tools/crossgate_head_fit.c']=digest(ROOT/'tools/crossgate_head_fit.c')
        for file in ['tools/prepare_shin_red_lightning_run.py',
                     'assets/characters/crossgate/shin/900050/polearm/item.png',
                     'assets/characters/crossgate/shin/900050/axe/item.png']:
            inputs[file]=digest(ROOT/file)
        outputs={str(p.relative_to(ROOT)):digest(p) for p in OUT.iterdir() if p.suffix in ['.png','.json','.bin'] and p.name not in ['preservation.json','sample-anchors.json','head-fits.json']}
        save_json(OUT/'preservation.json',dict(inputs=inputs,outputs=outputs))


if __name__=='__main__':main()
