"""Pin config301's six logical floors and ordinary source encounter groups."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/references/crossgate_sokia/events'
TABLES = ROOT / 'assets/references/crossgate_tina/events'
OUT = ROOT / 'assets/maps/falan/black_prayer/encounters.json'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer encounters/source-contracts.json'


def rows(path):
    return [line.split('\t') for line in path.read_bytes().decode('gb18030').splitlines()
            if line and not line.startswith('#')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ruby_audit(encounters, groups, enemies, bases):
    npcs = {r[3]: r for r in rows(TABLES / 'npc.txt') if len(r) > 24}
    actor = npcs['81000']
    encounter = encounters['11007']
    group = groups['11009']
    assert actor[0] == 'StandEnemy' and actor[8:11] == ['16508', '24', '11']
    assert actor[24].split('|')[9] == '11007' and encounter[14] == '11009'
    party = []
    for i, enemy_id in enumerate(group[5:15]):
        enemy = enemies[enemy_id]
        party.append(dict(enemy=enemy_id, appearance=int(bases[enemy[3]][30]),
                          levels=list(map(int, enemy[4:6])), counts=list(map(int, enemy[6:8])),
                          weight=int(group[15+i]), mandatory=int(group[25+i]) == 1))
    assert [m['appearance'] for m in party] == [100654] + [101121]*4 + [101600]*5
    scripts = {}
    references = {r['file']: r for r in json.loads((SOURCE / 'references.json').read_text())}
    for name in ['EV_mag_6305.txt', 'EV_mag_6308.txt', 'EV_mag_6309.txt', 'EV_mag_6927.txt']:
        path = SOURCE / name
        assert sha(path) == references[name]['sha256']
        scripts[name] = dict(sha256=sha(path), source_path=str(path.relative_to(ROOT)),
                             provenance=references[name],
                             executable_lines=[line.strip() for line in path.read_bytes().decode('gb18030').splitlines()
                                               if line.strip() and not line.lstrip().startswith('#')])
    return dict(status='source_contract_pinned_runtime_verification_separate', source_actor=actor,
                encounter=encounter, group=group, party=party, source_win=[0, 16509, 24, 12], scripts=scripts,
                matched=['Current native party has one Ruby level50, four Ghosts level30 and five Bloody Blades level30.',
                         'Existing Ruby native attacks, spells, source animation/audio and save keys are retained.'],
                historical_differences_before_source_route=[
                    'Previous tick_ruby proximity39m did not use NPC81000 source interaction.',
                    'Previous free ruby_gate crossings bypassed NPC6305 solo/item18421 and consumption before warp16508(24,29).',
                    'Previous victory only opened legacy doors in16508 instead of source win16509(24,12).',
                    'Previous post-return implementation omitted16509 actors and timed3350/3351/3354/5011 source routes.'
                ],
                current_source_owner='scripts/forest/forest_black_prayer_events.gd',
                current_source_recipe='tools/prepare_black_prayer_events.py',
                verification='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/native-{headless,rendered}.json',
                required_limits=['Original turn-based formation and StandEnemy repeat/cooldown/escape semantics remain unverified.',
                                 'Native/rendered execution must be checked against current source and the current actor bank; this source-only contract does not certify execution.',
                                 'Full source completion of the253 uncached16508 edge cells remains required; post16509 has its separate client-preserving source hybrid.'])


def prepare():
    proof = next(r for r in json.loads((SOURCE / 'references.json').read_text()) if r['file'] == 'dungeonconf.txt')
    assert sha(SOURCE / 'dungeonconf.txt') == proof['sha256']
    config = next(r for r in rows(SOURCE / 'dungeonconf.txt') if len(r) > 100 and r[3] == '301')
    assert config[39:41] == ['6', '6'] and config[49] == '15001'
    encounters = {r[0]: r for r in rows(TABLES / 'encount.txt')}
    encounter = encounters['15001']
    source_groups = {r[2]: r for r in rows(TABLES / 'group.txt')}
    enemies = {r[2]: r for r in rows(TABLES / 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES / 'enemybase.txt')}
    base = json.loads((ROOT / 'assets/maps/falan/south_kili_route/population.json').read_text())
    coast = json.loads((ROOT / 'assets/maps/falan/sokia/population.json').read_text())
    server = json.loads((ROOT / 'assets/maps/original_crossgate/sokia_server/encounters.json').read_text())
    offset = len(base['species']) + len(coast['extra_species']) + len(server['species'])
    bank = json.loads((ROOT / 'assets/characters/crossgate/black_prayer/motions.json').read_text())
    species = []
    for ident, skin, name, key, hp in [(101600, 1, '血腥之刃', 'original:1328', 400),
                                       (101121, 2, '鬼靈', 'original:2833', 300)]:
        assert int(bank['variants'][skin]['id']) == ident
        species.append(dict(id=ident, skin=skin, name=name, key=key, family='black_prayer', native_hp_per_level=hp))
    members = {row['id']: offset + i for i, row in enumerate(species)}
    groups, choices = {}, []
    for i, gid in enumerate(encounter[14:24]):
        weight = int(encounter[24 + i] or 0)
        if not gid or not weight:
            continue
        raw = source_groups[gid]
        assert raw[3:5] == ['-1', '-1'], 'Ordinary Prayer groups have no source item gate'
        native, details = [], []
        for j, enemy_id in enumerate(raw[5:15]):
            member_weight = int(raw[15 + j] or 0)
            if enemy_id in ['', '0'] or not member_weight:
                continue
            enemy = enemies[enemy_id]
            body = bases[enemy[3]]
            ident = int(body[30])
            assert ident in members and int(raw[25 + j] or 0) == 0
            native.append([members[ident], int(config[50]), int(config[51]), member_weight])
            details.append(dict(enemy=enemy_id, appearance=ident, weight=member_weight, must_appear=False,
                                source_levels=list(map(int, enemy[4:6])), source_counts=list(map(int, enemy[6:8])),
                                raw_enemy=enemy, raw_base=body))
        key = 'prayer:' + gid
        groups[key] = dict(source_group=gid, members=native, details=details, raw=raw, order=raw[1],
                           source_members=[dict(enemy_id=r['enemy'], count=r['source_counts'], mandatory=False)
                                           for r in details])
        choices.append([key, weight])
    assert choices == [['prayer:15006', 1], ['prayer:15004', 1], ['prayer:15005', 1]]
    levels = list(map(int, config[50:52]))
    floors = [dict(runtime_id=30100 + n, config=301, number=n, source_encounter=15001,
                   source_level_range=levels,
                   reference_generator_level=levels[0] + n * (levels[1] - levels[0]) // 6)
              for n in range(1, 7)]
    limits = [
        'Config301 and floor indexes1–6 identify the existing logical floors; original transient client filenames are not asserted.',
        'The existing64x64 sixteen-room graph, walk bits, source art, stairs and endpoint links are preserved. Original random generation and source door-size units/placement remain unverified.',
        'Per-floor levels use the pinned reference editor formula, not authenticated original server execution. Raw config20–23 and raw enemy rows remain available.',
        'Equal source group/member weights and membership are restored. Native movement chance1–3 and uniform1–6 party size use the existing adapter; original amount/rate/ramp/turn scheduling remain unverified.',
        'The old96 static patrol stations and death ledger remain compatibility data; new ordinary encounters are selected by source group through the existing native movement owner. This is a source-fidelity change, not a performance count reduction.',
        'Source boxAmount4 is a whole-branch reference-generator total. Existing Prayer loot and refresh behavior are not changed by this ordinary-roster patch and remain a separate source reconciliation task.',
        'Raw warp graphics contain103012 for entry/ordinary floor markers and17974/17975 at the exit. Existing cached-source solid stair visuals remain unchanged; dynamic/source-version marker parity is not claimed.',
        'Ruby100654 and its ten-member palace party, existing native boss spells, rewards and ledger remain owned by the existing Ruby owner.'
    ]
    data = dict(schema=1, config=301, species_offset=offset, species=species, groups=groups,
                zone=dict(id=15001, map=777, config=301, groups=choices,
                          probability=list(map(int, encounter[8:10])), minimum=1, maximum=int(encounter[10]), priority=int(encounter[11]),
                          raw=encounter, levels=levels), floors=floors,
                source_config=dict(raw=config, floor_count=6, size_range=list(map(int, config[41:49])),
                                   entry=list(map(int, config[9:12])), end=list(map(int, config[15:18])),
                                   ground=int(config[22]), warp_graphics=list(map(int, config[30:38])),
                                   enemy_rate=list(map(int, config[52:54])), box_amount=int(config[54])),
                source_hashes={name: sha(TABLES / name) for name in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']},
                limits=limits)
    evidence = dict(schema=1, config_source=proof, floor_inventory=floors,
                    source_config=data['source_config'], groups=groups, source_encounter=encounter,
                    schema_references=json.loads((ROOT / 'assets/references/crossgate_sokia/schema/references.json').read_text()),
                    generator_references=json.loads((ROOT / 'assets/references/crossgate_sokia/cape_schema/references.json').read_text()),
                    source_hashes=data['source_hashes'] | {'npc.txt': sha(TABLES / 'npc.txt')},
                    ruby_script_audit=ruby_audit(encounters, source_groups, enemies, bases),
                    limits=limits, goal_complete=False)
    return data, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data, evidence = prepare()
    for path, value in [(OUT, data), (REPORT, evidence)]:
        text = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
        if args.check:
            assert path.read_text() == text, path
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    print('BLACK_PRAYER_SOURCE config301 six floors; three source groups; two preserved native appearances')


if __name__ == '__main__':
    main()
