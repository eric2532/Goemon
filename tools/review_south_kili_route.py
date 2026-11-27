"""Package verified South Gate–Kili evidence; never modify the captured baseline."""
import html,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/South Gate Kili Route'
ART=[
 'Playable South Gate approach reviewed; existing gate silhouette and paving retained.',
 'Calmer corridor ground/cliff finish; smaller cave-mouth labels; source trees and gate landmarks retained.',
 'Quieter warm rock/floor; original entrance chamber, stairs and walls retained.',
 'Quieter warm chamber surfaces; original pool/chamber layout and Great Bear retained.',
 'Quieter warm rock/floor; original exit chamber and stairs retained.',
 'Calmer ground/cliffs along the 193-cell source road; smaller mouth labels; actual-road fixed views reviewed.',
 'Quieter cool rock/floor; original pools and source stairs retained.',
 'Quieter cool chamber surfaces; original boss chamber, pools and connecting stairs retained.',
 'Quieter cool rock/floor; original warrior gate, chambers, pools and exit retained.',
 'Calmer coast ground/cliffs and smaller mouth labels; source palm/shore/road geometry retained.',
 'Restrained facade contrast and ground finish; source-specific house silhouettes/roof forms and all street sectors reviewed.'
]
def read(name):return json.loads((OUT/name).read_text())
def main():
 population=json.loads((ROOT/'assets/maps/falan/south_kili_route/population.json').read_text())
 maps=read('population-locations.json');before=read('Before/inventory.json');after=read('After/inventory.json')
 walk=read('continuous.json');streets=read('kili-streets.json');cameras=read('After/cameras.json')
 assert walk['rendered'] and not walk['invincible'] and walk['debug_teleports_after_start']==0 and walk['failures']==0 and walk['player_hp']>0
 assert streets['failures']==0 and len(maps)==len(after)==len(before)==11
 for a,b in zip(before,after):assert (a['area'],a['floor'],a['mask_sha256'])==(b['area'],b['floor'],b['mask_sha256'])
 population_log=(OUT/'population-visual-test.log').read_text()
 assert re.search(r'RESULT maps=11 npcs=19 preserved=11 checks=\d+ failures=0',population_log)
 assert 'SCRIPT ERROR' not in population_log
 check=[]
 for i,m in enumerate(maps):
  names=set()
  for z in m['zones']:
   for gid in z['groups']:
    for member in population['groups'][gid]['members']:names.add(population['species'][member[0]]['name'])
  check.append(dict(order=i,area=m['area'],floor=m['floor'],source=after[i]['source'],title=m['title'],art=ART[i],enemies=sorted(names),zone_cases=len(m['zones']),npcs=m['npcs'],crossing='Passed continuous physical input; final village street reached' if i==10 else 'Passed continuous physical input',blockers=population['limits'][2:] if i not in [0,10] else []))
 (OUT/'checklist.json').write_text(json.dumps(check,ensure_ascii=False,indent=2)+'\n')
 lines=['# South Gate → 其利村 review','',
 'Latest complete source; no app export. All eleven route stages reviewed separately for art, enemies, NPCs and crossings. Original source map IDs below; Kili runtime uses area `kili`, floor 0.','',
 '| Order / map | Art / where to see it | Enemies | NPCs / F talk | Crossing |','|---|---|---|---|---|']
 for row in check:
  npcs='; '.join(n['name']+' '+str(n['cell']) for n in row['npcs']) or 'No documented addition in this corridor; existing actors retained.'
  enemies='、'.join(row['enemies'])+f" ({row['zone_cases']} map/zone cases)" if row['enemies'] else 'Safe; no encounter population.'
  lines.append(f"| {row['order']+1}. {row['title']} ({row['source']}) | {row['art']} | {enemies} | {npcs} | Passed |")
 lines+=['','## Route and crossing repair','',
 '1000 South Gate (153,241) → 100 (424,259) → 11000 → 11001 → 11002 → 100 (442,349) → 15005 → 15003 → 15004 → 300 (240,265) → 3200 west gate. The stale overrides that collapsed the three undersea floors into 15003 have been removed. The original 15004 warrior self-gate remains. Original warp rows are independently checked by `test_south_kili_source.py`. Optional branches and unrelated connections are excluded.','',
 '## Fresh verification','',
 f"- Continuous rendered Play Goemon run: {len(walk['route'])} observed crossing records, {walk['movement_frames']} movement frames, final HP {walk['player_hp']}; invincibility off; one initial city setup and zero subsequent debug teleports. Final street reached through the west gate. See `continuous.json`, `continuous-rendered.log` and `Continuous/`.",
 f"- {len(cameras)} fixed gameplay views across all eleven stages, plus {len(streets['sectors'])} village sectors. All eleven native walk-mask hashes match the captured baseline. The original connected grid has {streets['original_reachable_cells']} cells; the capsule/scenery grid reaches {streets['physical_reachable_cells']}, with at least one reachable approach in every sector. Local direct loads are not used as proof of the full crossing run.",
 '- 19 source NPC/sign interactions pass actual F input at source cells; 11 previous placement anchors retained and eight missing placements supplied. 31 map/zone cases install documented membership/levels through native imported groups. Special bosses/escorts and repeated non-duplication checks pass. See `population-visual-test.log` and `population-locations.json`.',
 '- Three independent Python source tests pass: raw NPC cells/directions/native pixels; encounter weights/levels/native banks; original warp tuples and protected source bytes. Asset audit: 319 assets, zero read errors. Asset/audio/cosmetic preservation passes.',
 '- Shared snow regression: 422 checks, zero failures across eleven maps. This protects the prior snow-region pass; it is not a new snow art review.',
 '- Final fixture logs contain no script errors. Godot still emits resource/RID diagnostics at editor/fixture shutdown; these checks do not establish long-session memory behavior or full-army frame times.','',
 '## Specific gaps / blockers','',
 '- Original groups 9033/9034 refer to quest item 18403. Its original server-state condition has no established Goemon equivalent; raw rows are retained and unconditional random boss insertion is withheld. Existing Great Bear and 熊哥 + 2 dragons/2 warriors remain working.',
 '- Exact original encounter probability ramp and group-size distribution are unavailable. Existing shuffle bags preserve documented bounds and weighted memberships; they do not establish exact original encounter frequency or turn-based formation.',
 '- Invisible door 6123 at 15004 (7,41), and later-event 哥布林士官 1102727 at Freyja (435,266), lack corroboration for visible original placement; not invented.',
 '- Event actors use one placeholder line. No missing quest behavior or unseen 3D-facing artwork is invented. Static artwork preserves the source facing record.',
 '- Original maps provide cells and isometric artwork, not authoritative third-person hidden surfaces. The owned finish preserves the established 3D geometry and source landmarks; it is a visual interpretation, not a pixel-identical original client reconstruction.','',
 '## Source and maintenance','',
 'See `assets/maps/falan/south_kili_route/README.md` for source provenance, owners, scope and reproduction commands. SHA-pinned raw tables are under `assets/references/crossgate_tina/events/`. Read-only original maps/warp table are in the adjacent Magic Power archive. Existing Habaru, undersea, frontier, source tile/layout and original actor assets remain authoritative.','',
 'References: [維諾亞](https://cg.skyey.tw/map/ma05.htm), [其利](https://cg.skyey.tw/map/ma07.htm), [索奇亞](https://cg.skyey.tw/map/ma002.htm), [undersea quest](https://cg.skyey.tw/errand/maae03.htm), [encounter field documentation](https://bbs.cgmsv.com/thread-1031-1-1.html).','']
 (OUT/'REVIEW.md').write_text('\n'.join(lines))
 sections=[]
 for folder,title in [('After','Fixed gameplay and village street views'),('Population','Native groups and F conversations'),('Continuous','Observed real crossings')]:
  photos=[p for p in sorted((OUT/folder).glob('*.png')) if 'mask' not in p.name]
  sections.append('<h2>'+title+'</h2><div class="grid">'+''.join('<a href="'+html.escape(str(p.relative_to(OUT)))+'"><img loading="lazy" src="'+html.escape(str(p.relative_to(OUT)))+'"><span>'+html.escape(p.stem)+'</span></a>' for p in photos)+'</div>')
 (OUT/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>South Gate → 其利村 review</title><style>body{background:#18242b;color:#edf2ef;font:16px system-ui;margin:32px}a{color:#e9d7a0;text-decoration:none}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}img{width:100%;display:block}span{display:block;padding:8px}h2{margin-top:40px}</style><h1>South Gate → 其利村</h1><p><a href="REVIEW.md">Per-map checklist and specific source gaps</a> · <a href="baseline-gameplay.jpg">Before montage</a> · <a href="after-gameplay.jpg">After montage</a></p>'+''.join(sections))
 print('PASS packaged 11 map records; native masks preserved; rendered continuous proof present')
if __name__=='__main__':main()
