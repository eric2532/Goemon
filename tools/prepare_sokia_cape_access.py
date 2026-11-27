"""Prepare pinned Cape prerequisite layouts through existing original-map contracts."""
import argparse
import base64
import json
import sys
import zlib
from pathlib import Path

from PIL import Image
import prepare_sokia_fixed_maps as fixed
import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape access'
OUT = ROOT / 'assets/maps/falan/sokia/cape/access'
PREFIX = '../falan/sokia/cape/access/'
MAPS = {15517: '森林小路', 15520: '阿魯巴斯的研究所', 15524: '峽之洞窟',
        15528: '牛之殿堂', 15529: '牛之殿堂'}
ACTORS = {str(number) for number in range(5225, 5238)} | {'5239', '5240', '5241', '5242', '6114', '6115', '6116', '6117', '6925'}
CATALOGS = ['assets/maps/original_crossgate/catalog.json', 'assets/maps/falan/sokia/fixed/catalog.json',
            'assets/maps/original_crossgate/university/catalog.json', 'assets/maps/original_crossgate/elsa/catalog.json',
            'assets/maps/original_crossgate/east/catalog.json', 'assets/maps/original_crossgate/sokia_server/catalog.json']


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    references = json.loads((ROOT / 'assets/references/crossgate_sokia/maps/cape-access-references.json').read_text())
    proofs = {int(Path(r['file']).name.split('_')[0]): r for r in references}
    old_maps = fixed.MAPS
    try:
        fixed.MAPS = MAPS
        source_catalog, _ = fixed.prepare()
    finally:
        fixed.MAPS = old_maps
    shared, owners, protected = {}, {}, {}
    for name in CATALOGS:
        path = ROOT / name
        protected[name] = recovery.digest(path.read_bytes())
        for serial, graphic in json.loads(path.read_text())['graphics'].items():
            if serial not in shared:
                shared[serial] = graphic
                owners[serial] = name
    lookup = lib.serial_index()
    used, evidence = set(), []
    for path, row in source_catalog['maps'].items():
        number = row['id']
        client = zlib.decompress(base64.b64decode(row['raw']))
        proof = proofs[number]
        server_path = ROOT / 'assets/references/crossgate_sokia/maps' / proof['file']
        server = server_path.read_bytes()
        assert recovery.digest(server) == proof['sha256']
        final, completion = complete_map(client, server, number)
        assert completion['compatible'] and completion['preserved_client_variations'] == 0
        width, height, ground, objects, flags = lib.parse_map(final)
        _, _, old_ground, old_objects, old_flags = lib.parse_map(client)
        before = navigation_grid(width, height, old_ground, old_objects, lookup)
        walk = navigation_grid(width, height, ground, objects, lookup)
        bits = bytearray((width * height + 7) // 8)
        for index, opened in enumerate(walk):
            if opened:
                bits[index >> 3] |= 1 << (index & 7)
        assert old_flags == flags
        assert all(before[i] == walk[i] for i, flag in enumerate(flags) if flag & 0xc000)
        used.update(s for s in ground if s)
        used.update(s for s in objects if s >= 1000)
        for serial in {s for s in ground if s} | {s for s in objects if s >= 1000}:
            if str(serial) in row['visible_bounds']:
                continue
            graphic = lookup[serial]
            image = lib.image_from_record(graphic['pack'], graphic['row'])
            box = image.getbbox()
            if box:
                row['visible_bounds'][str(serial)] = [graphic['x'] + box[0], graphic['y'] + box[1], box[2] - box[0], box[3] - box[1]]
        row.update(group='sokia_cape_access', title=MAPS[number], raw=recovery.encode(client),
                   restored_raw=recovery.encode(final), restored_sha256=recovery.digest(final),
                   walk=recovery.encode(bits), outdoor=number == 15517,
                   source_completion=completion, layout_complete=completion['layout_complete'], layout_reference=proof,
                   source_floor_object_sha256=recovery.digest(final[20:20 + width * height * 4]),
                   source_background_serials=[100], sokia_visual_only=True,
                   gate_status='Review-only layout preparation; original conditions are not activated by this catalog.')
        evidence.append(dict(source=number, source_path=path, client_sha256=recovery.digest(client),
                             hybrid_sha256=recovery.digest(final), reference=proof, **completion,
                             old_open_lost=sum(a and not b for a, b in zip(before, walk)),
                             recorded_walk_changes=0, flags_preserved=True,
                             runtime_status='staged_only_no_live_layout_or_event_hook'))
    for serial in sorted(used):
        if str(serial) not in shared:
            continue
        record = lookup[serial]
        image = lib.image_from_record(record['pack'], record['row'])
        assert recovery.digest(image.tobytes()) == shared[str(serial)]['rgba_sha256'], serial
    furniture = {**fixed.KIND, **fixed.PALACE_KIND, **fixed.CELLAR_KIND, **fixed.CIVIC_KIND,
                 **fixed.ARENA_KIND, **fixed.FREYJA_KIND, **fixed.KINDS}
    furniture.update({serial: 'room_wall' for serial in fixed.WALLS if serial >= 16000})
    novel = used - set(map(int, shared))
    pages, graphics, _ = recovery.pack_graphics(novel, lookup, furniture, lib)
    catalog = dict(schema=1, page_indices='local', requires=['east'], maps=source_catalog['maps'],
                   graphics=graphics, pages=[PREFIX + f'atlas-{i}.png' for i in range(len(pages))])
    surfaces = recovery.rock_surfaces(catalog, pages)
    solids = recovery.solid_pages(catalog, pages)
    catalog['surface_pages'] = [PREFIX + f'surfaces-{i}.png' for i in range(len(surfaces))]
    catalog['solid_pages'] = [PREFIX + f'solid-{i}.png' for i in range(len(solids))]
    images = {**{f'atlas-{i}.png': im for i, im in enumerate(pages)},
              **{f'solid-{i}.png': im for i, im in enumerate(solids)},
              **{f'surfaces-{i}.png': im for i, im in enumerate(surfaces)}}
    report = dict(status='staged_source_layouts_not_runtime_restored', goal_complete=False,
                  maps=evidence, new_graphics=sorted(novel),
                  reused_graphic_owners={str(s): owners[str(s)] for s in sorted(used) if str(s) in owners},
                  protected_catalog_sha256=protected,
                  limits=['Every recorded client cell and flag stays exact; server layers fill only unrecorded cells.',
                          'Pinned server/client release parity is supported by zero recorded tuple differences, not authenticated production-server execution.',
                          'Navigation derives from existing original graphic attributes and still requires native clearance and camera review.',
                          '15517/15520 belong to the distinct config300 branch; no direct shortcut is inferred.',
                          'All original event/item conditions and the raw18598 drop execution remain separate required work.'])
    actors, atlas = event_data(catalog, lookup, lib)
    images['events/npc-atlas.png'] = atlas
    return catalog, images, report, actors


def event_data(catalog, lookup, lib):
    from prepare_field_assets import navigation_grid
    from prepare_sokia_server_events import prepare as prepare_events
    from prepare_sokia_cape_dungeons import rows, TABLES
    source = json.loads(json.dumps(catalog))
    for number in [100, 300]:
        path = f'BlueCrossgate/map/0/{number}.dat'
        with lib.connection() as db:
            ident = db.execute('SELECT id FROM files WHERE path=?', (path,)).fetchone()[0]
        raw = lib.source_file(ident)[1].read_bytes()
        width, height, ground, objects, _ = lib.parse_map(raw)
        walk = navigation_grid(width, height, ground, objects, lookup)
        bits = bytearray((width * height + 7) // 8)
        for index, opened in enumerate(walk):
            if opened:
                bits[index >> 3] |= 1 << (index & 7)
        source['maps'][path] = dict(id=number, size=[width, height], raw=recovery.encode(raw),
                                  walk=recovery.encode(bits),
                                  source_floor_object_sha256=recovery.digest(raw[20:20 + width * height * 4]))
    data, atlas = prepare_events(source, ACTORS)
    assert set(data['actors']) == ACTORS
    for actor in data['actors'].values():
        if actor['source'] in [100, 300]:
            actor.update(area='source_outdoor', floor=0)
        actor['dialogue_owner'] = 'sokia_cape_access'
        if 'quest_action' in actor:
            actor['quest_action'] = 'sokia_cape:' + actor['id']
        if actor['id'] in ['5225', '5237']:
            actor['battle_owner'] = 'sokia_cape'
    encounters = {r[0]: r for r in rows(TABLES, 'encount.txt')}
    groups = {r[2]: r for r in rows(TABLES, 'group.txt')}
    enemies = {r[2]: r for r in rows(TABLES, 'enemy.txt')}
    bases = {r[1]: r for r in rows(TABLES, 'enemybase.txt')}
    encounter = encounters['12021']
    assert encounter[14] == '12099' and not any(int(v or 0) for v in encounter[25:34])
    group = groups['12099']; enemy = enemies['12117']; native = bases[enemy[3]]
    assert group[5] == '12117' and group[25] == '1' and int(native[30]) == 101010
    assert not any(int(value or 0) for value in group[6:15] + group[16:25] + group[26:35]), 'Retain every source member if this pinned party changes'
    bank_path = ROOT / 'assets/characters/crossgate/guard_pets/motions.json'
    bear = json.loads(bank_path.read_text())['variants'][135]
    assert bear['id'] == 101010 and bear['key'] == 'original:2807' and len(bear['clips']) == 64
    existing = json.loads((ROOT / 'assets/maps/falan/sokia/cape/encounters.json').read_text())['battles']['species']
    detail = dict(species=len(existing), name=native[0], enemy='12117',
                  level=list(map(int, enemy[4:6])), count=list(map(int, enemy[6:8])),
                  weight=int(group[15]), must_appear=True, raw_enemy=enemy, raw_base=native)
    data['battle_additions'] = dict(species_offset=len(existing), species=[dict(id=101010, name=native[0], key='original:2807', bank='companion', skin=135)],
                                    groups={'12099': dict(details=[detail], raw=group, order=group[1], required_item=int(group[3]), forbidden_item=int(group[4]))},
                                    bosses={'12021': dict(id=12021, groups=[['12099', int(encounter[24])]], next_encounter=int(encounter[12] or 0), next_probability=int(encounter[13] or 0), raw=encounter)})
    data['bear_bank_provenance'] = dict(path=str(bank_path.relative_to(ROOT)), sha256=recovery.digest(bank_path.read_bytes()), skin=135, key='original:2807', appearance=101010)
    data['source_item_drop'] = dict(enemy=12117, item=int(enemy[13]), raw_rate=int(enemy[23]),
                                    raw_items=enemy[13:23], raw_rates=enemy[23:33],
                                    execution_verified=False, production_grant_enabled=False,
                                    qualification='No authenticated original denominator/selection rule recovered; raw100 is not interpreted as100percent and no prerequisite grant is invented.')
    assert data['source_item_drop']['item'] == 18598 and data['source_item_drop']['raw_rate'] == 100
    data['existing_coast_actor_ids'] = ['5239', '6117']
    data['limitations'] += [
        'Staged source data only; no live NPC, gate, native dispatch or item-drop hook is activated.',
        'EV_rk_ushi06 line19 is the original malformed window_21069,yes,no; full raw program remains guarded rather than normalized without command evidence.',
        'Item18598 to18599 exchange is source-confirmed, but natural18598 acquisition remains unverified; held-item test contexts must be labeled fixture-only.',
        'EV_rk_ushi08 changepal6,180 remains a visual command adaptation; original palette-duration execution is unverified.',
        '15517/15520 use the separate config300 route. No direct15517to15520 shortcut or unconditional guard is added.',
    ]
    return data, atlas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=OUT)
    args = parser.parse_args()
    catalog, images, report, events = prepare()
    values = {'catalog.json': catalog, 'layout-provenance.json': report, 'events/data.json': events}
    if args.check:
        for name, value in values.items():
            assert json.loads((args.output / name).read_text()) == value, name
        for name, image in images.items():
            actual = Image.open(args.output / name)
            assert actual.size == image.size and actual.tobytes() == image.tobytes(), name
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, value in values.items():
            (args.output / name).parent.mkdir(parents=True, exist_ok=True)
            (args.output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
        for name, image in images.items():
            (args.output / name).parent.mkdir(parents=True, exist_ok=True)
            image.save(args.output / name)
    print('SOKIA_CAPE_ACCESS_CHECK' if args.check else 'SOKIA_CAPE_ACCESS_PREPARED', len(catalog['maps']), 'maps;', len(catalog['graphics']), 'new source graphics;', len(events['actors']), 'actors; normal map dispatch remains gated')


if __name__ == '__main__':
    main()
