"""Prepare original parties for the recovered ordinary-door frontier."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys

from prepare_sokia_cape_dungeons import rows, TABLES, sha
from prepare_east_region_population import append_native_bank, approved_height, native_page_index, pack_new_species

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/original_crossgate/explore_recovered'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Frontier native'
BANK = ROOT / 'assets/characters/crossgate/east_region'


def prepare(pack=False, activate=False):
    base = json.loads((OUT / 'encounters.json').read_text())
    previous = json.loads((OUT / 'frontier_encounters.json').read_text()) if (OUT / 'frontier_encounters.json').exists() else base
    assert previous['species'][:len(base['species'])] == base['species'], 'Preserve every established source species index'
    species = previous['species'].copy(); indices = {int(s['id']): i for i, s in enumerate(species)}
    events = json.loads((OUT / 'events/data.json').read_text())
    supplement = json.loads((ROOT / 'assets/maps/falan/explore-access.json').read_text()).get('source_events', {})
    inventory = json.loads((ROOT / 'build/Other Files/Asset Toolkit/Explore Access/runtime-inventory.json').read_text())
    regional = {(int(row['source']),str(actor))for row in inventory.get('native_bosses',[])for actor in row.get('actors',[])}
    for key, actor in supplement.get('actors',{}).items():
        if actor.get('explore_fight') and not actor.get('battle_owner') and (int(actor['source']),str(actor['id']))not in regional:
            assert not any(str(existing['id'])==str(actor['id'])for existing in events['actors'].values())
            events['actors'][key]=actor
    for name, script in supplement.get('scripts',{}).items():
        assert name not in events['scripts']or events['scripts'][name]==script
        events['scripts'][name]=script
    maps = {int(m['id']) for m in json.loads((OUT / 'catalog.json').read_text())['maps'].values()} | set(supplement.get('bank_sources',[]))
    source_pools = {r[0]: r for r in rows(TABLES, 'encount.txt')}
    source_groups = {r[2]: r for r in rows(TABLES, 'group.txt')}
    enemies = {r[2]: r for r in rows(TABLES, 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES, 'enemybase.txt')}
    fights, blockers, boss_ids = [], [], set()
    for actor in events['actors'].values():
        declarations = [(0, actor['script'])] if actor['type'] == 'StandEnemy' else []
        declarations += [(line, text) for line, text in events['scripts'].get(actor['script'], {}).get('lines', []) if re.match(r'\s*Encount\b', text, re.I)]
        for line, text in declarations:
            fields = re.sub(r'^\s*Encount\s+', '', text, flags=re.I).split('|')
            ids = fields[9].strip().split(',') if len(fields) > 9 else []
            if not ids or not all(i.isdecimal() for i in ids):
                blockers.append(dict(actor=actor['id'], source=actor['source'], reason='Unresolved original encounter declaration', command=text)); continue
            # The pinned server selects one alternative; see assets/references/standenemy-selection.json.
            if len(ids) > 16:
                blockers.append(dict(actor=actor['id'], source=actor['source'], reason='Original encounter list exceeds the authenticated sixteen-entry limit.', command=text)); continue
            for ident in ids:
                boss_ids.add(ident)
                fights.append(dict(actor=actor['id'], source=actor['source'], generated_by=None, encounter=int(ident), command=text, script=actor['script'], line=line))
    pending = sorted(boss_ids | {ident for ident, pool in source_pools.items() if int(pool[3]) in maps})
    pools, groups, zones = {}, {}, []
    pets = json.loads((ROOT / 'assets/characters/crossgate/guard_pets/motions.json').read_text())['variants']
    pets_by_id = {int(v['id']): (i, v) for i, v in enumerate(pets)}
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_assets as cg
    catalog = cg.catalog()['entries']
    prepared = {}
    for path in sorted((ROOT / 'assets/characters/crossgate').glob('*/motions.json')):
        if path.parent.name in ['guard_pets', 'east_region']: continue
        manifest = json.loads(path.read_text())
        if not {0, 1, 3, 5, 8, 9, 10} <= set(manifest.get('actions', [])): continue
        sidecar = json.loads(path.with_name('species.json').read_text()) if path.with_name('species.json').exists() else []
        for skin, v in enumerate(manifest.get('variants', [])):
            if not isinstance(v, dict) or 'id' not in v or 'standing_height' not in v: continue
            ident = int(v['id']); match = next((s for s in sidecar if int(s['id']) == ident), {})
            choices = sorted([r['key'] for r in catalog if int(r['id']) == ident], key=lambda key: (not (key.startswith('original:') and 2700 <= int(key.split(':')[1]) < 3000), key))
            prepared.setdefault(ident, dict(bank=path.parent.name, skin=skin, key=match.get('key', choices[0] if choices else ''), height=approved_height(path.parent.name, skin, manifest)))
    while pending:
        ident = pending.pop()
        if ident in pools: continue
        if ident not in source_pools:
            blockers.append(dict(encounter=ident, reason='Original encounter table row is absent.')); continue
        raw = source_pools[ident]; choices = []; pool_blockers = []
        for slot, gid in enumerate(raw[14:24]):
            weight = int(raw[24 + slot] or 0)
            if not gid or not weight: continue
            if gid not in source_groups:
                pool_blockers.append(dict(group=gid, weight=weight, reason='Original encounter references a group absent from the pinned group table.'))
                continue
            key = 'explore_frontier:' + gid
            if key not in groups:
                original = source_groups[gid]; members, details, identities, missing = [], [], [], []
                for j, eid in enumerate(original[5:15]):
                    member_weight = int(original[15 + j] or 0)
                    if eid in ['', '0'] or not member_weight and original[25 + j] != '1': continue
                    if eid not in enemies or enemies[eid][3] not in bases:
                        missing.append(dict(enemy=eid, base=enemies[eid][3] if eid in enemies else None, reason='Original required enemy/base row is absent from the pinned tables.')); continue
                    enemy = enemies[eid]; source = bases[enemy[3]]; appearance = int(source[30])
                    if appearance not in indices:
                        row = dict(id=appearance, name=source[0])
                        if appearance in pets_by_id:
                            skin, pet = pets_by_id[appearance]; row.update(bank='companion', skin=skin, key=pet['key'])
                        elif appearance in prepared: row.update(prepared[appearance])
                        else: row.update(bank='unavailable', skin=-1, key='')
                        indices[appearance] = len(species); species.append(row)
                    index = indices[appearance]
                    members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                    details.append(dict(species=index, enemy=eid, raw_enemy=enemy, raw_base=source))
                    identities.append(dict(enemy_id=eid, name=source[0], count=list(map(int, enemy[6:8])), mandatory=original[25 + j] == '1'))
                groups[key] = dict(members=members, details=details, source_members=identities, raw=original, order=original[1], source_group=gid, preparation_blockers=missing)
            if groups[key].get('preparation_blockers'):
                pool_blockers.append(dict(group=gid, reason='Original required party members are incomplete.', details=groups[key]['preparation_blockers']))
            if not groups[key]['members']:
                pool_blockers.append(dict(group=gid, reason='Original group has no weighted or mandatory members.', raw=groups[key]['raw']))
            choices.append([key, weight])
        if not choices and int(raw[10]) > 0:
            pool_blockers.append(dict(reason='Original positive-size encounter has no weighted groups.'))
        if pool_blockers:
            blockers.append(dict(encounter=ident, map=int(raw[3]), reason='Original party distribution is incomplete.', details=pool_blockers))
        # Retain the original zone priority, including incomplete and no-encounter
        # zones. Never fall through to a lower-priority party or omit a member.
        pools[ident] = dict(id=int(ident), map=int(raw[3]), bounds=list(map(int, raw[4:8])), probability=list(map(int, raw[8:10])), maximum=int(raw[10]), minimum=1, priority=int(raw[11]), groups=[] if pool_blockers else choices, raw=raw, preparation_blockers=pool_blockers, next_encounter=int(raw[12] or 0), next_probability=int(raw[13] or 0), source_party_contract=True)
        if int(raw[3]) in maps: zones.append(pools[ident])
        if int(raw[12] or 0): pending.append(str(int(raw[12]))); boss_ids.add(str(int(raw[12])))
    additions = species[len(base['species']):]
    if pack:
        old = json.loads((BANK / 'motions.json').read_text())
        existing_ids = {int(v['id']) for v in old['variants']}
        needed = [s for s in additions if s['bank'] != 'companion' and s['id'] not in existing_ids]
        capacity = int(re.search(r'const CAVE_SKINS=(\d+)', (ROOT / 'scripts/forest/crowd/pet_dimensions.gd').read_text())[1])
        candidates=pack_new_species(dict(species=[s for s in needed if s['bank']=='unavailable']),prepare=False)
        required=sum(s['bank']!='unavailable'for s in needed)+len(candidates)
        assert len(old['variants']) + required <= capacity, 'Prepare sufficient shared native capacity before appending source kits'
        if needed:
            baseline = REPORT / ('Before append-' + str(len(old['variants'])))
            baseline.mkdir(parents=True, exist_ok=True)
            for name in ['motions.json', 'frames.bin', 'palette.png', 'species.json']:
                if (baseline / name).exists():
                    assert (baseline / name).read_bytes() == (BANK / name).read_bytes(), 'Retain the pre-append source proof; current bank differs'
                else:
                    shutil.copyfile(BANK / name, baseline / name)
            for bank in sorted({s['bank'] for s in needed} - {'unavailable'}):
                selected = [s for s in needed if s['bank'] == bank]
                records = [dict(id=s['id'], name=s['name'], key=s['key'], height=s['height'], prepared_from=dict(bank=bank, skin=s['skin'])) for s in selected]
                append_native_bank(BANK, ROOT / 'assets/characters/crossgate' / bank, [s['skin'] for s in selected], records)
            missing = [s for s in needed if s['bank'] == 'unavailable']
            if missing:
                path = ROOT / 'assets/maps/falan/east_region/native-preparation-blockers.json'; previous = json.loads(path.read_text())
                pack_new_species(dict(species=missing)); current = json.loads(path.read_text())
                path.write_text(json.dumps(previous + [b for b in current if b['id'] not in {r['id'] for r in previous}], ensure_ascii=False, indent=2) + '\n')
            native_page_index(BANK)
            current = json.loads((BANK / 'motions.json').read_text())
            for key in ['variants', 'timelines', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources']: assert current[key][:len(old[key])] == old[key], key
    native = json.loads((BANK / 'species.json').read_text())
    for row in additions:
        match = next(((i, s) for i, s in enumerate(native) if int(s['id']) == row['id']), None)
        if match:
            skin, source = match; row.update(bank='east_region', skin=skin, key=source['key'], height=source['height'])
    result = dict(schema=1, species=species, groups=groups, zones=zones, bosses={i: p for i, p in pools.items() if i in boss_ids}, scripted_battles=fights, blockers=blockers, source_hashes={name: sha(TABLES / name) for name in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']})
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / 'encounters-staged.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    if activate:
        assert pack, 'Prepare and verify source/native contracts before activation'
        assert all(s['bank'] in ['east_region', 'companion', 'unavailable'] for s in species)
        (OUT / 'frontier_encounters.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('EXPLORE_FRONTIER_ENCOUNTERS', len(groups), 'groups;', len(zones), 'zones;', len(result['bosses']), 'boss pools;', len(additions), 'new species;', len(blockers), 'source contract gaps; activated=', activate)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true'); parser.add_argument('--activate', action='store_true')
    args = parser.parse_args(); prepare(args.prepare, args.activate)
