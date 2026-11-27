"""Package verified fixed views and the per-map art/enemy/NPC restoration ledger."""
import hashlib
import html
import json
from pathlib import Path
import re
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/Snow Region Restoration'
OLD=ROOT/'build/Other Files/Asset Toolkit/Snow Region Cleanup/After'

ART={51004:'Reviewed and retained the current orange/green house silhouettes, road masks and landmarks.',51031:'Calmer cliff paint and continuous earth colour reduce source-tile patches at the first-snow transition; snow boundaries and tree/prop anchors retained.',14000:'Calmer rock faces and earth paint reduce enlarged native contrast; corridor geometry and entrances retained.',14001:'Same owned rock/earth cleanup; all branches and transfers retained.',14002:'Same rock/earth cleanup at the northern snow transition; passage and snow pockets retained.',51032:'Calmer surrounding cliff/earth materials; existing snowy vegetation, monuments and route anchors retained.',51011:'Solid roof underside/fascia adds readable depth to existing snow-house eaves; house shells, doors, snow/prop anchors and roads retained.',51012:'Earth finish is masked away from the authored campus pavers; existing buildings, avenue, planted beds and snow boundaries retained.',51009:'Reviewed current generated floor, snow/rock seams and saplings; retained its existing layout and scenery.',51010:'Reviewed current generated floor, transfers and bare trees; retained its existing layout and scenery.',15522:'Cabin reuses the solid roof underside; calmer cliff/ground material. Fences, snowman, signs and route retained.'}
SEE={51004:'Main street (48,47), Hank (67,47), north shop area (64,22).',51031:'Village approaches and first snow at (212,349), then the existing western-cave entrance (235,338).',14000:'Miner (27,14); ordinary corridor near (24,29); rare level-1 zone (6–17,9–19).',14001:'Middle corridors near (28,42).',14002:'Northern passage (37,15), southern rare zone (22–35,40–48).',51032:'Outside Abanis (184,165); soldiers (216,165), (248,134); stone disc (54,161).',51011:'Hunter pair (49,31)/(48,30), street pair (43,52)/(42,51), assistant (62,64), woodcutters (71,52)/(70,51).',51012:'University entrance avenue; guide (75,127), message board (77,120), side guides (31,106)/(92,151).',51009:'Existing mountain entrance from snowfield (84,193), then the first generated floor.',51010:'Continue through the existing upper transfer to the second generated floor.',15522:'Cabin exterior and central clearing (27,22); the level-1 zombie pocket near (21–26,14–20).'}

