"""Bound the reachable snow region against the read-only Cross Gate client."""
import hashlib
import html
import json
import sys
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw
import review_west_snow_route as source

ROOT = source.ROOT
OUT = ROOT / 'build/Other Files/Asset Toolkit/Snow Region'
MAPS = [
    (4000, 51004, '傑諾瓦村', (46, 44)),
    (400, 51031, '莎蓮娜村外道路與初雪', (212, 349)),
    (14000, 14000, '西方洞窟1F', (24, 30)),
    (14001, 14001, '西方洞窟2F', (28, 42)),
    (14002, 14002, '西方洞窟3F與雪地出口', (36, 15)),
    (402, 51032, '阿巴尼斯雪原', (184, 165)),
    (4300, 51011, '阿巴尼斯村', (41, 55)),
    (4400, 51012, '魔法大學雪地外圍', (75, 120)),
    (None, 51009, '積雪的山路1F', (15, 21)),
    (None, 51010, '積雪的山路2F', (25, 4)),
    (15522, 15522, '雪山之頂與小屋外圍', (26, 22)),
]
PROTECTED = ['assets/maps/original_crossgate/catalog.json',
             'scripts/forest/forest_explorer_travel.gd',
             'scripts/forest/forest_explorer_npcs.gd',
             'scripts/forest/forest_original_snow.gd',
             'scripts/forest/forest_frostpass.gd']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plan():
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    stages = []
    for number, floor, title, anchor in MAPS:
        key = f'{floor}'
        stage = dict(key=key, source=number, floor=floor, title=title, anchor=anchor)
        if number is None:
            stage.update(sectors=[], bounds=[0, 0, 33, 27])
            stages.append(stage)
            continue
        data = source.decode(number, catalog)
        w, h = data['width'], data['height']
        bounds = [35, 70, 250, 140] if number == 402 else [0, 0, w, h]
        allowed = None
        paths = []
        if number == 400:
            # All three Jenova approaches join the ascent; stop before unrelated towns.
            for anchors in [[(216,456),(149,472),(170,425),(196,375),(235,338)],
                            [(216,456),(224,442)]]:
                paths.append(source.path_between(data, anchors))
            allowed = {(x+dx,y+dy) for path in paths for x,y in path
                       for dx in range(-20,21) for dy in range(-20,21)}
            allowed.update((265+dx,434+dy) for dx in range(-20,21) for dy in range(-20,21))
            bounds = [110, 240, 510, 240]
        x0,y0,bw,bh = bounds
        def walk(p):
            x,y=p
            return x0<=x<x0+bw and y0<=y<y0+bh and data['walk'][y*w+x] and (allowed is None or p in allowed)
        start = min(((x,y) for y in range(y0,y0+bh) for x in range(x0,x0+bw) if walk((x,y))),
                    key=lambda p:(p[0]-anchor[0])**2+(p[1]-anchor[1])**2)
        reached={start}
        if number==400:reached.add((265,434))
        queue=deque(reached)
        while queue:
            x,y=queue.popleft()
            for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if p not in reached and walk(p):reached.add(p);queue.append(p)
        sectors={}
        for x,y in sorted(reached):sectors.setdefault((x//20,y//20),[]).append((x,y))
        stage.update(bounds=bounds, reachable_cells=len(reached),
                     reachable_spans=[[y,min(x for x,z in reached if z==y),max(x for x,z in reached if z==y)] for y in sorted({z for x,z in reached})],
                     sectors=[dict(key=f'{key}-sector-{x}-{y}', at=min(cells,key=lambda p:(p[0]-x*20-10)**2+(p[1]-y*20-10)**2),
                                   count=len(cells)) for (x,y),cells in sorted(sectors.items())],
                     paths=paths, client_sha256=catalog['maps'][f'BlueCrossgate/map/0/{number}.dat']['sha256'])
        stage['anchor']=min(reached,key=lambda p:(p[0]-anchor[0])**2+(p[1]-anchor[1])**2)
        stages.append(stage)
        with source.lib.connection() as db:
            ident=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        assert digest(source.lib.source_file(ident)[1])==stage['client_sha256']
        source.lib.overview(ident,0,1800).save(OUT/f'original-{number}.png')
    document=dict(seed=341, stages=stages, exclusions=['蒂娜與其他城鎮','建築內部','詛咒迷宮與支線地城','海底洞窟及法蘭遠路','不可達15536'],
                  limits=['Original walkable heights and unseen 3D sides are unavailable.',
                          'The two current generated mountain floors are preserved; original random floor order is unavailable.'])
    (OUT/'boundary.json').write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    lock=OUT/'protected-before.json'
    if not lock.exists():lock.write_text(json.dumps({p:digest(ROOT/p) for p in PROTECTED},indent=2)+'\n')
    lines=['# 阿巴尼斯・傑諾瓦雪地區域範圍','',
           'Boundary established before this pass from the local BlueCrossgate client files and current Explore links. Full reachable village/campus/snowfield sectors are included; the southern road uses the continuous corridor and all three Jenova approaches.','',
           '| Runtime / original | Area | Coverage sections |','|---|---|---|']
    for s in stages:lines.append(f"| {s['floor']} / {s['source'] or 'generated'} | {s['title']} | "+(f"{len(s['sectors'])} reachable 20-tile sectors" if s['source'] else 'Entire current generated floor; 12 survey views')+' |')
    lines+=['','Excluded: '+', '.join(document['exclusions']), '',
            'Road: Jenova west/north/east approaches → southern road and first snow → 14000 → 14001 → 14002 → 402 → Abanis gate / university snowfield branch / mountain approach → 51009 → 51010 → 15522.',
            'Map 402 stops at the existing runtime crop (35,70)–(284,209). It includes every connected clearing inside that crop, including the stone-disc exterior threshold. No unrelated destination is entered.']
    (OUT/'BOUNDARY.md').write_text('\n'.join(lines)+'\n')
    print('Bounded',len(stages),'maps;',sum(len(s['sectors']) for s in stages),'reachable sectors')


def package():
    before=json.loads((OUT/'Before/cameras.json').read_text())
    after=json.loads((OUT/'After/cameras.json').read_text())
    baseline={p['name']:p for p in before}
    pairs=[];maximum_camera_roundoff=0.0
    for pose in after:
        old=baseline[pose['name']]
        delta=max(abs(a-b) for k in ['eye','rotation'] for a,b in zip(old[k],pose[k]))
        assert delta<1e-6 and all(old[k]==pose[k] for k in ['projection','fov','size','cell','links','raw','bits']),pose['name']
        maximum_camera_roundoff=max(maximum_camera_roundoff,delta)
        if pose['kind']!='gameplay':continue
        name=pose['name'];canvas=Image.new('RGB',(2560,850),'#222c32');draw=ImageDraw.Draw(canvas)
        draw.text((20,12),name+'  BEFORE',fill='white');draw.text((1300,12),'AFTER',fill='white')
        for i,phase in enumerate(['Before','After']):canvas.paste(Image.open(OUT/phase/(name+'.png')),(i*1280,50))
        canvas.save(OUT/(name+'-comparison.jpg'),quality=92);pairs.append(name)
    for p,sha in json.loads((OUT/'protected-before.json').read_text()).items():assert digest(ROOT/p)==sha,p
    original=(OUT/'original_maps-before.gd.txt').read_text()
    current=(ROOT/'scripts/forest/forest_original_maps.gd').read_text().replace('const AbanisVillageArt=preload("res://scripts/forest/forest_abanis_village_art.gd")\n','')
    assert original.split('static func build(')[0]==current.split('static func build(')[0]
    assert original.split('static func boundaries(')[1]==current.split('static func boundaries(')[1]
    (OUT/'verification.json').write_text(json.dumps(dict(matched_cameras=len(after),maximum_camera_roundoff=maximum_camera_roundoff,gameplay_pairs=pairs,protected_files_unchanged=True),indent=2)+'\n')
    for phase in ['Before','After']:
        images=sorted((OUT/phase).glob('*-iso.png'))
        sheet=Image.new('RGB',(1600,((len(images)+3)//4)*270),'#222c32');draw=ImageDraw.Draw(sheet)
        for i,p in enumerate(images):
            x=i%4*400;y=i//4*270;draw.text((x+5,y+3),p.stem,fill='white');sheet.paste(Image.open(p).resize((400,250)),(x,y+20))
        sheet.save(OUT/(phase+'-survey.jpg'),quality=90)
    plan=json.loads((OUT/'boundary.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    pages=['<!doctype html><meta charset="utf-8"><title>阿巴尼斯・傑諾瓦 snow region</title>',
           '<style>body{background:#202b32;color:#eee;font:17px/1.5 system-ui;max-width:1450px;margin:30px auto;padding:0 20px}img{width:100%;height:auto}a{color:#a9d8ee}details{border-top:1px solid #687782;margin:20px 0;padding:15px 0}summary{font-size:24px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}</style>',
           '<h1>阿巴尼斯・傑諾瓦 snowy region</h1><p><a href="BOUNDARY.md">Boundary</a> · <a href="REVIEW.md">Checklist and verification limits</a> · <a href="verification.json">Camera / map / exit verification</a></p>',
           '<p>Historical before / current after use identical fixed cameras. Native source panels are reconstructed from our read-only Cross Gate files; they are 2D references, not original third-person screenshots.</p>']
    for stage in plan['stages']:
        key=stage['key'];poses=[p for p in after if p['area']=='interior' and int(p['floor'])==stage['floor']]
        pages.append('<details open><summary>'+html.escape(stage['title'])+' / '+key+'</summary>')
        pages.append(f'<img loading="lazy" src="{key}-representative-play-comparison.jpg">')
        if stage['source'] is not None:
            iso=min((p for p in poses if p['kind']=='isometric'),key=lambda p:(p['cell'][0]-stage['anchor'][0])**2+(p['cell'][1]-stage['anchor'][1])**2)
            native=source.reference(iso,source.decode(stage['source'],catalog))
            native.save(OUT/(key+'-native-reference.png'))
            pages.append(f'<p>Native source / current 3D at a reachable sector</p><div class="grid"><img loading="lazy" src="{key}-native-reference.png"><img loading="lazy" src="After/{iso["name"]}.png"></div>')
        pages.append('<p>Every coverage section</p><div class="grid">')
        for p in poses:
            if p['kind']!='isometric':continue
            pages.append(f'<a href="After/{p["name"]}.png">{p["name"]}<img loading="lazy" src="After/{p["name"]}.png"></a>')
        pages.append('</div></details>')
    pages.append('<h2>Transition into snow</h2><img src="51031-first-snow-play-comparison.jpg">')
    (OUT/'index.html').write_text('\n'.join(pages)+'\n')
    print('Verified',len(after),'identical cameras / raw maps / walk masks / exits;',len(pairs),'gameplay pairs')


if __name__=='__main__':
    package() if '--package' in sys.argv else plan()
