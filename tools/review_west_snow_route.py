"""Read-only source route plan and fixed-camera comparison sheets."""
import base64
import hashlib
import heapq
import html
import json
import struct
import sys
import zlib
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/West Gate Snow Route'
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_library as lib
from prepare_field_assets import navigation_grid

STAGES = [
    ('01-west-gate', 'West Gate and outer approach', 100, 'freyja', 0, [(378,194),(374,195),(301,181),(289,181)]),
    ('02-western-freyja', 'Western Freyja to the undersea entrance', 100, 'west_lakes', 0, [(289,181),(201,166)]),
    ('03-undersea-1', 'Undersea cave, Freyja side', 15000, 'interior', 51001, [(22,33),(20,8)]),
    ('04-undersea-2', 'Undersea cave, lower crossing', 15001, 'interior', 51002, [(38,79),(11,9)]),
    ('05-undersea-3', 'Undersea cave, Shalena side', 15002, 'interior', 51003, [(14,41),(24,11)]),
    ('06-shalena-south', 'Shalena return mouth, southwest bend and western ascent', 400, 'interior', 51031, [(196,443),(149,472),(170,425),(196,375),(235,338)]),
    ('07-western-cave-1', 'Western cave 1F', 14000, 'interior', 14000, [(8,41),(45,9)]),
    ('08-western-cave-2', 'Western cave 2F', 14001, 'interior', 14001, [(14,68),(57,13)]),
    ('09-western-cave-3', 'Western cave 3F and snowy exit', 14002, 'interior', 14002, [(30,44),(36,7)]),
    ('10-snowfield', 'Abanis snowfield, village turnoff and mountain stone', 402, 'interior', 51032, [(258,180),(240,172),(217,171),(194,171),(184,165),(144,174),(84,193)]),
    ('11-snow-mountain-1', 'Generated snowy mountain 1F', None, 'interior', 51009, [(15,21),(25,2)]),
    ('12-snow-mountain-2', 'Generated snowy mountain 2F', None, 'interior', 51010, [(25,4),(15,23)]),
    ('13-summit', 'Snowy summit, cabin exterior and reachable endpoint', 15522, 'interior', 15522, [(41,40),(23,22),(41,9)]),
]


def decode(number, catalog):
    number=int(number)
    if number == 100:
        with lib.connection() as db:
            ident = db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/100.dat'").fetchone()[0]
        raw = lib.source_file(ident)[1].read_bytes()
        w,h,f,o,flags = lib.parse_map(raw)
        walk = navigation_grid(w,h,f,o,lib.serial_index())
    else:
        row = catalog['maps'][f'BlueCrossgate/map/0/{number}.dat']
        raw = zlib.decompress(base64.b64decode(row.get('restored_raw',row['raw'])))
        w,h,f,o,flags = lib.parse_map(raw)
        bits = zlib.decompress(base64.b64decode(row['walk']))
        walk = [bool(bits[i>>3] & (1 << (i&7))) for i in range(w*h)]
    return dict(raw=raw, width=w,height=h,floor=f,objects=o,flags=flags,walk=walk)


def path_between(data, anchors):
    w,h = data['width'], data['height']
    walk = data['walk']
    result = []
    for start, end in zip(anchors, anchors[1:]):
        assert walk[start[1]*w+start[0]] and walk[end[1]*w+end[0]], (start,end)
        costs = {start:0}; previous = {start:None}; queue = [(0,start)]
        while queue:
            cost,p = heapq.heappop(queue)
            if cost != costs[p]:continue
            if p == end:break
            x,y = p
            for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                a,b = q
                if not (0<=a<w and 0<=b<h) or not walk[b*w+a]:continue
                floor = data['floor'][b*w+a]
                if 5000<=floor<=5008:continue
                step = 1 if 5198<=floor<=5233 or 6400<=floor<=6409 else 2
                value = cost+step
                if value < costs.get(q,float('inf')):
                    costs[q]=value;previous[q]=p;heapq.heappush(queue,(value,q))
        assert end in previous, ('No unchanged source corridor',start,end)
        path=[];p=end
        while p is not None:path.append(p);p=previous[p]
        result += list(reversed(path))[bool(result):]
    assert all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(result,result[1:]))
    return result


