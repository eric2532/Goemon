"""Pinned source maps and fixed-camera evidence for the two Ruby-region branches."""
import hashlib,html,json,sys
from functools import lru_cache
from pathlib import Path
import review_west_snow_route as review
ROOT=review.ROOT
OUT=ROOT/'build/Other Files/Asset Toolkit/Ruby Region Reconstruction'
STAGES=[
 ('01-palace','露比 palace',16508,'interior',16508,None),
 ('02-prayer-entrance','Black Prayer entrance',16507,'interior',16507,None),
 *[(f'0{i+2}-maze-{i}',f'Black Prayer B{i}F',None,'interior',30100+i,None) for i in range(1,7)],
 ('09-undersea-middle','Sokia Undersea Cave 2F / Suspicious Rock',15003,'interior',15003,None),
 ('10-undersea-freyja','Sokia Undersea Cave Freyja 1F',15005,'interior',15005,None),
 ('11-undersea-coast','Sokia Undersea Cave Sokia 1F',15004,'interior',15004,None),
 ('12-venoa','維諾亞 reachable streets',2100,'venoa',0,None),
 ('13-southern-lakes','Southern Lakes roads and cave mouths',100,'south_lakes',0,[320,340,460,510]),
 ('14-sokia-coast','Sokia coast and both village gates',300,'sokia_coast',0,[227,251,306,335]),
 ('15-kili','其利 reachable streets',3200,'kili',0,None),
]
PROTECTED=['scripts/forest/forest_black_prayer.gd','scripts/forest/forest_falan_tour.gd',
 'scripts/forest/crowd/ruby_boss_sprites.gd','scripts/forest/forest_explorer_npcs.gd',
 'scripts/forest/forest_south_kili_population.gd','assets/maps/falan/freyja_destinations_data.gd',
 'assets/maps/falan/room_art_data.gd','assets/maps/falan/ruby_room_props.gd',
 'assets/maps/falan/black_prayer/data.gd','assets/maps/falan/south_kili_route/population.json']

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

@lru_cache(maxsize=2048)
def graphic(serial,palette=0):
 g=review.lib.serial_index()[serial]
 return review.lib.image_from_record(g['pack'],g['row'],palette)

def decode(number,*_):
 palette=2 if int(number) in [15003,15004,15005] else 0
 review.graphic=lambda serial:graphic(serial,palette)
 with review.lib.connection() as db:
  key=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{int(number)}.dat',)).fetchone()[0]
 source=review.lib.source_file(key)[1];raw=source.read_bytes()
 w,h,f,o,flags=review.lib.parse_map(raw)
 walk=review.navigation_grid(w,h,f,o,review.lib.serial_index())
 return dict(raw=raw,width=w,height=h,floor=f,objects=o,flags=flags,walk=walk,source=str(source))

def plan():
 OUT.mkdir(parents=True,exist_ok=True);stages=[]
 for key,title,number,area,floor,crop in STAGES:
  stage=dict(key=key,title=title,source=number,area=area,floor=floor,sections=[])
  if number:
   d=decode(number);w,h=d['width'],d['height'];low=[w,h];high=[0,0]
   for y in range(h):
    for x in range(w):
     if not d['walk'][y*w+x] or crop and not(crop[0]<=x<=crop[2] and crop[1]<=y<=crop[3]):continue
     low=[min(low[0],x),min(low[1],y)];high=[max(high[0],x),max(high[1],y)]
   step=14 if number in [16508,15003] else 18 if number in [2100,3200] else 20
   for y in range(low[1],high[1]+1,step):
    for x in range(low[0],high[0]+1,step):
     cells=[(xx,yy) for yy in range(y,min(y+step,high[1]+1)) for xx in range(x,min(x+step,high[0]+1)) if d['walk'][yy*w+xx]]
     if not cells:continue
     center=[x+step/2,y+step/2];at=min(cells,key=lambda c:(c[0]-center[0])**2+(c[1]-center[1])**2)
     stage['sections'].append(dict(key=f'{key}-{len(stage["sections"])+1:02d}',at=at,start=at,end=[at[0],at[1]-1]))
   stage.update(bounds=[low,high],client_sha256=digest(Path(d['source'])),source_file=d['source'])
  stages.append(stage)
 document=dict(seed=41829558,stages=stages,scope='Palace first; both complete region branches; village streets, not optional house interiors.',
  route=['2100 ↔ Southern Lakes (100) ↔ 15005 ↔ 15003',
   '15003 Suspicious Rock ↔ 16507 ↔ 30101 ↔ 30102 ↔ 30103 ↔ 30104 ↔ 30105 ↔ 30106 ↔ 16508',
   '15003 ↔ 15004 ↔ Sokia Coast (300) ↔ both 3200 gates'],
  limits=['Original server maze algorithm is unavailable; preserve current six seeded layouts and stair anchors.',
   'Native map and single-view art do not establish hidden geometry or authoritative walkable elevation.'])
 (OUT/'route.json').write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
 lock=OUT/'locked-inputs.json'
 if not lock.exists():lock.write_text(json.dumps({p:digest(ROOT/p) for p in PROTECTED},indent=2)+'\n')
 for p in ['scripts/forest/forest_black_prayer_art.gd','scripts/forest/forest_falan_room_art.gd','scripts/forest/forest_falan_interior.gd','scripts/forest/forest_coastal_buildings.gd','scripts/forest/forest_kili_art.gd','scripts/forest/forest_venoa_buildings.gd']:
  target=OUT/'Source baseline'/p;target.parent.mkdir(parents=True,exist_ok=True)
  if not target.exists():target.write_bytes((ROOT/p).read_bytes())
 print('Pinned',len(stages),'maps/floors and',sum(len(s['sections']) for s in stages),'fixed source sectors')

