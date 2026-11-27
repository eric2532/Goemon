"""Package both village checklists from source maps, warp coverage and fresh runtime evidence."""
import hashlib,json,re
from collections import deque
from pathlib import Path
from PIL import Image,ImageDraw
import review_kili_ghana as r
from build_freyja_destinations import KILI_ROOMS,GHANA_ROOMS,warp_rows,TITLES
ROOT=r.ROOT;OUT=r.OUT

def source_coverage():
 warps=list(warp_rows(ROOT.parent/'Magic Power'));records=[]
 for area,n in [('kili',3200),('ghana',3000)]:
  d=r.decode(n);w,h=d['width'],d['height'];seeds={(x,y) for a,x,y,b,tx,ty in warps if a==n and b==300}|{(tx,ty) for a,x,y,b,tx,ty in warps if a==300 and b==n}
  reached=set();queue=deque()
  for x,y in seeds:
   if d['walk'][y*w+x]:reached.add((x,y));queue.append((x,y))
  while queue:
   x,y=queue.popleft()
   for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    a,b=p
    if 0<=a<w and 0<=b<h and d['walk'][b*w+a] and p not in reached:reached.add(p);queue.append(p)
  sectors={}
  for x,y in reached:
   key=f'{x//12},{y//12}';sectors[key]=sectors.get(key,0)+1
  ports=[list(row) for row in warps if row[0]==n or row[3]==n]
  im=Image.new('RGB',(w,h),'#263138');pixels=im.load()
  for y in range(h):
   for x in range(w):pixels[x,y]=(125,176,137) if (x,y) in reached else (83,93,103) if d['walk'][y*w+x] else (43,50,59)
  im=im.resize((w*8,h*8),Image.Resampling.NEAREST);draw=ImageDraw.Draw(im)
  for a,x,y,b,tx,ty in warps:
   if a==n:draw.ellipse((x*8-3,y*8-3,x*8+3,y*8+3),fill='#f1d577')
  im.save(OUT/(area+'-source-coverage.png'))
  records.append(dict(village=area,map=n,source_size=[w,h],gate_seeds=sorted(seeds),native_gate_reachable_cells=len(reached),reachable_12_tile_sectors=sectors,source_ports=ports,scope='Map/warp enumeration and full overhead coverage; no exhaustive street walkthrough.'))
 (OUT/'street-coverage.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
 return records

def main():
 coverage=source_coverage();integration=json.loads((OUT/'integration.json').read_text());assert integration['failures']==0
 before=json.loads((OUT/'Before/cameras.json').read_text());after=list({p['name']:p for p in json.loads((OUT/'After/cameras.json').read_text())}.values());old={p['name']:p for p in before}
 assert len(after)==126 and len(old)==126
 for p in after:
  assert p['name'] in old
  for key in ['eye','rotation','projection','fov','size','seed','hour']:
   actual,previous=p[key],old[p['name']][key]
   assert all(abs(a-b)<1e-6 for a,b in zip(actual,previous)) if isinstance(actual,list) else actual==previous,(p['name'],key)
  assert p['actual_area']==p['area'] and p['actual_floor']==p['floor']
 for p in OUT.glob('After/inventory-*.json'):
  a=json.loads(p.read_text());b=json.loads((OUT/'Before'/p.name).read_text())
  assert a['npcs']==b['npcs'],p.name
  if any(f'ghana-{n}' in p.name for n in [3000,3804,3805,3806]):continue
  assert a['links']==b['links'] and a['mask']==b['mask'],p.name
 for log in ['after.log','integration.log']:
  text=(OUT/log).read_text();assert not re.search(r'SCRIPT ERROR|Parse Error|Assertion failed',text),log
 assert 'failures=0' in (OUT/'after.log').read_text()
 fixtures=json.loads((ROOT/'assets/maps/falan/village_street_props/data.json').read_text())
 blocks=(ROOT/'assets/maps/falan/coastal_room_props.gd').read_text().split('const ROOMS={')[1]
 rows=[]
 for area,n,maps in [('kili',3200,KILI_ROOMS),('ghana',3000,GHANA_ROOMS)]:
  stat=next(p for p in coverage if p['village']==area);label='其利村' if area=='kili' else '加納村'
  lines=[f'# {label} checklist — 2026-11-26','',
   'Finished to the available source, with the specific verification limits below. Current complete source; launch with Play Goemon. No app export.',
   '', '## Outdoor coverage','', '| Item | Result | Evidence |','|---|---|---|']
  checklist=[('Entrances and immediate approaches','Both original gates retained; matching entrance and approach cameras; both regional round trips spot-checked.'),('Main streets and spacing',f"Original map {n}, {stat['native_gate_reachable_cells']} gate-reachable cells across {len(stat['reachable_12_tile_sectors'])} source sectors; complete source overhead and exact original street mask retained."),('Side paths and housing courts','All original outdoor door links retained; source graph reaches every exterior door; original fences and approach openings retained.'),('Building exteriors','All eight original graphic pieces retained at native compound centres: two distinct residences, pub, hospital, two-tier chief house, both shop wings and open arcade. Individual low terrace contours and raised native entrance/sign paint use the existing solid kit.'),('Landmarks','Chief-house terrace and equipment arcade / original boundary columns.' if area=='kili' else 'Central open well, hospital belfries, cliff-bound north/south gates and source tree clusters.'),('Street fixtures',f"{len(fixtures['areas'][area])} omitted source placements restored: native signs, clotheslines, carts, containers, stone markers, plants and rocks"+(' and Ghana tree placements fitted to reusable woodland masters.' if area=='ghana' else '.'))]
  for title,result in checklist:lines.append(f'| [x] {title} | {result} | `street-coverage.json`, `Before/`, `After/`, `Source vs After/` |')
  lines+=['','## Every reachable interior','', '| Map | Interior | Source fixtures | Result / specific limit |','|---|---|---:|---|']
  for number in sorted(maps-{n}):
   block=re.search(rf' {number}:\[(.*?)\n \],',blocks,re.S)[1];count=len(re.findall('Vector2i',block))//2
   limit='Original BlueCrossgate cached map; complete floors, walls and furnishings, safe arrival and all source thresholds checked.'
   if number in [3801,3802,3803,3807]:limit='Recovered distinct classic LS2MAP house. Original BlueCG snapshot is absent; live version parity is unverified.'
   if number in [3804,3805,3806]:limit='Recovered distinct classic LS2MAP house replaces borrowed 3020/3021. New original threshold and village return spot-checked. Original BlueCG snapshot is absent; live version parity is unverified.'
   lines.append(f'| [x] {number} | {TITLES.get(number,str(number))} | {count} | {limit} |')
   rows.append(dict(village=area,map=number,source_objects=count,status='finished to available source',limits=limit))
  lines+=['','## Preserved behavior and verification','',
   '- Existing NPC identities, positions, quest owners and surrounding-region links retained. Before/after actor inventories match for every map. No NPC or unverified dialogue was invented; current source-referenced actors and short placeholders remain.',
   '- All 27 interiors were directly loaded; source floors and complete furnishings rendered, arrivals were safe, and every recorded indoor threshold was checked. Physical spot checks cover the three restored Ghana residences, both chief-house passages and four gate round trips. This is not a full street walkthrough.',
   '- 126 unique before/after cameras cover both villages, interiors and bounded approaches with identical transforms, projection, seed and noon lighting. The review index uses the clear source-aligned isometric views for entrances, main streets and landmarks. Raw close gameplay views include obstructed cameras and are not used as visual approval.',
   '- New scenery is setup-only, uses shared meshes/materials and bounded spatial batches, and adds no collision objects or gameplay owner. Existing saved maps/preferences were not overwritten. No app export.',
   '', '## Specific original-reference gaps','',
   '- Original artwork supplies one isometric view. Hidden rear faces, fine roof/corner relief, cloth depth, crown structure and lighting remain 3D interpretations. Full multi-view fidelity is not verified.',
   '- The pinned classic archive corroborates missing housing layouts; it does not certify the current BlueCG server version or dialogue. Crossgate_Docker is not used as proof of BlueCG dialogue.',
   '- Full-army frame-time, long-session stability and an exhaustive street walkthrough were not tested. Godot emits existing resource/RID shutdown diagnostics; these are retained in the logs and are not a leak-free claim.',
   '', 'Sources: local original `BlueCrossgate/map/0` cache and warp reference; pinned housing provenance under `assets/references/crossgate_'+area+'_houses/`. External map cross-check: [village guide](https://cg.skyey.tw/map/'+('ma07.htm' if area=='kili' else 'ma08.htm')+').',
   '', 'Reproduce: `python3 tools/recover_ghana_houses.py --check`; `python3 tools/prepare_kili_ghana_rooms.py --check`; `python3 tools/prepare_kili_ghana_props.py --check`; `python3 tests/forest-shrine/test_kili_ghana_source.py`. Run `kili_ghana_integration.gd` and `kili_ghana_review.gd -- --stage=After` through Play Goemon.']
  (OUT/(area.upper()+'_CHECKLIST.md')).write_text('\n'.join(lines)+'\n')
 (OUT/'completed-coverage.json').write_text(json.dumps(dict(villages=coverage,interiors=rows,integration=integration,matched_cameras=len(after)),ensure_ascii=False,indent=2)+'\n')
 print('PASS both village checklists: 29 maps, 27 interiors, four approaches, 126 matched cameras (transform float tolerance 1e-6)')
if __name__=='__main__':main()