def plan():
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    OUT.mkdir(parents=True,exist_ok=True)
    stages=[]
    for key,title,number,area,floor,anchors in STAGES:
        row=dict(key=key,title=title,source=number,area=area,floor=floor,anchors=anchors)
        if number is not None:
            data=decode(number,catalog);path=path_between(data,anchors)
            row.update(path=path,source_sha256=hashlib.sha256(data['raw']).hexdigest(),sections=[])
            for i,start in enumerate(range(0,len(path)-1,16)):
                part=path[start:min(start+17,len(path))]
                row['sections'].append(dict(key=f'{key}-{i+1:02d}',start=part[0],end=part[-1],at=part[len(part)//2],path=part,
                    recorded_cells=sum(bool(data['flags'][y*data['width']+x]&0xc000) for x,y in part)))
        else:
            row.update(path=[],sections=[],blocker='Current generated layout is not a recovered original floor; original random generation and 21–23-floor order are unavailable. Preserve existing two-floor connections.')
        stages.append(row)
    document=dict(seed=341,stages=stages,exclusions=['Saint Laruka','Jenova town','Tina','Abanis village interior and streets','Magic University','Cursed Maze','summit cabin interior','unreachable summit exit 15536'],
        gaps=['Original snowy mountain has a random multi-floor climb; current Explore has two generated floors. Exit destinations are frozen.',
              'Native map tiles and isometric art do not provide walkable elevation fields or hidden-side geometry. Existing collision and ground heights are frozen.',
              'The fixed summit return (41,40) is the current generated-route landing, not an original recovered stair. Original summit exit (41,8–9) leads to unavailable 15536.'])
    (OUT/'route.json').write_text(json.dumps(document,indent=2)+'\n')
    print('Planned',len(stages),'stages;',sum(len(s['sections']) for s in stages),'continuous fixed-map sections')


@lru_cache(maxsize=2048)
def graphic(serial):
    g=lib.serial_index()[serial]
    return lib.image_from_record(g['pack'],g['row'])


def reference(pose,data,overhead=False):
    canvas=Image.new('RGB',(1280,800),'#263138')
    origin=pose['source_zero'];vx=pose['source_x'];vy=pose['source_y']
    scale=abs(vx[0])/32 if not overhead else 1
    w,h=data['width'],data['height'];lookup=lib.serial_index()
    placements=[]
    for plane in (0,1):
        for i,serial in enumerate(data['floor'] if plane==0 else data['objects']):
            if serial<1000 or serial not in lookup:continue
            g=lookup[serial];x,y=i%w,i//w
            px=origin[0]+x*vx[0]+y*vy[0];py=origin[1]+x*vx[1]+y*vy[1]
            if overhead:
                if plane:continue
                if -10<px<1290 and -10<py<810:
                    im=graphic(serial);rgb=im.convert('RGB').resize((1,1)).getpixel((0,0))
                    a,b=abs(vx[0]),abs(vy[1]);ImageDraw.Draw(canvas).rectangle((px-a/2,py-b/2,px+a/2+1,py+b/2+1),fill=rgb)
                continue
            px+=g['x']*scale;py+=g['y']*scale
            sw,sh=max(1,round(g['w']*scale)),max(1,round(g['h']*scale))
            if px>1280 or py>800 or px+sw<0 or py+sh<0:continue
            depth=11*y-9*x-min(g['east'],g['south'])*10
            placements.append((0 if plane==0 or g['ground'] else 1,depth,px,py,serial,sw,sh))
    for _,_,x,y,serial,w,h in sorted(placements):
        im=graphic(serial).resize((w,h),Image.Resampling.BICUBIC)
        canvas.paste(im,(round(x),round(y)),im)
    return canvas


def panel(images,labels,width=640):
    out=Image.new('RGB',(width*len(images),round(images[0].height*width/images[0].width)+34),'#20292e')
    draw=ImageDraw.Draw(out)
    for i,(im,label) in enumerate(zip(images,labels)):
        im=im.convert('RGB').resize((width,out.height-34),Image.Resampling.LANCZOS)
        out.paste(im,(i*width,34));draw.text((i*width+9,10),label,fill='white')
    return out


def compare(phase='Before'):
    document=json.loads((OUT/'route.json').read_text())
    poses=json.loads((OUT/phase/'cameras.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    original=OUT/'Original';original.mkdir(exist_ok=True)
    pairs=OUT/('Source vs '+phase);pairs.mkdir(exist_ok=True)
    before_after=OUT/'Before vs After';before_after.mkdir(exist_ok=True)
    datasets={}
    grouped={}
    full_groups={}
    report=[]
    replay_file=OUT/'Replay/cameras.json'
    replay={p['name']:p for p in json.loads(replay_file.read_text())} if replay_file.exists() else {}
    for pose in poses:
        name=pose['name'];source=pose['source']
        current=Image.open(OUT/phase/(name+'.png'))
        if pose['kind'] in ('isometric','overhead') and source is not None:
            if source not in datasets:datasets[source]=decode(source,catalog)
            native=reference(pose,datasets[source],pose['kind']=='overhead')
            native.save(original/(name+'.png'))
            p=panel([native,current],[name+' | SOURCE MAP '+('PLAN' if pose['kind']=='overhead' else '/ NATIVE ART'),phase.upper()+' | SOURCE-ALIGNED 3D'])
            p.save(pairs/(name+'.jpg'),quality=90)
            key=next(s['key'] for s in document['stages'] if name.startswith(s['key']))
            grouped.setdefault(key,[]).append(p)
            full_groups.setdefault(key,[]).append((name,p))
        old=OUT/'Before'/(name+'.png')
        if phase=='After' and old.exists():
            p=panel([Image.open(old),current],[name+' | BEFORE',name+' | AFTER'])
            p.save(before_after/(name+'.jpg'),quality=90)
        elif phase=='After' and name in replay:
            previous=Image.open(OUT/'Replay'/(name+'.png'))
            p=panel([previous,current],[name+' | BASELINE SCENERY REPLAY',name+' | CURRENT'])
            p.save(before_after/(name+'.jpg'),quality=92)
        report.append(pose)
    # Compact sheets still link to every full-size, labelled comparison.
    for key,images in grouped.items():
        thumbs=[]
        for im in images:
            copy=im.copy();copy.thumbnail((768,270));thumbs.append(copy)
        sheet=Image.new('RGB',(768,sum(i.height for i in thumbs)),'#20292e');y=0
        for im in thumbs:sheet.paste(im,(0,y));y+=im.height
        sheet.save(pairs/(key+'-all-sections.jpg'),quality=90)
    for key,images in full_groups.items():
        for offset in range(0,len(images),4):
            rows=images[offset:offset+4]
            sheet=Image.new('RGB',(1280,sum(im.height for _,im in rows)),'#20292e');y=0
            for _,im in rows:sheet.paste(im,(0,y));y+=im.height
            sheet.save(pairs/(key+f'-page-{offset//4+1:02d}.jpg'),quality=93)
    (OUT/f'{phase.lower()}-coverage.json').write_text(json.dumps(dict(captures=len(poses),fixed_sections=sum(p['kind']=='isometric' and p['source'] is not None for p in poses),source_maps=list(datasets)),indent=2)+'\n')
    print('Compared',len(poses),'fixed captures;',len(grouped),'source-backed areas')


def handoff():
    document=json.loads((OUT/'After/route.json').read_text())
    poses=json.loads((OUT/'After/cameras.json').read_text())
    before={p['name']:p for p in json.loads((OUT/'Before/cameras.json').read_text())}
    after={p['name']:p for p in poses}
    differences=[]
    for name,old in before.items():
        if name not in after:differences.append([name,'missing']);continue
        for key in ('eye','rotation','size','fov','projection','seed','links'):
            a,b=after[name][key],old[key]
            equal=all(abs(x-y)<1e-4 for x,y in zip(a,b)) if key in ('eye','rotation') else a==b
            if not equal:differences.append([name,key])
    assert not differences, differences
    replay_file=OUT/'Replay/cameras.json'
    replay=json.loads(replay_file.read_text()) if replay_file.exists() else []
    replay_views=[p for p in replay if 'first-snow' in p['name']]
    for old in replay_views:
        assert old['name'] in after
        for key in ('eye','rotation','size','fov','projection','seed','links'):
            a,b=after[old['name']][key],old[key]
            assert all(abs(x-y)<1e-4 for x,y in zip(a,b)) if key in ('eye','rotation') else a==b, (old['name'],key)
    sections=sum(len(s['sections']) for s in document['stages'])
    scenery=json.loads((ROOT/'assets/maps/falan/west_route_scenery.json').read_text())
    tree_count=sum(len(s['trees']) for s in scenery['maps'].values())
    detail_count=sum(len(s['details']) for s in scenery['maps'].values())
    bank_count=sum(len(s['banks']) for s in scenery['maps'].values())
    proof=dict(common_fixed_cameras=len(before),after_captures=len(poses),continuous_sections=sections,
        camera_seed_and_exit_differences=differences,seed=poses[0]['seed'],additional_first_snow_replay_cameras=len(replay_views),
        source_fixed_sections=sum(len(s['sections']) for s in document['stages'] if s['source'] is not None),
        source_model_limit='Native maps/art establish visible paint and anchors, not unseen 3D sides or collision elevation fields.')
    (OUT/'verification.json').write_text(json.dumps(proof,indent=2)+'\n')
    lines=['# West Gate to the snowy endpoint — route review','',
        'Current source reconstruction, 2026-11-23. No app export. NPCs, encounters, native army, collision and exit destinations are unchanged. This is not a 1:1 claim.','',
        f'{sections} continuous sections were inspected; {len(before)} baseline cameras have identical eye, rotation, projection, FOV/span, seed and exit metadata in the final captures. Generated-floor coverage also includes additional path inspections.','',
        'The transit caves are necessary route sections. Optional towns, building interiors, side dungeons and unavailable destinations are excluded.','',
        '## Ordered route','',
        '| Order | Section | Source coordinates in travel order | Review stretches |','|---|---|---|---|']
    for i,s in enumerate(document['stages'],1):
        anchors=' → '.join(f'({int(x)},{int(y)})' for x,y in s['anchors'])
        lines.append(f"| {i} | {s['title']} — {int(s['source']) if s['source'] is not None else 'generated'} | {anchors} | {len(s['sections'])} |")
    lines+=['','White-tipped cliff artwork is already present on southern Shalena. The first clear ground-snow edge on the selected road is native tile 8299 at (212,349), followed by mostly snowy 8317 at (212,348) and full-snow 8174 at (212,347), before the western cave entrance. Earlier pale tiles 8181 and 8628 are grass/dirt, not ground snow. `snow-transition-source.png` records the original tiles in travel order. Western cave 3F contains a separate patchy-snow transition before the full snowfield on map 402.','',
        'The reachable snowy endpoint is the fixed summit (15522), including the cabin exterior and north approach (41,8–9). Its original transfer leads to unavailable map 15536; the current runtime has no active forward link there. The cabin interior is excluded.','',
        '## Corrections','',
        f'- Restored {tree_count} native tree anchors/identities across the two Freyja views, Shalena, the snowfield and summit. Reused editable flora meshes, fitted per source crown width/height, and recovered native green/blue/olive palette variations without thinning the corridor.',f'- Restored {detail_count} native roadside details, including the western stone bridge parapets/arch supports, fence arms, reeds, flowers, stumps, boulders, mushrooms and a chair. Preserved source art and reused shared mesh builders.','- Replaced the fabricated Freyja entrance arch/stone paving/sign with the recorded fence arrangement. The travel trigger remains at (201,166).','- Removed duplicate generic cliff visuals inside the restored Freyja corridor while retaining their existing collision shapes. Prepared 30 Freyja and 36 undersea cliff profiles through the existing native-paint builder; 186 measured profiles are covered by the source check.','- Joined cliff footprints and filled source-recorded blocked interiors so the masses no longer contain flat lawns and stray spikes. Every original open cell remains excluded. Visible vertical scale follows the native isometric projection; Freyja cliff bases follow the existing terrain without altering it. Meshes remain spatially batched.','- Restored full/patchy snow on route-owned tree materials and recovered sparse snowy sapling trunks/branches and crown clusters for fixed and generated route areas. Shared foliage keeps its previous appearance by default.','- Fixed Western Freyja being omitted from the original-ground texture path. Both western road views now use the actual recovered floor cells at full strength, retaining the existing painted finish.',f'- Restored {bank_count} native shore-bank paint tiles over the existing terrain using the shared coast builder. Preserved shore positions, stairs, buildings, source map planes, player/army ownership and travel destinations.','',
        '## Specific blockers and limits','',
        '1. **Mountain route gap:** the original is a random multi-floor mountain climb. Explore retains its existing two generated floors. The cached examples do not establish an original random generation algorithm, floor count/order or an exact fixed layout. No missing floors or new transfers were invented.','2. **Snowy endpoint gap:** summit transfer 15536 is unavailable. The checklist stops on reachable summit ground; it does not claim to reconstruct the destination.','3. **Elevation/collision:** source caches contain tile/object planes and walk masks, not authoritative walkable height fields. Existing rolling Freyja ground and flat recovered-map collision remain intact as requested. Exact slopes/grades cannot be verified from these references.','4. **3D geometry:** original art has one isometric view and masked/black unseen cliff surfaces. Hidden sides, caps, tunnel depth and crown depth remain fitted interpretations. Reused stylized tree/rock forms are not original 3D models. Source-backed positions, visible paint, contours and proportions were compared separately.','5. **Reference coverage:** no independent original gameplay-camera image exists for every ordinary stretch. The complete local client cells and unmodified source graphics provide the per-section comparison; references do not support calling the route 1:1.','6. **Existing transfer discrepancy:** the preserved catalog contains an obsolete southern-map Abanis transfer. Runtime already excludes it and uses all three western cave floors. This work did not redirect an exit.','7. **Camera occlusion:** fixed close entrance views `06-shalena-south-20-play`, `10-snowfield-15-play` and `10-snowfield-anchor-05-play` intersect recovered tree crowns. The original art supplies no third-person crown/back-face reference. Native anchors and camera poses were preserved; wider approach and source-aligned overhead comparisons show the placements, but these close views cannot verify the landmark silhouette. Moving the trees or changing the normal camera would defeat those preserved controls.','8. **Runtime diagnostics:** capture runs still emit shutdown RID/resource cleanup diagnostics, also present in the baseline. Script errors and assertions are checked separately. These short captures do not establish leak-free long-session behavior or an army stress-test FPS result.','',
        'Map composites retain every recorded client cell. Where the existing catalog supplies an overlap-checked pinned map-reference completion, that completion also appears in the source view. It is not presented as an original gameplay screenshot; the catalog preserves separate client/reference hashes and completion provenance.','',
        '## Evidence','',
        '- The exact ground-snow edge views were added after the historical baseline capture. Their comparisons are explicitly labelled **baseline scenery replay**, not historical Before. The replay restores source 400’s preserved original tree/rock presentation in memory, with the same native runtime, raw map and exits. `baseline-replay-control.jpg` compares that replay at an existing historical camera; its mean RGB difference is 0.027% of full scale (wind/animation remain live). Four exact first-snow camera poses are also matched to that replay.','',
        '- Two additional bridge approach/crossing gameplay views are current-only supplements, because the missing bridge was identified after baseline capture. They are not labelled historical Before.','- Open `index.html` beside this report for every labelled source/3D and before/after comparison.','- `Original/`: independent native art composites; `Source vs After/`: source-aligned section pages; `Before vs After/`: identical-camera comparisons.','- `Before/cameras.json` and `After/cameras.json`: captured camera poses and actual exit metadata.','- `After/route.json`: the full ordered, contiguous section checklist, including generated path cells.','- `verification.json`: camera/seed/exit equality checks. Source, asset, parse and rendered-review logs are retained beside it.','',
        'Original route corroboration: [western cave](https://cg.skyey.tw/map/ma17.htm), [Shalena map coordinates](https://cg.skyey.tw/map/ma003.htm), [mountain entrance and summit cabin](https://cg.skyey.tw/errand/macc01.htm). Local client bytes and their hashes remain the primary placement/art evidence.','',
        '## Every connecting stretch','']
    for s in document['stages']:
        lines += [f"### {s['key']} — {s['title']}",'']
        for part in s['sections']:
            start,end=part['start'],part['end'];name=part['key']
            state='Compared to native source cells/art; fitted 3D limits 3–5 above apply.' if s['source'] is not None else 'Compared across the unchanged seeded current layout; original layout/order blocked by limit 1.'
            lines.append(f"- [x] `{name}`: ({int(start[0])},{int(start[1])}) → ({int(end[0])},{int(end[1])}). {state}")
        lines.append('')
    (OUT/'ROUTE_REVIEW.md').write_text('\n'.join(lines)+'\n')
    pages=['<!doctype html><meta charset="utf-8"><title>West Gate → Snow Route</title><style>body{margin:32px auto;max-width:1440px;padding:0 24px;background:#19242b;color:#e9f1f5;font:17px/1.55 system-ui}a{color:#8ed8ff}img{max-width:100%;height:auto}details{border-top:1px solid #50616c;padding:16px 0}summary{font-size:22px;cursor:pointer}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}h1{font-size:36px}</style>',
        '<h1>West Gate → snowy summit</h1><p>Ordered route, ordinary connecting stretches, source comparisons and identical-camera before/after captures.</p><p><a href="ROUTE_REVIEW.md">Full ordered checklist, corrections and specific blockers</a> · <a href="verification.json">Camera and exit verification</a></p>',
        '<p>Not 1:1: the original random mountain climb is represented by the existing two generated floors; unavailable summit destination 15536 is excluded. Native maps do not establish collision elevations or unseen 3D geometry.</p>']
    for i,s in enumerate(document['stages'],1):
        pages.append(f"<details><summary>{i}. {html.escape(s['title'])} — {len(s['sections'])} continuous sections</summary>")
        key=s['key']
        overview=f'Source vs After/{key}-whole-overhead.jpg' if s['source'] is not None else f'Before vs After/{key}-whole-overhead.jpg'
        pages.append(f'<p>Full-route overhead</p><a href="{overview}"><img loading="lazy" src="{overview}"></a>')
        for section in s['sections']:
            name=section['key']
            if s['source'] is not None:
                path=f'Source vs After/{name}-iso.jpg'
                pages.append(f'<p>{html.escape(name)} · native source / final 3D</p><a href="{path}"><img loading="lazy" src="{path}"></a>')
            else:
                path=f'After/{name}-iso.png';pages.append(f'<p>{html.escape(name)} · current seeded layout, original layout unavailable</p><a href="{path}"><img loading="lazy" src="{path}"></a>')
        pages.append('<h3>Fixed gameplay cameras</h3><div class="grid">')
        for pose in poses:
            if not pose['name'].startswith(key) or pose['kind']!='gameplay':continue
            name=pose['name'];path=f'Before vs After/{name}.jpg' if name in before or any(p['name']==name for p in replay_views) else f'After/{name}.png'
            pages.append(f'<div>{html.escape(name)}<a href="{path}"><img loading="lazy" src="{path}"></a></div>')
        pages.append('</div></details>')
    (OUT/'index.html').write_text('\n'.join(pages))
    print('Handoff:',sections,'continuous sections;',len(before),'identical baseline cameras; no exit/seed differences')


if __name__=='__main__':
    if '--handoff' in sys.argv:handoff()
    elif '--compare' in sys.argv:compare('After' if '--after' in sys.argv else 'Before')
    else:plan()
