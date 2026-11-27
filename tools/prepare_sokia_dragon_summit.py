"""Stage complete Dragon/Summit fixed sources and every declared encounter pool."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import active_raw, complete_map, reference_map, solid_pages
from prepare_east_region_population import append_native_bank, approved_height, battle_ids, compile_script, native_page_index
from prepare_sokia_server_events import prepare as prepare_npcs
from prepare_sokia_server_maps import ROOT, SOURCE, CATALOGS, KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND, KINDS, WALLS
from prepare_snow_region_population import SOURCE as TABLES, rows

IDS = set(range(15568, 15591))
REUSED_MAP = 15577
CONFIGS = {108, 109, 110, 111, 309}
OUTDOORS = {15568, 15571, 15572, 15573, 15581, 15582, 15588}
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit'
OUT = REPORT / 'Staged'
SHARED = CATALOGS + [f'assets/maps/original_crossgate/{name}/catalog.json'
    for name in ['sokia_wind_tower', 'sokia_desert_temple', 'sokia_server']]


def stage_native_bank(output):
    output = output.resolve()
    base = REPORT / 'Native bank/Previous cache'
    if not base.exists():
        base = ROOT / 'assets/characters/crossgate/east_region'
    source = ROOT / 'assets/characters/crossgate/sokia_region'
    old = json.loads((base / 'motions.json').read_text())
    record = json.loads((source / 'species.json').read_text())[16]
    assert record['id'] == 100452 and all(v['id'] != 100452 for v in old['variants'])
    output.mkdir(parents=True, exist_ok=True)
    for name in ['motions.json', 'frames.bin', 'palette.png', 'species.json']:
        shutil.copyfile(base / name, output / name)
    addition = dict(record, prepared_from=dict(bank='sokia_region', skin=16))
    append_native_bank(output, source, [16], [addition]); native_page_index(output)
    new = json.loads((output / 'motions.json').read_text())
    for key in ['variants', 'timelines', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources']:
        assert new[key][:len(old[key])] == old[key], key
    new.setdefault('reused_source_hashes', {})['sokia_region'] = {n: recovery.digest((source / n).read_bytes())
        for n in ['motions.json', 'frames.bin', 'palette.png']}
    (output / 'motions.json').write_text(json.dumps(new, separators=(',', ':')) + '\n')
    print('DRAGON_NATIVE_STAGED', len(old['variants']), 'preserved;', len(new['variants']), 'total; original-frame/native/rendered review required.')


def encounters(graph):
    baseline = json.loads((ROOT / 'assets/maps/original_crossgate/sokia_desert_temple/encounters.json').read_text())
    species = list(baseline['species'])
    indices = {int(s['id']): i for i, s in enumerate(species)}
    for appearance, bank, skin, name in [(100452, 'sokia_region', 16, '杰特'), (101511, 'companion', 326, '风精希鲁夫')]:
        assert appearance not in indices
        folder = 'guard_pets' if bank == 'companion' else bank
        manifest = json.loads((ROOT / f'assets/characters/crossgate/{folder}/motions.json').read_text())
        variant = manifest['variants'][skin]
        assert int(variant['id']) == appearance
        height = variant['body'][4] if bank == 'companion' else approved_height(bank, skin, manifest)
        indices[appearance] = len(species)
        key = variant.get('key') or json.loads((ROOT / f'assets/characters/crossgate/{folder}/species.json').read_text())[skin]['key']
        native = json.loads((ROOT / 'assets/characters/crossgate/east_region/motions.json').read_text())
        prepared = next((i for i, v in enumerate(native['variants']) if int(v['id']) == appearance), None)
        if prepared is not None:
            bank = 'east_region'; skin = prepared
        species.append(dict(id=appearance, bank=bank, skin=skin, name=name, height=height, key=key))
    configurations = [c for c in graph['generated_dungeon_configs'] if c['config'] in CONFIGS]
    assert len(configurations) == 5 and sum(int(c['raw'][39]) for c in configurations) == 72
    fights = [f for f in graph['fight_triggers'] if f['source_map'] in IDS]
    scripted = {int(e['encounter_id']) for f in fights for e in f['resolved_encounters']}
    generated = {int(c['raw'][49]) for c in configurations}
    enemies = {r[2]: r for r in rows('enemy.txt')}
    bases = {r[1]: r for r in rows('enemybase.txt')}
    originals = {r[2]: r for r in rows('group.txt')}
    pools = {}; groups = {}; zones = []
    for raw in rows('encount.txt'):
        ident = int(raw[0])
        if int(raw[3]) not in IDS and ident not in scripted | generated:
            continue
        choices = []
        for slot, gid in enumerate(raw[14:24]):
            weight = int(raw[24 + slot] or 0)
            if not gid or not weight:
                continue
            original = originals[gid]; members = []; identities = []; details = []
            for j, eid in enumerate(original[5:15]):
                member_weight = int(original[15 + j] or 0)
                if eid in ['', '0'] or not member_weight:
                    continue
                enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
                members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=original[25 + j] == '1'))
                details.append(dict(species=index, enemy=eid, name=base[0], raw_enemy=enemy, raw_base=base))
            key = 'dragon:' + gid
            record = dict(members=members, raw=original, source_group=gid, order=original[1], source_members=identities, details=details)
            if key in groups:
                assert groups[key] == record
            groups[key] = record
            choices.append([key, weight])
        record = dict(id=ident, map=int(raw[3]), bounds=list(map(int, raw[4:8])), probability=list(map(int, raw[8:10])),
            maximum=int(raw[10]), minimum=1, priority=int(raw[11]), groups=choices, raw=raw, source_party_contract=True,
            next_encounter=int(raw[12] or 0), next_probability=int(raw[13] or 0))
        pools[str(ident)] = record
        if int(raw[3]) in IDS:
            zones.append(record)
    assert set(pools) == {'2006', '2007', '10029', '10030', '11011', '14014', '15007'} and len(groups) == 8
    branches = []
    for config in configurations:
        raw = config['raw']; pool = pools[raw[49]].copy(); pool['levels'] = list(map(int, raw[50:52]))
        branches.append(dict(config=config['config'], name=config['name'], raw=raw,
            floors=list(map(int, raw[39:41])), source_template=int(raw[7]), size=list(map(int, raw[41:45])),
            entry_map=int(raw[9]), entry_rect=list(map(int, raw[10:14])), end=list(map(int, raw[15:18])),
            pool=pool, runtime_registered=False,
            qualification='Required original branch; generated layouts, entrance execution and per-floor level curve remain unverified.'))
    used = sorted({m[0] for g in groups.values() for m in g['members']})
    contracts = []
    for index in used:
        s = species[index]; bank = 'guard_pets' if s['bank'] == 'companion' else s['bank']
        path = ROOT / f'assets/characters/crossgate/{bank}/motions.json'
        contracts.append(dict(index=index, appearance=s['id'], bank=s['bank'], skin=s['skin'],
            motions_sha256=recovery.digest(path.read_bytes()), frames_sha256=recovery.digest(path.with_name('frames.bin').read_bytes()),
            native_available=s['bank'] in ['companion', 'east_region'],
            qualification='Source cache ID/hash only; original frame, native, scale, motion and rendered review remain separate.'))
    assert len(contracts) == 12
    return dict(schema=1, species=species, reused_species=[dict(index=i, **species[i]) for i in used], zones=zones,
        pools=pools, bosses={str(k): pools[str(k)] for k in scripted}, groups=groups, generated_branches=branches, scripted_fights=fights, art_contracts=contracts,
        source_hashes={n: recovery.digest((TABLES / n).read_bytes()) for n in ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']},
        limits=['Staged only; no travel, encounter or event activation.',
            'All12appearances retain native contracts; complete rendered source-map/motion and original quest review remain separate.',
            'Original probability/count distributions, formation, AI, follow-on execution and scripted predicates remain unverified.'])


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    lookup = lib.serial_index(); shared = {}; owners = {}; protected = {}
    for name in SHARED:
        path = ROOT / name; catalog = json.loads(path.read_text()); protected[name] = recovery.digest(path.read_bytes())
        for key, graphic in catalog['graphics'].items():
            if key not in shared:
                shared[key] = graphic; owners[key] = name
    refs = json.loads((SOURCE / 'dragon-summit-references.json').read_text())
    graph = json.loads((REPORT.parent / 'Source events/source-graph.json').read_text())
    existing = json.loads((ROOT / SHARED[-1]).read_text())['maps']
    with lib.connection() as db:
        files = {r['path']: r['id'] for r in db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    maps = {}; evidence = []; variations = []; used = set(); reused = []
    for ref in refs:
        number = int(ref['file'].split('_')[0]); assert number in IDS
        server = (SOURCE / ref['file']).read_bytes()
        assert len(server) == ref['bytes'] and recovery.digest(server) == ref['sha256']
        assert hashlib.sha1(b'blob ' + str(len(server)).encode() + b'\0' + server).hexdigest() == ref['git_blob_sha1']
        path = f'BlueCrossgate/map/0/{number}.dat'
        if number == REUSED_MAP:
            row = existing[path]; restored = active_raw(row); raw = restored
            completion = dict(cells=row['cells'], completed=0, recorded=0, source_flags_available=False, existing_server_owner=True)
            reused.append(dict(id=number, path=path, owner=SHARED[-1], source_sha256=ref['sha256'],
                runtime_row_sha256=recovery.digest(json.dumps(row, sort_keys=True).encode()), qualification='Existing source-server map owner reused; no recorded client map/flags exist.'))
        else:
            raw = lib.source_file(files[path])[1].read_bytes(); restored, completion = complete_map(raw, server, number)
            assert completion['compatible'] and completion['layout_complete']
        w, h, ground, objects, flags = lib.parse_map(restored); _, _, values, title = reference_map(server, number); cells = w * h
        for i, (client, pinned) in enumerate(zip(ground + objects, values)):
            if client != pinned:
                variations.append(dict(map=number, layer=i // cells, cell=[i % cells % w, i % cells // w], client=client, server=pinned))
        assert restored[20 + cells * 4:] == raw[20 + cells * 4:]
        walk = navigation_grid(w, h, ground, objects, lookup); bits = bytearray((cells + 7) // 8)
        for i, opened in enumerate(walk):
            if opened:
                bits[i >> 3] |= 1 << (i & 7)
        if number != REUSED_MAP:
            used.update({s for s in ground if s} | {s for s in objects if s >= 1000})
            maps[path] = dict(group='sokia_dragon_summit', id=number, title=title, size=[w, h], outdoor=number in OUTDOORS,
                raw=recovery.encode(raw), sha256=recovery.digest(raw), restored_raw=recovery.encode(restored), restored_sha256=recovery.digest(restored),
                bytes=len(raw), walk=recovery.encode(bits), recorded=completion['recorded'], cells=cells, restored_cells=completion['completed'], layout_complete=True,
                warp_cells=[[i % w, i // w] for i, v in enumerate(flags) if v & 2], layout_reference=ref,
                source_floor_object_sha256=recovery.digest(server[44:]), source_flags_available=True, sokia_visual_only=True,
                fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map'] == number],
                gate_status='Staged only; exact source gates, native fights, complete scenery and72required generated floors remain unfinished.')
        evidence.append(dict(id=number, title=title, size=[w, h], completion=completion, source=ref, client_flags_preserved=number != REUSED_MAP, decoder_open_cells=sum(walk)))
    assert {r['id'] for r in maps.values()} == IDS - {REUSED_MAP} and len(reused) == 1
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({n: 'room_wall' for n in WALLS if n >= 16000})
    novel = used - set(map(int, shared)); pixels = {}
    for serial in sorted(used):
        native = lookup[serial]; image = lib.image_from_record(native['pack'], native['row']); digest = recovery.digest(image.tobytes())
        if str(serial) in shared:
            g = shared[str(serial)]
            assert g['rgba_sha256'] == digest and g['origin'] == [native['x'], native['y']] and g['footprint'] == [native['east'], native['south']], serial
        pixels[str(serial)] = dict(rgba_sha256=digest, pack=native['pack'], row=native['row'])
    pages, graphics, _ = recovery.pack_graphics(novel, lookup, furniture, lib)
    surfaces = recovery.rock_surfaces(dict(graphics=graphics), pages); solids = solid_pages(graphics, pages)
    catalog = dict(schema=1, page_indices='local', surface_indices='local', maps=maps, graphics=graphics,
        requires=['east', 'sokia_wind_tower', 'sokia_desert_temple', 'sokia_server'],
        pages=[f'sokia_dragon_summit/atlas-{i}.png' for i in range(len(pages))],
        surface_pages=[f'sokia_dragon_summit/surfaces-{i}.png' for i in range(len(surfaces))],
        solid_pages=[f'sokia_dragon_summit/solid-{i}.png' for i in range(len(solids))])
    actor_rows = [r for r in rows('npc.txt') if len(r) == 25 and r[8].isdigit() and int(r[8]) in IDS - {REUSED_MAP}
        and r[6] == '1' and r[0] not in ['Warp', 'HouseWarp2'] and int(r[3]) < 300000]
    npcs, npc_atlas = prepare_npcs(catalog, {r[3] for r in actor_rows if int(r[20]) > 1})
    npcs['invisible_actor_ids'] = []
    references = {r['file']: r for r in json.loads((ROOT / 'assets/references/crossgate_sokia/events/references.json').read_text())}
    messages = {r[0]: r[1].replace('\\n', '\n') for r in rows('msg.txt') if len(r) > 1}
    for raw in actor_rows:
        if int(raw[20]) > 1:
            continue
        name = raw[24]; payload = (ROOT / 'assets/references/crossgate_sokia/events' / name).read_bytes()
        assert recovery.digest(payload) == references[name]['sha256']
        npcs['scripts'][name] = compile_script(payload); npcs['source_provenance'][name] = references[name]
        source_line = next(i for i, line in enumerate((TABLES / 'npc.txt').read_bytes().decode('gb18030').splitlines(), 1) if line.split('\t') == raw)
        npcs['actors'][raw[3]] = dict(id=raw[3], source=int(raw[8]), type=raw[0], name=raw[1], source_line=source_line,
            cell=list(map(int, raw[9:11])), graphic=int(raw[20]), direction=int(raw[19]) % 8, script=name, raw=raw,
            invisible=True, generated_by=None, dialogue_owner='sokia_server', token=f'{raw[20]}:{int(raw[19]) % 8}',
            quest_action='sokia_server:' + raw[3], native_enemy=False, messages=[],
            qualification='Original invisible Event uses the existing manual F anchor; graphic0does not establish an automatic trigger. No visible piano is invented.')
        npcs['invisible_actor_ids'].append(raw[3])
    for actor in npcs['actors'].values():
        actor['generated_by'] = None
    npcs['scripted_battles'] = [b for b in battle_ids(list(npcs['actors'].values()), npcs['scripts']) if b['source'] in IDS]
    # Invisible event windows must resolve through the same original message table.
    import re
    for script in npcs['scripts'].values():
        for _, command in script['lines']:
            for ident in re.findall(r'\b(?:EndWindow|Window)\s+(\d+)', command, re.I):
                npcs['messages'][ident] = messages[ident]
    npcs['atlas_path'] = 'res://assets/maps/original_crossgate/sokia_dragon_summit/events/npc-atlas.png'
    roster = encounters(graph)
    proof = dict(goal_complete=False, runtime_registration_verified=False,
        runtime_registration_evidence='Source preparation alone does not prove registration; inspect Dragon Summit/runtime-map-contracts.json.',
        source_scope=sorted(IDS), maps=evidence, reused_maps=reused,
        source_graphics=pixels, reused_graphics={str(s): owners[str(s)] for s in sorted(used - novel)}, new_graphics=len(novel),
        original_graphics_repacked=0, protected_catalog_sha256=protected, recorded_client_variations=variations,
        fixed_ports=[r for r in graph['fixed_warps'] if r['source_map'] in IDS],
        boundary_ports=[r for r in graph['fixed_warps'] if (r['source_map'] in IDS) != (r['target_map'] in IDS)],
        event_warps=[r for r in graph['event_warps'] if r['source_map'] in IDS or r.get('target_map') in IDS],
        missing_fixed_source_files=[], required_missing_runtime_maps=roster['generated_branches'],
        missing_native_appearances=[r for r in roster['art_contracts'] if not r['native_available']],
        missing_original_enemy_art=[], remaining=['Native source-map contacts, pooled reuse and rendered evidence remain separate from source preparation.',
            'Complete fixed gameplay-camera/source-composite scenery and motion review.',
            'All source NPC gates, original prerequisites and scripted victory travel.',
            '72generated floors, their original placement/level curve, and original probability/count/AI semantics.',
            'Preserved client/server markers and overall warp-table/release parity remain qualified.'])
    images = {**{f'atlas-{i}.png': im for i, im in enumerate(pages)}, **{f'surfaces-{i}.png': im for i, im in enumerate(surfaces)},
        **{f'solid-{i}.png': im for i, im in enumerate(solids)}, 'events/npc-atlas.png': npc_atlas}
    return catalog, roster, npcs, images, proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUT); parser.add_argument('--check', action='store_true')
    parser.add_argument('--stage-native-bank', type=Path); args = parser.parse_args()
    if args.stage_native_bank:
        assert not args.check
        stage_native_bank(args.stage_native_bank); return
    catalog, roster, npcs, images, proof = prepare()
    for name, data in [('catalog.json', catalog), ('encounters.json', roster), ('events/data.json', npcs), ('source-preservation.json', proof)]:
        path = args.output / name; text = json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n'
        if args.check:
            assert path.read_text() == text, name
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)
    from PIL import Image
    for name, image in images.items():
        path = args.output / name
        if args.check:
            with Image.open(path) as actual:
                assert actual.mode == image.mode and actual.size == image.size and actual.tobytes() == image.tobytes(), name
        else:
            path.parent.mkdir(parents=True, exist_ok=True); image.save(path)
    print('DRAGON_SUMMIT_SOURCE', len(catalog['maps']), 'new fixed maps;1existing owner;', sum(m['restored_cells'] for m in catalog['maps'].values()),
        'recovered cells;', len(proof['source_graphics']), 'graphics;', len(roster['groups']), 'groups;', len(npcs['actors']) - len(npcs['invisible_actor_ids']), 'visible actors;',
        len(npcs['invisible_actor_ids']), 'invisible manual anchors;72generated floors remain required. Review-only source preparation, not playability certification.')


if __name__ == '__main__':
    main()