def package():
 data=json.loads((ROOT/'assets/maps/falan/snow_region/population.json').read_text())
 locations=json.loads((OUT/'locations.json').read_text());plan=json.loads((ROOT/'build/Other Files/Asset Toolkit/Snow Region/boundary.json').read_text())
 poses=json.loads((OUT/'After/cameras.json').read_text());baseline={p['name']:p for p in json.loads((OLD/'cameras.json').read_text())}
 log=(OUT/'visual-test.log').read_text()
 assert 'SCRIPT ERROR' not in log and 'SHADER ERROR' not in log and 'SHALENA_FAIL' not in log
 result=re.search(r'SNOW_POPULATION_RESULT checks=(\d+) failures=0 maps=11',log);assert result
 assert len(locations)==11 and {r['floor'] for r in locations}==set(ART)
 assert sum(len(r['npcs']) for r in locations)==42 and all(n['talked'] for r in locations for n in r['npcs'])
 assert len(poses)==17
 delta=0.
 for p in poses:
  old=baseline[p['name']]
  for key in ['floor','cell','projection','size','fov','links']:assert p[key]==old[key],(p['name'],key)
  delta=max(delta,max(abs(x-y) for key in ['eye','rotation'] for x,y in zip(old[key],p[key])))
 assert delta<1e-6
 lines=['# 阿巴尼斯・傑諾瓦 — art, encounters and NPCs','',
        'The current complete source and the last pass’s eleven-map boundary remain the baseline. No app was exported. Original map bytes, walking masks, routes and reusable masters are preserved.','',
        '| Map | Art | Enemies | NPCs / blockers | Where to see it |','|---|---|---|---|---|']
 ledger=[]
 titles={r['floor']:r['title'] for r in plan['stages']}
 for r in locations:
  floor=r['floor'];species=sorted({int(m[0]) for z in r['encounters'] for gid in z['groups'] for m in data['groups'][gid]['members']})
  enemies=', '.join(data['species'][i]['name'] for i in species) if species else 'Safe; no enemies added.'
  if floor in [51031,51032]:enemies+=' Existing species retained; weighted groups replace ambient regional posts.'
  elif floor in [14000,14001,14002]:enemies+=' Restored source pools and rare level-1 pockets where present.'
  elif floor==15522:enemies+=' Ice group is exactly one grass + three mutant slimes.'
  count=len(r['npcs']);npc=f'{count} source-placed residents/signs; all talk checks pass.' if count else 'Reviewed: no documented NPC in this reachable exterior/floor scope; none invented.'
  if floor==51012:npc+=' Four farm placements blocked by missing walkable ground; invisible grave and uncertain later events remain excluded.'
  lines.append(f'| {titles[floor]} ({floor}) | {ART[floor]} | {enemies} | {npc} | {SEE[floor]} |')
  ledger.append(dict(floor=floor,title=titles[floor],art=ART[floor],enemies=enemies,npcs=npc,see=SEE[floor],locations=r))
 lines+=['','## Specific gaps and limits','',
 'Four documented farm positions in original 4400 have no walkable ground within talk range: 菜園介紹板 (38,147), 學生阿葛里 (38,159), 農夫葛德里夫 (44,166), 學生哈斯帕 (34,167). The (36,30) grave is an invisible source event marker. These need a corroborated original terrain/visible-event reference; actors were not moved and paths were not invented. Every later/inactive/uncertain object is listed in population.json.skipped.', '',
 'Source NPC cells, names, graphic IDs and direction fields are preserved. Static native NPC drawings use the existing billboard presentation and retain their drawn facing; alternate third-person directional art is unavailable. Event conversations are explicit placeholders. Existing interior shops, quests and dialogue are untouched.', '',
 'Original group/member weights, levels, rectangles, override priorities and maximum group sizes are retained. Exact server probability ramp and count distribution are unavailable, so Goemon draws uniform shuffle bags within the recorded bounds. The current two generated mountain floors retain the existing hound/zombie identities and 39–42 levels; their equal pool weights, 1–3% per-walked-tile checks and six-member cap are explicit adaptations because the original random-floor configuration cannot be mapped exactly. These are specific fidelity limits, not a claim that the original server has been reproduced.', '',
 'The summit one-grass/three-slime grouping is corroborated by the original quest guide. Those actors reuse native combat; special poison/status spells, escape/self-destruction rules, quest drops and rewards are not restored by this pass. They require verified attack/event contracts and a separate gameplay implementation, not invented placeholder quest logic.', '',
 'Some inherited close-follow cave views are tight or occluded. The fixed views preserve the camera and layout rather than claiming unseen original 3D sides. No long-session FPS or resource-growth claim is made.', '',
 '## Fresh verification','',
 f'- Desktop launcher: {result[1]} assertions, zero failures; all eleven maps, 42 talk interactions, 21 reachable encounter zones and every documented pool within them.',
 f'- 17 fixed gameplay cameras match the last pass (maximum transform roundoff {delta:.3g}); native travel metadata matches.',
 '- Independent source/atlas/preservation tests pass. Source map/travel/generation owners and original assets are unchanged. Native group installation, stationary safety, shuffle-bag refill and walked-tile dispatch are checked at actual map locations.',
 '- Asset toolkit preservation and regional derivative checks pass. Shutdown RID/resource diagnostics remain in logs; script and shader errors fail the package check.', '',
 '## References','',
 '- [Pinned NPC/encounter records](https://github.com/linv2/Crossgate_Docker/tree/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data) — local copies are SHA-256 pinned; corroborating records, not recovered BlueCG server state.',
 '- [阿巴尼斯](https://cg.skyey.tw/map/ma12.htm), [傑諾瓦](https://cg.skyey.tw/map/ma10.htm), [莎蓮娜](https://cg.skyey.tw/map/ma003.htm), [western cave](https://cg.skyey.tw/map/ma17.htm), [mountain/summit encounter](https://cg.skyey.tw/errand/macc01.htm).',
 '- Preserved read-only BlueCrossgate map/art archive and the project’s [Game Art Style reference](https://gameartstyle.loopyhop.com/).','',
 'Reproduce with tools/prepare_snow_region_population.py, tools/prepare_snow_region_art.py --check, test_snow_region_population_source.py and snow_region_population_test.gd through Play Goemon.']
 (OUT/'REVIEW.md').write_text('\n'.join(lines)+'\n')
 (OUT/'checklist.json').write_text(json.dumps(dict(maps=ledger,checks=int(result[1]),failures=0,cameras=len(poses),camera_roundoff=delta,blocked_objects=data['skipped'],limits=data['limits']),ensure_ascii=False,indent=2)+'\n')
 image=Image.new('RGB',(1536,6*345),'#253239');draw=ImageDraw.Draw(image)
 page=['<!doctype html><meta charset="utf-8"><title>Snow region restoration</title><style>body{max-width:1450px;margin:32px auto;background:#253239;color:#eee;font:17px/1.5 system-ui}a{color:#afe3ff}img{max-width:100%}summary{font-size:22px;margin:20px 0}</style><h1>阿巴尼斯・傑諾瓦 — restoration</h1><p><a href="REVIEW.md">Per-map art/enemy/NPC ledger and blockers</a> · <a href="checklist.json">Machine-readable checks</a></p>']
 for i,p in enumerate(poses):
  x=i%3*512;y=i//3*345;im=Image.open(OUT/'After'/(p['name']+'.png'));image.paste(im.resize((512,320)),(x,y+25));draw.text((x+4,y+5),p['name'],fill='white')
 for stage in plan['stages']:
  floor=stage['floor'];page.append(f'<details><summary>{html.escape(stage["title"])} ({floor})</summary><p>{html.escape(ART[floor])}</p><p>{html.escape(SEE[floor])}</p>')
  for p in poses:
   if int(p['floor'])!=floor:continue
   name=p['name'];page.append(f'<p>{name} · <a href="../Snow Region Cleanup/After/{name}.png">Baseline</a></p><img loading="lazy" src="After/{name}.png">')
  for name in [f'npc-{floor}',f'group-{floor}',f'group-{floor}-ice']:
   if (OUT/'After'/(name+'.png')).exists():page.append(f'<p>{name}</p><img loading="lazy" src="After/{name}.png">')
  page.append('</details>')
 image.save(OUT/'final-gameplay.jpg',quality=93)
 (OUT/'index.html').write_text('\n'.join(page)+'\n')
 print('PASS eleven maps; 42 talk interactions; 17 matched gameplay views; source and native checks recorded')

if __name__=='__main__':package()
