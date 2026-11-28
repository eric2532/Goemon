"""Record each generated dungeon's ending without treating source ownership as play proof."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access'
FILES = ['assets/maps/falan/university_region/dungeon_specs.gd',
         'assets/maps/falan/east_region/dungeon_specs.gd',
         'assets/maps/falan/sokia/cape/dungeon_specs.gd',
         'assets/maps/falan/explore-dungeon-specs.gd']
GOEMON = {'scientist', 'permafrost', 'east_8', 'east_4096', 'sokia_309', 'sokia_303'}
FIXED = {'mountain': 15522, 'east_4085': 32115, 'east_4086': 32106}
REGIONAL = {'lizard': 'lizard', 'tunnel': 'dijiro', 'abyss': 'abyss'}
CONTINUES = {
    'east_13': ['east_15'], 'east_14': ['east_15'],
    'east_605': ['Original actors306170/306173 behind the source tree-door conversations'],
    'east_803': ['east_804'], 'east_804': ['east_805'], 'east_805': ['east_806'],
    'east_908': ['Original46057 stair to underground lake46056, then east_909 and original boss306333'],
    'east_4075': ['east_4076', 'east_4077', 'east_4078'],
    'east_4076': ['east_4077', 'east_4078'], 'east_4077': ['east_4078'],
    'east_4079': ['east_4080', 'east_4081', 'east_4082', 'east_4083'],
    'east_4080': ['east_4081', 'east_4082', 'east_4083'],
    'east_4081': ['east_4082', 'east_4083'], 'east_4082': ['east_4083'],
    'east_4083': ['east_4084', 'east_4085'],
}
QUEST_OR_TRANSIT = {
    'east_600': 'Brown Mountain route to the original summit quest areas.',
    'east_601': 'Brown Mountain route to the original summit quest areas.',
    'east_603': 'Brown Mountain route to the original summit quest areas.',
    'east_602': 'Mermaid rescue endpoint37008 retains original actors306065/306071; original boss306062 is in37004.',
    'east_705': 'Original quest hideout47002 retains actors305110/305111/305112 and their original departures.',
    'east_800': 'Lemur Mountain route to the original summit quest areas.',
    'east_801': 'Lemur Mountain route to the original summit quest areas.',
    'east_802': 'Lemur Mountain route to the original summit quest areas.',
    'east_902': 'Original royal conversation variant46033; no source encounter declared.',
    'east_903': 'Original royal conversation variant46034; no source encounter declared.',
    'east_904': 'Original royal conversation variant46035; no source encounter declared.',
    'east_905': 'Original royal conversation variant46036; no source encounter declared.',
    'east_4072': 'Original Oma quest conversation1102354 in31916.',
    'east_4103': 'Original herb/summit quest route; do not add a boss solely for floor count.',
    'east_4104': 'Original herb/summit quest route; do not add a boss solely for floor count.',
    'cape_descent': 'Geographic passage through Cape Cave to the connected Sokia route.',
    'cape_ascent': 'Geographic passage through Cape Cave to the connected Sokia route.',
    'sokia_110': 'Post-quest White Dragon Castle reward branch; original castle boss5340 belongs to sokia_108.',
    'sokia_111': 'Post-quest Black Dragon Castle reward branch; original castle boss5333 belongs to sokia_109.',
}


def main():
    specs = {}
    for file in FILES:
        specs.update(json.loads((ROOT / file).read_text().split('const SPECS=', 1)[1]))
    census = json.loads((OUT / 'map-checklist.json').read_text())
    maps = {int(row['map']): row for row in census['maps']}
    rows = []
    for key, spec in specs.items():
        end = spec.get('end', [])
        area = maps.get(int(end[0]), {}) if end else {}
        bosses = area.get('bosses', [])
        row = dict(branch=key, title=spec['title'], floors=[spec['minimum'], spec['maximum']],
                   entry=spec['entry'], end=end, source_terminal_enemy=spec.get('terminal_enemy', 0),
                   original_bosses=[dict(actor=b['actor'], name=b['name']) for b in bosses],
                   traversal_and_fight_verification='PENDING; consult map-checklist and bosses-history for exact tested interactions')
        if key in GOEMON:
            row.update(ending='NEW_GOEMON_ENCOUNTER', location='last generated floor')
        elif key in FIXED:
            row.update(ending='NEW_GOEMON_ENCOUNTER', location=FIXED[key])
        elif key in REGIONAL or spec.get('terminal_enemy'):
            row.update(ending='ORIGINAL_SCRIPTED_ENCOUNTER', encounter=REGIONAL.get(key, str(spec['terminal_enemy'])))
        elif bosses:
            row.update(ending='ORIGINAL_SOURCE_BOSS', location=end[0])
        elif key in CONTINUES:
            row.update(ending='CONTINUES_TO_DUNGEON_ENCOUNTER', continuation=CONTINUES[key])
        elif key in QUEST_OR_TRANSIT:
            row.update(ending='QUEST_OR_TRANSIT_REVIEW', reason=QUEST_OR_TRANSIT[key])
        else:
            row.update(ending='NEEDS_ENDPOINT_REVIEW')
        rows.append(row)
    assert len(rows) == len(specs) and len({row['branch'] for row in rows}) == len(rows)
    (OUT / 'major-dungeon-endpoints.json').write_text(json.dumps(dict(
        qualification='Source ending review, not normal-play verification. Quest/transit cases retain their source purpose; pending reviews are not marked finished.',
        branches=rows), ensure_ascii=False, indent=2) + '\n')
    print('EXPLORE_DUNGEON_ENDINGS', len(rows), 'branches;',
          [r['branch'] for r in rows if r['ending'] == 'NEEDS_ENDPOINT_REVIEW'], 'still unclassified')


if __name__ == '__main__':
    main()
