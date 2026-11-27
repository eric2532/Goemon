"""Source-checked scenery inputs for the recovered southwest Freyja strip."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
from PIL import Image, ImageDraw
from build_freyja_destinations import load_map

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/venoa_field/scenery.json'
REVIEW=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit'
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib
from prepare_field_assets import navigation_grid


def prepare(complete_source=False,source_extension=False):
    extended=complete_source or source_extension
    w,h,floor,objects,flags=load_map(lib,100);lookup=lib.serial_index()
    walk=navigation_grid(w,h,floor,objects,lookup)
    anchors=[[x,y,objects[y*w+x]]for y in range(410,444)for x in range(201,227)if objects[y*w+x]>=1000]
    baseline=json.loads((OUT.parent/'provenance.json').read_text())['new_source_art_anchors']
    if extended:
        anchors=baseline
        assert all(objects[y*w+x]==serial for x,y,serial in anchors)
    else:assert anchors==baseline
    assert len(anchors)==80
    extension=[]
    if extended:
        # Include every station in the added columns and the adjacent omitted
        # source row, keeping the already published80-station prefix unchanged.
        old={tuple(row)for row in anchors}
        extension=[[x,y,objects[y*w+x]]for y in range(405,444)for x in range(193,227)
                   if objects[y*w+x]>=1000 and (x,y,objects[y*w+x])not in old]
        assert len(extension)==52 and sum(row[0]<201 for row in extension)==35
    ruby=json.loads((ROOT/'assets/maps/falan/black_prayer/region-trees.json').read_text())
    # These isolated water props have no land-envelope owner. Preserve their
    # source water and separate them from the already checked 80-station strip.
    offshore=[]
    for x in range(20,25):
        i=7*w+x;serial=objects[i]
        assert serial==12175+x-20 and 5000<=floor[i]<=5008 and flags[i]==49152
        offshore.append(dict(cell=[x,7],serial=serial,family='flowers',native_open=bool(walk[i]),
                             ground=floor[i],flags=flags[i],placement_surface='existing_source_water'))
    if complete_source:
        existing={tuple(row['cell']) for row in offshore}
        for y in range(6,8):
            for x in range(10,30):
                i=y*w+x;serial=objects[i]
                if serial<1000 or (x,y)in existing:continue
                assert 5000<=floor[i]<=5008,'Offshore source props do not authorize new land'
                family='tree'if 10058<=serial<=10094 else'stump'if 12165<=serial<=12168 else'flowers'
                offshore.append(dict(cell=[x,y],serial=serial,family=family,native_open=bool(walk[i]),
                    ground=floor[i],flags=flags[i],placement_surface='existing_source_water',source_recorded=bool(flags[i]&0xc000)))
        assert len(offshore)==40
    graphics={};counts={};placements=[];crowns={}
    def crown(serial):
        if serial not in crowns:
            g=lookup[serial];image=lib.image_from_record(g['pack'],g['row'])
            limit=min(image.height,max(1,-g['y']-36))
            # Reuse the foliage recovery's trunk/shadow cutoff, retaining every
            # opaque crown hue rather than selecting green-dominant pixels.
            pixels=[p for y in range(limit)for x in range(image.width)if(p:=image.getpixel((x,y)))[3]==255 and max(p[:3])>45]
            assert len(pixels)>500
            def linear(value):
                s=value/255.
                return s/12.92 if s<=.04045 else((s+.055)/1.055)**2.4
            crowns[serial]=dict(limit_y=limit,pixels=len(pixels),
                srgb=[sum(p[c]for p in pixels)/len(pixels)/255 for c in range(3)],
                linear=[sum(linear(p[c])for p in pixels)/len(pixels)for c in range(3)])
        return crowns[serial]
    for x,y,serial in anchors+extension+[[*r['cell'],r['serial']]for r in offshore]:
        family='tree'if 10058<=serial<=10094 else'shore'if 12500<=serial<=12535 else'stump'if 12165<=serial<=12168 else'flowers'
        assert family!='flowers'or serial in [12169,12170,12171,12175,12176,12177,12178,12179,12180]
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
        native_open=bool(walk[y*w+x])
        assert (not native_open)if family=='tree'else True
        assert native_open if family in ['flowers','stump']else True
        if [x,y,serial]in anchors+extension:
            placements.append(dict(cell=[x,y],serial=serial,family=family,native_open=native_open))
            counts[family]=counts.get(family,0)+1
        if str(serial)in graphics:continue
        rgba_hash=hashlib.sha256(im.tobytes()).hexdigest()
        record=dict(origin=[g['x'],g['y']],bounds=list(im.getbbox()),size=list(im.size),
                    footprint=[max(1,g['east']),max(1,g['south'])],rgba_sha256=rgba_hash,family=family)
        if family=='tree':
            assert ruby['graphics'][str(serial)]['rgba_sha256']==rgba_hash
            base=10058 if serial<10074 else 10088 if serial>=10088 else 10085
            native=crown(serial);source_base=crown(base)
            record.update(base_serial=base,crown_sample_limit_y=native['limit_y'],crown_sample_pixels=native['pixels'],
                crown_srgb_mean=native['srgb'],crown_linear_mean=native['linear'],base_crown_linear_mean=source_base['linear'],
                crown_linear_tint=[a/b for a,b in zip(native['linear'],source_base['linear'])])
            record['reuse']='RubyRegionArt.tree_fit; Meadow.crossgate_tree; owned crown-only linear source/base tint, bark and old Ruby materials unchanged'
        elif family=='shore':record['reuse']='OriginalArt base/east raw atlas; existing TinaGround.bank_mesh cap/descending-face/water form, visually fitted between unchanged terrain and water'
        elif family=='stump':record['reuse']='OriginalMapSolids.mesh(stump); original solid atlas'
        else:
            pixels=[p for p in im.getdata()if p[3]>=128]
            leaves=[p for p in pixels if p[1]>p[0]*1.1 and p[1]>p[2]*1.1]
            petals=[p for p in pixels if not(p[1]>p[0]*1.1 and p[1]>p[2]*1.1)and max(p[:3])>110]
            assert leaves and petals
            record['green']=[sum(p[c]for p in leaves)/len(leaves)/255 for c in range(3)]
            record['petals']=[sum(p[c]for p in petals)/len(petals)/255 for c in range(3)]
            record['asset']='flowers_ivory'if serial<=12171 else'flowers_coral'
            record['reuse']='Existing whole Meadow flower mesh; original source petal/leaf palette and source-sized fit'
        graphics[str(serial)]=record
    assert counts==(dict(shore=92,tree=27,flowers=10,stump=3)if extended else dict(shore=49,tree=22,flowers=8,stump=1))
    sources=['assets/maps/falan/black_prayer/region-trees.json','assets/maps/falan/undersea_coast_banks.png',
             'assets/maps/original_crossgate/catalog.json',
             'assets/maps/original_crossgate/east/catalog.json',
             'assets/models/environments/wind_meadow/crossgate_flora/cg_evergreen.glb',
             'assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb',
             'assets/models/environments/wind_meadow/crossgate_flora/cg_silverleaf.glb',
             'assets/models/environments/wind_meadow/flowers_ivory.glb','assets/models/environments/wind_meadow/flowers_coral.glb']
    data=dict(schema=1,source_map=100,source_bounds=[201,410,26,34],source_map_sha256=json.loads((OUT.parent/'provenance.json').read_text())['source_sha256'],
        placements=placements,graphics=graphics,counts=counts,offshore_placements=offshore,
        reused_source_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in sources},
        collision_contract='Only the22source-blocked tree cells use existing2.5m trunk obstacles, wholly inside their3m source cells; existing player-passable tree behavior retained. Open flowers/stump and shore overlays add no collision.',
        scope='80 original southwest anchors plus five separately listed original water-flower anchors at (20..24,7). The latter reuse the full-source water plane, with no new land, support, collision or navigation. Reused 3D forms and unseen surfaces are adaptations, not original 3D recovery.')
    if extended:
        from prepare_sokia_outdoor_source import FREYJA_ACTIVE
        folder=Path(os.environ.get('CROSSGATE_FREYJA_SOURCE_DIR',str(FREYJA_ACTIVE)))
        raw=(folder/'100.dat').read_bytes();proof=json.loads((folder/'provenance.json').read_text())
        assert hashlib.sha256(raw).hexdigest()==proof['active_sha256']
        old=json.loads(OUT.read_text())
        assert placements[:80]==old['placements'][:80] and offshore[:5]==old['offshore_placements'][:5]
        assert all(graphics[key]==record for key,record in old['graphics'].items())
        data.update(source_bounds=[193,405,34,39],source_map_sha256=proof['active_sha256'],
            preserved_client_source_sha256=proof['client_sha256'],source_extension_bounds=[193,405,34,39],
            source_extension_anchors=extension,preserved_prefixes=dict(placements=80,offshore_placements=5),
            collision_contract='Existing source-blocked trunk obstacles for the27land trees only; no shore/flower/stump or offshore props add support/collision/navigation.',
            scope='132southwest source stations, including all35anchors in the added8columns and17adjacent previously unowned stations, plus%dsource-water props. The original80land/5water prefixes and every prior graphic record remain exact. Offshore tree/stump/flower forms reuse existing models at source water height, adding no land/support/collision/navigation. Original placement intent beyond the source coordinates is unverified.'%len(offshore))
    return data


def source_reviews(data):
    lookup=lib.serial_index();images={}
    def image(serial):
        if serial not in images:
            g=lookup[serial];images[serial]=lib.image_from_record(g['pack'],g['row'])
        return images[serial]
    ids=sorted(map(int,data['graphics']));sheet=Image.new('RGB',(1400,((len(ids)+6)//7)*200),'#30393a');draw=ImageDraw.Draw(sheet)
    for i,s in enumerate(ids):
        native=image(s).copy();native.thumbnail((188,170));x=i%7*200;y=i//7*200
        sheet.paste(native,(x+(200-native.width)//2,y+20+(170-native.height)//2),native);draw.text((x+5,y+3),str(s),fill='white')
    sheet.save(REVIEW/'southwest-source-graphics.png')
    w,h,floor,objects,flags=load_map(lib,100);items=[]
    for plane,rows in enumerate([floor,objects]):
        for y in range(402,450):
            for x in range(193,235):
                s=rows[y*w+x]
                if s<1000:continue
                g=lookup[s];px=(x+y)*32+g['x'];py=(y-x)*24+g['y']
                items.append((0 if plane==0 or g['ground']else 1,11*y-9*x-min(g['east'],g['south'])*10,px,py,s))
    x0=min(r[2]for r in items);y0=min(r[3]for r in items)
    x1=max(r[2]+image(r[4]).width for r in items);y1=max(r[3]+image(r[4]).height for r in items)
    canvas=Image.new('RGB',(x1-x0,y1-y0),'#263138')
    for _,_,x,y,s in sorted(items):canvas.paste(image(s),(x-x0,y-y0),image(s))
    canvas.save(REVIEW/'southwest-original-composite.png')
    draw=ImageDraw.Draw(canvas)
    bx,by,bw,bh=data['source_bounds'];corners=[(bx-.5,by-.5),(bx+bw-.5,by-.5),(bx+bw-.5,by+bh-.5),(bx-.5,by+bh-.5),(bx-.5,by-.5)]
    draw.line([((x+y)*32-x0,(y-x)*24-y0)for x,y in corners],fill='#ffdc68',width=3)
    for row in data['placements']:
        x,y=row['cell'];p=((x+y)*32-x0,(y-x)*24-y0)
        draw.ellipse((p[0]-4,p[1]-4,p[0]+4,p[1]+4),outline='white',width=2)
    canvas.save(REVIEW/'southwest-original-anchors.png')
    verification=REVIEW/'southwest-rendered-verification.json'
    if verification.exists():
        from review_west_snow_route import reference, decode
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
        for pose in json.loads(verification.read_text()).get('captures',[]):
            if pose.get('projection')=='orthographic':
                reference(pose,decode(100,catalog)).save(REVIEW/(pose['name']+'-original.png'))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');parser.add_argument('--review',action='store_true')
    parser.add_argument('--complete-source',action='store_true');parser.add_argument('--source-extension',action='store_true');parser.add_argument('--out',type=Path,default=OUT);parser.add_argument('--review-dir',type=Path)
    args=parser.parse_args()
    if args.review_dir:REVIEW=args.review_dir;REVIEW.mkdir(parents=True,exist_ok=True)
    data=prepare(args.complete_source,args.source_extension)
    if args.check:assert json.loads(args.out.read_text())==data
    else:args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    if args.review:source_reviews(data)
    print('VENOA_SOUTHWEST_SCENERY_SOURCE anchors=%d counts=%s offshore=%d exact_source=true'%(len(data['placements']),data['counts'],len(data['offshore_placements'])))
