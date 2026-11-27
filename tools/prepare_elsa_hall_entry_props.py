"""Stage the mapped BG pedestal and source-clipped apron repairs for59530."""
import copy
import json
import math
import argparse
import shutil
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter
import recover_elsa_island as source
from prepare_elsa_gate import native_layers
from prepare_elsa_props import nearest_material_paint

OUT=source.REPORT/'Temple Interior/Hall Entry Candidate'
PROPS=source.ROOT/'assets/maps/falan/elsa/props'


def build():
    props=json.loads((PROPS/'data.json').read_text());group=props['groups']['406']
    x,y,w,h=group['rect']
    template=Image.open(PROPS/f"atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
    assert source.sha(template.tobytes())==group['rgba_sha256']
    origin=[4944,344] # Native mapped-paint fit; blue bounds and silhouette are checked below.
    _,original=native_layers(props['maps']['59530'],(*origin,origin[0]+w,origin[1]+h),59530)
    selection=template.getchannel('A').filter(ImageFilter.MaxFilter(3))
    for yy in range(h):
        for xx in range(w):
            color=original.getpixel((xx,yy))
            if not color[3] or max(color[:3])<=2 or yy>=148 and max(color[:3])>60:selection.putpixel((xx,yy),0)
    assert sum(p>0 for p in selection.getdata())==13946
    selected=original.copy();selected.putalpha(ImageChops.multiply(original.getchannel('A'),selection))
    blue=Image.new('L',(w,h));orb=Image.new('RGBA',(w,h))
    for yy in range(h):
        for xx in range(w):
            r,g,b,a=selected.getpixel((xx,yy))
            if a and b>r*1.1 and b>g*1.1 and b>100:blue.putpixel((xx,yy),255);orb.putpixel((xx,yy),(r,g,b,a))
    assert blue.getbbox()==(39,7,89,52)
    body=selected.copy();cap=blue.filter(ImageFilter.MaxFilter(11));body.paste((18,18,18,255),(0,0),cap)
    body_paint=nearest_material_paint(body)
    orb_paint=nearest_material_paint(orb).filter(ImageFilter.GaussianBlur(6)).convert('RGBA');orb_paint.paste(orb,(0,0),orb.getchannel('A'))
    for yy in range(h):
        for xx in range(w):
            if selection.getpixel((xx,yy)) and not cap.getpixel((xx,yy)):
                assert body_paint.getpixel((xx,yy))==original.getpixel((xx,yy))[:3]
            if blue.getpixel((xx,yy)):assert orb_paint.getpixel((xx,yy))==original.getpixel((xx,yy))
    body_paint.save(OUT/'bg-pedestal-body.png');orb_paint.save(OUT/'bg-pedestal-globe.png');selection.save(OUT/'bg-pedestal-photo-mask.png')
    selected.save(OUT/'bg-pedestal-source.png');blue.save(OUT/'bg-pedestal-blue-mask.png');cap.save(OUT/'bg-pedestal-cap-mask.png')
    spec=copy.deepcopy(json.loads((PROPS/'pedestal-406/data.json').read_text()))
    spec.update(origin=[0,0],rgba_sha256=source.sha(selected.tobytes()),candidate_only=True)
    spec['body']['cap_paint_pixel']=[64,56]
    assert body_paint.getpixel((64,56))==(18,18,18)
    spec['orb']['centre']=[64.,29.5]
    vertical=math.sqrt(2*((32/3)**2-8**2))
    spec['orb']['source_null_lift']=spec['orb']['radius']-(38.-29.5)/vertical
    spec['paints']={k:'res://'+str((OUT/f'bg-pedestal-{name}.png').relative_to(source.ROOT)) for k,name in [('body','body'),('globe','globe')]}
    spec['geometry_template']='res://assets/maps/falan/elsa/props/pedestal-406/data.json'
    spec['source_kind']='mapped59530 BG paint;301044 geometry family only'
    spec['inferred'].append('The confirmed BG source variant reuses the reviewed406 body. Its blue mask lies one pixel lower; body depth, selection edge and hidden continuation remain inferred.')
    spec['inferred'].append('The BG top cap samples its original18,18,18 material at64,56, keeping front gold off the horizontal cap.')

    entry=json.loads((OUT/'data.json').read_text());rect=entry['rect']
    _,background=native_layers(props['maps']['59530'],tuple(rect),59530)
    assert source.sha(background.tobytes())==entry['hashes']['background']
    stairs=Image.open(OUT/'displaced-floor-mask.png').convert('L')
    bg_mask=Image.new('L',background.size);bg_mask.paste(selection,(origin[0]-rect[0],origin[1]-rect[1]))
    placement=next(p for p in props['maps']['59530'] if p['group']=='406')
    fg_origin=[placement['anchor'][a]+group['origin'][a] for a in [0,1]]
    fg_mask=Image.new('L',background.size);fg_mask.paste(template.getchannel('A').filter(ImageFilter.MaxFilter(3)),(fg_origin[0]-rect[0],fg_origin[1]-rect[1]))
    excluded=ImageChops.lighter(ImageChops.lighter(bg_mask,fg_mask),stairs)
    # These visible straight edges bracket the existing apron, not the tall images.
    probes={'left':[[4896,582],[4912,570],[4928,559],[5088,433],[5104,422],[5120,410]],
            'right':[[5440,672],[5456,660],[5472,650],[5488,638],[5504,626]]}
    for edge in probes.values():
        for u,v in edge:
            color=background.getpixel((u-rect[0],v-rect[1]));assert color[3]>200 and max(color[:3])>8
    left=max(v+.75*u for u,v in probes['left']);right=min(v+.75*u for u,v in probes['right'])
    assert (left,right)==(4255.,4752.)
    infill=Image.new('RGBA',background.size);copied=[];unfilled=[]
    fits=[]
    for doubled in range(10416,10449):
        cx=doubled/2;errors=[]
        for v in range(472,710,3):
            for u in range(5048,5210,3):
                if not 130**2<=(u-cx)**2+((v-590)/.75)**2<=173**2:continue
                a=background.getpixel((u-rect[0],v-rect[1]));b=background.getpixel((doubled-u-rect[0],v-rect[1]))
                if a[3]<255 or b[3]<255 or max(a[:3])<10 or max(b[:3])<10:continue
                errors.append(abs((a[0]-a[2])-(b[0]-b[2])))
        assert len(errors)>1000
        fits.append([sum(errors)/len(errors),cx,len(errors)])
    fits.sort();assert fits[0][1]==5213.5
    medallion=[fits[0][1],590.,170.,.75]
    offsets=[(k*64,-k*48) for k in [2,3,4,-2,-3,-4,1,-1,5,-5]]
    for yy in range(background.height):
        for xx in range(background.width):
            if stairs.getpixel((xx,yy)):continue
            old=background.getpixel((xx,yy))
            occluded=not old[3] or old[:3] in [(0,0,0),(2,2,2)]
            if not (bg_mask.getpixel((xx,yy)) or fg_mask.getpixel((xx,yy)) and occluded):continue
            u,v=rect[0]+xx,rect[1]+yy
            if not left<=v+.75*u<=right:continue
            color=None
            cx,cy,radius,aspect=medallion
            if fg_mask.getpixel((xx,yy)) and (u-cx)**2+((v-cy)/aspect)**2<=radius**2:
                su,sv=round(2*cx-u),v;sx,sy=su-rect[0],sv-rect[1]
                if 0<=sx<background.width and 0<=sy<background.height and not excluded.getpixel((sx,sy)):
                    sample=background.getpixel((sx,sy))
                    if sample[3]>200 and max(sample[:3])>8:color=sample;copied.append([u,v,su,sv])
            for dx,dy in offsets if color is None else []:
                sx,sy=xx+dx,yy+dy
                if not 0<=sx<background.width or not 0<=sy<background.height or excluded.getpixel((sx,sy)):continue
                sample=background.getpixel((sx,sy))
                if sample[3]>200 and max(sample[:3])>8 and max(sample[:3])-min(sample[:3])<28:
                    color=sample;copied.append([u,v,u+dx,v+dy]);break
            if color is None:unfilled.append([u,v]);continue
            infill.putpixel((xx,yy),color)
    assert copied and not unfilled,('Every selected repair needs a confirmed native apron sample',len(unfilled))
    coverage=infill.getchannel('A');visible=infill.copy()
    infill=nearest_material_paint(infill).convert('RGBA');infill.putalpha(coverage)
    for channel in ImageChops.difference(visible,infill).split():
        assert ImageChops.multiply(channel,coverage).getbbox() is None
    infill.save(OUT/'pedestal-apron-infill.png');bg_mask.save(OUT/'bg-pedestal-relocated-mask.png')
    combined=ImageChops.lighter(stairs,bg_mask);combined.save(OUT/'relocated-photo-mask.png')
    preview=background.copy()
    for yy in range(background.height):
        for xx in range(background.width):
            if bg_mask.getpixel((xx,yy)):preview.putpixel((xx,yy),(2,2,2,255))
    preview.alpha_composite(infill);preview.save(OUT/'apron-repair-review.png')
    assert background.getpixel((4864-rect[0],816-rect[1]))==(2,2,2,255)
    record=dict(map=59530,candidate_only=True,bg_origin=origin,native_rect=rect,spec=spec,
        map_size=list(source.reference_map(59530)[:2]),void_native_rgba=[2,2,2,255],void_native_sample=[4864,816],
        infill_path='res://'+str((OUT/'pedestal-apron-infill.png').relative_to(source.ROOT)),
        original_background_sha256=source.sha(original.tobytes()),selected_source_sha256=source.sha(selected.tobytes()),
        selection_sha256=source.sha(selection.tobytes()),blue_sha256=source.sha(blue.tobytes()),cap_sha256=source.sha(cap.tobytes()),
        body_sha256=source.sha(body_paint.tobytes()),globe_sha256=source.sha(orb_paint.tobytes()),infill_sha256=source.sha(infill.tobytes()),
        apron_edges=dict(probes=probes,conservative_parallel_strip=[left,right],equation='v+0.75*u; constant world Z'),
        fg_occlusion_padding=1,
        medallion_inference=dict(centre=medallion[:2],radius=medallion[2],aspect=medallion[3],fits=fits,method='Visible native ring chroma fits the symmetry axis. The opposite side continues the medallion beneath the original FG image; selection/continuation are inferred.'),
        repair_samples=copied,unfilled=unfilled,
        inferred=['Apron continuation is clipped to the conservative band between original visible edges, only beneath the two original pedestal photographs.',
                  'Every new paving pixel copies original paint along the same material band. The occluded medallion rim continues its visible opposite side. Source image pixels, walkability, routes and geometry footprints remain unchanged.',
                  'Transparent apron texels extend neighboring native RGB while retaining exact alpha; mipmaps must not mix the repair edge with black.',
                  'The map uses its confirmed native matte color at background depth, without collision or new terrain. It closes scene-sky gaps between original void tiles.',
                  'BG photograph selection, hidden parent paving and406 geometry reuse are inferred. Candidate only; inspect fixed actual gameplay views before publication.'])
    path=OUT/'props-data.json';temp=path.with_suffix('.tmp');temp.write_text(json.dumps(record,ensure_ascii=False,separators=(',',':'))+'\n');temp.replace(path)
    print('ELSA_HALL_ENTRY_PROPS mapped BG pedestal;',len(copied),'source-band apron samples; outside-apron void preserved; candidate only',flush=True)


def publish():
    from prepare_elsa_hall_entry_floor import CANON, build as floor_build
    record=json.loads((OUT/'props-data.json').read_text());CANON.mkdir(exist_ok=True)
    for name in ['bg-pedestal-body.png','bg-pedestal-globe.png','pedestal-apron-infill.png',
                 'bg-pedestal-source.png','bg-pedestal-photo-mask.png','bg-pedestal-blue-mask.png','bg-pedestal-cap-mask.png',
                 'displaced-floor-mask.png','relocated-photo-mask.png']:
        shutil.copyfile(OUT/name,CANON/name)
    record['candidate_only']=False;record['spec']['candidate_only']=False
    for key in record['spec']['paints']:
        name=Path(record['spec']['paints'][key]).name
        record['spec']['paints'][key]='res://'+str((CANON/name).relative_to(source.ROOT))
    record['infill_path']='res://'+str((CANON/'pedestal-apron-infill.png').relative_to(source.ROOT))
    record['inferred'][-1]='BG photograph selection, hidden parent paving and406 geometry reuse are inferred. Original client heights and live3D behavior do not exist in the archive.'
    floor_build(pedestals_only=True)
    path=CANON/'data.json';temp=path.with_suffix('.tmp');temp.write_text(json.dumps(record,ensure_ascii=False,separators=(',',':'))+'\n');temp.replace(path)
    print('ELSA_ENTRY_PEDESTALS_PUBLISHED source paint/parent apron only; negative stair candidate remains private',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--publish',action='store_true');args=parser.parse_args()
    build()
    if args.publish:publish()
