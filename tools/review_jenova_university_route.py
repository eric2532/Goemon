"""Lock and compare the Blue Cross Gate west-gate route without changing travel."""
import hashlib
import html
import json
import sys
import review_west_snow_route as review

ROOT = review.ROOT
OUT = ROOT / 'build/Other Files/Asset Toolkit/Jenova University Route'
STAGES = [
    ('01-jenova-west-gate', 'Jenova west gate', 4000, 51004, [(29,40),(24,40)]),
    ('02-shalena-south', 'Shalena western road and cave approach', 400, 51031,
     [(216,456),(149,472),(170,425),(196,375),(235,338)]),
    ('03-western-cave-1', 'Western cave 1F', 14000, 14000, [(8,41),(45,9)]),
    ('04-western-cave-2', 'Western cave 2F', 14001, 14001, [(14,68),(57,13)]),
    ('05-western-cave-3', 'Western cave 3F', 14002, 14002, [(30,44),(36,7)]),
    ('06-university-snowfield', 'Snowfield, Abanis junction and university arch', 402, 51032,
     [(258,180),(240,172),(217,171),(194,171),(184,165),(143,159),(118,101),(118,100)]),
    ('07-university-main-approach', 'Campus entrance to main building doorway', 4400, 51012,
     [(75,171),(75,150),(75,120),(75,94),(75,93)]),
]
EDGES = [[4000,24,40,400,216,456], [400,235,338,14000,8,41],
         [14000,45,9,14001,14,68], [14001,57,13,14002,30,44],
         [14002,36,7,402,258,180], [402,118,100,4400,75,171]]
