"""Verify the current-baseline follow-up and package its eleven-map review."""
import hashlib
import html
import json
from pathlib import Path
import re
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/Snow Region Followup'


def package():
    before = {p['name']: p for p in json.loads((OUT / 'Before/cameras.json').read_text())}
    after = {p['name']: p for p in json.loads((OUT / 'After/cameras.json').read_text())}
    assert before.keys() == after.keys() and len(after) == 17
    delta = 0.0
    for name, pose in after.items():
        old = before[name]
        for key in ['floor', 'cell', 'projection', 'size', 'fov', 'links', 'seed']:
            assert old[key] == pose[key], (name, key)
        delta = max(delta, max(abs(a-b) for key in ['eye', 'rotation'] for a, b in zip(old[key], pose[key])))
    assert delta < 1e-6
    baseline = json.loads((OUT / 'baseline.json').read_text())
    changed = {'scripts/forest/wind_meadow_foliage.gdshader', 'scripts/forest/forest_waves.gd',
               'scripts/forest/forest_snow_cliff.gdshader'}
    for path, digest in baseline.items():
        if path not in changed:
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    log = (OUT / 'after-test.log').read_text()
    assert not any(word in log for word in ['SCRIPT ERROR', 'SHADER ERROR', 'SHALENA_FAIL'])
    result = re.search(r'SNOW_POPULATION_RESULT checks=(\d+) failures=0 maps=11', log)
    assert result
    locations = json.loads((OUT / 'locations.json').read_text())
    assert len(locations) == 11 and sum(len(r['npcs']) for r in locations) == 42
    assert all(n['talked'] for r in locations for n in r['npcs'])
    assert next(r for r in locations if r['floor'] == 51031)['distant_patrol_regression']
    old_ledger = json.loads((ROOT / 'build/Other Files/Asset Toolkit/Snow Region Restoration/checklist.json').read_text())
    population = json.loads((ROOT / 'assets/maps/falan/snow_region/population.json').read_text())
    rows = []
    for entry, location in zip(old_ledger['maps'], locations):
        assert entry['floor'] == location['floor']
        floor = entry['floor']
        art = 'Reviewed the current house forms, ground, seams and props; retained the baseline.'
        if floor in [51004, 51031, 51032, 51011, 51012, 15522]:
            art = 'Calmer crown paint and lighting; quieter cliff texture. Existing tree geometry, trunks, anchors and house forms retained.'
        if floor == 51004:
            art = 'Calmer green canopy colour/lighting and cliff texture; existing house forms, paving and landmarks retained.'
        if floor in [14000, 14001, 14002]:
            art = 'Lower-contrast rock paint reduces stretched texture noise; existing chambers, earth finish and entrances retained.'
        if floor in [51009, 51010]:
            art = 'Reviewed the existing snow/rock seams and bare trees; retained the generated layout and scenery.'
        enemy = entry['enemies']
        if floor == 51031:
            enemy += ' Fixed distant branch patrols suppressing corridor encounters; nearby combat and the current group still block another group.'
        rows.append(dict(floor=floor, title=entry['title'], art=art, enemies=enemy,
                         npcs=entry['npcs'], see=entry['see'], locations=location))
    lines = ['# 阿巴尼斯・傑諾瓦 current-baseline follow-up', '',
             'This pass starts from the already-restored current build. Existing NPCs and enemy identities are retained, not counted as newly added. No app was exported. Original assets, map planes, scenery anchors, collision and route owners are unchanged.', '',
             '| Map | Art | Enemies | NPCs | Where to look |', '|---|---|---|---|---|']
    for r in rows:
        lines.append(f"| {r['title']} ({r['floor']}) | {r['art']} | {r['enemies']} | {r['npcs']} | {r['see']} |")
    lines += ['', '## Fresh verification', '',
              f'- Play Goemon: {result[1]} assertions, zero failures, all eleven maps, 42 F-key talk interactions and 21 reachable encounter zones. Every documented pool in those zones is installed into the native army at a source location.',
              f'- Seventeen normal-camera pairs match the fresh baseline (maximum pose roundoff {delta:.3g}); exit metadata and seed match. Source/atlas tests and asset preservation checks pass.',
              '- A distant original branch post no longer suppresses a corridor encounter. The current encounter group and nearby combat still prevent extra groups; stationary safety and shuffle-bag refill pass.',
              '- Art uses existing meshes, batches and setup-owned material overrides. There is no new per-frame art processing. These checks do not establish long-session FPS or resource-growth performance. Existing Godot RID/resource shutdown diagnostics remain.', '',
              '## Specific gaps retained', '',
              '- Source 4400 farm positions have no walkable ground within talk range in the preserved client: 菜園介紹板 (38,147), 學生阿葛里 (38,159), 農夫葛德里夫 (44,166), 學生哈斯帕 (34,167). The grave (36,30) is an invisible event marker. No actor was moved to an invented location.',
              '- Original probability ramp/count weights and the original random mountain-floor mapping are unavailable. Documented rectangles, group/member weights, levels and maxima remain preserved; uniform shuffled bounds and the existing adapted mountain pools remain explicit approximations.',
              '- NPCs retain source coordinates, names, pixels and recorded directions. Their static drawings retain their drawn facing; alternate directional 3D artwork is unavailable. Event dialogue remains a short placeholder, without invented quest behavior.',
              '- The summit ice group retains one 冰之人魔草 and three 變種液態史萊姆. Original special spell/escape/drop/reward scripting is unrecovered; compatible native combat remains in use.',
              '- The inherited tight western-cave views remain constrained by the normal camera and original corridor geometry. No route or camera redesign was included.', '',
              'The complete 36-record excluded/uncertain-object list is in [GAPS.md](GAPS.md), including names, IDs, source cells and reasons. Source references and the previous population restoration are documented in assets/maps/falan/snow_region/README.md.', '',
              'Reproduce: run snow_region_population_test.gd with --visual and --review-root pointing here, then python3 tools/review_snow_region_followup.py. Do not overwrite Before.']
    (OUT / 'REVIEW.md').write_text('\n'.join(lines)+'\n')
    gaps = ['# Source placements requiring corroboration', '',
            'All 36 records below belong to source 4400 (university exterior / runtime 51012). They are retained in the source ledger and have not been moved or invented.', '',
            'G: no walkable ground within talk range in the preserved map. I: invisible event marker; visible appearance/location needs evidence. U: later/private-server, inactive or unnamed record; original presence remains uncorroborated.', '',
            '| Record | Source name | Cell | Blocker |', '|---|---|---|---|']
    for n in population['skipped']:
        code = 'G' if 'walkable ground' in n['reason'] else 'I' if 'Invisible' in n['reason'] else 'U'
        gaps.append(f"| {n['id']} | {n['name'] or '(unnamed)'} | {n['cell'][0]},{n['cell'][1]} | {code} |")
    (OUT / 'GAPS.md').write_text('\n'.join(gaps)+'\n')
    (OUT / 'checklist.json').write_text(json.dumps(dict(maps=rows, checks=int(result[1]),
        failures=0, cameras=len(after), maximum_camera_roundoff=delta,
        preserved_sources=[p for p in baseline if p not in changed],
        gaps=population['skipped'], limits=population['limits']), ensure_ascii=False, indent=2)+'\n')
    page = ['<!doctype html><meta charset="utf-8"><title>Snow region follow-up</title>',
            '<style>body{max-width:1450px;margin:32px auto;background:#253239;color:#eee;font:17px/1.5 system-ui}img{width:100%}a{color:#afe3ff}</style>',
            '<h1>阿巴尼斯・傑諾瓦 follow-up</h1><p><a href="REVIEW.md">Eleven-map review and gaps</a> · Fresh baseline on the left; current on the right.</p>']
    preview = Image.new('RGB', (1440, 3*480), '#253239')
    for index, name in enumerate(['51031-first-snow-play', '51011-pub-play', '51032-representative-play']):
        canvas = Image.new('RGB', (2560, 840), '#253239')
        ImageDraw.Draw(canvas).text((15, 10), name+'  BEFORE / AFTER', fill='white')
        for x, phase in [(0, 'Before'), (1280, 'After')]:
            canvas.paste(Image.open(OUT / phase / (name+'.png')), (x, 40))
        canvas.save(OUT / (name+'-comparison.jpg'), quality=94)
        preview.paste(canvas.resize((1440, 473)), (0, index*480))
    preview.save(OUT / 'comparison.jpg', quality=94)
    survey = Image.new('RGB', (1536, ((len(after)+2)//3)*345), '#253239')
    draw = ImageDraw.Draw(survey)
    for i, name in enumerate(after):
        x, y = i % 3 * 512, i // 3 * 345
        draw.text((x+5, y+3), name, fill='white')
        survey.paste(Image.open(OUT / 'After' / (name+'.png')).resize((512, 320)), (x, y+25))
    survey.save(OUT / 'final-gameplay.jpg', quality=94)
    for row in rows:
        page.append('<h2>'+html.escape(row['title'])+'</h2>')
        for name, pose in after.items():
            if int(pose['floor']) == row['floor']:
                page.append(f'<p>{name}</p><img loading="lazy" src="After/{name}.png">')
    (OUT / 'index.html').write_text('\n'.join(page)+'\n')
    print(f'PASS {len(rows)} maps; 42 F interactions; {len(after)} matched cameras; {result[1]} assertions; protected baseline sources retained')


if __name__ == '__main__':
    package()
