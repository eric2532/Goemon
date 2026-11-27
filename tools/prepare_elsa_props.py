"""Reassemble native CUT fragments into coherent original scenery objects."""
from collections import defaultdict
import argparse
import json
import math
import random
import itertools
import statistics
from collections import deque
from PIL import Image, ImageChops, ImageFilter
import recover_elsa_island as source
from prepare_elsa_scenery import outline, solid_pages, TOWER_MASTERS

OUT=source.ROOT/'assets/maps/falan/elsa/props'

# Four brown top-surface crops, distinct from the blue wall/arch crops in the
# same native sheet. Verified against 59609 BG+FG and its original walking mask.
TRIAL_CAPS={
    (300374,(-320,-192),(640,432)),
    (300375,(-320,-192),(384,144)),
    (300943,(0,-48),(192,288)),
    (300943,(-320,-240),(192,480)),
}


def fit_trial_caps(data):
    count=0
    for group in data['groups'].values():
        key=(group['master'],tuple(group['origin']),tuple(group['size']))
        if key not in TRIAL_CAPS:continue
        group['grounded']=[dict(box=[0,0,*group['size']],flat=True)]
        group['native_floor_cap']=dict(source_map=59609,
            source='Original brown cap crops in BG+FG composite and walking-mask review. Blue cliff/arch fragments remain separate. Original pixels, anchors, blocked cells and crossings are unchanged; no new walkable surface is added.')
        if key==(300943,(-320,-240),(192,480)):
            # The two embedded pillars match the already fitted 300938 post.
            # Sparse visible RGB comparison gives 4.67/4.71 mean channel error
            # at these native translations; adjacent offsets score worse.
            template=next(g for g in data['groups'].values() if g['master']==300938 and g['origin']==[0,-240] and g['size']==[64,192])
            def crop(g):
                x,y,w,h=g['rect'];return Image.open(OUT/f"atlas-{g['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
            art=crop(group);post=crop(template);mask=Image.new('L',art.size);columns=[]
            for dx,dy in [(65,-8),(2,88)]:
                layer=Image.new('L',art.size);layer.paste(post.getchannel('A'),(dx,dy));mask=ImageChops.lighter(mask,layer)
                fit=json.loads(json.dumps(template['columns'][0]));fit['foot']=[fit['foot'][0]+dx,fit['foot'][1]+dy]
                fit['profile']=[[x+dx,y+dy,width] for x,y,width in fit['profile']]
                fit['box']=[fit['box'][0]+dx,fit['box'][1]+dy,fit['box'][2]+dx,fit['box'][3]+dy]
                fit['paint_rows']=True # Keep cap/neighbor paint off the round base and reverse face.
                columns.append(fit)
            group['columns']=columns
            mask=ImageChops.multiply(mask.filter(ImageFilter.MaxFilter(3)),art.getchannel('A'))
            seeds=art.copy();pixels=seeds.load();covered=mask.load()
            for y in range(art.height):
                for x in range(art.width):
                    r,g,b,a=pixels[x,y]
                    if covered[x,y] or not(a and r>15 and 1.02*g<r<1.55*g and 1.03*b<g<1.8*b):pixels[x,y]=(0,0,0,0)
            from prepare_elsa_gate import native_layers
            placement=next(p for p in data['maps']['59609'] if p['group'] in data['groups'] and data['groups'][p['group']] is group)
            u=placement['anchor'][0]+group['origin'][0];v=placement['anchor'][1]+group['origin'][1]
            _,background=native_layers([],(u,v,u+art.width,v+art.height),59609)
            blank=ImageChops.multiply(mask,ImageChops.invert(background.getchannel('A')))
            infill=background.copy()
            if blank.getbbox():infill.paste(nearest_material_paint(seeds),(0,0),ImageChops.invert(background.getchannel('A')))
            paint=art.copy();paint.paste(infill,(0,0),mask);paint.putalpha(art.getchannel('A'))
            paint.save(OUT/'trial-cap-300943-floor.png');mask.save(OUT/'trial-cap-300943-infill-mask.png')
            group['floor_paint']=dict(path='res://assets/maps/falan/elsa/props/trial-cap-300943-floor.png',rgba_sha256=source.sha(paint.tobytes()),
                mask='res://assets/maps/falan/elsa/props/trial-cap-300943-infill-mask.png',mask_sha256=source.sha(mask.tobytes()),
                background_native_rect=[u,v,art.width,art.height],background_rgba_sha256=source.sha(background.tobytes()),inferred_blank_pixels=sum(bool(p) for p in blank.getdata()),
                inference='Original BG ground beneath the two FG pillars. Only missing BG pixels require inferred nearby brown paint. Original cap alpha and all pixels outside the infill mask remain unchanged; hidden pillar depth is inferred.')
            group['native_floor_cap']['pillars']=dict(template_master=300938,template_rgba_sha256=template['rgba_sha256'],translations=[[65,-8],[2,88]],mean_rgb_error=[4.665204678362573,4.714912280701754])
        count+=1
    assert count==4,('Expected four reviewed native cap crops',count)
    print('ELSA_TRIAL_CAPS',count,'original top-surface templates; no atlas or navigation changes',flush=True)


def retain_prepared_surfaces(data):
    folder=source.ROOT/'assets/maps/falan/elsa/scenery/trial-surfaces'
    for path in folder.glob('*.json'):
        raw=path.read_bytes();spec=json.loads(raw)
        matches=[(token,g) for token,g in data['groups'].items() if g['master']==spec['master'] and g['origin']==spec['origin'] and g['rgba_sha256']==spec['source_rgba_sha256']]
        assert len(matches)==1,('Prepared cliff surface requires source review',path,matches)
        token,group=matches[0]
        assert all(p['anchor']==spec['anchor'] for rows in data['maps'].values() for p in rows if p['group']==token)
        if 'variants' in spec:
            maps={ident for ident,rows in data['maps'].items() if any(p['group']==token for p in rows)}
            assert set(spec['map_templates'])==maps,('Prepared surface map coverage changed',path)
            for ident,key in spec['map_templates'].items():
                background=json.loads((source.ROOT/f'assets/maps/falan/elsa/scenery/terrain/{ident}.json').read_text())
                assert key==background['template'] and key in spec['variants'],('Rebuild the map-specific BG fit',ident,path)
        group['source_surface']=dict(path='res://'+str(path.relative_to(source.ROOT)),sha256=source.sha(raw))


def alpha_parts(art):
    alpha=art.getchannel('A');pixels=alpha.load()
    occupied={(x,y) for y in range(art.height) for x in range(art.width) if pixels[x,y]>0};parts=[]
    while occupied:
        start=occupied.pop();queue=deque([start]);component=[]
        while queue:
            cx,cy=queue.popleft();component.append((cx,cy))
            for p in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]:
                if p in occupied:occupied.remove(p);queue.append(p)
        parts.append([min(p[0] for p in component),min(p[1] for p in component),
                      max(p[0] for p in component)+1,max(p[1] for p in component)+1])
    return sorted(parts)


def prepare_edges(data):
    pages={}
    for group in data['groups'].values():
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h))
        group['edges']=outline(art)
        for part in group.get('grounded',[]):
            if not part['flat']:part['edges']=outline(art.crop(tuple(part['box'])))
    print('ELSA_OPAQUE_EDGE_SAMPLES',len(data['groups']),'coherent objects; original atlases unchanged')


