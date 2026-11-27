"""Read-only regional survey. Original client geography and current runtime stay distinct."""
import hashlib,json,sys
from collections import deque
from functools import lru_cache
from pathlib import Path
from PIL import Image,ImageDraw
import review_ruby_region as source
from prepare_snow_region_population import rows,SOURCE

ROOT=source.ROOT
OUT=ROOT/'build/Other Files/Asset Toolkit/Sokia Region Reconstruction'

@lru_cache(maxsize=64)
def native(number):
    return source.decode(number)

def audit():
    OUT.mkdir(parents=True,exist_ok=True)
    d=native(300);w,h=d['width'],d['height']
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    warps=[r for r in catalog['warps'] if r[0]==300 or r[3]==300]
    # Both sides of Great Wind and Ghana's north gate are separate outdoor entry components.
    seeds=[(273,294),(294,325),(402,304),(704,95)]
    components=[];seen=set()
    for seed in seeds:
        start=seed[1]*w+seed[0]
        assert d['walk'][start],seed
        if start in seen:continue
        found={start};queue=deque([start])
        while queue:
            i=queue.popleft();x,y=i%w,i//w
            for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                j=yy*w+xx
                if 0<=xx<w and 0<=yy<h and d['walk'][j] and j not in found:
                    found.add(j);queue.append(j)
        components.append(dict(seed=seed,cells=len(found),bounds=[min(i%w for i in found),min(i//w for i in found),max(i%w for i in found),max(i//w for i in found)]))
        seen.update(found)
    crops=json.loads((ROOT/'assets/maps/falan/sokia/provenance.json').read_text())['regions']
    covered=set()
    for region in crops.values():
        x,y,cw,ch=region['bounds']
        covered.update(yy*w+xx for yy in range(max(0,y),min(h,y+ch)) for xx in range(max(0,x),min(w,x+cw)))
    im=Image.new('RGB',(w,h),'#172329');paint=im.load()
    for i in range(w*h):
        if i in seen:paint[i%w,i//w]=(103,174,122) if i in covered else (214,112,74)
        elif d['walk'][i]:paint[i%w,i//w]=(80,96,104)
    draw=ImageDraw.Draw(im)
    for area,region in crops.items():
        x,y,cw,ch=region['bounds'];draw.rectangle((x,y,x+cw-1,y+ch-1),outline='#e5db9c');draw.text((x+2,max(0,y)+3),area,fill='white')
    for a,x,y,b,tx,ty in warps:
        if a==300:draw.ellipse((x-2,y-2,x+2,y+2),fill='#faf5dc')
    im.resize((1600,1064),Image.Resampling.NEAREST).save(OUT/'source-300-reachable-coverage.png')
    reach=bytearray((w*h+7)//8)
    for i in seen:reach[i>>3]|=1<<(i&7)
    (OUT/'source-reachable.bin').write_bytes(reach)
    runtime_path=OUT/'runtime-before.json'
    runtime=json.loads(runtime_path.read_text()) if runtime_path.exists() else []
    actor_maps={300,13001,3000,3350,3351,3352,3353,*[int(r['floor']) for r in runtime if r['area']=='interior' and r['floor'] not in [15004,47010,3300]]}
    npcs=[]
    for r in rows('npc.txt'):
        if len(r)<25 or not r[8].isdigit() or int(r[8]) not in actor_maps:continue
        if r[0] in ['Warp','HouseWarp2']:continue
        active=r[6]=='1' and r[20].isdigit() and r[20]!='1' and int(r[3])<1000000
        npcs.append(dict(id=r[3],name=r[1],type=r[0],map=int(r[8]),cell=list(map(int,r[9:11])),graphic=r[20],active_original_candidate=active,event=r[24],status='pending runtime roster reconciliation'))
    branches=[]
    for a,x,y,b,tx,ty in warps:
        if a!=300:continue
        branches.append(dict(source=300,at=[x,y],target=b,arrival=[tx,ty],native_reachable=y*w+x in seen,inside_current_crop=y*w+x in covered,source_file_exists=(ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0'/f'{b}.dat').exists(),status='pending runtime link reconciliation'))
    zones=[dict(id=r[0],map=int(r[3]),bounds=list(map(int,r[4:8])),raw=r) for r in rows('encount.txt') if int(r[3]) in actor_maps]
    report=dict(source_map=300,size=[w,h],source_sha256=hashlib.sha256(d['raw']).hexdigest(),components=components,reachable_cells=len(seen),reachable_cells_outside_current_crops=len(seen-covered),crops=crops,warps=warps,branches=branches,npcs=npcs,encounter_zones=zones,limits='Client map/art are original BlueCrossgate. Fixed warps and NPC/encounter records are pinned recovery/server references, not authenticated BlueCG server execution. Reachability is four-neighbour native walking geometry, not proof of current 3D traversal.')
    (OUT/'source-survey.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    lock=OUT/'protected-before.json'
    if not lock.exists():
        protected=['assets/maps/falan/freyja_destinations_data.gd','assets/maps/falan/venoa_scenery/data.gd','scripts/forest/forest_kili_art.gd','scripts/forest/forest_kili_roofs.gd','scripts/forest/forest_ruby_region_art.gd']
        lock.write_text(json.dumps({p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in protected if (ROOT/p).exists()},indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['components','reachable_cells','reachable_cells_outside_current_crops']},indent=2))
    print('Surveyed',len(branches),'outward warp records and',len(npcs),'NPC/event records; no gameplay edited')

def plan():
    survey=json.loads((OUT/'source-survey.json').read_text())
    stages=[]
    definitions=[('01-coast','Sokia coast outside both Kili gates',300,'sokia_coast',0,survey['crops']['sokia_coast']['bounds']),
      ('02-great-wind','Great Wind Cave / both mouths and every chamber',13001,'interior',13001,None),
      ('03-desert','Sokia desert',300,'sokia_desert',0,survey['crops']['sokia_desert']['bounds']),
      ('04-ghana-road','Ghana southern roads',300,'ghana_road',0,survey['crops']['ghana_road']['bounds']),
      ('05-ghana','Ghana reachable streets',3000,'ghana',0,None),
      ('06-ghana-north','Ghana northern roads / Imur boundary',300,'ghana_north_road',0,survey['crops']['ghana_north_road']['bounds']),
      ('07-fengnu','Fengnu house',3350,'interior',3350,None),('08-fengnu-study','Fengnu study',3352,'interior',3352,None)]
    for key,title,number,area,floor,crop in definitions:
        d=native(number);w,h=d['width'],d['height']
        x,y,cw,ch=crop if crop else [0,0,w,h]
        sections=[];step=24
        for yy in range(max(0,y),min(h,y+ch),step):
            for xx in range(max(0,x),min(w,x+cw),step):
                cells=[(a,b) for b in range(yy,min(h,yy+step,y+ch)) for a in range(xx,min(w,xx+step,x+cw)) if d['walk'][b*w+a]]
                if not cells:continue
                at=min(cells,key=lambda c:(c[0]-xx-step/2)**2+(c[1]-yy-step/2)**2)
                sections.append(dict(key=f'{key}-{len(sections)+1:02d}',at=at,start=at,end=[at[0],at[1]-1]))
        stages.append(dict(key=key,title=title,source=number,area=area,floor=floor,bounds=[[x,y],[x+cw-1,y+ch-1]],sections=sections))
    (OUT/'route.json').write_text(json.dumps(dict(seed=41829558,stages=stages,scope='Initial map-by-map captures. Source cells outside crops, missing branches, Ghana interiors and destination boundaries stay pending in REGIONAL_ROUTE.md.'),ensure_ascii=False,indent=2)+'\n')
    runtime=json.loads((OUT/'runtime-before.json').read_text())
    available={int(l.get('site',l.get('floor',0))) for r in runtime if r['area'] in ['sokia_coast','sokia_desert','ghana_road','ghana_north_road'] for l in r['links']}
    lines=['# Sokia regional reconstruction — locked survey, 2026-11-26','',
      'Work is active. No map is marked finished by this survey. Kili interiors and their data remain excluded.','',
      '## Actual current route','',
      '- Both Kili 3200 gates → Sokia 300 coast (west: 273–275,294; east: 294,324–326).',
      '- Coast → Great Wind 13001 at Sokia (356,334) / cave (18,6) → cave (133,26) / desert (402,304). The fixed source warp list has two outdoor ports and no onward room on 13001; all chambers of this one source room are in scope.',
      '- Desert → Ghana southern road: current region seam at original x550, y235; Ghana 3000 south gate at source (702–704,147). Ghana streets and its current connected interiors are in scope.',
      '- Ghana north gate (48–49,26) → Sokia (704–705,95); northern road → guard (707,58) → grave (715,34). Imur 47010 and its seeded forest/quest chain are a separate region: inspect the connection, finish this approach, preserve that chain.',
      '- Desert → existing ancient-person Falken link (540,350) → 3300 and its capital/tower quest. Finish the desert branch up to the ancient person; the time-travel capital/tower is outside this geographic region. Preserve the working quest and named fight.',
      '- Coast (349,261) ↔ Fengnu 3350 (1,6), plus study 3352. Existing Ruby-only reward return chain is preserved as a separate dungeon boundary.',
      '- Coast (240,265) ↔ undersea 15004 (11,44): finish the coastal approach, preserve the already connected Freyja/Ruby region beyond it.','',
      '## Source coverage gap','',
      f"Original map 300 is {survey['size'][0]} × {survey['size'][1]}. Native four-neighbour reachability from both Kili gates, Great Wind east and Ghana north covers {survey['reachable_cells']:,} cells; {survey['reachable_cells_outside_current_crops']:,} are outside the current four crops. These cells remain required work, not a missing-source excuse.",
      '', '## Every outward fixed source port','', '| Original cell | Destination / arrival | Current outdoor link | Status |','|---|---|---|---|']
    for b in survey['branches']:
        current=b['target'] in available
        status='pending review' if current else 'missing link: source exists; investigate/restore original approach'
        if not b['native_reachable']:status='pending reachability investigation: separate source component; not silently excluded'
        lines.append(f"| {b['at']} | {b['target']} / {b['arrival']} | {'present' if current else 'absent'} | {status} |")
    lines+=['','## Map and actor review queue','']
    for r in runtime:lines.append(f"- [ ] {r['key']} — {r['title']}: {len(r['links'])} actual links, {len(r['npcs'])} visible NPC records. Kili is read-only boundary evidence; 15004, 47010 and 3300 are connection evidence at separate-region boundaries.")
    lines+=['','- [ ] All additional map-300 ground outside the four current crops, including the western hills, southern desert/stone monuments and eastern land.','- [ ] Missing fixed-port branches 5003, 13014, 13015, 13500, 23600 and 15564; inspect onward links before assigning dungeon boundaries.','- [ ] Event-only/one-way ports returning from 13002, 15517/15520, 302 and 3355: recover event semantics before adding a crossing.','- [ ] Source 15527/15530 islands: inspect access; native four-neighbour component is not connected to current entry seeds.','- [ ] Reconcile every active documented NPC and encounter against actual current actors before adding or moving anything. Existing Falken ancient person is at (540,350); pinned general server NPCs also list distinct ancient people at (579,275), (514,337), (593,332). Preserve the working quest while reconciling these records.','',
      'Evidence: `source-survey.json`, `runtime-before.json`, `source-300-reachable-coverage.png`, `protected-before.json`. Client geography/art are authoritative originals; server warp/NPC/encounter references have their own provenance and are not certified BlueCG server execution.']
    (OUT/'REGIONAL_ROUTE.md').write_text('\n'.join(lines)+'\n')
    print('Locked regional survey; prepared',len(stages),'initial source/build comparison stages')

def compare(phase):
    source.OUT=OUT
    source.compare(phase)

def approach_plan():
    """Add current-only path-facing views; retain every historical camera unchanged."""
    def views(number,root,ports,prefix):
        d=native(number);w,h=d['width'],d['height'];walk=d['walk']
        start=min((i for i,v in enumerate(walk) if v),key=lambda i:(i%w-root[0])**2+(i//w-root[1])**2)
        parent={start:None};queue=deque([start])
        while queue:
            i=queue.popleft();x,y=i%w,i//w
            for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                j=b*w+a
                if 0<=a<w and 0<=b<h and walk[j] and j not in parent:parent[j]=i;queue.append(j)
        result=[]
        for name,(x,y) in ports:
            eligible=[i for i in parent if abs(i%w-x)<=2 and abs(i//w-y)<=2]
            assert eligible,(number,name,'No source walking approach')
            last=min(eligible,key=lambda i:(i%w-x)**2+(i//w-y)**2);path=[]
            while last is not None:path.append([last%w,last//w]);last=parent[last]
            path.reverse();assert len(path)>3,(number,name,'Review hub too close to port')
            k=max(1,len(path)-9)
            result.append(dict(key=prefix+'-'+name,at=path[k],start=path[max(0,k-3)],end=path[min(len(path)-1,k+3)],original_port=[x,y],source=number,current_only=True))
        return result
    p=OUT/'route.json';route=json.loads(p.read_text())
    route['approaches']={
        '10-coast-expanded':views(300,(334,329),[
            ('kili-west-approach',(274,294)),('kili-east-approach',(294,325)),('undersea-approach',(240,265)),
            ('trainer-approach',(148,199)),('fengnu-approach',(349,261)),('great-wind-west-approach',(356,334)),
            ('great-wind-east-approach',(402,304)),('meteor-lower-approach',(187,229)),('lion-hall-approach',(380,324)),('wind-cave-approach',(368,351))],'10-coast-expanded'),
        '02-great-wind':views(13001,(75,25),[('west-mouth',(18,6)),('east-mouth',(133,26)),('pools-junction',(85,23))],'02-great-wind')}
    route['approaches']['05-ghana']=views(3000,(52,52),[('south-gate',(48,76)),('north-gate',(48,27)),('well',(55,54))],'05-ghana')
    route['approaches']['12-desert-expanded']=views(300,(440,310),[('quiet-column',(488,314)),('ancient-west',(514,337)),('ancient-north',(579,275)),('ancient-east',(593,332)),('camp',(534,323)),('fire-stone',(512,232)),('water-stone',(581,422)),('earth-stone',(630,300)),('ancient-stele',(623,362))],'12-desert-expanded')
    route['approaches']['13-ghana-expanded']=views(300,(700,180),[('south-gate',(704,147)),('water-cave',(626,209)),('forger',(671,157))],'13-ghana-expanded')
    route['approaches']['06-ghana-north']=views(300,(710,70),[('north-gate',(704,96)),('cape-guard',(707,58)),('grave',(715,34))],'06-ghana-north')
    p.write_text(json.dumps(route,ensure_ascii=False,indent=2)+'\n')
    print('Prepared source-walking approaches:',{key:len(value) for key,value in route['approaches'].items()})

def contacts(phase):
    target=OUT/('Review '+phase);target.mkdir(exist_ok=True)
    poses=json.loads((OUT/phase/'cameras.json').read_text())
    route=json.loads((OUT/'route.json').read_text())
    for stage in route['stages']:
        panels=[]
        for pose in poses:
            if not pose['name'].startswith(stage['key']) or pose['kind']!='isometric':continue
            panel=Image.new('RGB',(640,228),'#20292e');draw=ImageDraw.Draw(panel)
            draw.text((4,3),pose['name'],fill='white')
            for i,folder in enumerate(['Original',phase]):
                with Image.open(OUT/folder/(pose['name']+'.png')) as im:panel.paste(im.convert('RGB').resize((320,200)),(i*320,28))
                draw.text((i*320+4,15),'BLUE CG SOURCE' if i==0 else phase.upper()+' 3D',fill='white')
            panels.append(panel)
        for offset in range(0,len(panels),8):
            batch=panels[offset:offset+8];sheet=Image.new('RGB',(1280,228*((len(batch)+1)//2)),'#20292e')
            for i,im in enumerate(batch):sheet.paste(im,((i%2)*640,(i//2)*228))
            sheet.save(target/(stage['key']+f'-{offset//8+1:02d}.jpg'),quality=95)
    print('Prepared',len(list(target.glob('*.jpg'))),'source/build contact sheets')

def candidates():
    import recover_sokia
    import re
    original=dict(recover_sokia.AREAS)
    profiles={'coast-only':{'sokia_coast':210,'sokia_desert':104,'ghana_road':102,'ghana_north_road':82},
              'whole-region':{'sokia_coast':210,'sokia_desert':205,'ghana_road':200,'ghana_north_road':82}}
    survey=json.loads((OUT/'source-survey.json').read_text());w,h=survey['size']
    reach=(OUT/'source-reachable.bin').read_bytes()
    reachable=[i for i in range(w*h) if reach[i>>3]&(1<<(i&7))]
    old_graphics={int(s) for s in re.findall(r'^ (\d+):Rect2i', (ROOT/'assets/maps/falan/sokia/data.gd').read_text(),re.M)}
    kili=native(3200)
    kili_props={s for s in kili['objects'] if 11625<=s<=11710 or 12160<=s<=12180}
    proof=[]
    for label,radii in profiles.items():
        recover_sokia.AREAS=radii
        masks,atlas,data,meta=recover_sokia.prepare(ROOT.parent/'Magic Power')
        target=OUT/'Source candidates'/label;target.mkdir(parents=True,exist_ok=True)
        for area,im in masks.items():im.save(target/(area+'_surface.png'))
        atlas.save(target/'props.png');(target/'data.gd').write_text(data)
        (target/'provenance.json').write_text(json.dumps(meta,indent=2)+'\n')
        bounds=[r['bounds'] for r in meta['regions'].values()]
        missing=[i for i in reachable if not any(x<=i%w<x+cw and y<=i//w<y+ch for x,y,cw,ch in bounds)]
        new_graphics={int(s) for s in re.findall(r'^ (\d+):Rect2i',data,re.M)}
        # Repacking the atlas must not silently introduce flora inside the excluded village.
        assert not ((new_graphics-old_graphics)&kili_props),('Kili prop ownership would change',label)
        if label=='whole-region':assert not missing,'The full-region candidate still drops source-connected land'
        proof.append(dict(candidate=label,radii=radii,remaining_native_cells_outside_crops=len(missing),placements={a:r['placements'] for a,r in meta['regions'].items()},excluded_kili_prop_ownership_unchanged=True,activated=False))
    recover_sokia.AREAS=original
    (OUT/'source-expansion-candidates.json').write_text(json.dumps(proof,indent=2)+'\n')
    print(json.dumps(proof,indent=2))

def activate_coast(whole=False):
    import re
    target=ROOT/'assets/maps/falan/sokia';candidate=OUT/'Source candidates'/('whole-region' if whole else 'coast-only')
    old=json.loads((target/'provenance.json').read_text());new=json.loads((candidate/'provenance.json').read_text())
    assert old['ground_sha256']==new['ground_sha256'] and old['object_sha256']==new['object_sha256']
    for area in (['sokia_coast','ghana_north_road'] if whole else ['sokia_desert','ghana_road','ghana_north_road']):
        assert old['regions'][area]==new['regions'][area],area
        assert Image.open(target/(area+'_surface.png')).tobytes()==Image.open(candidate/(area+'_surface.png')).tobytes(),area
    def rects(path):return {int(s):tuple(map(int,r.split(','))) for s,r in re.findall(r'^ (\d+):Rect2i\(([^)]+)\)',path.read_text(),re.M)}
    before=rects(target/'data.gd');after=rects(candidate/'data.gd')
    a=Image.open(target/'props.png');b=Image.open(candidate/'props.png')
    for serial,(x,y,w,h) in before.items():
        xx,yy,ww,hh=after[serial]
        assert (w,h)==(ww,hh) and a.crop((x,y,x+w,y+h)).tobytes()==b.crop((xx,yy,xx+ww,yy+hh)).tobytes(),serial
    if whole:
        reach=(OUT/'source-reachable.bin').read_bytes();w,h=new['map_size'];bounds=[r['bounds'] for r in new['regions'].values()]
        assert all(any(x<=i%w<x+cw and y<=i//w<y+ch for x,y,cw,ch in bounds) for i in range(w*h) if reach[i>>3]&(1<<(i&7)))
    baseline=OUT/('Source baseline/Before whole-region' if whole else 'Source baseline/Sokia crops');baseline.mkdir(parents=True,exist_ok=True)
    names=['data.gd','props.png','provenance.json',*([a+'_surface.png' for a in new['regions']] if whole else ['sokia_coast_surface.png'])]
    for name in names:
        if not (baseline/name).exists():(baseline/name).write_bytes((target/name).read_bytes())
        (target/name).write_bytes((candidate/name).read_bytes())
    print('Activated native whole region: zero omitted connected native cells; old prop pixels, coast and north crops unchanged' if whole else 'Activated native coast: 421x421 cells, all previous prop pixels and other region crops unchanged')

def expanded_plan():
    """Append new coverage without renaming or replacing historical baseline views."""
    path=OUT/'route.json';route=json.loads(path.read_text())
    bounds=json.loads((ROOT/'assets/maps/falan/sokia/provenance.json').read_text())['regions']['sokia_coast']['bounds']
    definitions=[('09-trainer-house','Original trainer house',5003,'interior',5003,[0,0,20,20]),
                 ('10-coast-expanded','Recovered whole coastal crop',300,'sokia_coast',0,bounds)]
    for key,title,number,area,floor,(x,y,cw,ch) in definitions:
        d=native(number);w,h=d['width'],d['height'];sections=[]
        for yy in range(max(0,y),min(h,y+ch),24):
            for xx in range(max(0,x),min(w,x+cw),24):
                cells=[(a,b) for b in range(yy,min(h,yy+24,y+ch)) for a in range(xx,min(w,xx+24,x+cw)) if d['walk'][b*w+a]]
                if not cells:continue
                at=min(cells,key=lambda c:(c[0]-xx-12)**2+(c[1]-yy-12)**2)
                sections.append(dict(key=f'{key}-{len(sections)+1:03d}',at=at,start=at,end=[at[0],at[1]-1]))
        route['stages']=[s for s in route['stages'] if s['key']!=key]
        route['stages'].append(dict(key=key,title=title,source=number,area=area,floor=floor,bounds=[[x,y],[x+cw-1,y+ch-1]],sections=sections))
    path.write_text(json.dumps(route,ensure_ascii=False,indent=2)+'\n')
    print('Added source/current-only house and expanded coast views; historical baseline identities retained')

def branch_plan():
    path=OUT/'route.json';route=json.loads(path.read_text())
    catalog=json.loads((ROOT/'assets/maps/falan/sokia/fixed/catalog.json').read_text())
    route['stages']=[s for s in route['stages'] if not s['key'].startswith('11-branch-')]
    for row in catalog['maps'].values():
        number=row['id']
        if number==5003 or row.get('sokia_visual_only',False):continue
        d=native(number);w,h=d['width'],d['height'];key=f'11-branch-{number}';sections=[]
        for y in range(0,h,24):
            for x in range(0,w,24):
                cells=[(xx,yy) for yy in range(y,min(h,y+24)) for xx in range(x,min(w,x+24)) if d['walk'][yy*w+xx]]
                if not cells:continue
                at=min(cells,key=lambda c:(c[0]-x-12)**2+(c[1]-y-12)**2)
                sections.append(dict(key=f'{key}-{len(sections)+1:02d}',at=at,start=at,end=[at[0],at[1]-1]))
        route['stages'].append(dict(key=key,title=row['title'],source=number,area='interior',floor=number,bounds=[[0,0],[w-1,h-1]],sections=sections))
    path.write_text(json.dumps(route,ensure_ascii=False,indent=2)+'\n')
    print('Added',sum(r['id']!=5003 and not r.get('sokia_visual_only',False) for r in catalog['maps'].values()),'new coastal branch maps; their first capture is labeled BranchBaseline, not a historical before state')

def delivery_views():
    """Package the latest completed phases, without relabeling historical captures."""
    import html
    route=json.loads((OUT/'route.json').read_text())
    phases=['CurrentRegional','NativeRoomArt','FinalDetails','CompletePlans']
    poses={p:json.loads((OUT/p/'cameras.json').read_text()) for p in phases}
    target=OUT/'Final overheads';target.mkdir(exist_ok=True)
    manifest=[]
    for stage in route['stages']:
        key=stage['key']
        candidates=[(phase,p) for phase in phases for p in poses[phase]
                    if p['name'].startswith(key+'-') and p['kind']=='overhead']
        if not candidates:continue
        phase,pose=candidates[-1]
        d=native(int(stage['source']));w,h=d['width'],d['height']
        grid=Image.new('RGB',(1280,800),'#263138');draw=ImageDraw.Draw(grid)
        zero=pose['source_zero'];a=pose['source_x'];b=pose['source_y']
        for i,walk in enumerate(d['walk']):
            if d['floor'][i]<1000 and d['objects'][i]<1000:continue
            x,y=i%w,i//w
            if not(stage['bounds'][0][0]<=x<=stage['bounds'][1][0] and stage['bounds'][0][1]<=y<=stage['bounds'][1][1]):continue
            cx=zero[0]+x*a[0]+y*b[0];cy=zero[1]+x*a[1]+y*b[1]
            if not(-15<cx<1295 and -15<cy<815):continue
            corners=[(cx+dx*a[0]+dy*b[0],cy+dx*a[1]+dy*b[1])
                     for dx,dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
            draw.polygon(corners,fill='#91b396' if walk else '#454f5c')
        current=Image.open(OUT/phase/(pose['name']+'.png'))
        pair=source.review.panel([grid,current],
              [key+' | ORIGINAL GRID: GREEN WALK / GREY BLOCKED',phase+' | CURRENT 3D / SAME SOURCE AXES'],width=640)
        pair.save(target/(key+'.jpg'),quality=95)
        all_poses=[dict(p,phase=phase_) for phase_ in phases for p in poses[phase_]
                   if p['name'].startswith(key+'-')]
        # A later phase replaces only the identically named view, not other sectors.
        latest={p['name']:p for p in all_poses}
        manifest.append(dict(key=key,title=stage['title'],source=stage['source'],
                             floor=stage['floor'],overhead_phase=phase,overhead=pose['name'],
                             views=list(latest.values()),one_to_one=False))
    (OUT/'final-view-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    pages=['<!doctype html><meta charset="utf-8"><title>Sokia regional source review</title>',
           '<style>body{background:#172329;color:#eee;font:16px/1.5 system-ui;max-width:1320px;margin:28px auto;padding:0 16px}a{color:#a6dbef}img{max-width:100%;height:auto}section{border-top:1px solid #687d86;padding-top:16px;margin:30px 0}summary{padding:12px;background:#293940;cursor:pointer}figure{margin:18px 0}nav{columns:3}figcaption{color:#d9d0af}</style>',
           '<h1>索奇亞 — regional reconstruction review</h1>',
           '<p><a href="REGIONAL_ROUTE.md">Ordered route, all branches and blockers</a> · <a href="current-status.json">Verification</a> · <a href="final-view-manifest.json">Exact camera / phase manifest</a></p>',
           '<p>Local BlueCrossgate map/art are primary. Green/grey overheads show the decoder walking grid, not authenticated server collision. Original isometric panels reconstruct original client art; gameplay images show the current 3D build. No section is certified 1:1. Newest room art and path views supersede the corresponding historical captures.</p>',
           '<nav>'+''.join(f'<div><a href="#{m["key"]}">{html.escape(m["title"])} / {m["source"]}</a></div>' for m in manifest)+'</nav>']
    for m in manifest:
        key=m['key'];pages.append(f'<section id="{key}"><h2>{html.escape(m["title"])} — original {m["source"]}</h2>')
        pages.append(f'<figure><figcaption>Whole plan · {m["overhead_phase"]} · source grid left, current 3D right</figcaption><a href="Final overheads/{key}.jpg"><img loading="lazy" src="Final overheads/{key}.jpg"></a></figure>')
        phase='NativeRoomArt' if any(p['phase']=='NativeRoomArt' for p in m['views']) else 'CurrentRegional'
        pages.append('<details><summary>Every native-art sector comparison</summary>')
        for sheet in sorted((OUT/('Review '+phase)).glob(key+'-*.jpg')):
            pages.append(f'<figure><figcaption>{html.escape(sheet.name)} · original left / {phase} right</figcaption><a href="Review {phase}/{sheet.name}"><img loading="lazy" src="Review {phase}/{sheet.name}"></a></figure>')
        pages.append('</details><details><summary>Current fixed gameplay / crossing approaches</summary>')
        preferred='FinalDetails' if any(p['phase']=='FinalDetails' for p in m['views']) else phase
        for p in m['views']:
            if p['kind']!='gameplay' or p['phase']!=preferred:continue
            phase=p['phase'];name=p['name'];pages.append(f'<figure><figcaption>{html.escape(name)} · original cell {p["cell"]} · {phase}</figcaption><a href="{phase}/{name}.png"><img loading="lazy" src="{phase}/{name}.png"></a></figure>')
        pages.append('</details></section>')
    pages.append('<section><h2>Source event stones</h2><p>Original client front art below; positions come from pinned event/NPC records, not map300 objects. Existing actor bounds/night/F owners remain. Current 3D backs/depth are fitted, not authenticated original geometry.</p><img loading="lazy" src="Source event stones.png">')
    for name in ['10-coast-expanded-air-stone','12-desert-expanded-fire-stone','12-desert-expanded-water-stone','12-desert-expanded-earth-stone','12-desert-expanded-ancient-stele']:
        pages.append(f'<figure><figcaption>{name} · CURRENT 3D / source camera</figcaption><a href="FinalDetails/{name}-iso.png"><img loading="lazy" src="FinalDetails/{name}-iso.png"></a></figure>')
    pages.append('</section><section><h2>Unresolved Ghana house interiors</h2><p>Runtime proxy IDs 3804–3806 are not known original map IDs. The three exterior doors are native; their original interior identity/art is unresolved. These are current stand-in views, with no native comparison or 1:1 claim.</p>')
    for p in sorted((OUT/'UnresolvedHouses').glob('*-iso.png')):
        pages.append(f'<figure><figcaption>{p.stem} · CURRENT STAND-IN ONLY</figcaption><img loading="lazy" src="UnresolvedHouses/{p.name}"></figure>')
    pages.append('</section>')
    (OUT/'index.html').write_text('\n'.join(pages)+'\n')
    print('Packaged',len(manifest),'latest whole-plan reviews with labeled native sectors and gameplay views')

if __name__=='__main__':
    command=sys.argv[1] if len(sys.argv)>1 else 'audit'
    if command=='plan':plan()
    elif command=='compare':compare(sys.argv[2])
    elif command=='contacts':contacts(sys.argv[2])
    elif command=='candidates':candidates()
    elif command=='activate-coast':activate_coast()
    elif command=='activate-region':activate_coast(whole=True)
    elif command=='expanded-plan':expanded_plan()
    elif command=='branch-plan':branch_plan()
    elif command=='approach-plan':approach_plan()
    elif command=='delivery-views':delivery_views()
    else:audit()
