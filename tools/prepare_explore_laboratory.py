"""Connect Alubass's original cave/arena using the existing map and native owners."""
import json
from pathlib import Path
import shutil

from prepare_sokia_cape_dungeons import rows, SOURCE, TABLES, sha
from prepare_east_region_population import pack_new_species, native_page_index

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
                if eid in ['', '0'] or not member_weight:
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
    output = dict(schema=1, species=species, groups=groups, pools=pools, bosses={'11001': pools['11001']},
        zones=[], generated_branch=branch, scripted_battles=fights,
        source_hashes={n: sha(TABLES / n) for n in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']},
        dungeon_source_sha256=sha(SOURCE / 'dungeonconf.txt'),
        qualification='Source preparation only; normal interactions, original body/motion, native reuse and rendered review remain separate.')
    (OUT / 'encounters.json').write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('EXPLORE_LABORATORY', len(groups), 'source groups; native cow skin', skin, 'key', prepared[skin]['key'])


if __name__ == '__main__':
    prepare()
