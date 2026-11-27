"""Compare the cleanup against its fresh current-source baseline, using fixed cameras."""
import hashlib
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/Snow Region Cleanup'
SELECTED=[('Abanis | shop street','51011-pub-play'),
          ('Jenova | main street','51004-representative-play'),
          ('Shalena | first snow','51031-first-snow-play')]


def package():
    before={p['name']:p for p in json.loads((OUT/'Before/cameras.json').read_text())}
    after={p['name']:p for p in json.loads((OUT/'After/cameras.json').read_text())}
    assert before.keys()==after.keys() and len(after)==260
    delta=0.0
    for name,pose in after.items():
        old=before[name]
        error=max(abs(x-y) for k in ['eye','rotation'] for x,y in zip(old[k],pose[k]))
        delta=max(delta,error)
        assert error<1e-6,name
        for key in ['floor','cell','projection','size','fov','raw','bits','links']:
            assert old[key]==pose[key],(name,key)
    sources=json.loads((OUT/'source-before.json').read_text())
    protected=['assets/maps/original_crossgate/catalog.json',
               'assets/maps/falan/snow_region/scenery.json','assets/maps/falan/snow_region/surfaces.json',
               'scripts/forest/forest_explorer_travel.gd','scripts/forest/forest_explorer_npcs.gd',
               'scripts/forest/forest_frostpass.gd','scripts/forest/forest_original_snow.gd',
               'scripts/forest/forest_original_cliffs.gd','scripts/forest/forest_original_map_solids.gd',
               'scripts/forest/forest_original_cave_entrance.gd']
    for path in protected:assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sources[path],path
    path='scripts/forest/forest_original_maps.gd'
    old=(OUT/'Source Before'/path).read_text()
    assert old.replace('WestScenery.sapling(serial)','WestScenery.sapling(serial,true)')==(ROOT/path).read_text()
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',28)
    small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
    preview=Image.new('RGB',(1440,3*495),'#202b32')
    for i,(title,name) in enumerate(SELECTED):
        pair=Image.new('RGB',(2560,855),'#202b32');draw=ImageDraw.Draw(pair)
        draw.text((18,8),title+'  |  BEFORE',font=font,fill='white')
        draw.text((1298,8),'AFTER',font=font,fill='white')
        for x,phase in [(0,'Before'),(1280,'After')]:pair.paste(Image.open(OUT/phase/(name+'.png')),(x,55))
        pair.save(OUT/f'comparison-{i+1:02}.jpg',quality=94)
        preview.paste(pair.resize((1440,481),Image.Resampling.LANCZOS),(0,i*495))
    preview.save(OUT/'three-comparisons.jpg',quality=94)
    plan=json.loads((OUT/'boundary.json').read_text())
    inventory=[]
    for stage in plan['stages']:
        poses=[p for p in after.values() if int(p['floor'])==stage['floor']]
        images=sorted(p['name'] for p in poses if p['kind']=='isometric')
        sheet=Image.new('RGB',(1600,((len(images)+3)//4)*270),'#202b32');draw=ImageDraw.Draw(sheet)
        for i,name in enumerate(images):
            x=i%4*400;y=i//4*270
            draw.text((x+5,y+2),name,font=small,fill='white')
            sheet.paste(Image.open(OUT/'After'/(name+'.png')).resize((400,250)),(x,y+20))
        sheet.save(OUT/(stage['key']+'-survey.jpg'),quality=92)
        inventory.append(dict(floor=stage['floor'],title=stage['title'],views=len(poses),sectors=len(images)))
    verification=dict(matched_views=len(after),maximum_camera_roundoff=delta,
                      map_planes_walk_masks_exits_unchanged=True,protected_sources=protected,
                      original_map_renderer_only_change='Select the material-separated sapling variant.',
                      selected_views=[name for _,name in SELECTED],maps=inventory)
    (OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n')
    page=['<!doctype html><meta charset="utf-8"><title>Snow region cleanup</title>',
          '<style>body{background:#202b32;color:#eee;font:17px/1.5 system-ui;max-width:1450px;margin:30px auto;padding:0 20px}a{color:#9dd8f0}img{max-width:100%;height:auto}details{border-top:1px solid #687782;padding:18px 0}summary{font-size:23px}</style>',
          '<h1>阿巴尼斯・傑諾瓦 — cleanup and readability</h1>',
          '<p>The current source was captured before this cleanup. All views reuse the last pass’s camera positions; no walkthrough or gameplay changes.</p>',
          '<p><a href="REVIEW.md">Map checklist and findings</a> · <a href="verification.json">Preservation and camera checks</a></p>']
    for i,(title,_) in enumerate(SELECTED,1):page.append(f'<h2>{html.escape(title)}</h2><img src="comparison-{i:02}.jpg">')
    for stage in plan['stages']:
        page.append(f'<details><summary>{html.escape(stage["title"])} / {stage["floor"]}</summary><img loading="lazy" src="{stage["key"]}-survey.jpg"><p>Fixed gameplay cameras:</p>')
        for pose in after.values():
            if int(pose['floor'])!=stage['floor'] or pose['kind']!='gameplay':continue
            name=pose['name']
            page.append(f'<p>{name} · <a href="Before/{name}.png">Before</a> · <a href="After/{name}.png">After</a></p>')
        page.append('</details>')
    (OUT/'index.html').write_text('\n'.join(page)+'\n')
    print(f'PASS {len(after)} matched cameras; all 11 maps; 3 requested comparisons; source/exit/walk-mask preservation')


if __name__=='__main__':package()
