"""Recover native trial surfaces and publish only their reviewed geometry fits."""
import argparse
from collections import deque
import json
from pathlib import Path
from PIL import Image, ImageFilter
import recover_elsa_island as source

PROPS=source.ROOT/'assets/maps/falan/elsa/props'
TERRAIN=source.ROOT/'assets/maps/falan/elsa/scenery/terrain'
OUT=source.REPORT/'Trial Wall Candidate'
TOKENS=['549','562','563']


def native_draw_signature(ident, rect, members):
    """Hash the exact ordered static drawing inputs, without decoding every tile."""
    width,_,planes=source.reference_map(ident);cuts=source.cut_records(ident)
    allowed={tuple(cell) for member in members for cell in member['cells']};rows=[]
    for layer in range(2):
        for index,serial in enumerate(planes[layer]):
            if serial<1000 or layer==1 and (index%width,index//width) not in allowed:continue
            record=cuts[serial-1000];master,mode,x,y,w,h,ax,ay=record
            if not w or not h:continue
            u=(index%width+index//width)*32-ax;v=(index//width-index%width)*24-ay
            if u+w<=rect[0] or v+h<=rect[1] or u>=rect[2] or v>=rect[3]:continue
            header=source.cut_header(ident)
            assert serial-1000<header[2]+header[3], 'An animated crop needs frame/palette evidence in its signature'
            rows.append([layer,u,v,master,mode,x,y,w,h])
    return source.sha(json.dumps(rows,separators=(',',':')).encode()),len(rows)


def prepare_entrance(publish=False):
    """Recover identical native openings and optionally publish the reviewed fit."""
    from prepare_elsa_gate import native_layers
    from prepare_elsa_inner_hall import portal_edges
    props=json.loads((PROPS/'data.json').read_text());group=props['groups']['562']
    placements=[(int(ident),p) for ident,rows in props['maps'].items() for p in rows if p['group']=='562']
    assert len(placements)==56 and {tuple(p['anchor']) for _,p in placements}=={(4544,1008)}
    links=json.loads((source.ROOT/'assets/maps/falan/elsa/links.json').read_text())
    crossing=[r for r in links if r['source']==59603 and r['cell']==[45,95]]
    assert len(crossing)==1 and crossing[0]['target']==59602 and crossing[0]['landing']==[66,75]
    rect=(4256,784,4736,1328);roi=[4416,1120,4544,1201]
    signature,count=native_draw_signature(59603,roi,props['maps']['59603'])
    proofs={};surroundings={}
    for ident,_ in placements:
        digest,draws=native_draw_signature(ident,roi,props['maps'][str(ident)])
        assert (digest,draws)==(signature,count),('Recess source art differs',ident)
        full,full_count=native_draw_signature(ident,rect,props['maps'][str(ident)])
        surroundings.setdefault(full,[]).append(ident)
        proofs[str(ident)]={'recess_draw_sha256':digest,'recess_draws':draws,'surrounding_draw_sha256':full,'surrounding_draws':full_count}
    assert sorted(len(ids) for ids in surroundings.values())==[8,48], 'Review changed surrounding source groups'
    foreground,background=native_layers(props['maps']['59603'],rect,59603)
    composite=background.copy();composite.alpha_composite(foreground)
    seed=(4480,1170);seen={seed};queue=deque([seed])
    def dark(x,y):
        r,g,b,a=composite.getpixel((x-rect[0],y-rect[1]));return a<128 or max(r,g,b)<=5
    assert dark(*seed)
    while queue:
        x,y=queue.popleft()
        for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
            p=x+dx,y+dy
            if p not in seen and roi[0]<=p[0]<roi[2] and roi[1]<=p[1]<roi[3] and dark(*p):seen.add(p);queue.append(p)
    rows={}
    for x,y in seen:rows.setdefault(y,[]).append(x)
    spans={str(y):[min(xs),max(xs)+1] for y,xs in sorted(rows.items())}
    paint=Image.new('RGBA',(roi[2]-roi[0],roi[3]-roi[1]));last_full=1197
    for y in range(min(rows),1201):
        span=spans.get(str(min(y,last_full)))
        if not span:continue
        for x in range(*span):
            color=composite.getpixel((x-rect[0],y-rect[1]))
            paint.putpixel((x-roi[0],y-roi[1]),(*color[:3],255) if color[3] else (0,0,0,255))
    shade=composite.getpixel((4460-rect[0],1160-rect[1]));assert shade==(3,0,0,255)
    # A hidden two-pixel lap closes subpixel BG/FG separation at the dark edge.
    backing=Image.new('RGBA',paint.size,(*shade[:3],0))
    backing.putalpha(paint.getchannel('A').filter(ImageFilter.MaxFilter(5)))
    backing.paste(paint,(0,0),paint.getchannel('A'))
    backing_rows={}
    alpha=backing.getchannel('A')
    for y in range(backing.height):
        bounds=alpha.crop((0,y,backing.width,y+1)).getbbox()
        if bounds:backing_rows[str(y+roi[1])]=[bounds[0]+roi[0],bounds[2]+roi[0]]
    folder=source.REPORT/'Arch Map Variants/Prepared Entrance';folder.mkdir(parents=True,exist_ok=True)
    paint.save(folder/'recess-paint.png')
    backing.save(folder/'backing-paint.png')
    data={'group':'562','source_map':59603,'maps':sorted(ident for ident,_ in placements),'anchor':[4544,1008],
          'front_rect':[4416,960,4544,1248],'foot_v':24*(95-45),'transition_pixels':64,'foreground_offset':.03,
          'native_rect':roi,'rows':spans,'backing_rows':backing_rows,'backing_margin_pixels':2,'lower_continuation_from':last_full,'inferred_depth':.75,'candidate_paint':'backing-paint.png',
          'edges':portal_edges(paint),'intrados_rgb':list(shade[:3]),'crossing':crossing[0],
          'source_rect':list(rect),'source_composite_rgba_sha256':source.sha(composite.tobytes()),
          'foreground_rgba_sha256':group['rgba_sha256'],'recess_paint_rgba_sha256':source.sha(paint.tobytes()),
          'backing_paint_rgba_sha256':source.sha(backing.tobytes()),
          'map_source_proofs':proofs,'surrounding_source_groups':surroundings,'candidate_only':True,
          'inferred':['Front plane,64px transition and0.75m hidden recess depth are inferred from the visible opening and documented crossing.',
                      'The final three rows continue the last complete opening span to walking height. A two-pixel hidden lap closes the separated BG/FG edge using its original dark inner color. No room, route or collision is added.'],
          'inferred_floor_thickness':.5,
          'limits':['All56 maps have identical ordered native drawing inputs in the recess crop. The broader surroundings have separate48-map/eight-map source groups; retain their original artwork. Walking ownership/depth fits can still differ.',
                    'This preparation does not activate geometry. Fixed approach/side views and transfer checks remain required.']}
    (folder/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_ENTRANCE_SOURCE',len(proofs),'maps;',count,'identical recess drawing inputs;',len(surroundings),'surrounding source groups; prepared, not activated',flush=True)
    if publish:
        runtime=source.ROOT/'assets/maps/falan/elsa/scenery/trial-entrance';runtime.mkdir(exist_ok=True)
        backing.save(runtime/'paint.png');Image.new('RGB',(1,1),shade[:3]).save(runtime/'inner-edge.png')
        data['candidate_only']=False
        data['candidate_paint']='paint.png'
        data['limits'][-1]='Published after source proof and scoped fixed-view review. Full surrounding architecture and final gameplay checks remain open.'
        data['inferred'].append('A half-meter underside continues the source opening base entirely below the original walking floor; no collision, sill or walking space is added.')
        (runtime/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
        path=source.ROOT/'assets/maps/falan/elsa/scenery/trial-surfaces/562.json'
        fit=json.loads(path.read_text());assert set(fit['map_templates'])==set(proofs)
        fit['entrance']='res://assets/maps/falan/elsa/scenery/trial-entrance/data.json'
        raw=json.dumps(fit,ensure_ascii=False,separators=(',',':'))+'\n';path.write_text(raw)
        props['groups']['562']['source_surface']['sha256']=source.sha(raw.encode())
        (PROPS/'data.json').write_text(json.dumps(props,ensure_ascii=False,separators=(',',':'))+'\n')
        print('ELSA_ENTRANCE_PUBLISHED 56 source-proven maps; two background fits retained; no map/trigger/collision edits',flush=True)


def background_walls(ident):
    record=json.loads((TERRAIN/f'{ident}.json').read_text())
    geometry=json.loads((TERRAIN/record['template']).read_text())
    width,height,planes=source.reference_map(ident)
    cuts=source.cut_records(ident)
    surfaces={}
    for key,token in geometry['placements'].items():
        i=int(key);cut=cuts[planes[0][i]-1000]
        u=(i%width+i//width)*32-cut[6];v=(i//width-i%width)*24-cut[7]
        profile=geometry['profiles'][token]
        for role,quad in zip(profile['roles'],profile['quads']):
            if role:surfaces[u+quad[0],v+quad[1]]=quad[4:]
    return record,surfaces


def build(publish=False):
    props=json.loads((PROPS/'data.json').read_text())
    record,surfaces=background_walls(59609)
    groups={}
    for token in TOKENS:
        group=props['groups'][token];x,y,w,h=group['rect']
        art=Image.open(PROPS/f"atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        placements=[(ident,p) for ident,rows in props['maps'].items() for p in rows if p['group']==token]
        anchors={tuple(p['anchor']) for ident,p in placements}
        assert len(anchors)==1,(token,anchors)
        anchor=next(iter(anchors));u=anchor[0]+group['origin'][0];v=anchor[1]+group['origin'][1]
        assert u%8==v%8==w%8==h%8==0
        quads=[];roles=[];missing=[];blue=0;matched=0
        for yy in range(0,h,8):
            for xx in range(0,w,8):
                drops=surfaces.get((u+xx,v+yy));roles.append(int(drops is not None))
                quads.append([xx,yy,8,8,*(drops if drops is not None else [0]*4)])
                pixels=[c for c in art.crop((xx,yy,xx+8,yy+8)).getdata() if c[3]]
                count=sum(b>r*1.08 and b>g*1.05 for r,g,b,a in pixels)
                blue+=count
                if drops is not None:matched+=count
                elif count:missing.append(dict(rect=[xx,yy,8,8],blue_pixels=count))
        groups[token]=dict(master=group['master'],size=group['size'],origin=group['origin'],anchor=list(anchor),
            source_rgba_sha256=group['rgba_sha256'],placements=len(placements),maps=sorted(int(ident) for ident,p in placements),
            quads=quads,roles=roles,blue_pixels=blue,blue_pixels_on_existing_wall=matched,unmatched=missing)
        print('ELSA_TRIAL_SURFACE_CANDIDATE',token,'placements',len(placements),'blue',blue,'mapped',matched,'unmatched patches',len(missing),flush=True)
    OUT.mkdir(parents=True,exist_ok=True)
    data=dict(source_map=59609,background_template=record['template'],groups=groups,
        limits=['Candidate only; no runtime activation or source atlas/navigation edits.',
                'Original RGBA, native UV scale and one repeated anchor per group are retained.',
                'Existing BG wall quads provide source-fitted ledges and native vertical pixel spacing.',
                'Unmatched blue patches require explicit source review; zero placeholders are not accepted geometry.',
                'A runtime fit still needs normal/side captures and closed hidden surfaces where reachable.'])
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    if publish:
        # Only this reviewed arch has complete blue-pixel coverage. Other
        # candidates remain staged until their unmatched patches are resolved.
        row=groups['562'];assert row['blue_pixels']==row['blue_pixels_on_existing_wall'] and not row['unmatched']
        # Identical FG art spans two BG fits. Share meshes only when their
        # actual background depth agrees, rather than using59609 everywhere.
        variants={};map_templates={};group=props['groups']['562']
        u=row['anchor'][0]+group['origin'][0];v=row['anchor'][1]+group['origin'][1]
        for ident in row['maps']:
            background,wall=background_walls(ident);quads=[];roles=[]
            for q in row['quads']:
                drops=wall.get((u+q[0],v+q[1]));roles.append(int(drops is not None))
                quads.append(q[:4]+(drops if drops is not None else [0]*4))
            key=background['template'];map_templates[str(ident)]=key
            if key in variants:
                assert variants[key]['quads']==quads and variants[key]['roles']==roles,(ident,key)
            else:variants[key]=dict(source_map=ident,background_template=key,quads=quads,roles=roles)
        assert len(map_templates)==56 and len(variants)==2
        folder=source.ROOT/'assets/maps/falan/elsa/scenery/trial-surfaces';folder.mkdir(exist_ok=True)
        entrance={'entrance':'res://assets/maps/falan/elsa/scenery/trial-entrance/data.json'} if (source.ROOT/'assets/maps/falan/elsa/scenery/trial-entrance/data.json').exists() else {}
        raw=json.dumps(dict(row,**entrance,background_template=record['template'],source_map=59609,variants=variants,map_templates=map_templates,
            source='Original FG paint follows each map\'s existing BG geometry with a 3 cm surface offset. Two depth fits share the same original UV scale, placement and alpha; walking data is unchanged. Hidden geometry remains owned by the existing cliff fit. The primary blue-pixel coverage describes59609 only; variants follow their own BG wall/floor roles.'),separators=(',',':'))+'\n'
        target=folder/'562.json';target.write_text(raw)
        props['groups']['562']['source_surface']=dict(path='res://assets/maps/falan/elsa/scenery/trial-surfaces/562.json',sha256=source.sha(raw.encode()))
        path=PROPS/'data.json';temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(props,ensure_ascii=False,separators=(',',':'))+'\n');temporary.replace(path)
        print('ELSA_TRIAL_SURFACE_PUBLISHED 562: 56 placements; 2 shared depth variants match all56 original BG fits',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--publish-reviewed',action='store_true');parser.add_argument('--entrance-candidate',action='store_true');parser.add_argument('--publish-entrance',action='store_true')
    args=parser.parse_args()
    if args.entrance_candidate or args.publish_entrance:prepare_entrance(args.publish_entrance)
    else:build(args.publish_reviewed)