PROTECTED = ['scripts/forest/forest_original_maps.gd', 'scripts/forest/forest_explorer_travel.gd',
             'scripts/forest/forest_explorer_npcs.gd', 'scripts/forest/forest_falan_tour.gd',
             'scripts/forest/forest_frostpass.gd', 'assets/maps/original_crossgate/catalog.json']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plan():
    catalog = json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    stages=[]
    for key,title,number,floor,anchors in STAGES:
        data=review.decode(number,catalog)
        path=review.path_between(data,anchors)
        sections=[]
        for i,start in enumerate(range(0,len(path)-1,16)):
            part=path[start:start+17]
            sections.append(dict(key=f'{key}-{i+1:02d}',start=part[0],end=part[-1],
                                 at=part[len(part)//2],path=part))
        assert all(data['flags'][y*data['width']+x]&0xc000 for x,y in path), key
        row=catalog['maps'][f'BlueCrossgate/map/0/{number}.dat']
        with review.lib.connection() as db:
            ident=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        source=review.lib.source_file(ident)[1]
        assert digest(source)==row['sha256'], source
        stages.append(dict(key=key,title=title,source=number,area='interior',floor=floor,
                           anchors=anchors,path=path,sections=sections,source_file=str(source),
                           client_sha256=row['sha256'],rendered_planes_sha256=hashlib.sha256(data['raw']).hexdigest()))
    assert all(edge in catalog['warps'] for edge in EDGES)
    document=dict(seed=341,stages=stages,edges=EDGES,
        route_locked_before_scenery_edits=True,
        departure='4000 west gate (24,39–41); centre (24,40)',
        endpoint='4400 main building exterior doorway (74–75,93); no building entry',
        exclusions=['Jenova beyond the departure lane','Abanis interior','Tina','Snow Mountain',
                    'Cursed Maze','university side buildings and interiors'],
        reference_notes=['BlueCrossgate client bytes and graphic records are the primary reference.',
            'Map 400/4000 uncached cells use the existing pinned server completion; recorded client cells are preserved.',
            'Every selected walking cell is recorded in the client. A walk trace is a review corridor, not a new gameplay path.',
            'The footage corroborates original Cross Gate geography/art; exact lighting is not independently documented for every fixed view.'],
        web_references=['https://cg.skyey.tw/map/ma10.htm','https://cg.skyey.tw/map/ma12.htm',
            'https://cg.skyey.tw/map/ma13.htm','https://www.youtube.com/watch?v=SEhtR-sc8hc',
            'https://www.youtube.com/watch?v=hBjeJb804hg'])
    (OUT/'route.json').write_text(json.dumps(document,indent=2,ensure_ascii=False)+'\n')
    lock=OUT/'locked-inputs.json'
    if not lock.exists():
        lock.write_text(json.dumps({p:digest(ROOT/p) for p in PROTECTED},indent=2)+'\n')
    lines=['# Locked route — 傑諾瓦 to 魔法大學','',
           'Locked before scenery edits. Primary reference: our adjacent Magic Power BlueCrossgate client archive. All six map links exist; no replacement route is needed.','',
           '| Order | Section / original ID | Source coordinates |','|---|---|---|']
    for i,s in enumerate(stages,1):
        lines.append(f"| {i} | {s['title']} / {s['source']} | "+' → '.join(f'({x},{y})' for x,y in s['anchors'])+' |')
    lines+=['','The route leaves by the west gate, crosses 14000 → 14001 → 14002, passes the Abanis junction without entering the village, and enters campus through 402 (117–119,100) → 4400 (74–76,171). The central exterior approach ends at the main building doorway (74–75,93); map 4410 is excluded.','',
            'Map geometry, native ground patterns and object anchors come from the original files. Unknown walkable heights, unseen geometry and independent original gameplay views must be reported separately.']
    (OUT/'ROUTE_LOCK.md').write_text('\n'.join(lines)+'\n')
    print('LOCKED:',len(stages),'maps,',sum(len(s['sections']) for s in stages),'continuous sections, six existing links')


def compare(phase):
    review.OUT=OUT
    review.compare(phase)
    if phase=='After':
        # Historical gate shots could cross a map boundary; don't publish them as matched evidence.
        archive=OUT/'Historical normal comparisons';archive.mkdir(exist_ok=True)
        for pose in json.loads((OUT/'After/cameras.json').read_text()):
            if pose['kind']!='gameplay':continue
            pair=OUT/'Before vs After'/(pose['name']+'.jpg')
            if pair.exists():pair.replace(archive/pair.name)


def check_protected():
    original=json.loads((OUT/'locked-inputs.json').read_text())
    for p,sha in original.items():
        if p in ['scripts/forest/forest_original_maps.gd','original_maps_gameplay_sha256']:continue
        assert digest(ROOT/p)==sha, p
    source=(ROOT/'scripts/forest/forest_original_maps.gd').read_text()
    source=source.replace('const UniversityRouteArt=preload("res://scripts/forest/forest_university_route_art.gd")\n','')
    behavior=source[:source.index('static func build(')]+source[source.index('static func boundaries('):]
    assert hashlib.sha256(behavior.encode()).hexdigest()==original['original_maps_gameplay_sha256']
    print('PASS: locked source maps, NPCs, collision owner and travel code unchanged')


def handoff():
    from PIL import Image, ImageDraw
    check_protected()
    route=json.loads((OUT/'route.json').read_text())
    before={p['name']:p for p in json.loads((OUT/'Before/cameras.json').read_text())}
    after={p['name']:p for p in json.loads((OUT/'After/cameras.json').read_text())}
    assert before.keys()==after.keys()
    for name,a in before.items():
        b=after[name]
        stage=next(s for s in route['stages'] if name.startswith(s['key']))
        assert b['actual_floor']==stage['floor'] and b['actual_source']==stage['source'],name
        if a['kind']=='gameplay':continue
        for key in ('eye','rotation','size','fov','projection','seed','links'):
            equal=all(abs(x-y)<1e-4 for x,y in zip(a[key],b[key])) if key in ('eye','rotation') else a[key]==b[key]
            assert equal,(name,key)
    collisions=[]
    for s in route['stages']:
        a=json.loads((OUT/'Before'/(s['key']+'-geometry.json')).read_text())
        b=json.loads((OUT/'After'/(s['key']+'-geometry.json')).read_text())
        assert a['collision_shapes']==b['collision_shapes'], s['key']
        collisions.append(dict(source=s['source'],before=a,after=b))
    assert len(after)==119 and sum(p['kind']=='isometric' for p in after.values())==59
    proof=dict(captures=len(after),continuous_sections=59,source_maps=7,
               identical_baseline_native_camera_seed_and_exit_records=66,current_gameplay_views=53,
               all_current_capture_map_ids_verified=True,unchanged_collision_counts=True,geometry=collisions,
               historical_gameplay_baseline='Not used as matched evidence: automatic exits could fire at gate tiles. Final review freezes physics only in the harness and checks the actual floor in every capture.')
    (OUT/'verification.json').write_text(json.dumps(proof,indent=2)+'\n')
    limits={
      'B1':'Native maps record floor/object planes and walking masks, not authoritative walkable elevation fields. Existing flat recovered-map collision and all stair/exit behavior are frozen. Exact slopes and traversable grades cannot be established or corrected under that constraint.',
      'B2':'Cliff caps, rear faces, tunnel depth and cave ceilings are absent or black in the single-view native art. Existing fitted rock masses/ceilings remain visible. Their caps, exposed rear strips and void closure do not match an independently recovered original surface; that surface is unavailable. No exact 3D claim is made for them.',
      'B3':'The three reusable editable tree masters and existing solid prop kits provide volume; native serials provide placement, image, facing extent and palette. Fine crown/branch depth, hedge thickness, ice-tip volume and hidden prop silhouettes at rotated gameplay angles are not recovered. Known isometric paint and contours are retained separately from those inferred dimensions.',
      'B4':'The inspected footage is labeled version 2.0 of the original Cross Gate game. It corroborates the route and all three cave floors. At the university it shows a snow-covered arch where our BlueCrossgate cache uses the green/moss 11331/11332 pair; our files remain primary. Exact weather/lighting is not independently documented for every fixed view. Lighting and this observed art-variant difference remain unverified.',
      'B5':'Map 400/4000 preserve client-recorded cells plus the pre-existing pinned completion of uncached cells. All review walking cells are client-recorded. Unrecorded surroundings, black voids and off-corridor distant scenery do not become verified originals because a runtime surface is visible.',
      'B6':'Native per-tile shore anchors and artwork are recovered, but shoreline depth behind the visible paint is inferred. The existing water level and collision remain fixed; the local native water backing closes exposed gaps without changing movement.',
    }
    stage_limits=[['B1','B2','B3','B4','B5'],['B1','B2','B3','B4','B5','B6'],
                  ['B1','B2','B4'],['B1','B2','B4'],['B1','B2','B3','B4'],
                  ['B1','B2','B3','B4','B5','B6'],['B1','B2','B3','B4','B5']]
    sections=[]
    transitions=Image.new('RGB',(1280,7*426),'#20292e')
    draw=ImageDraw.Draw(transitions)
    for index,(s,blocks) in enumerate(zip(route['stages'],stage_limits)):
        for section in s['sections']:
            name=section['key']+'-iso'
            assert name in after and (OUT/'Source vs After'/(name+'.jpg')).exists()
            sections.append(dict(section=section['key'],source=s['source'],tile=section['at'],
                checked_against_native_map=True,visually_certified_1_to_1=False,limits=blocks,
                comparison='Source vs After/'+name+'.jpg'))
        for side,anchor in enumerate([0,len(s['anchors'])-1]):
            name=f'{s["key"]}-anchor-{anchor:02d}-play'
            assert name in after
            im=Image.open(OUT/'After'/(name+'.png')).convert('RGB').resize((640,400))
            transitions.paste(im,(side*640,index*426+26))
            draw.text((side*640+8,index*426+7),f'MAP {s["source"]} | '+('ARRIVAL' if side==0 else 'EXIT / END')+f' | {s["anchors"][anchor]}',fill='white')
    transitions.save(OUT/'fixed-transitions.jpg',quality=94)
    (OUT/'section-review.json').write_text(json.dumps(sections,indent=2)+'\n')
    Image.open(OUT/'Source vs After/06-university-snowfield-14-iso.jpg').save(OUT/'university-gate-comparison.jpg',quality=95)
    lines=['# 傑諾瓦 → 魔法大學 route review','',
      '2026-11-23. Reconstructed from our BlueCrossgate files, with original-game footage as corroboration. The route was locked before scenery edits. All seven sections were checked overhead and through continuous source-camera comparisons; fixed normal gameplay views cover the departure, bends, both sides of every transition and the university approach. No app was exported.','',
      '**Status: checked with the specific limits below; no section is certified visually 1:1.** All six required links already exist. No cave or indoor link was omitted or replaced. The building interior 4410 is not part of the route.','',
      '## Ordered route checklist','',
      '| Checked | Section / original ID | Entrance → exit and route anchors | Continuous views | Remaining limits |',
      '|---|---|---|---|---|']
    for s,blocks in zip(route['stages'],stage_limits):
        anchors=' → '.join(f'({x},{y})' for x,y in s['anchors'])
        lines.append(f"| ✓ | {s['title']} / {s['source']} | {anchors} | {len(s['sections'])} | {', '.join(blocks)} |")
    lines+=['','West gate lanes: 4000 (24,39–41) → 400 (216,455–457). University gate lanes: 402 (117–119,100) → 4400 (74–76,171). The Abanis branch is visible at 402 (182–184,161), but the route does not enter 4300. Campus review stops at main building doorway 4400 (74–75,93), before 4410.','',
      '## Applied local corrections','',
      '- Restored native-size, source-painted trees across the full selected corridor, including the previously generic university snow trees. Existing editable flora, wind and canopy hiding are reused; materials and UV derivatives are owned by this route.',
      '- Restored the original modular stone wall/arch silhouettes at the departure and university approach, plus continuous solid campus hedges instead of potted plant forms. All eighteen prepared contours retain native image hashes.',
      '- Replaced short generic university forts with the existing measured Falan models of those exact graphic serials. Source axes, anchors, crenellations, slits, tower braces and gate ironwork are reused without changing the shared models.',
      '- Fitted the matching existing guild model to the main university building. Its original node hierarchy and source material mapping are retained.',
      '- Reused the editable travel-stone kit for the visible crescent, posts and lectern; fitted native roadside plants, rocks, fence arms, lamps, statues, planters and cave ice to their own source extents.',
      '- Reused the recovered three-band shore builder and native water backing in the corridor to correct clipped bank posts and exposed water gaps. Existing heights and collision remain authoritative.',
      '- Joined the departure-side cliff fragments using the existing source-measured cliff builder; original open cells remain clear. Unknown upper/rear surfaces remain limited by B2.','',
      '## Evidence and preservation','',
      '119 fixed rendered captures: 7 whole-section overheads, 59 continuous source-aligned views and 53 normal gameplay views. All 119 final captures assert their actual runtime floor and source map ID. The 66 overhead/source-camera views retain baseline eye, rotation, projection, FOV/span, seed and complete exit metadata. All seven collision-shape counts match baseline. `verification.json` contains geometry counts as well as these checks.','',
      'The initial normal-camera harness allowed automatic exits at gate tiles. Those historical normal images are not used as matched before/after proof. The corrected harness freezes physics in the test scene, keeps the actual game map fixed, and uses the normal follow camera for fresh gameplay views. Production travel behavior is unchanged. Historical generated pairs are retained separately under `Historical normal comparisons/`.','',
      'The focused runtime contract check passes 7,178 assertions: all three source map planes, recorded/open route cells, source scenery anchors, exact crossings and excluded destinations. Locked file hashes separately protect NPC scripts, travel, the map catalog, state/layout/links and the original collision builder. The only change in the original map owner is visual assembly. The standard asset preservation check passes; four reused flora/travel-stone GLBs were audited with zero read errors.','',
      'Rendered runs have zero review failures and no script errors. Godot still reports cached resource/RID allocations during fixture shutdown, also present in the baseline. This is not a leak-free or frame-time benchmark claim.','',
      '## Specific blockers / unverifiable details','']
    lines += [f'- **{key}:** {value}' for key,value in limits.items()]
    lines+=['','## References','',
      'Primary files and SHA-256 values are listed per stage in `route.json`. They resolve to the read-only adjacent `Magic Power/data/crossgate/source/BlueCrossgate/map/0/` archive. `locked-inputs.json` and `original-maps-before.gd.txt` preserve the pre-edit comparison boundary.','',
      '- [傑諾瓦 reference](https://cg.skyey.tw/map/ma10.htm)',
      '- [阿巴尼斯 and western cave route](https://cg.skyey.tw/map/ma12.htm)',
      '- [University coastal approach](https://cg.skyey.tw/map/ma13.htm)',
      '- [Original-game departure and cave footage](https://www.youtube.com/watch?v=SEhtR-sc8hc): sampled at 00:04, 00:20, 00:45, 00:54, 01:00, 01:17 and 01:24.',
      '- [Original-game university footage](https://www.youtube.com/watch?v=hBjeJb804hg): sampled at 00:20, 00:30, 00:40 and 01:00. The last frame is beyond the exterior route and is retained only as a reference boundary, not implemented scope.','',
      'Open `index.html` for every labeled source/current and before/after comparison. Original source-camera renders are in `Original/`, unmodified gameplay images in `After/`, and browser reference captures in `Footage/`. Normal perspective views are labeled separately: an isometric original image is not a matching perspective-camera screenshot.']
    (OUT/'ROUTE_REVIEW.md').write_text('\n'.join(lines)+'\n')
    body=['<!doctype html><meta charset="utf-8"><title>Jenova to Magic University — checked route</title>',
      '<style>body{background:#172329;color:#eee;font:16px system-ui;margin:30px auto;max-width:1320px}img{width:100%;height:auto}a{color:#bde2f3}section{border-top:1px solid #667;margin-top:30px}summary{cursor:pointer;padding:14px;background:#28373b}figure{margin:15px 0}p{max-width:1000px;line-height:1.6}</style>',
      '<h1>傑諾瓦 → 魔法大學</h1><p>Seven checked maps; 59 continuous stretches. Native BlueCrossgate files are primary. Specific limits remain; no full visual 1:1 certification.</p>',
      '<p><a href="ROUTE_REVIEW.md">Ordered route, changes and blockers</a> · <a href="route.json">Locked source IDs / coordinates / hashes</a> · <a href="verification.json">Camera, exits and collision comparison</a></p>']
    body.append('<p><a href="section-review.json">Every continuous section and its remaining limits</a> · <a href="fixed-transitions.jpg">All seven fixed gameplay arrivals and exits</a></p>')
    for s in route['stages']:
        key=s['key'];body.append(f'<section><h2>{html.escape(s["title"])} — map {s["source"]}</h2>')
        body.append('<p>'+html.escape(' → '.join(f'({x},{y})' for x,y in s['anchors']))+'</p>')
        for page in sorted((OUT/'Source vs After').glob(key+'-page-*.jpg')):
            body.append(f'<figure><img loading="lazy" src="Source vs After/{page.name}" alt="{page.stem}: native source left, current 3D right"></figure>')
        body.append('<details><summary>Matched native-camera before / after views</summary>')
        for pair in sorted((OUT/'Before vs After').glob(key+'-*.jpg')):
            body.append(f'<figure><figcaption>{html.escape(pair.stem)} · baseline left, current right</figcaption><img loading="lazy" src="Before vs After/{pair.name}"></figure>')
        body.append('</details>')
        body.append('<details><summary>Verified current normal gameplay views</summary>')
        for pose in after.values():
            if pose['name'].startswith(key) and pose['kind']=='gameplay':
                name=pose['name'];body.append(f'<figure><figcaption>{html.escape(name)} · source tile {pose["cell"]} · verified runtime map {pose["actual_floor"]}</figcaption><img loading="lazy" src="After/{name}.png"></figure>')
        body.append('</details></section>')
    body.append('<section><h2>Footage corroboration — CG1 game, version 2.0</h2><p>These are browser captures of the linked reference videos. Version/lighting differences remain unverified; see B4.</p>')
    for f in sorted((OUT/'Footage').glob('*.jpg')):body.append(f'<figure><figcaption>{f.stem}</figcaption><img loading="lazy" src="Footage/{f.name}"></figure>')
    (OUT/'index.html').write_text('\n'.join(body))
    print('Packaged 119 map-verified views, 66 matched native camera records and seven route checklists')


if __name__=='__main__':
    command=sys.argv[1] if len(sys.argv)>1 else 'plan'
    if command=='plan':plan()
    elif command=='compare':compare(sys.argv[2])
    elif command=='check':check_protected()
    elif command=='handoff':handoff()
    else:raise ValueError(command)
