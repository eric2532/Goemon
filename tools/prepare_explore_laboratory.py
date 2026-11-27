"""Connect Alubass's original cave/arena using the existing map and native owners."""
import json
from pathlib import Path
import shutil

from prepare_sokia_cape_dungeons import rows, SOURCE, TABLES, sha
from prepare_east_region_population import pack_new_species, native_page_index, append_native_bank, approved_height

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/original_crossgate/explore_recovered'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Laboratory native'


def prepare():
    data = json.loads((ROOT / 'assets/maps/original_crossgate/sokia_dragon_summit/encounters.json').read_text())
    species = data['species'].copy()
    assert not any(int(s['id']) == 101921 for s in species)
    species.append(dict(id=101921, name='最终决战型牛鬼', bank='unavailable', skin=-1, key=''))
    bank = ROOT / 'assets/characters/crossgate/east_region'
    old = json.loads((bank / 'motions.json').read_text())
    if not any(int(v['id']) == 101921 for v in old['variants']):
        baseline = REPORT / 'Previous cache'
        baseline.mkdir(parents=True, exist_ok=True)
        for name in ['motions.json', 'frames.bin', 'palette.png', 'species.json']:
            assert not (baseline / name).exists(), 'Preserve the original pre-append baseline'
            shutil.copyfile(bank / name, baseline / name)
        pack_new_species(dict(species=species))
        native_page_index(bank)
        current = json.loads((bank / 'motions.json').read_text())
        for key in ['variants', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources']:
            assert current[key][:len(old[key])] == old[key], key
        assert current['timelines'][:len(old['timelines'])] == old['timelines']
        assert all(current['sounds'][k] == v for k, v in old['sounds'].items())
    prepared = json.loads((bank / 'species.json').read_text())
    skin = next(i for i, s in enumerate(prepared) if int(s['id']) == 101921)
    species[-1].update(bank='east_region', skin=skin, key=prepared[skin]['key'], height=prepared[skin]['height'])
    baseline_population = json.loads((ROOT / 'assets/maps/falan/east_region/population.json').read_text())
    repair_ids = [gid for gid, group in baseline_population['groups'].items()
                  if any(eid not in ['', '0'] and not int(group['raw'][15 + i] or 0)
                         and group['raw'][25 + i] == '1' for i, eid in enumerate(group['raw'][5:15]))]
    enemies = {r[2]: r for r in rows(TABLES, 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES, 'enemybase.txt')}
    source_groups = {r[2]: r for r in rows(TABLES, 'group.txt')}
    known = {int(s['id']) for s in species}
    for gid in repair_ids:
        assert source_groups[gid] == baseline_population['groups'][gid]['raw'], gid
        for i, eid in enumerate(source_groups[gid][5:15]):
            if eid in ['', '0'] or not int(source_groups[gid][15 + i] or 0) and source_groups[gid][25 + i] != '1':
                continue
            base = bases[enemies[eid][3]]; appearance = int(base[30])
            if appearance not in known:
                species.append(dict(id=appearance, name=base[0], bank='unavailable', skin=-1, key=''))
                known.add(appearance)
    old = json.loads((bank / 'motions.json').read_text())
    native_ids = {int(v['id']) for v in old['variants']}
    missing = [s for s in species if s['bank'] == 'unavailable' and s['id'] not in native_ids and s['id'] != 107712]
    if missing:
        baseline = REPORT / 'Before mandatory-member repair'
        baseline.mkdir(parents=True, exist_ok=True)
        for name in ['motions.json', 'frames.bin', 'palette.png', 'species.json']:
            assert not (baseline / name).exists(), 'Preserve the pre-repair native baseline'
            shutil.copyfile(bank / name, baseline / name)
        elsa = ROOT / 'assets/characters/crossgate/elsa_region'
        manifest = json.loads((elsa / 'motions.json').read_text())
        skins = [i for i, v in enumerate(manifest['variants']) if int(v['id']) in {s['id'] for s in missing}]
        additions = [dict(id=int(manifest['variants'][i]['id']), name=next(s['name'] for s in missing if s['id'] == int(manifest['variants'][i]['id'])),
                          key=f'v3:{[2, 8, 14, 20][i - 21]}', height=approved_height('elsa_region', i, manifest),
                          prepared_from=dict(bank='elsa_region', skin=i)) for i in skins]
        if additions:
            append_native_bank(bank, elsa, skins, additions)
        remaining = [s for s in missing if s['id'] not in {a['id'] for a in additions}]
        if remaining:
            blockers = ROOT / 'assets/maps/falan/east_region/native-preparation-blockers.json'
            previous_blockers = json.loads(blockers.read_text())
            pack_new_species(dict(species=remaining))
            new_blockers = json.loads(blockers.read_text())
            blockers.write_text(json.dumps(previous_blockers + [b for b in new_blockers if b['id'] not in {p['id'] for p in previous_blockers}], ensure_ascii=False, indent=2) + '\n')
        native_page_index(bank)
        current = json.loads((bank / 'motions.json').read_text())
        for key in ['variants', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources', 'timelines']:
            assert current[key][:len(old[key])] == old[key], key
    prepared = json.loads((bank / 'species.json').read_text())
    for s in species:
        match = next(((i, p) for i, p in enumerate(prepared) if int(p['id']) == int(s['id'])), None)
        if match and s['bank'] == 'unavailable':
            i, p = match
            s.update(bank='east_region', skin=i, key=p['key'], height=p['height'])
    indices = {int(s['id']): i for i, s in enumerate(species)}
    enemies = {r[2]: r for r in rows(TABLES, 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES, 'enemybase.txt')}
    source_groups = {r[2]: r for r in rows(TABLES, 'group.txt')}
    source_pools = {r[0]: r for r in rows(TABLES, 'encount.txt')}
    groups, pools, pending = {}, {}, ['11001', '15000']
    while pending:
        ident = pending.pop()
        if ident in pools:
            continue
        raw = source_pools[ident]
        choices = []
        for slot, gid in enumerate(raw[14:24]):
            weight = int(raw[24 + slot] or 0)
            if not gid or not weight:
                continue
            original = source_groups[gid]
            members, identities, details = [], [], []
            for j, eid in enumerate(original[5:15]):
                member_weight = int(original[15 + j] or 0)
                if eid in ['', '0'] or not member_weight and original[25 + j] != '1':
                    continue
                enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
                members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=original[25 + j] == '1'))
                details.append(dict(species=index, enemy=eid, name=base[0], raw_enemy=enemy, raw_base=base))
            key = 'explore_laboratory:' + gid
            record = dict(members=members, raw=original, source_group=gid, order=original[1], source_members=identities, details=details)
            assert key not in groups or groups[key] == record
            groups[key] = record; choices.append([key, weight])
        pools[ident] = dict(id=int(ident), map=int(raw[3]), bounds=list(map(int, raw[4:8])), probability=list(map(int, raw[8:10])),
            maximum=int(raw[10]), minimum=1, priority=int(raw[11]), groups=choices, raw=raw, source_party_contract=True,
            next_encounter=int(raw[12] or 0), next_probability=int(raw[13] or 0))
        if int(raw[12] or 0):
            pending.append(str(int(raw[12])))
    raw = next(r for r in rows(SOURCE, 'dungeonconf.txt') if len(r) > 100 and r[3] == '300')
    pool = dict(pools['15000'], levels=list(map(int, raw[50:52])))
    branch = dict(config=300, name=raw[0], raw=raw, floors=list(map(int, raw[39:41])), source_template=int(raw[7]),
        size=list(map(int, raw[41:45])), entry_map=int(raw[9]), entry_rect=list(map(int, raw[10:14])),
        end=list(map(int, raw[15:18])), pool=pool, runtime_registered=True,
        qualification='Original configuration and source party; existing seeded room-graph adaptation, not original random-generator parity.')
    actors = json.loads((OUT / 'events/data.json').read_text())['actors']
    fights = [dict(actor=a['id'], source=a['source'], generated_by=None, encounter=11001, command=a['script'], script='', line=0)
        for a in actors.values() if a['id'] in ['80061', '80062']]
    assert len(fights) == 2 and set(pools) == {'11001', '15000'}
    repaired_groups = {}
    for gid in repair_ids:
        original = source_groups[gid]; members, details, identities = [], [], []
        for i, eid in enumerate(original[5:15]):
            weight = int(original[15 + i] or 0)
            if eid in ['', '0'] or not weight and original[25 + i] != '1':
                continue
            enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
            members.append([index, int(enemy[4]), int(enemy[5]), weight])
            details.append(dict(species=index, enemy=eid, raw_enemy=enemy, raw_base=base))
            identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=original[25 + i] == '1'))
        repaired_groups[gid] = dict(members=members, raw=original, order=original[1], details=details, source_members=identities)
    repaired_bosses = {}
    for ident, pool in baseline_population['bosses'].items():
        if not pool['groups'] and any(gid in repaired_groups for gid in pool['raw'][14:24]):
            pool = dict(pool)
            pool['groups'] = [[gid, int(pool['raw'][24 + i])] for i, gid in enumerate(pool['raw'][14:24])
                              if gid in repaired_groups and int(pool['raw'][24 + i] or 0)]
            assert pool['groups'], ident
            repaired_bosses[ident] = pool
    output = dict(schema=1, species=species, groups=groups, pools=pools, bosses={'11001': pools['11001']},
        repaired_groups=repaired_groups, repaired_bosses=repaired_bosses,
        zones=[], generated_branch=branch, scripted_battles=fights,
        source_hashes={n: sha(TABLES / n) for n in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']},
        dungeon_source_sha256=sha(SOURCE / 'dungeonconf.txt'),
        qualification='Source preparation only; normal interactions, original body/motion, native reuse and rendered review remain separate.')
    (OUT / 'encounters.json').write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('EXPLORE_LABORATORY', len(groups), 'source groups; native cow skin', skin, 'key', prepared[skin]['key'])


if __name__ == '__main__':
    prepare()
