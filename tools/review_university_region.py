"""Inventory the complete University region before changing its recovered maps."""
import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/University Region'
SOURCE = OUT / 'Source'
CATALOG = ROOT / 'assets/maps/original_crossgate/catalog.json'
GROUPS = {
    'Regional roads and sea-cave return': [400, 402, 15000, 15001, 15002, 14000, 14001, 14002],
    'Jenova and the hospital/key approach': [4000, 4001, 4002, 4008, 4009, 4010, 4011, 4012, 4013, 4020, 4021, 4022, 4099],
    'Abanis and all interiors/time states': [4300, 4308, 4309, 4310, 4312, 4313, 4320, 4321, 4322, 4330, 4331, 4332, 4333, 4334, 4335, 4399],
    'University grounds and interiors': [4400, 4401, 4402, *range(4410, 4425), 4430, 4431, 4432, *range(4451, 4456)],
    'Azure Dragon cave, nest and post-fight room': [*range(4403, 4410), 32154],
    'Underground lake': [4456, 4457],
    'Snow mountain summit, cabin and permafrost': [15522, 15523, 15536, 15537],
    'Holy Decree entry, sixty floors and six post-guardian rooms': [*range(24008, 24075)],
    'Holy Decree connected post-fight shop': [5014],
    'Bezlheim entrance, beast and reward/return rooms': [*range(16510, 16516)],
    'Lizard nest entrance and boss': [16521, 16520],
    'Strange tunnel, dark doctor and abyss endpoints': [15531, 15532, 15533, 15535, 15538, 15539],
    'Eastern cave, abandoned cabin and sealed altar': [14003, 14004, 14005, 14006, 14007, 4500, 4501, 4502],
    'Ice prison approach, thirteen floors and event/reward states': [401, 15400, 15401, 15402, *range(20501, 20523), *range(20524, 20528), 20530, 20414, 20428, 20001],
    'Locally connected Sylph event': [59752],
  'Curse hideout and connected teaching rooms': list(range(15006,15013)),
  'Beast-unlocked Astia approach: seven Sando floors': list(range(14010,14017)),
  'Astia boundary gateway only': [4100],
    'Conditional campus romance-event auditorium': [32269],
    'Four-beast memory boundary gateway': [32183],
}

GENERATED = [
    ('Scientists prison', 401, 5, 5, 4402, 4430),
    ('Bezlheim', 400, 12, 12, 16510, 16511),
    ('Snow Mountain', 402, 20, 24, 402, 15522),
    ('Lizard nest', 403, 10, 10, 16521, 16520),
    ('Strange tunnel', 404, 12, 16, 400, 15531),
    ('Permafrost', 406, 36, 36, 15536, 15537),
    ('Abyss', 407, 36, 36, 15538, 15539),
]
ALIASES = {400: 51031, 402: 51032, 4000: 51004, 4020: 51006, 4300: 51011,
           4400: 51012, 4313: 51013, 4410: 51014, 4411: 51016, 4310: 51018,
           4418: 51019, 4320: 51021, 4331: 51022, 4333: 51023,
           15000: 51001, 15001: 51002, 15002: 51003}


def runtime_id(n):
    if 24009 <= n <= 24068:
        floor = n - 24008
        return 51024 + floor // 10 if floor % 10 == 0 else 51100 + floor
    return ALIASES.get(n, n)