def assemble_spires(groups,images,maps):
    result=[];dedup={}
    for body in maps['59520']:
        if groups[body['group']]['master']!=300788:continue
        u,v=body['anchor']
        tip=next(p for p in maps['59520'] if groups[p['group']]['master']==300789 and p['anchor'][0]==u and abs(p['anchor'][1]-(v-480))<=1)
        base=next(p for p in maps['59520'] if groups[p['group']]['master']==300791 and p['anchor']==[u-223,v+4])
        members=[tip,body,base];rects=[]
        for p in members:
            g=groups[p['group']];x=p['anchor'][0]+g['origin'][0];y=p['anchor'][1]+g['origin'][1]
            rects.append((x,y,images[int(p['group'])]))
        left=min(x for x,y,a in rects);top=min(y for x,y,a in rects)
        right=max(x+a.width for x,y,a in rects);bottom=max(y+a.height for x,y,a in rects)
        art=Image.new('RGBA',(right-left,bottom-top))
        for x,y,a in rects:art.alpha_composite(a,(x-left,y-top))
        origin=[left-u,top-v];key=(source.sha(art.tobytes()),tuple(origin))
        if key not in dedup:
            token=str(len(images));dedup[key]=token;images.append(art)
            groups[token]=dict(master=300788,origin=origin,rgba_sha256=key[0],edges=outline(art),size=list(art.size),spire=True,
                               source_masters=[300788,300789,300791])
        result.append(dict(group=dedup[key],anchor=body['anchor'],members=members))
    assert len(result)==5
    return result


def fit_ground(data):
    """Only native treads, landings and floor panels belong on walkable ground."""
    floor_forms={
        (301045,(-192,-240),(512,480)):'temple landing',
        (301046,(-128,-240),(448,432)):'temple stairs',
        (301054,(-320,-240),(320,192)):'spiral stairs',
        (301054,(-192,0),(128,96)):'spiral stairs',
        (301054,(-320,-48),(128,144)):'spiral stairs',
        **{(301053,(-320,v),(192,96)):'blue floor panel' for v in [-240,-144,-48]},
        (301295,(192,144),(128,96)):'metal stair opening',
        (301295,(192,0),(128,144)):'metal stairs',
        (301295,(64,144),(128,96)):'metal stair opening',
        (301295,(64,0),(128,144)):'metal stairs',
    }
    for group in data['groups'].values():
        group.pop('ground_role',None);group.pop('floor_only',None)
        key=(group['master'],tuple(group['origin']),tuple(group['size']))
        if key in floor_forms:
            group['ground_role']=floor_forms[key]
            if floor_forms[key] in ['blue floor panel','metal stair opening']:group['floor_only']=True
    for ident,placements in data['maps'].items():
        width,height,planes=source.reference_map(int(ident))
        for placement in placements:
            placement.pop('ground_cells',None)
            if placement.get('empty_cut'):continue
            group=data['groups'][placement['group']]
            if not group.get('ground_role'):continue
            ox,oy=group['origin'];_,_,w,h=group['rect'];u,v=placement['anchor']
            corners=[((u+px)*3/64-(v+py)/16,(u+px)*3/64+(v+py)/16)
                     for px,py in [(ox,oy),(ox+w,oy),(ox+w,oy+h),(ox,oy+h)]]
            cells=[]
            for y in range(max(0,int(min(p[1] for p in corners)/3-.5)),min(height,int(max(p[1] for p in corners)/3+.5)+1)):
                for x in range(max(0,int(min(p[0] for p in corners)/3-.5)),min(width,int(max(p[0] for p in corners)/3+.5)+1)):
                    if not planes[2][y*width+x]:cells.append([x,y])
            if cells:placement['ground_cells']=cells
    print('ELSA_ARCHITECTURE_GROUND',sum(len(p.get('ground_cells',[])) for rows in data['maps'].values() for p in rows),'original walkable cells before rectangle clipping')


def fit_bridges(data):
    pages={};count=0
    for group in data['groups'].values():
        if group['master'] not in [300814,300815] or group['origin']!=[-320,-240] or group['size']!=[256,480]:continue
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h));pixels=art.load();samples=[];feet=[];widths=[]
        for yy in range(0,h,4):
            marks=[xx for xx in range(w) if pixels[xx,yy][3] and pixels[xx,yy][1]>110 and pixels[xx,yy][1]-pixels[xx,yy][0]>20 and pixels[xx,yy][2]-pixels[xx,yy][1]>25]
            if marks:samples.append((yy,max(marks)));widths.append(max(marks)-min(marks)+1)
            marks=[xx for xx in range(w) if pixels[xx,yy][3]]
            if marks:feet.append((yy,max(marks)))
        slopes=[(b[1]-a[1])/(b[0]-a[0]) for a in samples[::4] for b in samples[::4] if b[0]-a[0]>h*.5]
        slope=statistics.median(slopes);intercept=statistics.median(u-slope*v for v,u in samples)
        footer=statistics.median(u-slope*v for v,u in feet);height=(footer-intercept)/-slope
        assert slope<-.1
        assert height>0
        mask=art.getchannel('A');quads=[]
        for yy in range(0,h,4):
            for xx in range(0,w,4):
                if mask.crop((xx,yy,xx+4,yy+4)).getbbox():quads.append([xx,yy,4,4])
        group['bridge']=dict(edge=[slope,intercept],footer=footer,height_pixels=height,depth_pixels=statistics.median(widths)+8,quads=quads,
                             source='Original bright blue deck and gray lower footer. The level decorative span is raised above its original grounded arch face. It adds no walkable ground or crossing; hidden thickness is inferred.')
        count+=1
    print('ELSA_BRIDGE_FITS',count,'original level decks and lower arch faces')
    if count:
        import prepare_elsa_gate as gates
        placement=next(p for p in data['maps']['59520'] if data['groups'][p['group']]['master']==300814 and 'bridge' in data['groups'][p['group']])
        group=data['groups'][placement['group']];fit=group['bridge'];u0=placement['anchor'][0]+group['origin'][0];v0=placement['anchor'][1]+group['origin'][1]
        rect=(11940,-1160,12040,-760);_,background=gates.native_layers([],rect);tile=Image.new('RGBA',(64,48))
        for y in range(tile.height):
            for x in range(64):
                u=11950+x;v=round(v0+(u-u0-fit['footer'])/fit['edge'][0]+40+y)
                tile.putpixel((x,y),background.getpixel((u-rect[0],v-rect[1])))
        tile.save(OUT/'wall-inner.png')
        data['bridge_inner']=dict(origin_u=11950,below_footer=40,slope=fit['edge'][0],footer=fit['footer'],wall_origin=[u0,v0],rgba_sha256=source.sha(tile.tobytes()),
            source='Original background masonry unskewed along the native wall plane. Repetition on the unseen inner face is inferred; foreground cap paint is unchanged.')
        for group in data['groups'].values():
            if 'bridge' in group:group['bridge']['inner']='res://assets/maps/falan/elsa/props/wall-inner.png'


def mark_empty_crops(data):
    for ident,placements in data['maps'].items():
        records=source.cut_records(int(ident))
        for p in placements:
            p.pop('empty_cut',None)
            if all(records[serial-1000][4:6]==(0,0) for serial in p['pieces']):p['empty_cut']=True
    print('ELSA_ZERO_AREA_CROPS',sum(bool(p.get('empty_cut')) for rows in data['maps'].values() for p in rows),'nonvisual placements; diagnostic masters retained')


