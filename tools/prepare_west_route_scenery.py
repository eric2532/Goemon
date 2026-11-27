"""Prepare native roadside scenery for the West Gate–snow route corridor."""
import argparse
import base64
import copy
import hashlib
import json
import sys
import tempfile
from collections import deque
from pathlib import Path
from PIL import Image

from review_west_snow_route import ROOT, decode, path_between, STAGES
from build_coastal_villages import atlas as pack_atlas
from recover_falan_architecture import opaque_paint

sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib

DEST=ROOT/'assets/maps/falan/west_route_scenery.json'
SOURCE_REVIEW=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage'


def source_recipe(serial,family):
    if family=='source_shore_profiles':return 'shore'
    if family=='source_fit_trees':return 'tree'
    if family!='native_flowers':return None
    if 11629<=serial<=11659 or serial in [12169,12170,12171,12178,12179,12180]:return 'flower_cluster'
    if 11625<=serial<=11628 or serial in [11691,11696,11697,11698,12175,12176,12177]:return 'stem_bouquet'
    if 11680<=serial<=11684:return 'large_daisy'
    if 12165<=serial<=12168:return 'stump'
    return None


def plant_samples(image):
    """Original painted green groups and connected bloom groups; no runtime image scans."""
    leaves={};petals=set()
    for y in range(image.height):
        for x in range(image.width):
            r,g,b,a=image.getpixel((x,y))
            if a<128 or max(r,g,b)<=45:continue
            if g>r*1.1 and g>b*1.1:leaves.setdefault((x//4,y//4),[]).append((x,y))
            elif max(r,g,b)>110:petals.add((x,y))
    def group(points):
        pixels=[image.getpixel(p)for p in points];xs=[p[0]for p in points];ys=[p[1]for p in points]
        return dict(pixel=[sum(xs)/len(xs),sum(ys)/len(ys)],bounds=[min(xs),min(ys),max(xs)-min(xs)+1,max(ys)-min(ys)+1],
            pixels=len(points),rgb=[sum(p[c]for p in pixels)/len(pixels)/255 for c in range(3)])
    leaf_rows=[group(points)for _,points in sorted(leaves.items())if len(points)>=2]
    blooms=[];pending=set(petals)
    while pending:
        start=min(pending);pending.remove(start);seen={start};queue=[start]
        for x,y in queue:
            for dy in [-1,0,1]:
                for dx in [-1,0,1]:
                    p=x+dx,y+dy
                    if p in pending:pending.remove(p);seen.add(p);queue.append(p)
        if len(seen)>=2:blooms.append(group(seen))
    assert leaf_rows and blooms
    return leaf_rows,blooms


def prepare_source_cliffs():
    """Full original stations for the existing continuous cliff owner, staged only."""
    from prepare_field_assets import navigation_grid
    inventory=SOURCE_REVIEW/'Freyja full-source art inventory'
    contracts=json.loads((inventory/'inventory.json').read_text())['owner_contracts']
    safety=json.loads((inventory/'Safety metadata/Prepared full/provenance.json').read_text())
    raw=(SOURCE_REVIEW/'Freyja full-source outdoors/Full source/100.dat').read_bytes()
    digest=hashlib.sha256(raw).hexdigest();assert digest==safety['source_sha256']
    w,h,floor,objects,flags=lib.parse_map(raw);lookup=lib.serial_index()
    walk=navigation_grid(w,h,floor,objects,lookup)
    original=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    ids={s for s in set(objects)if 12536<=s<=12565}
    entrances={s for s in set(objects)if s in [12834,12838,12839]}
    graphics={str(s):copy.deepcopy(catalog['graphics'].get(str(s),original.get('extra_graphics',{}).get(str(s))))for s in ids|entrances}
    assert all(graphics.values())
    profiles={str(s):copy.deepcopy(original['profiles'][str(s)])for s in ids}
    source_graphics={};checks=0
    for serial in sorted(ids):
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
        colored=sum(a>=128 and max(r,g,b)>45 for r,g,b,a in im.getdata())
        assert colored>0 and hashlib.sha256(im.tobytes()).hexdigest()==graphics[str(serial)]['rgba_sha256'];checks+=1
        source_graphics[str(serial)]=dict(origin=[g['x'],g['y']],footprint=[max(1,g['east']),max(1,g['south'])],
            rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest(),colored_pixels=colored,
            sparse_visible_fragment=colored<im.width*im.height*.05,paint_source=profiles[str(serial)]['paint_source'])
    rows=[[i%w,i//w,s]for i,s in enumerate(objects)if s in ids]
    entrance_rows=[[i%w,i//w,s]for i,s in enumerate(objects)if s in entrances]
    controls=[]
    for y in range(h):
        x=0
        while x<w:
            if floor[y*w+x]!=100 or walk[y*w+x]:x+=1;continue
            start=x
            while x<w and floor[y*w+x]==100 and not walk[y*w+x]:x+=1
            controls.append([y,start,x-1])
    maps={};covered=set();owner_count=0
    for area,contract in contracts.items():
        frame=contract['frame'];origin=contract['full_origin'];size=contract['full_size'];safe=safety['areas'][area]['safe_rectangles']
        def inside(x,y):
            dx=x*3-frame['origin'][0];dy=y*3-frame['origin'][1]
            px=(dx*frame['x'][0]+dy*frame['x'][1]-origin[0])/3
            py=(dx*frame['y'][0]+dy*frame['y'][1]-origin[1])/3
            return -.5<=px<size[0]-.5 and -.5<=py<size[1]-.5 and not any(a-.5<=px<a+cw-.5 and b-.5<=py<b+ch-.5 for a,b,cw,ch in safe)
        bits=bytearray((w*h+7)//8);owner_cells=set()
        for y in range(h):
            for x in range(w):
                i=y*w+x
                if walk[i]or not inside(x,y):bits[i>>3]|=1<<(i&7)
                else:owner_cells.add((x,y))
        placements=[]
        for x,y,serial in rows:
            footprint=graphics[str(serial)]['footprint']
            if not any((x+xx,y-yy)in owner_cells for xx in range(footprint[0])for yy in range(footprint[1])):continue
            placements.append([x,y,serial]);covered.add((x,y,serial));checks+=1
        maps[area]=dict(cliffs=placements,entrances=entrance_rows,walk=bits.hex(),frame=frame,
            mask_origin=origin,mask_size=size,canonical_area=contract['canonical_area'],safe_rectangles=safe)
        owner_count+=len(placements)
    missing=[row for row in rows if tuple(row)not in covered]
    frozen=json.loads((inventory/'stations.json').read_text())
    gaps=[r for r in frozen if r['family']=='source_cliff_profiles']
    assert len(rows)==2882 and len(gaps)==471;checks+=2
    for row in rows:assert objects[row[1]*w+row[0]]==row[2];checks+=1
    return dict(schema=1,active=False,source=100,source_sha256=digest,size=[w,h],source_walk_sha256=hashlib.sha256(walk).hexdigest(),
        source_anchors=len(rows),frozen_missing_anchors=len(gaps),owner_rows=owner_count,maps=maps,unowned_anchors=missing,blocked_control_spans=controls,
        graphics=graphics,profiles=profiles,source_graphics=source_graphics,cap_paint=original['cap_paint'],checks=checks,
        texture='res://assets/maps/original_crossgate/cliff-paint.png',original_palette=False,preserve_profile_height=True,
        limits='Staged visual input only. All colored sparse fragments remain source stations. Measured profiles already combine3m source-cell footprints and native heights; no additional camera/whole-sprite height fit applies. Source-open footprint clipping and entrance reservation remain. Outside-owner/city/village cells are excluded from this visual mass only; raw source, native physics and canonical terrain are unchanged. Hidden caps/backs remain inferred; source/camera review required.')


def prepare_source_additions():
    """Explicit staged inputs for the existing seven scenery owners; no route/BFS filter."""
    inventory=SOURCE_REVIEW/'Freyja full-source art inventory'
    stations=json.loads((inventory/'stations.json').read_text())
    originals=json.loads((inventory/'graphics-source.json').read_text())
    raw=(SOURCE_REVIEW/'Freyja full-source outdoors/Full source/100.dat').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==originals['source_sha256']
    w,h,ground,objects,flags=lib.parse_map(raw);lookup=lib.serial_index()
    safety=json.loads((inventory/'Safety metadata/Prepared full/provenance.json').read_text())
    old_scenery=json.loads((ROOT/'assets/maps/falan/venoa_field/scenery.json').read_text())
    known=old_scenery['graphics'];graphics={};maps={a:[]for a in safety['areas']};deferred=[];held=[];checks=0
    def safe(owner):
        x,y=owner['mask_pixel']
        return any(a<=x<a+width and b<=y<b+height for a,b,width,height in safety['areas'][owner['area']]['safe_rectangles'])
    for row in stations:
        if row['reconciliation']!='requires_append_or_recipe':continue
        serial=row['serial'];recipe=source_recipe(serial,row['family'])
        if recipe is None:
            deferred.append(dict(cell=row['cell'],serial=serial,family=row['family'],reason='Separate source-specific recipe required; not an interchangeable bouquet/tree/shore.'))
            continue
        if row['source_surface_domain']=='control100':
            held.append(dict(cell=row['cell'],serial=serial,recipe=recipe,reason='Source100 control is not physical ground. Determine the existing cliff/bank host and fitted visual root height before append; no new floor/support.'))
            continue
        owners=[o for o in row['owner_candidates']if(o['anchor_inside']or o['footprint_centre_inside'])and not safe(o)]
        if not owners:
            held.append(dict(cell=row['cell'],serial=serial,recipe=recipe,reason='Exact city/village exclusions remove exterior candidates; reconcile actual existing owner before append.'))
            continue
        x,y=row['cell'];assert objects[y*w+x]==serial;checks+=1
        for owner in owners:
            maps[owner['area']].append(dict(cell=row['cell'],serial=serial,recipe=recipe,
                local_anchor=owner['local_anchor'],source_floor=ground[y*w+x],source_surface_domain=row['source_surface_domain'],
                source_decoder_open=row['source_decoder_open'],server_only_object=row['server_only_object'],
                canonical_area=owner['canonical_area']))
        if str(serial)in graphics:continue
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row']);digest=hashlib.sha256(im.tobytes()).hexdigest()
        assert digest==originals['graphics'][str(serial)]['rgba_sha256'];checks+=1
        if str(serial)in known and recipe in ['tree','shore','stump']:
            record=copy.deepcopy(known[str(serial)]);assert record['rgba_sha256']==digest;checks+=1
        else:
            body=im.getchannel('A');body.putdata([a if max(r,g,b)>45 else 0 for r,g,b,a in im.getdata()])
            record=dict(origin=[g['x'],g['y']],bounds=list(body.getbbox()),size=list(im.size),
                footprint=[max(1,g['east']),max(1,g['south'])],rgba_sha256=digest,
                family='flowers'if recipe in ['flower_cluster','stem_bouquet','large_daisy']else recipe)
        record['recipe']=recipe
        if recipe=='tree':
            record['asset']='res://assets/models/environments/wind_meadow/crossgate_flora/'+('cg_evergreen'if serial<10074 and serial!=10000 else'cg_silverleaf'if serial>=10088 else'cg_woodland')+'.glb'
            if 'crown_linear_tint'not in record:
                limit=min(im.height,max(1,-g['y']-36));pixels=[p for y in range(limit)for x in range(im.width)if(p:=im.getpixel((x,y)))[3]==255 and max(p[:3])>45]
                def linear(v):
                    s=v/255.;return s/12.92 if s<=.04045 else((s+.055)/1.055)**2.4
                mean=[sum(linear(p[c])for p in pixels)/len(pixels)for c in range(3)]
                base=known['10085']['base_crown_linear_mean'];record['crown_linear_tint']=[mean[c]/base[c]for c in range(3)]
        if recipe in ['flower_cluster','stem_bouquet','large_daisy']:
            pixels=[p for p in im.getdata()if p[3]>=128 and max(p[:3])>45]
            leaves=[p for p in pixels if p[1]>p[0]*1.1 and p[1]>p[2]*1.1]
            petals=[p for p in pixels if not(p[1]>p[0]*1.1 and p[1]>p[2]*1.1)and max(p[:3])>110]
            assert leaves and petals,serial;checks+=1
            record['green']=[sum(p[c]for p in leaves)/len(leaves)/255 for c in range(3)]
            record['petals']=[sum(p[c]for p in petals)/len(petals)/255 for c in range(3)]
            r,green,b=record['petals'];record['studied_whole_asset']='flowers_blue'if b>r*1.15 else'flowers_coral'if r>green*1.2 and b>green*.9 else'flowers_ivory'
            record['reuse']='Existing rounded garden sphere leaf/bloom parts, using actual original painted group positions and colors. Whole Meadow flower/shrub models were studied and visually rejected for these low round clusters; masters remain intact. Unseen depth/height is fitted and unaccepted until camera review.'
            record['source_leaves'],record['source_blooms']=plant_samples(im)
            record['sample_contract']='Exact original painted green4px-group centroids and8-connected non-green bloom centroids/bounds/palettes. Existing rounded garden leaf/petal parts are assembled offline at those measured sub-tile locations; unseen depth/height inferred.'
            if recipe=='large_daisy':
                cx,cy=im.width*.5,im.height*.45
                centre=[p for y in range(im.height)for x in range(im.width)if(x-cx)**2+(y-cy)**2<(im.width*.14)**2 and(p:=im.getpixel((x,y)))[3]>=128]
                record['centre']=[sum(p[c]for p in centre)/len(centre)/255 for c in range(3)]
                outer=[p for y in range(im.height)for x in range(im.width)if(x-cx)**2+(y-cy)**2>(im.width*.25)**2 and(p:=im.getpixel((x,y)))[3]>=128 and max(p[:3])>110 and not(p[1]>p[0]*1.1 and p[1]>p[2]*1.1)]
                record['petals']=[sum(p[c]for p in outer)/len(outer)/255 for c in range(3)]
                record['source_rgba']=base64.b64encode(im.tobytes()).decode()
                record['petal_count']=10
                record['morphology']='One source-observed ten-petal head assembled from existing rounded garden petal/leaf primitives; original source RGB is sampled onto solid head vertices. Hidden depth/root height inferred; fixed-camera appearance not yet accepted.'
        graphics[str(serial)]=record
    unique={(r['cell'][0],r['cell'][1],r['serial'])for rows in maps.values()for r in rows}
    frozen={(*r['cell'],r['serial'])for r in stations if r['reconciliation']=='requires_append_or_recipe'}
    assert unique<=frozen;checks+=1
    assert len(unique)+len(deferred)+len(held)==len(frozen);checks+=1
    return dict(schema=1,active=False,source_sha256=originals['source_sha256'],maps=maps,graphics=graphics,deferred=deferred,held=held,
        checks=checks,unique_anchors=len(unique),owner_rows=sum(map(len,maps.values())),
        source_art_inventory_sha256=hashlib.sha256((inventory/'stations.json').read_bytes()).hexdigest(),
        safety_metadata_sha256=hashlib.sha256((inventory/'Safety metadata/Prepared full/provenance.json').read_bytes()).hexdigest(),
        old_scenery_sha256=hashlib.sha256((ROOT/'assets/maps/falan/venoa_field/scenery.json').read_bytes()).hexdigest(),
        contract='Staged setup-only source additions through the existing WestRoute/Meadow/southwest mesh owners. All seven envelopes and overlapping scene candidates retained;474existing-owner candidates,52published headland and35root-staged offshore stations excluded. No canonical publication, source activation, culling-span broadening, native collision/navigation/Waves or masters changed.')


def prepare():
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    stages=[dict(source=number,area=area,path=path_between(decode(number,catalog),anchors))
            for _,_,number,area,_,anchors in STAGES if number is not None]
    lookup=lib.serial_index();maps={};trees={};sources={};palettes=[[1.0,1.0,1.0]];means={}
    def leaf_mean(serial):
        if serial not in means:
            g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
            pixels=[p[:3] for y in range(round(im.height*.8)) for x in range(im.width)
                    if (p:=im.getpixel((x,y)))[3]>=128 and p[1]>p[0]*1.02 and p[1]>p[2]*.8]
            assert pixels,serial
            means[serial]=[sum(p[c] for p in pixels)/len(pixels) for c in range(3)]
        return means[serial]
    profiles=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']
    def remember(serial):
        if serial in trees:return
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
        mask=im.getchannel('A').point(lambda a:255 if a>=128 else 0)
        for yy in range(im.height):
            for xx in range(im.width):
                if max(im.getpixel((xx,yy))[:3])<=45:mask.putpixel((xx,yy),0)
        bbox=mask.getbbox();assert bbox,serial
        trees[serial]=dict(origin=[g['x'],g['y']],bounds=list(bbox),rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
        if 10058<=serial<=10094:
            base=10058 if serial<=10074 else 10085 if serial<10088 else 10088
            tint=[round(min(2,max(.3,(a/b)**2.2))*10)/10 for a,b in zip(leaf_mean(serial),leaf_mean(base))]
            if tint not in palettes:palettes.append(tint)
            trees[serial]['palette']=palettes.index(tint)
        if 11622<=serial<=11624:
            clusters=[]
            for y in range(0,round(im.height*.68),16):
                for x in range(0,im.width,16):
                    points=[(a,b) for b in range(y,min(y+16,im.height)) for a in range(x,min(x+16,im.width))
                            if (p:=im.getpixel((a,b)))[3]>=128 and min(p[:3])>110 and max(p[:3])>170]
                    if len(points)<20:continue
                    clusters.append([sum(p[0] for p in points)/len(points),sum(p[1] for p in points)/len(points),min(1,len(points)/180)])
            trees[serial]['snow_clusters']=clusters
            trees[serial]['branches']={
                11622:[[[70,204],[78,155],[76,128],[90,84],[110,43],[120,3]],[[77,155],[59,130],[47,106],[34,84]],[[77,155],[102,141],[121,129]],[[77,126],[61,102],[61,72],[43,50]]],
                11623:[[[107,217],[110,178],[105,154],[85,122],[59,110],[25,87]],[[110,178],[112,135],[111,96],[112,60],[113,32],[119,10]],[[109,174],[131,145],[159,125],[177,100]],[[85,122],[69,91],[46,76]]],
                11624:[[[99,261],[108,220],[102,190],[97,161],[91,127],[92,97],[77,66],[92,38],[104,7]],[[105,220],[143,204],[167,176],[174,155]],[[102,190],[74,166],[61,144],[44,131]],[[92,127],[134,113],[154,90],[169,69]],[[80,83],[42,69],[21,50]]]
            }[serial]
        if str(serial) not in catalog['graphics']:
            trees[serial]['graphic']=dict(rect=[0,0,im.width,im.height],origin=[g['x'],g['y']],footprint=[max(1,g['east']),max(1,g['south'])])
    for stage in stages:
        if stage['source'] is None:continue
        data=decode(stage['source'],catalog);w,h=data['width'],data['height']
        near={(x+dx,y+dy) for x,y in stage['path'] for dx in range(-24,25) for dy in range(-24,25)}
        cliff_ids={int(s) for s,p in profiles.items() if p['height']>=3 and ((12536<=int(s)<=12565) if stage['source']==100 else not 12536<=int(s)<=12565)}
        reserved=set()
        for i,serial in enumerate(data['objects']):
            if serial not in (12834,12838,12839):continue
            x,y=i%w,i//w;g=lookup[serial]
            reserved.update((x+dx,y-dy) for dx in range(max(1,g['east'])) for dy in range(max(1,g['south'])))
        owners={};cliff_rows=[]
        for i,serial in enumerate(data['objects']):
            if serial not in cliff_ids:continue
            x,y=i%w,i//w;g=lookup[serial]
            footprint=[(x+dx,y-dy) for dx in range(max(1,g['east'])) for dy in range(max(1,g['south']))]
            if not any(p in near for p in footprint):continue
            cliff_rows.append([x,y,serial])
            for a,b in footprint:
                if 0<=a<w and 0<=b<h and (a,b) not in reserved and not data['walk'][b*w+a]:owners[(a,b)]=(serial,x,y)
        queue=deque(owners)
        while queue:
            x,y=queue.popleft()
            for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                a,b=p
                if p in owners or p in reserved or p not in near or not(0<=a<w and 0<=b<h):continue
                i=b*w+a
                if data['floor'][i]!=100 or data['walk'][i] or not(data['flags'][i]&0xc000):continue
                owners[p]=owners[(x,y)];queue.append(p)
        cliff_fill=[[x,y,*owners[x,y]] for x,y in sorted(owners)]
        assert all(not data['walk'][y*w+x] for x,y,*_ in cliff_fill)
        assert not (set(owners)&reserved)
        spans=[]
        for y in sorted({p[1] for p in near}):
            xs=sorted(x for x,z in near if z==y);start=last=xs[0]
            for x in xs[1:]+[xs[-1]+2]:
                if x>last+1:spans.append([y,start,last]);start=x
                last=x
        rows=[];details=[];banks=[]
        for x,y in sorted(near):
            if not (0<=x<w and 0<=y<h):continue
            serial=data['objects'][y*w+x]
            if stage['source']==100:
                if 12500<=serial<=12535:banks.append([x,y,serial])
                family=''
                if stage['area']=='west_lakes' and 10620<=serial<=10630:family='parapet'
                elif serial==10405:family='chair'
                elif 10475<=serial<=10478:family='grille'
                elif serial==11098:family='detail_mushrooms'
                elif 11363<=serial<=11390:family='fence'
                elif serial in [12166,12168]:family='stump'
                elif 12197<=serial<=12201:family='branch'
                elif serial==12121 or 12202<=serial<=12384:family='boulder'
                elif 11662<=serial<=11679 or serial==12181:family='grass'
                elif 11625<=serial<=11710 or 12160<=serial<=12180:family='leafy_stems'
                if family:details.append([x,y,serial,family]);remember(serial)
            if not (10058<=serial<=10094 or 11600<=serial<=11624):continue
            rows.append([x,y,serial])
            remember(serial)
        key=stage['area'] if stage['source']==100 else str(stage['source'])
        bounds_points=near|set(owners)
        bounds=[max(0,min(x for x,y in bounds_points)),max(0,min(y for x,y in bounds_points)),min(w-1,max(x for x,y in bounds_points)),min(h-1,max(y for x,y in bounds_points))]
        x0,y0,x1,y1=bounds;cw,ch=x1-x0+1,y1-y0+1
        bits=bytearray((cw*ch+7)//8)
        for y in range(ch):
            for x in range(cw):
                if data['walk'][(y+y0)*w+x+x0]:
                    i=y*cw+x;bits[i>>3]|=1<<(i&7)
        maps[key]=dict(source=stage['source'],spans=spans,trees=rows,cliffs=cliff_rows,cliff_fill=cliff_fill,details=details,banks=banks,bounds=[x0,y0,cw,ch],walk=bits.hex())
        sources[str(stage['source'])]=hashlib.sha256(data['raw']).hexdigest()
    for serial in [11622,11623,11624]:remember(serial)
    missing={s for s,g in trees.items() if 'graphic' in g}
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/'details.png'
        rects=pack_atlas(lib,lookup,missing,path,1024)
        paint=Image.open(path).convert('RGBA')
        for serial,rect in rects.items():
            g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
            paint.paste(opaque_paint(im),rect[:2]);trees[serial]['graphic']['rect']=list(rect)
        path=DEST.with_name('west_route_details.png')
        if '--check' in sys.argv:assert Image.open(path).tobytes()==paint.tobytes()
        else:paint.save(path)
    assert len(maps)==11 and sum(bool(m['trees']) for m in maps.values())==5
    return dict(schema=1,source_sha256=sources,maps=maps,graphics=trees,palettes=palettes,
                scope='Source corridor plus twenty-four tiles of visible surroundings; cliff interiors fill only recorded blocked native cells. Collision and exits unchanged.')


if __name__=='__main__':
    if '--source-cliffs'in sys.argv:
        parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source-cliffs',action='store_true');parser.add_argument('--check',action='store_true');parser.add_argument('--stage',type=Path,required=True);args=parser.parse_args()
        result=prepare_source_cliffs();text=json.dumps(result,ensure_ascii=False,indent=2)+'\n';path=args.stage/'source-cliffs.json'
        if args.check:assert path.read_text()==text,'Stale staged full-source cliffs'
        else:args.stage.mkdir(parents=True,exist_ok=True);path.write_text(text)
        print('FREYJA_SOURCE_CLIFFS',result['checks'],'checks',result['source_anchors'],'source stations',result['owner_rows'],'overlapping owner rows;',len(result['unowned_anchors']),'not mounted; active=false')
        sys.exit(0)
    if '--source-additions'in sys.argv:
        parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source-additions',action='store_true');parser.add_argument('--check',action='store_true');parser.add_argument('--stage',type=Path,required=True);args=parser.parse_args()
        result=prepare_source_additions();text=json.dumps(result,ensure_ascii=False,indent=2)+'\n';path=args.stage/'source-additions.json'
        if args.check:assert path.read_text()==text,'Stale staged full-source scenery additions'
        else:args.stage.mkdir(parents=True,exist_ok=True);path.write_text(text)
        print('FREYJA_SOURCE_ADDITIONS',result['checks'],'checks',result['unique_anchors'],'unique stations',result['owner_rows'],'overlapping owner rows; active=false')
        sys.exit(0)
    result=prepare();text=json.dumps(result,separators=(',',':'))+'\n'
    if '--check' in sys.argv:assert DEST.read_text()==text,'Stale western route tree anchors'
    else:DEST.write_text(text)
    print('PASS:',sum(len(m['trees']) for m in result['maps'].values()),'native tree anchors in five route views')
