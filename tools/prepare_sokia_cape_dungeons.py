"""Recover Cape cave source contracts; do not claim the absent original generator."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from prepare_east_region_population import compile_script

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/references/crossgate_sokia/events'
TABLES = ROOT / 'assets/references/crossgate_tina/events'
OUT = ROOT / 'assets/maps/falan/sokia/cape'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves'
CONFIGS = {305: 'cape_descent', 306: 'cape_ascent'}


def rows(folder, name):
    return [line.split('\t') for line in (folder / name).read_bytes().decode('gb18030').splitlines()
            if line and not line.startswith('#')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    proofs = json.loads((SOURCE / 'references.json').read_text())
    for name in ['dungeonconf.txt', 'EV_rk_ushi08.txt', 'EV_rk_ushi09.txt']:
        proof = next(r for r in proofs if r['file'] == name)
        assert sha(SOURCE / name) == proof['sha256'], name
    configs = {int(r[3]): r for r in rows(SOURCE, 'dungeonconf.txt') if len(r) > 100 and r[3].isdigit()}
    encounters = {int(r[0]): r for r in rows(TABLES, 'encount.txt')}
    source_groups = {r[2]: r for r in rows(TABLES, 'group.txt')}
    enemies = {r[2]: r for r in rows(TABLES, 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES, 'enemybase.txt')}
    base = json.loads((ROOT / 'assets/maps/falan/south_kili_route/population.json').read_text())
    coast = json.loads((ROOT / 'assets/maps/falan/sokia/population.json').read_text())
    assert len(base['species']) == coast['base_species_count']
    base_skins = {r['id']: i for i, r in enumerate(base['species'])}
    sokia_skins = {r['id']: len(base['species']) + i for i, r in enumerate(coast['extra_species'])}
    specs, generated, groups, floors = {}, {}, {}, []
    for config, key in CONFIGS.items():
        r = configs[config]
        spec = dict(first=7_000_000 + config * 1000, minimum=int(r[39]), maximum=int(r[40]),
                    size=list(map(int, r[41:45])), ground=int(r[22]), stairs=[int(r[33]), int(r[32])],
                    title=r[0], source_floor_prefix=r[1], source_floor_suffix=r[2],
                    entry=list(map(int, r[9:12])), end=list(map(int, r[15:18])),
                    entry_rect=list(map(int, r[10:14])), end_rect=list(map(int, r[16:20])),
                    frozen=False, outdoor=False, sokia=True, range_bags=True,
                    encounter=int(r[49]), levels=list(map(int, r[50:52])), config=config,
                    source_entrance_graphics=[int(r[31]), int(r[35])],
                    source_fixed_markers=[int(r[30]), int(r[34])], source_warp_graphics=list(map(int, r[30:38])),
                    source_door_graphics=list(map(int, r[36:38])),
                    source_door_size_range=list(map(int, r[45:49])),
                    enemy_rate=list(map(int, r[52:54])), box_amount=int(r[54]), box_amount_scope='whole_branch_reference_generator',
                    source_level_parameters=list(map(int, r[50:55])), raw=r)
        assert spec['minimum'] == spec['maximum'] == 10
        specs[key] = spec
        encounter = encounters[spec['encounter']]
        choices = []
        # Preserve the original encounter row and member details alongside the existing native adaptation.
        for index, gid in enumerate(encounter[14:24]):
            weight = int(encounter[24 + index] or 0)
            if not gid or not weight:
                continue
            g = source_groups[gid]
            members, details = [], []
            for n, eid in enumerate(g[5:15]):
                member_weight = int(g[15 + n] or 0)
                if eid in ['', '0'] or not member_weight:
                    continue
                enemy = enemies[eid]
                native = bases[enemy[3]]
                appearance = int(native[30])
                palette = sokia_skins if config == 305 else base_skins
                assert appearance in palette, ('Missing prepared Cape actor', config, appearance)
                members.append([palette[appearance], *spec['levels'], member_weight])
                details.append(dict(enemy=eid, appearance=appearance, raw_enemy=enemy, raw_base=native,
                                    source_levels=list(map(int, enemy[4:6])), source_counts=list(map(int, enemy[6:8])),
                                    must_appear=int(g[25 + n] or 0)))
            ident = 'cape:' + gid
            groups[ident] = dict(members=members, order=g[1], source_group=gid, raw=g, details=details)
            choices.append([ident, weight])
        assert choices
        generated[key] = dict(id=spec['encounter'], map=777, config=config, groups=choices,
                              probability=list(map(int, encounter[8:10])), maximum=int(encounter[10]),
                              priority=int(encounter[11]), levels=spec['levels'], raw=encounter,
                              uncorroborated_reference_amount=list(map(int, encounter[8:10])),
                              field_semantics='Existing native probability/maximum labels retained. The reference CEncountInfoReader conflicts with pinned rare-zone priority evidence; original amount/rate/ramp semantics remain unverified.')
        for n in range(1, 11):
            floors.append(dict(config=config, branch=key, number=n, runtime_id=spec['first'] + n - 1,
                               encounter=spec['encounter'], groups=choices, level_range=spec['levels'],
                               reference_generator_level=spec['levels'][0] + n * (spec['levels'][1] - spec['levels'][0]) // 10,
                               branch_box_amount=spec['box_amount'],
                               original_layout='Unrecovered random generator; existing seeded room graph is an adaptation.'))
    actors = {}
    for number, r in enumerate(rows(TABLES, 'npc.txt'), 1):
        if r[3] not in ['5243', '5305']:
            continue
        actors[r[3]] = dict(id=r[3], name=r[1], type=r[0], source=int(r[8]), cell=list(map(int, r[9:11])),
                            script=r[24], source_line=number, raw=r, source_verified=True, cell_verified=True,
                            battle_owner='sokia_cape')
    assert actors['5243']['script'] == 'EV_rk_ushi09.txt'
    scripts = {name: compile_script((SOURCE / name).read_bytes()) for name in ['EV_rk_ushi08.txt', 'EV_rk_ushi09.txt']}
    gate = json.loads(json.dumps(scripts['EV_rk_ushi09.txt']))
    gate['source_sha256'] = gate['sha256']
    gate['excluded_tail'] = [line for line in gate['lines'] if line[0] > 29]
    gate['lines'] = [line for line in gate['lines'] if line[0] <= 29]
    for block in gate['blocks']:
        block['lines'] = [line for line in block['lines'] if line[0] <= 29]
    gate['projection'] = 'Source gate lines1–29 only. Unbound Window_OK and bare condition/item18114 tail at31–35 are retained in full source but not given invented execution semantics.'
    itemspace_lines = [line for _, line in gate['lines'] if re.search(r'\bItemSpace\b', line, re.I)]
    assert itemspace_lines and all(re.search(r'\bItemSpace\s*(==|!=)\s*0\b', line, re.I) for line in itemspace_lines)
    actors['5243']['unbounded_source_quest_items'] = True
    actors['5243']['itemspace_contract'] = 'Events.set_item and the source-item commit store use an unbounded dictionary. Another source quest item always fits, so zero/nonzero ItemSpace predicates are1; original slot-limit parity is unmodeled. Pure/unknown contexts remain guarded.'
    gate['sha256'] = hashlib.sha256(json.dumps(gate, sort_keys=True).encode()).hexdigest()
    from prepare_sokia_cape_bank import records as cape_records
    battle_species = [{**record, 'bank': 'sokia_region', 'skin': 13 + i} for i, record in enumerate(cape_records())]
    battle_species.append(dict(id=101532, name='地縛靈羅連斯', key='original:2911', bank='companion', skin=311))
    battle_skins = {r['id']: i for i, r in enumerate(battle_species)}
    boss_groups, bosses = {}, {}
    for eid in [12019, 12020]:
        r = encounters[eid]
        choices = []
        for i, gid in enumerate(r[14:24]):
            weight = int(r[24 + i] or 0)
            if not gid or not weight:
                continue
            g = source_groups[gid]
            details = []
            for n, enemy_id in enumerate(g[5:15]):
                if enemy_id in ['', '0'] or not int(g[15 + n] or 0):
                    continue
                enemy = enemies[enemy_id]
                native = bases[enemy[3]]
                appearance = int(native[30])
                assert appearance in battle_skins, (eid, enemy_id, appearance)
                assert int(g[25 + n] or 0) == 1, 'Cape boss owner requires all source slots mandatory'
                details.append(dict(species=battle_skins[appearance], name=native[0], enemy=enemy_id,
                                    level=list(map(int, enemy[4:6])), count=list(map(int, enemy[6:8])),
                                    weight=int(g[15 + n]), must_appear=True, raw_enemy=enemy, raw_base=native))
            boss_groups[gid] = dict(details=details, raw=g, order=g[1], required_item=int(g[3]), forbidden_item=int(g[4]))
            choices.append([gid, weight])
        bosses[str(eid)] = dict(id=eid, groups=choices, next_encounter=int(r[12] or 0), next_probability=int(r[13] or 0), raw=r)
    data = dict(schema=1, specs=specs, generated=generated, groups=groups, actors=actors,
                scripts=scripts, runtime_scripts={'EV_rk_ushi09.txt': gate},
                battles=dict(species=battle_species, groups=boss_groups, bosses=bosses),
                source_hashes={name: sha(TABLES / name) for name in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt', 'npc.txt']},
                dungeon_source_sha256=sha(SOURCE / 'dungeonconf.txt'),
                limits=['Pinned CGMSV data corroborates source contracts; BlueCG release/server execution is unverified.',
                        'No authenticated original Cape random-floor snapshots or generation algorithm were recovered. Layout, physical depths, room topology, and native movement encounter timing remain adapted.',
                        'DungeonMapRegionInfo labels raw45–48 as east/south door-size ranges. They are retained, but original server units/placement/generation semantics are unverified and the existing seeded room graph does not claim to execute them. Raw36/37 are door graphics, not stair counts.',
                        'The reference generator selects boxAmount5/6 once across all ten floors. Native allocation weights the current adapted floor open cells, then the existing loot owner places each selected floor\'s allocation; original positions/refresh timing remain unverified.',
                        'DungeonMapRegionInfo maps fields30–37 to enter-in/out,next-in/back,exit-in/out,door-south/east. Cape stair identities use those labels. The reference CDungeonReader terminal code incorrectly uses enterInfo instead of exitInfo; exact source endpoint rows and cached fixed maps remain authoritative.',
                        'Relative group/member weights are retained. Existing native uniform1–8 party bags and movement probability1–3 are adaptations. CEncountInfoReader amount/priority labels conflict with pinned rare-zone data; raw encounter8–11 and config enemyRate1–4 remain available for verification.',
                        'NPC5243 retains ItemSpace zero/nonzero checks through the existing unbounded source-quest dictionary, item18599 exchange to18600 and original script warp. Original inventory slot-limit parity is unmodeled; pure/unknown contexts remain guarded.',
                        'Natural prerequisite access remains incomplete: item18599 comes from EV_rk_ushi06 through NPC5237 on source100(182,101), exchanging source item18598. EV_rk_ushi08 belongs to NPC5240/5241/5242 on15529. Maps15524/15528/15529 and those source actors/items must be restored before claiming the complete natural quest chain.',
                        'Fresh explicit Cape source interactions reset only their completed native battle ledger; unfinished real-time fights resume surviving slots after reentry. Exact original repeat/cooldown/escape scheduling is unverified; other regional completion rules remain unchanged.',
                        'Script encounter IDs require encount.txt lookup before group.txt lookup. NPC5305 is not resolved directly as group12020.',
                        gate['projection']])
    evidence = dict(schema=1, source_commit=next(r['commit'] for r in proofs if r['file'] == 'dungeonconf.txt'),
                    config_source=next(r for r in proofs if r['file'] == 'dungeonconf.txt'), floors=floors, specs=specs,
                    schema_references=json.loads((ROOT / 'assets/references/crossgate_sokia/schema/references.json').read_text()),
                    generator_references=json.loads((ROOT / 'assets/references/crossgate_sokia/cape_schema/references.json').read_text()),
                    princess_gate_projection=gate,
                    source_encounters={str(k): encounters[k] for k in [15005, 15006]}, limits=data['limits'],
                    goal_complete=False)
    text = 'extends RefCounted\n## Exact pinned contracts; random geometry remains the existing room-graph adaptation.\nconst SPECS=' + json.dumps(specs, ensure_ascii=False, indent=1) + '\n'
    return text, data, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text, data, evidence = prepare()
    files = {OUT / 'dungeon_specs.gd': text, OUT / 'encounters.json': json.dumps(data, ensure_ascii=False, indent=2) + '\n',
             REPORT / 'source-contracts.json': json.dumps(evidence, ensure_ascii=False, indent=2) + '\n'}
    for path, content in files.items():
        if args.check:
            assert path.read_text() == content, path
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    print('SOKIA_CAPE_SOURCE', len(evidence['floors']), 'floors', len(data['groups']), 'groups; original generator unavailable')


if __name__ == '__main__':
    main()