def check():
 for p,sha in json.loads((OUT/'locked-inputs.json').read_text()).items():
  if p=='scripts/forest/forest_falan_tour.gd':
   source=(ROOT/p).read_text().replace(' preload("res://scripts/forest/forest_ruby_region_art.gd").finish(root,model)\n','')
   assert hashlib.sha256(source.encode()).hexdigest()==sha,p
  else:assert digest(ROOT/p)==sha,p
 for s in json.loads((OUT/'route.json').read_text())['stages']:
  if s['source']:assert digest(Path(s['source_file']))==s['client_sha256'],s['key']
 print('PASS protected gameplay, generator, links, source maps and original placement tables')

def compare(phase):
 review.OUT=OUT;review.decode=decode;review.compare(phase)

def contacts():
 from PIL import Image,ImageDraw
 target=OUT/'Review contacts';target.mkdir(exist_ok=True)
 route=json.loads((OUT/'route.json').read_text());poses=json.loads((OUT/'After/cameras.json').read_text())
 for stage in route['stages']:
  panels=[]
  for pose in poses:
   if not pose['name'].startswith(stage['key']) or pose['kind']!='isometric':continue
   current=OUT/'After'/(pose['name']+'.png');old=OUT/'Before'/(pose['name']+'.png')
   if pose['source'] is not None:old=OUT/'Original'/(pose['name']+'.png');label='NATIVE SOURCE'
   else:label='BEFORE / SAME SEED' if old.exists() else 'CURRENT STAIR / NO BASELINE'
   panel=Image.new('RGB',(640,228),'#20292e');draw=ImageDraw.Draw(panel);draw.text((4,3),pose['name'],fill='white')
   for i,file in enumerate([old if old.exists() else current,current]):
    with Image.open(file) as im:panel.paste(im.convert('RGB').resize((320,200)),(i*320,28))
    draw.text((i*320+4,15),label if i==0 else 'CURRENT 3D',fill='white')
   panels.append(panel)
  for offset in range(0,len(panels),8):
   batch=panels[offset:offset+8];sheet=Image.new('RGB',(1280,228*((len(batch)+1)//2)),'#20292e')
   for i,im in enumerate(batch):sheet.paste(im,((i%2)*640,(i//2)*228))
   sheet.save(target/(stage['key']+f'-{offset//8+1:02d}.jpg'),quality=95)
 print('Prepared',len(list(target.glob('*.jpg'))),'review contact sheets')

def overheads():
 from PIL import Image,ImageDraw
 target=OUT/'Overhead review';target.mkdir(exist_ok=True)
 poses=json.loads((OUT/'Landmarks/cameras.json').read_text())
 for pose in poses:
  if pose['kind']!='overhead':continue
  current=Image.open(OUT/'Landmarks'/(pose['name']+'.png')).convert('RGB')
  original=Image.new('RGB',(1280,800),'#263138');draw=ImageDraw.Draw(original)
  if pose['source'] is None:
   raw=json.loads((OUT/'Landmarks'/(pose['name'].split('-complete-plan')[0]+'-plan.json')).read_text())
   bits=bytes.fromhex(raw['bits']);data=dict(width=raw['width'],height=raw['height'],walk=[bool(bits[i>>3]&(1<<(i&7))) for i in range(raw['width']*raw['height'])])
   label='CURRENT SEEDED WALK GRID · ORIGINAL LAYOUT UNAVAILABLE'
  else:data=decode(pose['source']);label='NATIVE MAP WALK GRID · GREEN OPEN / GREY BLOCKED'
  zero=pose['source_zero'];a=pose['source_x'];b=pose['source_y'];w=data['width']
  for index,walk in enumerate(data['walk']):
   x,y=index%w,index//w;cx=zero[0]+x*a[0]+y*b[0];cy=zero[1]+x*a[1]+y*b[1]
   if cx < -15 or cx>1295 or cy < -15 or cy>815:continue
   if not walk and (pose['source'] is None or data['floor'][index]<1000 and data['objects'][index]<1000):continue
   corners=[(cx+dx*a[0]+dy*b[0],cy+dx*a[1]+dy*b[1]) for dx,dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
   draw.polygon(corners,fill='#91b396' if walk else '#424c5a')
  result=review.panel([original,current],[pose['name']+' · '+label,'CURRENT 3D · COMPLETE BOUNDS / SAME SOURCE AXES'])
  result.save(target/(pose['name']+'.jpg'),quality=95)
 print('Prepared 15 complete overhead map/seed comparisons')


def handoff():
 check()
 route=json.loads((OUT/'route.json').read_text());before={p['name']:p for p in json.loads((OUT/'Before/cameras.json').read_text())}
 after=json.loads((OUT/'After/cameras.json').read_text());common=[]
 assert len(after)==411
 for pose in after:
  assert pose['actual_area']==pose['area'] and pose['actual_floor']==pose['floor'] and pose['seed']==41829558 and pose['hour']==12,pose['name']
  if pose['name'] not in before:continue
  old=before[pose['name']]
  for key in ['eye','rotation','seed','links','hour','projection','fov','size']:
   assert pose[key]==old[key],(pose['name'],key)
  common.append(pose['name'])
 assert len(common)==387
 manual=json.loads((OUT/'manual-review.json').read_text())
 assert set(manual)=={s['key'] for s in route['stages']}
 checks=[]
 for stage in route['stages']:
  key=stage['key'];a=json.loads((OUT/'Before'/(key+'-geometry.json')).read_text());b=json.loads((OUT/'After'/(key+'-geometry.json')).read_text())
  assert a['collision_shapes']==b['collision_shapes'],key
  if stage['source'] is not None and stage['area']=='interior':assert a['mask_sha256']==b['mask_sha256'],key
  assert manual[key]['checked'] and manual[key]['sheets'] and manual[key].get('complete_overhead_checked'),key
  checks.append(dict(key=key,title=stage['title'],source=stage['source'],runtime_floor=stage['floor'],area=stage['area'],captures=sum(p['name'].startswith(key) for p in after),collision_shapes=b['collision_shapes'],source_sectors=len(stage['sections']),review=manual[key],certified_1_to_1=False))
 for log,marker in [('final-transitions-render.log','RUBY_REGION_TRANSITIONS_RESULT checks=182 failures=0'),('maze-generator.log','BLACK_PRAYER_MAZE_RESULT seeds=32 floors=6 unique=192 checks=111010 failures=0')]:
  text=(OUT/log).read_text();assert marker in text and 'SCRIPT ERROR' not in text and 'Parse Error' not in text,log
 landmarks=json.loads((OUT/'Landmarks/cameras.json').read_text())
 assert len(landmarks)==49 and sum(p['kind']=='overhead' for p in landmarks)==15
 for pose in landmarks:
  assert pose['actual_area']==pose['area'] and pose['actual_floor']==pose['floor'] and pose['seed']==41829558 and pose['hour']==12,pose['name']
  if pose['source'] is not None and pose['kind']=='gameplay':
   source=decode(pose['source']);x,y=map(int,pose['cell'])
   assert source['walk'][y*source['width']+x],('Named view must use an original reachable cell',pose['name'])
 for log in ['accepted-fixed-rooms-render.log','final-entry-render.log','final-palms-render.log','final-solid-walls-render.log','final-landmark-render.log']:
  value=(OUT/log).read_text();assert 'failures=0' in value and 'SCRIPT ERROR' not in value and 'Parse Error' not in value,log
 proof=dict(seed=41829558,complete_map_plans=15,named_current_gameplay_views=34,current_captures=411,matched_historical_cameras=387,current_actual_stair_views=24,actual_map_ids_verified=True,clock_hour=12,unchanged_collision_counts=True,mazes=dict(seeds=32,floors=6,distinct_layouts=192,checks=111010),transition_checks=182,maps=checks,
  historical_limits='The first harness used doorway snapping for village coordinates and planned maze stair cameras with seed 341 while the actual run used 41829558. Village baselines were retaken before village art edits. The 24 historical planned-stair shots are excluded; 24 current actual-stair views replace them. The 387 common camera/seed/clock/exit records match exactly. Initial generated-mask metadata sampled seed 341 and is not used as captured-layout proof. Generator source hashes, matched actual seed/link records, overhead pairs and the 32-seed fixture provide the maze preservation evidence.')
 (OUT/'verification.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
 (OUT/'checklist.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n')
 lines=['# 露比 connected region reconstruction','',
  'Completed review 2026-11-26. Current complete source through Play Goemon; no app export. BlueCrossgate map bytes and recovered source art are primary. Work started at palace 16508, then covered all fifteen maps/floors on both branches.','',
  '**Status: reviewed with the specific reference limits below. No section is certified visually 1:1.**','',
  '## Ordered region and crossings','',
  '1. 維諾亞村 **2100**: reachable streets and east gate. Source entry (66,46–47), return (67,46–47) ↔ Freyja/Southern Lakes **100** (330–331,480–481).',
  '2. Southern Lakes **100**: the village junction and roads to Sokia cave mouth (343,497). The city/bear-road junction is retained; the separate Venoa Undersea Cave branch is not redone.',
  '3. Sokia Undersea Cave Freyja 1F **15005**: (10,5) ↔ (18,34).',
  '4. Playable middle room **15003**: Freyja stairs (49,46); Suspicious Rock (34,7); coastal stairs (27,29).',
  '5. Boss branch: rock → **16507**, original return stair (7,4), forward maze threshold (14,14) → six separately seeded floors **30101–30106** → palace **16508**, original endpoint (39,5), existing landing (39,6). The 301xx identities are runtime IDs, not original transient map-cache names.',
  '6. Coastal branch: 15003 (27,29) ↔ Sokia 1F **15004** (24,13) → (11,44) ↔ Sokia Coast **300** (240,265).',
  '7. Sokia Coast **300** → 其利村 **3200**: west gate (273–275,294) ↔ (58–60,46), with village returns at y45; east gate (294,324–326) ↔ (78,75–77), with village returns at x79. Both gates and reachable streets were reviewed.','',
  '`original-warps.json` preserves the available archived entrance/exit tuples. The rock is the existing scripted branch; its runtime redirection through 16507 and all six floors is preserved.','',
  '## Per-map review','',
  '| Section / source | Runtime | Fixed views | Collision shapes | Review |','|---|---|---|---|---|']
 for row in checks:
  source=str(row['source']) if row['source'] is not None else 'seeded / no fixed source layout'
  lines.append(f"| {row['title']} — {source} | {row['area']} / {row['runtime_floor']} | {row['captures']} | {row['collision_shapes']} unchanged | {row['review']['note']} |")
 lines+=['','## Applied corrections','',
  '- Palace: corrected floor-motif orientation; recovered individual native stone wall faces and dark caps; fitted the existing solid furnishings, columns, statues, pictures, curtains and arch headers to source bounds/anchors. Restored native blue/red passage-panel paint, raised the native flower arrangements onto their source stations, removed unsupported canopy crossbars and omitted duplicate black occlusion-only caps already represented by the solid walls. Existing decorative masters and body poses remain.',
  '- Palace ceiling presentation clears the recovered tall artwork; its original physical headroom collider is retained. The blank exterior backing represents the source void, not newly invented scenery.',
  '- Fixed undersea rooms and Prayer floors: corrected native floor/bank UV orientation, restored the documented undersea palette instead of the pale route tint, replaced stretched boundary strips with per-graphic native wall volumes and source-camera surface paint. Navy/black source void is excluded from rock geometry; unseen surfaces use the same graphic’s native average color rather than stretched edge columns. Source silhouette trimming applies near the native camera; normal gameplay keeps the underlying solid wall surfaces closed. The fixed entrance has its separate palette-0 wall and stair variants. Restored all 39 original guard-area props in 15004, using existing solid forms and owned palette-2 surface paint. Walk masks, stair placements, encounters and physical headroom are preserved.',
  '- Villages/roads: retained Venoa’s existing seven native house placements and curved roof forms, and Kili’s native flat-roof building kit. Corrected undersized source trees, palms and fences at native cells using the existing editable masters. Single palm crowns now also match the native recipe’s measured leaf width/height while keeping their trunk attachments; traced/compound crowns retain their existing geometry. Thin palm fronds use owned two-sided materials. Native leaf palettes use owned materials. Kili/coastal wall and column ornaments now use their complete original surface paint over the existing geometry. Recovered the foliage-covered Venoa/southern cliffs and Sokia stone cliffs from their actual native records, with owned meshes/materials; the older generic clusters are omitted only within the reviewed bounds.',
  '- All changes occur during map setup. Shared source models, source atlases, NPC data, army combat and saved adventure data are preserved.','',
  '## Verification','',
  '- 411 final fixed captures: 15 historical overview cameras, 282 isometric sectors/maze rooms/stairs, and 114 normal gameplay views. A further 15 complete-map overheads and 34 named current gameplay views are delivered separately; several historical overview cameras cropped map edges and are not used as whole-map evidence. Every final image checks its actual area/floor, seed 41829558 and noon clock. 387 historical camera, seed, clock and complete exit records match exactly; 24 current actual-stair views are labeled separately.',
  '- All fifteen baseline collision-shape counts match. Fixed-room walking-mask hashes match. Protected source hashes cover the maze generator, Ruby/native combat presentation owner, NPC scripts, population tables, original map data, furniture cells and routing; the tour owner adds only a visual setup call.',
  '- Focused rendered transition check: 182 checks, zero failures. It enters Venoa, crosses 15005 → 15003 → 15004 to the coast, uses both Kili gates, enters through the actual rock branch, visits all six maze floors, observes Ruby and her nine escorts, checks locked rewards, defeats all ten through the native owner and follows the unlocked exit outside.',
  '- Generator fixture: 32 seeds × six floors, 192 distinct layouts, 111,010 checks, zero failures. This checks connectivity, both stair approaches, room patrol stations, return links and persistent identities; the generator is not replaced with a fixed layout.',
  '- New preparation reproduces from read-only source bytes; standard asset/audio/cosmetic preservation passes. Four reused flora/palm GLBs audited with zero read errors. These results do not establish long-session memory behavior or frame times. Fixtures still emit resource/RID diagnostics at shutdown.',
  '- Historical harness correction: village coordinates now stay on the raw source grid. The original 24 planned maze-stair shots used the wrong planning seed and are not matched evidence. Initial generated-mask metadata also sampled that planning seed; it is excluded from preservation claims. See `verification.json` for the exact evidence boundary.','',
  '## What remains unverified','',
  '- Palace collision/exit blockers: the native raised dais/step appearance in palace views 01–06 cannot become a matching walkable rise while preserving the current flat floor collision. Current physical headroom is also retained. The palace arrival remains (39,6), one cell inward from the archived endpoint (39,5); correcting that landing would change exit behavior.',
  '- Collision/navigation blocker at the outer source boundaries: Venoa views 12-01/02/21/22 and Kili views 15-01/04/24 expose the existing terrain/water collar beyond native cached edges. Exact boundary/shore-grade correction would require changing the traversable terrain or collision, which is outside this visual pass. Source-void cliff/cave backs also do not establish a 3D surface to fill.',
  '- Cave-mouth depth blocker: the named Southern Lakes approach (341,496) and Sokia Coast approach (237,265) are original open cells, but the fitted cliff volumes still overhang/partly obscure the existing recessed opening from the low gameplay camera. Native map pixels establish their isometric silhouette, not the solid depth or elevation needed to resolve that overlap without inventing geometry. These approach views are delivered as unresolved visual mismatches; the working transitions are independently verified. They must not be treated as a completed 1:1 entrance reconstruction.',
  '- Exact original server maze generation and a corresponding original layout for each runtime seed are unavailable. The documented six-floor room/material/stair contract is preserved, not certified as the original algorithm.',
  '- Native maps and single-view sprites do not supply walkable elevation fields, hidden wall/ceiling surfaces, curtain/cabinet rear geometry, concealed supports or exact 3D relief depth. Pure black/navy source occlusion does not specify a 3D mountaintop or cave rear surface: those regions can expose the current background/terrain from an orbiting camera; they are not filled with invented scenery. Current terrain grades, stage/shore depth and physical headroom remain adaptations. Raised visual walls/ceilings do not establish original walkable height.',
  '- Tree crown volume, trunk bends, fine palm leaf spacing/depth and hidden prop silhouettes still use the existing 3D adapters. Source stations, colors and visible bounds constrain them; they are not recovered original 3D meshes.',
  '- Original baked sprite lighting does not establish a 3D sun/ambient-light setup. Before/after review uses the same current noon setup; original runtime lighting is not certified. Undersea references use the repo’s documented Blue CG palette 2; the other fixed sources use palette 0.',
  '- Uncached/distant exterior cells and areas beyond the selected road corridors do not become verified original scenery because the runtime fills them. Optional house interiors and unrelated dungeons were not redesigned.','',
  'Open `index.html` for labeled source/current, matched before/after, normal gameplay, and current-only stair views. Source art and input hashes, the fifteen-row checklist, capture metadata, transition logs and generator evidence are retained beside this report.']
 (OUT/'REGION_REVIEW.md').write_text('\n'.join(lines)+'\n')
 body=['<!doctype html><meta charset="utf-8"><title>露比 connected region — source review</title>',
  '<style>body{background:#172329;color:#eee;font:16px system-ui;margin:32px auto;max-width:1320px}a{color:#c9e8f1}img{width:100%;height:auto}section{border-top:1px solid #657a80;margin:35px 0}summary{background:#293940;padding:14px;cursor:pointer}figure{margin:18px 0}p{line-height:1.6}</style>',
  '<h1>露比 connected region</h1><p>15 reviewed maps/floors, both branches. Source files are primary; no full visual 1:1 certification.</p><p><a href="REGION_REVIEW.md">Ordered route, per-map findings and limits</a> · <a href="verification.json">Verification</a> · <a href="original-warps.json">Original coordinates</a></p><figure><img src="Highlights.jpg" alt="Palace, cave and both villages: native source left, current 3D right"></figure>']
 for stage in route['stages']:
  key=stage['key'];body.append(f'<section><h2>{html.escape(stage["title"])} — {stage["source"] or stage["floor"]}</h2><p>{html.escape(manual[key]["note"])}</p>')
  body.append(f'<figure><img loading="lazy" src="Overhead review/{key}-complete-plan-overhead.jpg" alt="Complete native/current map plan"></figure>')
  body.append('<details><summary>Named current gameplay views at crossings and landmarks</summary>')
  for pose in landmarks:
   if pose['name'].startswith(key) and pose['kind']=='gameplay':body.append(f'<figure><figcaption>{html.escape(pose["name"])} · current only</figcaption><img loading="lazy" src="Landmarks/{pose["name"]}.png"></figure>')
  body.append('</details>')
  for page in sorted((OUT/'Source vs After').glob(key+'-page-*.jpg')):body.append(f'<figure><img loading="lazy" src="Source vs After/{page.name}" alt="Original left; current 3D right"></figure>')
  body.append('<details><summary>Matched before / after cameras</summary>')
  for name in common:
   if name.startswith(key):body.append(f'<figure><figcaption>{html.escape(name)} — same seed, camera, noon</figcaption><img loading="lazy" src="Before vs After/{name}.jpg"></figure>')
  body.append('</details><details><summary>Current fixed gameplay and actual stair views</summary>')
  for pose in after:
   if pose['name'].startswith(key) and (pose['kind']=='gameplay' or '-actual-stair-' in pose['name']):body.append(f'<figure><figcaption>{html.escape(pose["name"])} · native cell {pose["cell"]} · actual map {pose["actual_area"]}/{pose["actual_floor"]}</figcaption><img loading="lazy" src="After/{pose["name"]}.png"></figure>')
  body.append('</details></section>')
 (OUT/'index.html').write_text('\n'.join(body))
 print('Packaged 15 map reviews, 411 verified current views and 387 matched historical cameras')

if __name__=='__main__':
 command=sys.argv[1] if len(sys.argv)>1 else 'plan'
 if command=='plan':plan()
 elif command=='compare':compare(sys.argv[2])
 elif command=='check':check()
 elif command=='handoff':handoff()
 elif command=='contacts':contacts()
 elif command=='overheads':overheads()
 else:raise ValueError(command)