def main():
    catalog = json.loads(CATALOG.read_text())
    proofs = json.loads((SOURCE / 'references.json').read_text())
    for proof in proofs:
        assert hashlib.sha256((SOURCE / proof['file']).read_bytes()).hexdigest() == proof['sha256'], proof['file']
    layouts = {}
    for p in SOURCE.iterdir():
        raw = p.read_bytes()
        if raw[:6] == b'LS2MAP':
            n = struct.unpack_from('>H', raw, 6)[0]
            layouts[n] = dict(file=p.name, title=raw[8:40].split(b'\0')[0].decode('gb18030').split('|')[0], size=list(struct.unpack_from('>HH', raw, 40)))
    rows = []
    for group, ids in GROUPS.items():
        for n in ids:
            path = f'BlueCrossgate/map/0/{n}.dat'
            cached = catalog['maps'].get(path)
            reference = layouts.get(n)
            row = dict(source=n, runtime=runtime_id(n), group=group,
                       title=reference['title'] if reference else cached['title'] if cached else 'Source identity pending',
                       catalog=bool(cached), reference=reference,
                       art='awaiting fixed-view review', population='awaiting actor audit',
                       progression='awaiting normal-entry walkthrough')
            if cached:
                raw = zlib.decompress(base64.b64decode(cached['raw']))
                w, h = struct.unpack_from('<II', raw, 12)
                values = struct.unpack_from(f'<{w*h*3}H', raw, 20)
                row['recorded_cells'] = sum(bool(v & 0xc000) for v in values[w*h*2:])
                row['cells'] = w*h
                row['sha256'] = hashlib.sha256(raw).hexdigest()
            rows.append(row)
    assert len({r['source'] for r in rows}) == len(rows), 'One checklist row per fixed map/state'
    generated = []
    for title, config, lo, hi, start, end in GENERATED:
        for floor in range(1, hi + 1):
            generated.append(dict(branch=title, config=config, floor=floor, optional=floor>lo,
                                  approach=start, terminal=end, status='awaiting floor coverage audit'))
    data = dict(schema=1, date='2026-11-26', fixed=rows, generated=generated,
                source_commit='dd8690ed3df11e4eb5a038a54079a8f40d8e93b3',
                limits=['Server layouts/scripts corroborate the read-only BlueCG client; differences must be retained and reported.',
                        'A catalog entry is not evidence of a working entrance or complete recorded ground.',
                        'A fixed-view/direct-load capture is art evidence only, never dungeon progression evidence.'])
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'scope.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    lines = ['# 魔法大學 regional checklist', '',
             'Status: active. This is the pre-edit inventory; no map is certified finished or visually 1:1.', '',
             'Boundary: the complete northern Shalena map 402, University, Abanis, the Jenova approach and locally entered dungeon branches. The earlier 402 crop is not a scope boundary. Preserve the sea-cave return. Stop at other independent hubs (Tina, Astia, Falan) and at the final reward/return of each listed branch; do not recursively rebuild the other three sacred beasts, later dragon cities, Wind Tower, Six曜 Tower, or foreign-country signature collection. Their prerequisite references remain recorded. The ice-prison journey stays in scope because its sealed altar is on map 402.', '',
             'Evidence: original client catalog/planes, pinned fixed warps, pinned NPC/event/dungeon tables, current Explore component graph, and original-game quest references. Missing runtime links remain missing work.', '',
             '| Group | Source ID | Runtime ID | Map/state | Catalog | Pinned layout | Art | Population | Progression |',
             '|---|---:|---:|---|---|---|---|---|---|']
    for r in rows:
        lines.append(f"| {r['group']} | {r['source']} | {r['runtime']} | {r['title']} | {'present' if r['catalog'] else 'MISSING'} | {r['reference']['file'] if r['reference'] else 'client / needs reference'} | pending | pending | pending |")
    lines += ['', '## Generated floors', '', 'Floor counts come from the pinned dungeon configuration; cached visit numbers are not floor numbers.', '', '| Branch | Floor | Conditional | Approach → terminal | Status |', '|---|---:|---|---|---|']
    for r in generated:
        lines.append(f"| {r['branch']} | {r['floor']} | {'only when the seeded count includes it' if r['optional'] else 'always'} | {r['approach']} → {r['terminal']} | pending |")
    lines += ['', '## Entry and boss work', '',
              '- 聖詔: 開啟者/title and career restriction; historian 4320 → wild strawberry → 米希安 → 4331 → past 4332/blade → 4333/4334 → present 4335 → 4320. Stone 402 (54,162) → 24008 → 1–60F. Guardians at 10/20/30/40/50F, both kings at 60F; all six post-fight rooms 24069–24074, rewards and priest return to 402 (53,162). Preserve chamber backtracking.',
              '- 神獸: Jenova hospital 4010/4011 key → priest 400 (135,333) → 16510 → all 12 floors → scale gate at 16511 (26,67) → beast (26,25) → 16512; both job side rooms, 16513 and return stone. Existing direct transfers do not establish quest gating.',
              '- 青龍: campus (106,54) → 4403; basement 4404/4405 and ascent 4406/4407/4408 → 4409 nest; 小龍 medicine, boss, post-fight 32154, reward and return to 4403. Other sacred beasts are separate regions.',
              '- Snow Mountain: stone 402 (84,193) → 20–24 generated floors → 15522 summit encounter → 15523 cabin NPC/reward/paid return. Northeast summit → 15536 → 36 permafrost floors → 15537 white altar; preserve World Heart and conflicting-memory gates.',
              '- Lizard nest: Abanis hospital approach → 402 (318,136) → 16521 → 10 floors → 16520 captain/retinue, reward and return. Preserve external recommendation/hospital handoff without rebuilding Falan.',
              '- Dark doctor / abyss: local zombie/researcher → random tunnel in documented source rectangle → 12–16 floors → 15531 underground watercourse; preserve prism and ghoul gate. Include 15532/15533 swamp, 15535 doctor and return. Branch 15538 → 36 abyss floors → 15539 black altar boss/reward/return; external Wind Tower/God Eye prerequisites remain external gates.',
              '- Sealed altar / ice prison: eastern-cave approach, 4500 book cabin, 4501 two-stage 依代 → 4502 → 401 snow approach → ice cave → 20501–20513 and every linked puzzle/event state, Ruby checkpoint, 神籬 boss and final goddess/return room. Preserve torch/blue flame consumption, blocked candles and backtracking. Later Wind Tower is a separate region.',
              '- Campus: all study/service rooms, barns, stores, exam rooms, laboratory variants, timed music-room variants; underground-lake grave entry and island jump; restore documented NPCs without replacing working dialogue. Local Sylph gate remains listed; upstream overseas signatures are external prerequisites.', '',
              '## Quest references', '',
              '[Region maps](https://cg.skyey.tw/map/ma003.htm), [University](https://cg.skyey.tw/map/ma13.htm), [Holy Decree](https://cg.skyey.tw/errand/macc03.htm), [Beast](https://cg.skyey.tw/errand/maca01.htm), [Azure Dragon](https://cg.skyey.tw/errand/macf01.htm), [Snow Mountain](https://cg.skyey.tw/errand/macc01.htm), [Permafrost](https://cg.skyey.tw/errand/macc02.htm), [Lizards](https://cg.skyey.tw/errand/maaa39.htm), [Dark doctor](https://cg.skyey.tw/errand/maca03.htm), [Abyss](https://cg.skyey.tw/errand/maca04.htm), [Ice prison](https://cg.skyey.tw/errand/mace02.htm), [Campus exam](https://cg.skyey.tw/errand/macd02.htm), [Sylph](https://cg.skyey.tw/errand/mebb20.htm).', '']
    (OUT / 'CHECKLIST.md').write_text('\n'.join(lines))
    print(f'UNIVERSITY_SCOPE fixed={len(rows)} generated_floor_rows={len(generated)} absent_catalog={sum(not r["catalog"] for r in rows)}')


if __name__ == '__main__':
    main()