def fit_trees(data):
    pages={}
    for group in data['groups'].values():
        master=group['master']
        if master not in range(300795,300805):continue
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h));boxes=[]
        slices=[(0,0,w//2,h),(w//2,0,w,h)] if master in [300795,300799] and w>450 else [(0,0,w,h)]
        for left,top,right,bottom in slices:
            box=art.crop((left,top,right,bottom)).getbbox()
            if box:boxes.append([left+box[0],top+box[1],left+box[2],top+box[3]])
        group['tree']=dict(boxes=boxes,model='res://assets/models/environments/palm.glb' if master==300804 else
                           'res://assets/models/environments/wind_meadow/crossgate_flora/'+('cg_evergreen' if master==300803 else 'cg_woodland')+'.glb')
    print('ELSA_COHERENT_TREES',sum(len(g.get('tree',{}).get('boxes',[])) for g in data['groups'].values()),'source forms before instancing')


def fit_columns(data):
    pages={}
    for group in data['groups'].values():
        if group['master'] not in [301039,301049,301050,301051] and not group.get('spire'):continue
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h));box=art.getbbox()
        if not box or box[3]-box[1]<(box[2]-box[0])*1.6:continue
        alpha=art.getchannel('A');pixels=alpha.load();foot_x=(box[0]+box[2])*.5
        foot_y=box[3]-(box[2]-box[0])*.25;profile=[]
        for row in [int(foot_y),*range(int(foot_y)-4,box[1]-1,-4),box[1]]:
            marks=[col for col in range(box[0],box[2]) if pixels[col,row]>0]
            if not marks:continue
            profile.append([round((marks[0]+marks[-1])*.5,4),row,marks[-1]-marks[0]+1])
        group['column']=dict(foot=[foot_x,foot_y],profile=profile)
    print('ELSA_COLUMN_FITS',sum('column' in g for g in data['groups'].values()),'source silhouettes')


def prepare_pedestal_candidate(data=None, runtime=False):
    """Recover separate source sections, optionally enrolling the reviewed fit."""
    data=json.loads((OUT/'data.json').read_text()) if data is None else data;group=data['groups']['406']
    assert (group['master'],group['origin'],group['size'])==(301044,[-192,48],[128,192])
    x,y,w,h=group['rect'];original=Image.open(OUT/f"atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
    assert source.sha(original.tobytes())==group['rgba_sha256']
    blue=Image.new('L',original.size);orb=Image.new('RGBA',original.size)
    for y in range(h):
        for x in range(w):
            r,g,b,a=original.getpixel((x,y))
            if a and b>r*1.1 and b>g*1.1 and b>100:blue.putpixel((x,y),255);orb.putpixel((x,y),(r,g,b,a))
    assert blue.getbbox()==(39,6,89,51)
    gray=[original.getpixel((x,y)) for y in [144,145] for x in range(18,112) if original.getpixel((x,y))[3]>0]
    assert len(gray)==168 and all(max(c[:3])-min(c[:3])<=5 for c in gray), 'Molding continuation must use the original visible gray material, never the gold band'
    body=original.copy();mask=blue.filter(ImageFilter.MaxFilter(11));body.paste((18,18,18,255),(0,0),mask)
    target=OUT/'pedestal-406' if runtime else source.REPORT/'Temple Interior';target.mkdir(exist_ok=True)
    if not runtime:original.save(target/'406-original.png');blue.save(target/'406-orb-mask.png')
    body_paint=nearest_material_paint(body)
    assert all(max(c[:3])-min(c[:3])<=5 for y in [144,145] for x in range(18,112) for c in [body_paint.getpixel((x,y))]), 'Inferred edge continuation must keep the molding gray'
    body_path=target/('body.png' if runtime else '406-body-candidate.png');body_paint.save(body_path)
    # Nearest-seed fill leaves long axis stripes outside the photographed orb.
    # Soften only that inferred continuation, then restore every source pixel.
    orb_paint=nearest_material_paint(orb).filter(ImageFilter.GaussianBlur(6)).convert('RGBA')
    orb_paint.paste(orb,(0,0),orb.getchannel('A'))
    assert all(orb_paint.getpixel((x,y))==original.getpixel((x,y)) for y in range(h) for x in range(w) if blue.getpixel((x,y))), 'Original photographed globe pixels must remain exact'
    orb_path=target/('globe.png' if runtime else '406-orb-candidate.png');orb_paint.save(orb_path)
    vertical=math.sqrt(2*((32/3)**2-8**2));radius=50/30.16989
    # Front octagon: the84-pixel body has31.5px projected depth. Its last
    # visible front edge is178, fixing the inferred center at146.5.
    rows=[(146.5,84),(114.5,84),(112.5,95),(108.5,95),(110.5,84),(76,84),(38,84)]
    result=dict(group='406',master=301044,origin=group['origin'],size=group['size'],rgba_sha256=group['rgba_sha256'],
        body=dict(foot=[64.5,146.5],profile=[[64.5,v,width/math.cos(math.pi/8)] for v,width in rows],paint_rows=False,
                  native_faces=True,molding=dict(min_row=108.4,max_row=114.6,paint_row=144.5)),
        orb=dict(centre=[64.,28.5],radius=radius,cap_native_row=38.,source_null_lift=radius-(38-28.5)/vertical),
        source_sections=dict(body_width=84,front_depth=31.5,front_base=178,front_gold_bottom=107.5,
                             front_molding_top=144.125,front_molding_bottom=148.125,molding_paint_row=144.5),
        paints=dict(body='res://'+str(body_path.relative_to(source.ROOT)),globe='res://'+str(orb_path.relative_to(source.ROOT))),
        candidate_only=not runtime,inferred=[
            'The octagonal cross-sections, four-pixel molding and146.5 native foot center reconstruct the visible front edges; hidden depth and contact remain inferred.',
            'The source body cap under the original blue component uses native18,18,18 paint. Other visible source body colors are retained.',
            'The round globe moves only along the source projection null direction until its bottom touches the cap. Its native image center stays fixed.',
            'Horizontal molding faces continue the confirmed gray front at source row144.5; native projection alone incorrectly samples the gold band above them.',
            'The globe uses the original source-camera projection across its whole round surface; planar-wall X/Z reflection is inappropriate for a sphere. Unseen blue paint is inferred from the same original material.',
            'Only pixels outside the original blue globe mask use a six-pixel softened material continuation. Every original blue source pixel is restored exactly; this avoids long nearest-fill stripes on unseen surfaces.',
            'Confirmed native faces continue around hidden sides. Original navigation, source graphics and placement are unchanged.'])
    path=target/('data.json' if runtime else '406-separated-candidate.json')
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    if runtime:group['pedestal']=dict(path='res://'+str(path.relative_to(source.ROOT)),sha256=source.sha(path.read_bytes()))
    assert abs(146.5+84*.375-178)<1e-8
    assert result['orb']['source_null_lift']>0
    print('ELSA_PEDESTAL_PUBLISHED' if runtime else 'ELSA_PEDESTAL_CANDIDATE', 'source sections and separate round globe',flush=True)


def inventory_baked_pedestals():
    """Find the same source family in actually mapped BG crops, not unused art."""
    from prepare_elsa_gate import native_layers
    from PIL import ImageDraw
    width,_,planes=source.reference_map(59530);cuts=source.cut_records(59530)
    graphics={};blue=set();draws=[]
    def is_blue(color):
        r,g,b,a=color;return a>200 and b>r*1.1 and b>g*1.1 and b>100
    for index,serial in enumerate(planes[0]):
        if serial<1000:continue
        master,mode,x,y,w,h,ax,ay=cuts[serial-1000]
        if not w or not h:continue
        if master not in graphics:
            record,art=source.graphic(master);rows=defaultdict(list)
            for i,color in enumerate(art.getdata()):
                if is_blue(color):rows[i//art.width].append(i%art.width)
            graphics[master]=(record,art,rows)
        record,art,rows=graphics[master];left=x-(320+record['x']);top=y-(240+record['y'])
        u=(index%width+index//width)*32-ax;v=(index//width-index%width)*24-ay
        draws.append(dict(cell=[index%width,index//width],serial=serial,master=master,native_rect=[u,v,w,h]))
        for yy in range(max(0,top),min(art.height,top+h)):
            for xx in rows.get(yy,[]):
                if left<=xx<left+w:blue.add((u+xx-left,v+yy-top))
    components=[];pending=set(blue)
    while pending:
        seed=min(pending);pending.remove(seed);seen={seed};queue=deque([seed])
        while queue:
            x,y=queue.popleft()
            for dx,dy in itertools.product([-1,0,1],repeat=2):
                point=x+dx,y+dy
                if point in pending:pending.remove(point);seen.add(point);queue.append(point)
        left=min(p[0] for p in seen);top=min(p[1] for p in seen);right=max(p[0] for p in seen)+1;bottom=max(p[1] for p in seen)+1
        if len(seen)>=500 and 30<=right-left<=80 and 25<=bottom-top<=75:components.append((left,top,right,bottom,seen))
    props=json.loads((OUT/'data.json').read_text());folder=source.REPORT/'Temple Interior/BG Pedestal Inventory';folder.mkdir(exist_ok=True)
    records=[];previews=[]
    for number,(left,top,right,bottom,points) in enumerate(sorted(components,key=lambda c:(c[0],c[1]))):
        rect=(left-39,top-6,left-39+128,top-6+192)
        foreground,background=native_layers(props['maps']['59530'],rect,59530)
        composite=background.copy();composite.alpha_composite(foreground)
        observed=sum(is_blue(background.getpixel((u-rect[0],v-rect[1]))) for u,v in points)
        visible=sum(is_blue(background.getpixel((u-rect[0],v-rect[1]))) and composite.getpixel((u-rect[0],v-rect[1]))==background.getpixel((u-rect[0],v-rect[1])) for u,v in points)
        background.save(folder/f'{number}-background-original.png');composite.save(folder/f'{number}-composite-original.png')
        contributing=[d for d in draws if d['native_rect'][0]<rect[2] and d['native_rect'][1]<rect[3] and d['native_rect'][0]+d['native_rect'][2]>rect[0] and d['native_rect'][1]+d['native_rect'][3]>rect[1]]
        roles={(4297,-940,4329,-903):'Colored-glass opening; not a pedestal',
               (4983,351,5033,396):'Confirmed BG blue-orb pedestal; reuse the406 family with its own source paint'}
        assert (left,top,right,bottom) in roles,'Review a changed native blue component before assigning a scenery role'
        records.append(dict(index=number,blue_bounds=[left,top,right,bottom],native_rect=list(rect),mapped_blue_pixels=len(points),observed_bg_blue_pixels=observed,unchanged_composite_pixels=visible,
            source_bg_rgba_sha256=source.sha(background.tobytes()),source_composite_rgba_sha256=source.sha(composite.tobytes()),source_draws=contributing,semantic_status=roles[left,top,right,bottom]))
        preview=Image.new('RGBA',composite.size,(40,48,56,255));preview.alpha_composite(composite);previews.append(preview.convert('RGB'))
    assert records,'Expected the already observed BG pedestal family'
    sheet=Image.new('RGB',(3*272,((len(previews)+2)//3)*420),(40,48,56));draw=ImageDraw.Draw(sheet)
    for index,preview in enumerate(previews):
        x=(index%3)*272;y=(index//3)*420
        sheet.paste(preview.resize((256,384),Image.Resampling.NEAREST),(x,y+28));draw.text((x+4,y+4),f"{index}: {records[index]['blue_bounds'][:2]}",fill='white')
    sheet.save(folder/'source-review.png')
    data=dict(map=59530,source_layer=0,background_masters=sorted(graphics),candidates=records,report_only=True,
        limits=['Detection uses only actual BG CUT placements. Reused master images can have several map origins; unused source pixels are excluded.',
                'A candidate is not a new NPC or event. Confirm its visible source role before modeling; this report adds no runtime placement.',
                'The foreground406 model may be reused with each confirmed source color variant. Do not copy foreground colors over a distinct BG variant.',
                'BG photograph removal and hidden parent-surface repair must accompany any eventual3D recovery.'])
    data['limits'].append('This search covers406-sized blue components only. BG columns, arches, other props and composite architecture still require their own role inventory.')
    (folder/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_BG_PEDESTAL_SOURCE',len(records),'mapped BG candidates;',len(graphics),'source masters; report only',flush=True)


def fill_occluded_floor(background,foreground,padding):
    w,h=foreground.size;area=(padding,padding,padding+w,padding+h)
    mask=foreground.getchannel('A')
    full=Image.new('L',background.size);full.paste(mask,(padding,padding))
    ring=ImageChops.subtract(full.filter(ImageFilter.MaxFilter(9)),full)
    pixels=background.load();alpha=full.load();edge=ring.load()
    def paving(color):return color[3]>200 and min(color[:3])>75 and max(color[:3])-min(color[:3])<28
    holes=[(x,y) for y in range(padding,padding+h,4) for x in range(padding,padding+w,4) if alpha[x,y]>128 and (pixels[x,y][3]==0 or max(pixels[x,y][:3])<=40)]
    border=[(x,y) for y in range(padding-4,padding+h+4,3) for x in range(padding-4,padding+w+4,3) if edge[x,y]>128 and paving(pixels[x,y])]
    scores=[]
    for dy in range(-176,177,16):
        for dx in range(-176,177,16):
            if dx==dy==0 or not holes or not border:continue
            coverage=sum(paving(pixels[x+dx,y+dy]) for x,y in holes)/len(holes)
            errors=[sum(abs(a-b) for a,b in zip(pixels[x,y][:3],pixels[x+dx,y+dy][:3]))/3 for x,y in border if paving(pixels[x+dx,y+dy])]
            if len(errors)<len(border)*.7:continue
            scores.append((sum(errors)/len(errors)+(1-coverage)*180,coverage,dx,dy))
    scores.sort()
    paint=solid_pages(dict(graphics={'floor':dict(rect=[0,0,*background.size],page=0)}),[background])[0].crop(area)
    target=paint.load();mask_pixels=mask.load()
    for y in range(h):
        for x in range(w):
            if not mask_pixels[x,y]:continue
            original=pixels[padding+x,padding+y]
            if original[3] and max(original[:3])>40:target[x,y]=original;continue
            for _,_,dx,dy in scores:
                color=pixels[padding+x+dx,padding+y+dy]
                if paving(color):target[x,y]=color;break
    paint.putalpha(mask)
    return paint,[dict(score=round(score,5),coverage=round(coverage,5),offset=[dx,dy]) for score,coverage,dx,dy in scores[:8]]


def nearest_material_paint(art):
    """Extend the selected native material in two dimensions, without row streaks."""
    paint=art.convert('RGBA').copy();pixels=paint.load();w,h=paint.size
    pending=deque();seen=set()
    for y in range(h):
        for x in range(w):
            if pixels[x,y][3]:pending.append((x,y));seen.add((x,y))
    assert pending,'Material extraction must contain native paint'
    while pending:
        x,y=pending.popleft()
        for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if not (0<=xx<w and 0<=yy<h) or (xx,yy) in seen:continue
            pixels[xx,yy]=pixels[x,y];seen.add((xx,yy));pending.append((xx,yy))
    return paint.convert('RGB')


def fit_furniture(data):
    styles={
        (301043,(192,96),(128,144)):dict(kind='table',feet=[[17,102],[52,126],[110,86],[75,62]],height_pixels=33,leg_width=4,paint_sources=[0,1,2,1]),
        (301045,(-320,96),(128,144)):dict(kind='bench',feet=[[17,109],[38,125],[115,71],[94,55]],height_pixels=16,leg_width=2,paint_sources=[0,1,1,0],leg_heights=[35,16,16,35],
            back=dict(indices=[0,3],bottom=21,top=[33,33],paint=[[22,82],[22,77],[90,29],[90,34]]),braces=[[[38,125],[59,110]]]),
        (301045,(-320,0),(128,96)):dict(kind='bench',feet=[[15,80],[37,94],[115,41],[93,27]],height_pixels=16,leg_width=2,paint_sources=[0,1,2,0],leg_heights=[16,39,35,16],
            back=dict(indices=[1,2],bottom=23,top=[37,33],paint=[[40,74],[40,68],[106,20],[106,26]]),braces=[[[15,80],[37,94]]]),
    }
    for group in data['groups'].values():
        group.pop('table',None);group.pop('furniture',None)
        key=(group['master'],tuple(group['origin']),tuple(group['size']))
        if key in styles:
            group['furniture']=styles[key]
            group['furniture']['source']='Native seat edges and visible feet guide the fit. Occluded feet and rear paint are inferred; original foreground pixels and navigation are retained.'
            page=Image.open(OUT/f"atlas-{group['page']}.png").convert('RGBA');x,y,w,h=group['rect'];art=page.crop((x,y,x+w,y+h))
            metal=art.copy();metal.putalpha(Image.new('L',art.size));original=art.load();pixels=metal.load()
            for yy in range(h):
                for xx in range(w):
                    r,g,b,a=original[xx,yy]
                    if a and r-g>=10 and g-b>=8 and r<=g*1.8:pixels[xx,yy]=(r,g,b,a)
            name='furniture-gold-%d-%d-%d-%d-%d.png'%(group['master'],*group['origin'],w,h)
            paint=nearest_material_paint(metal);paint.save(OUT/name)
            group['furniture']['gold']=dict(path='res://assets/maps/falan/elsa/props/'+name,sha256=source.sha(paint.tobytes()),
                source='Only native warm frame colors are extended onto the metal; pale background matte fringes are excluded. Original artwork is preserved.')
            if group['furniture']['kind']=='bench':
                wood=art.copy();wood.putalpha(Image.new('L',art.size));pixels=wood.load()
                for yy in range(h):
                    for xx in range(w):
                        r,g,b,a=original[xx,yy]
                        if a and (r>g*1.6 and g>b*1.2 or max(r,g,b)<=40):pixels[xx,yy]=(r,g,b,a)
                name='furniture-wood-%d-%d-%d-%d-%d.png'%(group['master'],*group['origin'],w,h)
                paint=nearest_material_paint(wood);paint.save(OUT/name)
                group['furniture']['wood']=dict(path='res://assets/maps/falan/elsa/props/'+name,sha256=source.sha(paint.tobytes()),source='Native brown board paint; metal and matte fringes remain separate.')
    import prepare_elsa_gate as gates
    data['floor_infills']={}
    for ident,placements in data['maps'].items():
        members=[p for p in placements if 'furniture' in data['groups'][p['group']]]
        if not members:continue
        pieces=[]
        for member in members:
            group=data['groups'][member['group']];x,y,w,h=group['rect']
            page=Image.open(OUT/f"atlas-{group['page']}.png").convert('RGBA')
            pieces.append((member['anchor'][0]+group['origin'][0],member['anchor'][1]+group['origin'][1],page.crop((x,y,x+w,y+h))))
        left=min(u for u,v,a in pieces);top=min(v for u,v,a in pieces)
        right=max(u+a.width for u,v,a in pieces);bottom=max(v+a.height for u,v,a in pieces)
        foreground=Image.new('RGBA',(right-left,bottom-top))
        for u,v,art in pieces:foreground.alpha_composite(art,(u-left,v-top))
        padding=192;rect=(left-padding,top-padding,right+padding,bottom+padding)
        _,background=gates.native_layers([],rect,int(ident));paint,patches=fill_occluded_floor(background,foreground,padding)
        name=f'floor-infill-{ident}.png';paint.save(OUT/name)
        data['floor_infills'][ident]=dict(path='res://assets/maps/falan/elsa/props/'+name,map=int(ident),origin=[left,top],members=members,
            background_rect=list(rect),background_sha256=source.sha(background.tobytes()),rgba_sha256=source.sha(paint.tobytes()),padding=padding,patches=patches,
            source='One shared native floor repair under the modeled furniture masks. Existing background colors are copied; transparent/dark matte pixels are inferred from nearby native paving. Navigation is unchanged.')
    print('ELSA_FURNITURE',sum('furniture' in g for g in data['groups'].values()),'source table/benches; shared occluded floor fits',len(data['floor_infills']),flush=True)


def fit_rocks(data):
    pages={}
    for group in data['groups'].values():
        if group['master'] not in [300401,300835,300836,300837,300867,300868,300869,300894,300895,300896,300897,300939,300942,300944,300945,300946,300947]:continue
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h));box=art.getbbox()
        if not box:continue
        parts=alpha_parts(art)
        if group['master'] in [300835,300836,300837,300867,300868,300869,300894,300895,300896,300897]:
            # Moss flecks belong to their rock's painted rim, not separate solid boulders.
            major=[p[:] for p in parts if p[2]-p[0]>=8 and p[3]-p[1]>=12 and (p[2]-p[0])*(p[3]-p[1])>=128]
            centers=[((p[0]+p[2])*.5,(p[1]+p[3])*.5) for p in major]
            if major:
                for part in parts:
                    if part in major:continue
                    center=((part[0]+part[2])*.5,(part[1]+part[3])*.5)
                    slot=min(range(len(major)),key=lambda i:math.hypot(centers[i][0]-center[0],centers[i][1]-center[1]));p=major[slot]
                    major[slot]=[min(p[0],part[0]),min(p[1],part[1]),max(p[2],part[2]),max(p[3],part[3])]
                parts=major
            else:parts=[list(art.getbbox())]
        below=group['master'] in [300401,300942,300944,300945]
        group['rock']=dict(parts=sorted(parts),model='res://assets/models/cedar_pass/river_rock.glb' if below else 'res://assets/models/environments/wind_meadow/mossy_boulder.glb',below=below)
    print('ELSA_ROCK_FITS',sum(len(g.get('rock',{}).get('parts',[])) for g in data['groups'].values()),'source silhouettes reuse the existing boulder master')


def fit_walls(data):
    """Recover the native ground line from the bottom of each continuous wall sheet."""
    pages={}
    for group in data['groups'].values():
        group.pop('wall',None);group.pop('wall_parts',None)
        if group['master'] not in [300066,300774,300777,300778,300779,300786,300807,300808,300809,300810,300812,300813,301295,301296]:continue
        if group.get('ground_role'):continue
        page=int(group['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=group['rect'];alpha=pages[page].crop((x,y,x+w,y+h)).getchannel('A');box=alpha.getbbox()
        if not box or box[2]-box[0]<40:continue
        if group['master']==301295 and w==256:
            pieces=[];art=pages[page].crop((x,y,x+w,y+h))
            for left,right in [(0,w//2),(w//2,w)]:
                pixels=alpha.load();samples=[]
                for col in range(left,right,3):
                    rows=[row for row in range(h) if pixels[col,row]>127]
                    if rows:samples.append((col,max(rows)+1))
                slopes=[(b[1]-a[1])/(b[0]-a[0]) for a in samples for b in samples if b[0]-a[0]>=(right-left)*.4]
                slope=statistics.median(slopes);base=statistics.median(v-slope*u for u,v in samples);ox,oy=group['origin']
                rect=[left,0,right,h]
                pieces.append(dict(box=rect,flat=False,foot=[slope,oy+base-slope*ox],edges=outline(art.crop(rect))))
            group['wall_parts']=pieces
            continue
        pixels=alpha.load();samples=[]
        # Sample actual foot pixels; transparent padding and upper finials are not feet.
        for col in range(box[0],box[2],max(1,(box[2]-box[0])//40)):
            marks=[row for row in range(box[1],box[3]) if pixels[col,row]>127]
            if marks:samples.append((col,max(marks)+1))
        slopes=[(b[1]-a[1])/(b[0]-a[0]) for a in samples for b in samples if b[0]-a[0]>=(box[2]-box[0])*.4]
        if not slopes or len(samples)<10:continue
        slope=statistics.median(slopes);intercepts=sorted(y-slope*x for x,y in samples)
        # Fence spans have scalloped openings; use their lower post feet.
        fence=group['master'] in [300066,300774,300777,300778,300779,300786]
        intercept=intercepts[int((len(intercepts)-1)*(.95 if fence else .65))]
        ox,oy=group['origin'];residual=statistics.median(abs(y-slope*x-intercept) for x,y in samples)
        # A tower with adjoining walls needs a separate model, not a single sloping slab.
        if residual>(32 if fence else 12) or abs(slope)>1:continue
        group['wall']=dict(foot=[round(slope,7),round(oy+intercept-slope*ox,5)],
                           residual=round(residual,4),source='Native alpha bottom envelope; inferred slab depth only.')
    print('ELSA_WALL_FITS',sum('wall' in g for g in data['groups'].values()),'native ground lines')


def fit_small_props(data):
    """Ground recognizable plants/props and split packed lamp variants before fitting."""
    pages={}
    upright={300839,300842,300843,300844,300845,300846,300847,300850,300851,300852,300853,300854,300855,300857,300859,300860,300861,
             300873,300876,300883,300885,300874,300886,300891,300892,300899,300901,300902,300987,300988,300989,300990,300991,300993,300994,300997,
             301000,301001,301042,300933,300932,300934}
    ground={300838,300840,300841,300862,300863,300865,300866,300893,300983,300984,300992,300995,300996}
    flowers={300793,300794,300805}
    for g in data['groups'].values():
        master=g['master'];g.pop('grounded',None);g.pop('columns',None)
        if master not in upright|ground|flowers|{300938,300936,300937,300940,300775,300776}:continue
        page=int(g['page'])
        if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
        x,y,w,h=g['rect'];art=pages[page].crop((x,y,x+w,y+h))
        parts=alpha_parts(art) if master in [300938,300936,300937,300940] else [art.getbbox()]
        if master in [300775,300776]:
            box=art.getbbox();left,top,right,bottom=box;width=right-left
            center=(left+right)*.5;foot_y=bottom-width*.18
            # The round basin is distinct from the original figure and curved bronze handles.
            upper=235 if master==300775 else 215
            inner_left=int(center-width*.33);inner_right=int(center+width*.33)
            alpha=art.getchannel('A');pixels=alpha.load();colors=art.load();profile=[[center,foot_y,30]]
            for row in [int(foot_y),*range(int(foot_y)-3,upper-1,-3),upper]:
                marks=[col for col in range(inner_left,inner_right) if pixels[col,row]>0 and max(colors[col,row][:3])-min(colors[col,row][:3])<35 and max(colors[col,row][:3])>45]
                if marks:profile.append([(marks[0]+marks[-1])*.5,row,marks[-1]-marks[0]+1])
            g['columns']=[dict(foot=[center,foot_y],profile=profile,sides=32,paint_rows=True)]
            rects=[[left,top,right,upper],[left,upper,inner_left,bottom],[inner_right,upper,right,bottom],[inner_left,int(foot_y),inner_right,bottom]]
            g['grounded']=[dict(box=rect,flat=False,foot=[0,g['origin'][1]+foot_y],edges=outline(art.crop(rect))) for rect in rects]
        elif master in [300938,300936,300937,300940]:
            columns=[]
            for box in parts:
                left,top,right,bottom=box;alpha=art.getchannel('A');pixels=alpha.load()
                width=right-left;foot=[(left+right)*.5,bottom-width*.18];profile=[]
                for row in [int(foot[1]),*range(int(foot[1])-3,top-1,-3),top]:
                    marks=[col for col in range(left,right) if pixels[col,row]>0]
                    if marks:profile.append([(marks[0]+marks[-1])*.5,row,marks[-1]-marks[0]+1])
                if len(profile)>1:columns.append(dict(box=box,foot=foot,profile=profile,sides=12 if master==300938 else 4))
                else:
                    # Retain single-pixel ornaments rather than dropping alpha components.
                    columns.append(dict(box=box,foot=foot,profile=[[(left+right)*.5,bottom,max(1,width)],[(left+right)*.5,top,max(1,width)]],sides=4))
            g['columns']=columns
        else:
            g['grounded']=[dict(box=box,flat=master in ground or master in flowers and box[3]-box[1]<=(box[2]-box[0])*.8,
                                foot=[0,g['origin'][1]+box[3]-(box[2]-box[0])*.18],edges=outline(art.crop(box))) for box in parts]
    print('ELSA_SMALL_PROP_FITS',sum(len(g.get('grounded',[]))+len(g.get('columns',[])) for g in data['groups'].values()),'native plant and lamp components')


def fit_effects(data):
    """Keep recovered animated flame art attached to its original torch stand in depth."""
    pages={};targets={};result={};proofs={}
    for ident,placements in data['maps'].items():
        flames=[]
        for placement in placements:
            group=data['groups'][placement['group']]
            if group['master']!=300934 or placement.get('empty_cut'):continue
            token=placement['group']
            if token not in targets:
                page=int(group['page'])
                if page not in pages:pages[page]=Image.open(OUT/f'atlas-{page}.png').convert('RGBA')
                x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h));pixels=art.load()
                warm=[(x,y) for y in range(int(h*.4)) for x in range(w) if pixels[x,y][3] and pixels[x,y][0]>90 and pixels[x,y][0]>pixels[x,y][1]*1.4 and pixels[x,y][0]>pixels[x,y][2]*1.4]
                if not warm:continue
                targets[token]=[sum(p[0] for p in warm)/len(warm),sum(p[1] for p in warm)/len(warm)]
            u,v=placement['anchor'];ox,oy=group['origin'];point=targets[token]
            flames.append((u+ox+point[0],v+oy+point[1],v+group['grounded'][0]['foot'][1],placement))
        if not flames:continue
        width,_,planes=source.reference_map(int(ident));header=source.cut_header(int(ident));animated_start=sum(header[2:4])
        for i,serial in enumerate(planes[1]):
            if serial<1000+animated_start:continue
            master,_,_,_,_,_,ax,ay=source.cut_records(int(ident))[serial-1000]
            art,ox,oy,_=source.scenery_frame(master)
            u=(i%width+i//width)*32;v=(i//width-i%width)*24
            center=(u+ox+ax+art.width*.5,v+oy+ay+art.height*.5)
            nearest=min(flames,key=lambda p:math.hypot(p[0]-center[0],p[1]-center[1]))
            if math.hypot(nearest[0]-center[0],nearest[1]-center[1])<64:
                result.setdefault(ident,{})[str(i)]=round(nearest[2]-v,5)
                proofs.setdefault(ident,{})[str(i)]=dict(master=master,parent_group=nearest[3]['group'],parent_anchor=nearest[3]['anchor'],
                                                        native_distance=round(math.hypot(nearest[0]-center[0],nearest[1]-center[1]),4))
    data['effect_feet']=result
    data['effect_sources']=proofs
    print('ELSA_ATTACHED_EFFECTS',sum(len(rows) for rows in result.values()),'original torch flames')


def fit_banyan_trunk(group,art,body):
    """First solid root/shaft fit; keep the other native forms until reviewed."""
    if (group['master'],tuple(group['origin']),tuple(group['size']))!=(300843,(-320,-240),(320,432)):return
    w,h=art.size;mask=Image.new('L',art.size);pixels=mask.load();native=body.load()
    for y in range(int(h*.4),h):
        for x in range(w):
            r,g,b,a=native[x,y]
            green=g>r*.95 and g>b*1.15
            if a and not green:pixels[x,y]=a
    opened=mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    probe=art.copy();probe.putalpha(opened);boxes=alpha_parts(probe)
    box=max(boxes,key=lambda b:sum(opened.crop(b).getdata()))
    selected=Image.new('L',art.size);selected.paste(opened.crop(box),box[:2]);pixels=selected.load()
    root=[163,327];top=None
    for y in range(box[1],root[1]-48):
        runs=[];start=None
        for x in range(box[0],box[2]+1):
            solid=x<box[2] and pixels[x,y]>127
            if solid and start is None:start=x
            elif not solid and start is not None:runs.append((start,x));start=None
        if runs:
            a,b=max(runs,key=lambda p:p[1]-p[0])
            if b-a>=38:top=[(a+b)*.5,y,b-a];break
    assert top,'Native shaft must have a continuous visible wood region'
    paint=art.copy();paint.putalpha(selected);paint=nearest_material_paint(paint)
    for y in range(h):
        for x in range(w):
            if native[x,y][3]:paint.putpixel((x,y),native[x,y][:3])
    # Visible moss-covered tips are native fitting landmarks; color segmentation stops before them.
    tips=[[130,396],[231,402],[66,348],[257,347]]
    from asset_pipeline.glb import GLB
    glb=GLB.read(source.ROOT/group['banyan']['model'].removeprefix('res://'))
    primitive=next(m for m in glb.doc['meshes'] if m['name']=='Body')['primitives'][0]
    positions=glb.accessor(primitive['attributes']['POSITION']);indices=[p[0] for p in glb.accessor(primitive['indices'])]
    adjacency=defaultdict(set)
    for i in range(0,len(indices),3):
        for index in indices[i:i+3]:adjacency[index].update(indices[i:i+3])
    seen=set();ends=[]
    for start in adjacency:
        if start in seen:continue
        pending=[start];component=[];seen.add(start)
        while pending:
            i=pending.pop();component.append(positions[i])
            for other in adjacency[i]-seen:seen.add(other);pending.append(other)
        center=[sum(p[k] for p in component)/len(component) for k in range(3)]
        if len(component)==9 and max(p[1] for p in component)<.1 and math.hypot(center[0],center[2])>.5:
            radius=max(math.dist(p,center) for p in component);ends.append(dict(model=center,radius=radius))
    assert len(ends)==6,'Reuse the six existing root ends'
    def angle_error(tip,end):
        du,dv=tip[0]-root[0],tip[1]-root[1]
        wanted=math.atan2(du*3/64+dv/16,du*3/64-dv/16);actual=math.atan2(end['model'][2],end['model'][0])
        return math.atan2(math.sin(wanted-actual),math.cos(wanted-actual))**2
    assignment=min(itertools.permutations(ends,4),key=lambda values:sum(angle_error(tip,end) for tip,end in zip(tips,values)))
    toes=[dict(pixel=tip,**end) for tip,end in zip(tips,assignment)]
    name='banyan-300843-solid-bark.png';paint.save(OUT/name)
    shape=group['banyan'];shape['body_parts'][0]['foot']=[0,group['origin'][1]+root[1]]
    shape['trunks']=[dict(part=0,root_pixel=root,root_cells=[3,3],top=top,core_limit=3.2,toes=toes,
                         bark=dict(path='res://assets/maps/falan/elsa/props/'+name,sha256=source.sha(paint.tobytes())),
                         source='Native wood silhouette and repeated 3x3 walking-mask footprint guide the existing woodland root/shaft mesh. Hidden volume is inferred; original art and walking data remain intact.')]


def fit_banyans(data):
    """Fit native crowns while retaining their fruit, crystals and hanging roots."""
    from asset_pipeline.glb import GLB
    model='res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb'
    glb=GLB.read(source.ROOT/model.removeprefix('res://'))
    canopy=next(mesh for mesh in glb.doc['meshes'] if mesh['name']=='Canopy')
    leaf_count=sum(glb.doc['accessors'][part['indices']]['count']//6 for part in canopy['primitives'])
    masters={300842,300843,300844,300845,300846,300847,300850,300851,300852,300853,300854,300855,300857,300859,300860,300861}
    for group in data['groups'].values():
        group.pop('banyan',None)
        if group['master'] not in masters or group['size'][1]<400:continue
        x,y,w,h=group['rect'];page=Image.open(OUT/f"atlas-{group['page']}.png").convert('RGBA');art=page.crop((x,y,x+w,y+h))
        leaf=art.copy();leaf.putalpha(Image.new('L',art.size));pixels=leaf.load();native=art.load()
        for yy in range(int(h*.65)):
            for xx in range(w):
                r,g,b,a=native[xx,yy]
                if a and g>r*.95 and g>b*1.15:pixels[xx,yy]=(r,g,b,a)
        box=leaf.getbbox();assert box
        body=art.copy();body.putalpha(ImageChops.subtract(art.getchannel('A'),leaf.getchannel('A')))
        stem='banyan-%d-%d-%d'%(group['master'],*group['origin'])
        paint=nearest_material_paint(leaf).convert('RGBA');paint.putalpha(leaf.getchannel('A'))
        images={'body':body,'body_solid':nearest_material_paint(body),'leaf':paint}
        points=[(xx,yy) for yy in range(box[1],box[3]) for xx in range(box[0],box[2]) if pixels[xx,yy][3]]
        cuts=[0,w]
        if w>400:
            columns=defaultdict(int)
            for xx,yy in points:columns[xx]+=1
            split=min(range(int(w*.4),int(w*.7)),key=lambda xx:(columns[xx],abs(xx-w/2)))
            assert columns[split]==0,'Separate doubled crowns at an actual native gap'
            cuts.insert(1,split)
        crowns=[];parts=[]
        for left,right in zip(cuts,cuts[1:]):
            members=[(xx,yy) for xx,yy in points if left<=xx<right];spans={}
            for xx,yy in members:
                if yy not in spans:spans[yy]=[xx,xx]
                else:spans[yy][1]=xx
            rng=random.Random(161126+left);crown=[]
            for xx,yy in rng.sample(members,leaf_count):
                a,b=spans[yy];axis=(a+b)*.5;radius=max(1.,(b-a)*.5)
                depth=math.sqrt(max(0.,radius**2-(xx-axis)**2))*rng.uniform(-.45,.45)
                crown.append([xx,yy,round(depth,5)])
            rect=[left,0,right,h];bounds=art.crop(rect).getbbox();assert bounds
            foot=[0,group['origin'][1]+bounds[3]-(bounds[2]-bounds[0])*.18]
            center=[(min(x for x,y in members)+max(x for x,y in members))*.5,(min(y for x,y in members)+max(y for x,y in members))*.5]
            crowns.append(dict(points=crown,center=center,leaf_pixels=round(math.sqrt(len(members)*8/leaf_count),5),part=len(parts)))
            parts.append(dict(box=rect,flat=False,foot=foot,depth=.3,edges=outline(body.crop(rect))))
        shape=dict(box=list(box),body_parts=parts,model=model,crowns=crowns,
                   model_sha256=source.sha((source.ROOT/model.removeprefix('res://')).read_bytes()),
                   source='Original crown colors on reused canopy geometry. Crown depth and hidden branch structure are inferred; lower trunk/root pixels and native navigation are retained.')
        for role,image in images.items():
            name=stem+'-'+role+'.png';image.save(OUT/name)
            shape[role]=dict(path='res://assets/maps/falan/elsa/props/'+name,sha256=source.sha(image.tobytes()))
        group['banyan']=shape
        fit_banyan_trunk(group,art,body)
    print('ELSA_BANYAN_CROWNS',sum(len(group.get('banyan',{}).get('crowns',[])) for group in data['groups'].values()),'native crowns with shared foliage geometry',flush=True)


def build():
    scope=json.loads((source.REPORT/'scope.json').read_text())
    OUT.mkdir(parents=True,exist_ok=True)
    groups={};images=[];dedup={};maps={}
    for ident in scope['maps']:
        width,height,planes=source.reference_map(ident);floor_count=source.cut_header(ident)[2]
        animated_start=sum(source.cut_header(ident)[2:4]);placed=defaultdict(list)
        for i,serial in enumerate(planes[1]):
            if serial<1000 or not floor_count<=serial-1000<animated_start:continue
            record=source.cut_records(ident)[serial-1000];master,mode,cx,cy,cw,ch,ax,ay=record
            if ident==59520 and master in TOWER_MASTERS:continue
            u=(i%width+i//width)*32;v=(i//width-i%width)*24
            base=(u-ax-cx,v-ay-cy) if cw or ch else (u+ax-320,v+ay-240)
            art,origin,_=source.cut_image(ident,serial)
            placed[(master,*base)].append((u+origin[0]-base[0],v+origin[1]-base[1],art,serial,i))
        rows=[]
        for (master,bu,bv),pieces in sorted(placed.items()):
            left=min(x for x,y,a,s,i in pieces);top=min(y for x,y,a,s,i in pieces)
            right=max(x+a.width for x,y,a,s,i in pieces);bottom=max(y+a.height for x,y,a,s,i in pieces)
            art=Image.new('RGBA',(right-left,bottom-top))
            for x,y,im,s,i in sorted(pieces,key=lambda p:(11*(p[4]//width)-9*(p[4]%width),p[4])):
                art.alpha_composite(im,(x-left,y-top))
            if art.getbbox() is None:continue
            origin=[left-320,top-240];key=(source.sha(art.tobytes()),tuple(origin),art.size,master)
            if key not in dedup:
                token=str(len(images));dedup[key]=token;images.append(art)
                groups[token]=dict(master=master,origin=origin,rgba_sha256=key[0],edges=outline(art),size=list(art.size))
            rows.append(dict(group=dedup[key],anchor=[bu+320,bv+240],pieces=[s for x,y,a,s,i in pieces],
                             cells=[[i%width,i//width] for x,y,a,s,i in pieces]))
        maps[str(ident)]=rows
    spires=assemble_spires(groups,images,maps)
    pages=[];page=Image.new('RGBA',(2048,2048));x=y=row_height=0
    for token,g in groups.items():
        art=images[int(token)];width,height=art.size
        assert max(width,height)+4<=2048,(token,art.size)
        if x+width+4>2048:x=0;y+=row_height;row_height=0
        if y+height+4>2048:pages.append(page);page=Image.new('RGBA',(2048,2048));x=y=row_height=0
        page.paste(art,(x+2,y+2));g['page']=len(pages);g['rect']=[x+2,y+2,width,height]
        x+=width+4;row_height=max(row_height,height+4)
    pages.append(page)
    for i,im in enumerate(pages):im.save(OUT/f'atlas-{i}.png')
    for i,im in enumerate(solid_pages(dict(graphics=groups),pages)):im.save(OUT/f'solid-{i}.png')
    result=dict(groups=groups,maps=maps,spires=spires,pages=len(pages),source='Native CUT rectangles, placements, palettes and unmodified RGBA pixels.',
                limits=['Depth is inferred. Pieces sharing the original graphic and native canvas origin form one object; no original mesh is supplied.'])
    mark_empty_crops(result)
    fit_trees(result)
    fit_columns(result)
    fit_furniture(result)
    fit_ground(result)
    fit_rocks(result)
    fit_walls(result)
    fit_small_props(result)
    fit_trial_caps(result)
    fit_banyans(result)
    fit_bridges(result)
    fit_effects(result)
    retain_prepared_surfaces(result)
    prepare_pedestal_candidate(result,True)
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print('ELSA_COHERENT_PROPS',len(groups),'unique original objects',sum(len(r) for r in maps.values()),'placements',len(pages),'pages')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--fit-only',action='store_true');parser.add_argument('--solids-only',action='store_true');parser.add_argument('--edges-only',action='store_true');parser.add_argument('--trial-caps-only',action='store_true');parser.add_argument('--pedestal-candidate',action='store_true');parser.add_argument('--publish-pedestal',action='store_true');parser.add_argument('--baked-pedestal-source',action='store_true');args=parser.parse_args()
    if args.baked_pedestal_source:inventory_baked_pedestals()
    elif args.pedestal_candidate:prepare_pedestal_candidate()
    elif args.publish_pedestal:
        data=json.loads((OUT/'data.json').read_text());prepare_pedestal_candidate(data,True)
        (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    elif args.trial_caps_only:
        data=json.loads((OUT/'data.json').read_text());fit_trial_caps(data)
        (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    elif args.edges_only:
        data=json.loads((OUT/'data.json').read_text());prepare_edges(data)
        (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    elif args.solids_only:
        data=json.loads((OUT/'data.json').read_text());pages=[Image.open(OUT/f'atlas-{i}.png').convert('RGBA') for i in range(data['pages'])]
        for i,im in enumerate(solid_pages(dict(graphics=data['groups']),pages)):im.save(OUT/f'solid-{i}.png')
        print('ELSA_PROP_SOLIDS',len(pages),'pages; every opaque source RGB value retained')
    elif args.fit_only:
        data=json.loads((OUT/'data.json').read_text());mark_empty_crops(data);fit_trees(data);fit_columns(data);fit_furniture(data)
        fit_ground(data)
        fit_rocks(data)
        fit_walls(data)
        fit_small_props(data)
        fit_trial_caps(data)
        fit_banyans(data)
        fit_bridges(data)
        fit_effects(data)
        retain_prepared_surfaces(data)
        prepare_pedestal_candidate(data,True)
        (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    else:build()
