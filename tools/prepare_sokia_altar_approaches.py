"""Stage the complete altar/inquiry branch; shared runtime integration is held."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import active_raw, complete_map, reference_map, solid_pages
from prepare_east_region_population import compile_script
from prepare_sokia_server_events import prepare as prepare_npcs
from prepare_sokia_server_maps import ROOT, SOURCE, CATALOGS, KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND, KINDS, WALLS
from prepare_snow_region_population import SOURCE as TABLES, rows

IDS = set(range(15548, 15564))
REUSED = {15549, 15556, 15560, 15562}
CONFIGS = set(range(408, 427))
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Altar Approaches'
OUT = REPORT / 'Staged'
SERVER = 'assets/maps/original_crossgate/sokia_server/catalog.json'
SHARED = CATALOGS + [f'assets/maps/original_crossgate/{n}/catalog.json' for n in
    ['sokia_wind_tower', 'sokia_desert_temple', 'sokia_server', 'sokia_dragon_summit']]
MARKER_EXCEPTIONS = {
    15553: {(12, 9, 13997), (14, 9, 13997), (10, 18, 13996), (13, 18, 13996), (16, 18, 13996)},
    15557: {(13, 9, 13997), (10, 18, 13996), (16, 18, 13996)},
    15559: {(12, 9, 13997), (14, 9, 13997), (10, 18, 13996), (16, 18, 13996)},
}


def configs():
    payload = ROOT / 'assets/references/crossgate_sokia/events/dungeonconf.txt'
    return {int(r[3]): r for line in payload.read_bytes().decode('gb18030').splitlines()
        if not line.startswith('#') and len(r := line.split('\t')) > 100 and r[3].isdigit() and int(r[3]) in CONFIGS}


def marker_sources(configurations):
    result = {}
    for ident, r in configurations.items():
        for role, mid, xs, ys, xe, ye, graphic, field in [
            ('entry', *map(int, r[9:14]), int(r[30]), 30),
            ('terminal', *map(int, r[15:20]), int(r[35]), 35)]:
            for y in range(ys, ye + 1):
                for x in range(xs, xe + 1):
                    result.setdefault((mid, x, y, graphic), []).append(dict(config=ident, role=role, graphic_field=field,
                        qualification='Config coordinate and paired warp graphic corroboration; original generator execution is not established.'))
    return result


def restore(raw, server, ident, markers):
    restored, proof = complete_map(raw, server, ident)
    if not proof['compatible']:
        # These rooms already have complete planes. Only the explicitly enumerated,
        # config-corroborated client stair objects differ; no bytes are rewritten.
        assert ident in MARKER_EXCEPTIONS
        import struct
        w, h, expected, _ = reference_map(server, ident); cells = w * h
        planes = struct.unpack_from(f'<{cells * 3}H', raw, 20)
        differences = [(i, a, b) for i, (a, b) in enumerate(zip(planes[:cells*2], expected)) if a != b]
        actual = set()
        for i, client, pinned in differences:
            cell = i % cells; x, y = cell % w, cell // w
            assert i >= cells and pinned == 0 and planes[2*cells+cell] & 0xc000
            assert (ident, x, y, client) in markers
            actual.add((x, y, client))
        assert actual == MARKER_EXCEPTIONS[ident] and restored == raw and proof['completed'] == 0
        proof.update(layout_complete=True, full_planes_exact_except_config_markers=True,
            qualification='Original ratio heuristic rejected recorded stair density; complete planes independently checked. No bytes copied or changed.')
    assert proof['layout_complete']
    return restored, proof


def encounters(configurations):
    baseline = json.loads((ROOT / 'assets/maps/original_crossgate/sokia_dragon_summit/encounters.json').read_text())
    species = list(baseline['species']); indices = {int(s['id']): i for i, s in enumerate(species)}
    manifest = json.loads((ROOT / 'assets/characters/crossgate/guard_pets/motions.json').read_text())
    for appearance, skin, name in [(101720, 41, '地龙蜥'), (101722, 43, '火龙蜥'), (101701, 375, '蜥蜴斗士')]:
        assert appearance not in indices
        variant = manifest['variants'][skin]
        assert int(variant['id']) == appearance
        indices[appearance] = len(species)
        species.append(dict(id=appearance, bank='companion', skin=skin, name=name,
            height=1.0, key=variant['key']))
    enemies = {r[2]: r for r in rows('enemy.txt')}; bases = {r[1]: r for r in rows('enemybase.txt')}
    source_groups = {r[2]: r for r in rows('group.txt')}; groups = {}; pools = {}
    selected = {int(r[49]) for r in configurations.values()}
    fixed = [r for r in rows('encount.txt') if int(r[3]) in IDS]
    assert not fixed, 'Do not silently add generated monsters to fixed safe rooms.'
    for r in rows('encount.txt'):
        ident = int(r[0])
        if ident not in selected:
            continue
        choices = []
        for slot, gid in enumerate(r[14:24]):
            weight = int(r[24+slot] or 0)
            if not gid or not weight:
                continue
            g = source_groups[gid]; members = []; identities = []; details = []
            for j, eid in enumerate(g[5:15]):
                member_weight = int(g[15+j] or 0)
                if eid in ['', '0'] or not member_weight:
                    continue
                enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
                members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=g[25+j] == '1'))
                details.append(dict(species=index, enemy=eid, name=base[0], raw_enemy=enemy, raw_base=base))
            key = 'altar:' + gid
            group = dict(members=members, raw=g, source_group=gid, order=g[1], source_members=identities, details=details)
            assert key not in groups or groups[key] == group
            groups[key] = group; choices.append([key, weight])
        pools[str(ident)] = dict(id=ident, map=int(r[3]), bounds=list(map(int, r[4:8])),
            probability=list(map(int, r[8:10])), maximum=int(r[10]), minimum=1, priority=int(r[11]),
            groups=choices, raw=r, source_party_contract=True, next_encounter=int(r[12] or 0), next_probability=int(r[13] or 0))
    assert set(pools) == {'16007', '16008', '16009'} and len(groups) == 1
    branches = []; floors = []
    for config, r in sorted(configurations.items()):
        pool = dict(pools[r[49]], levels=list(map(int, r[50:52])))
        assert r[39:41] == ['9', '9']
        branches.append(dict(config=config, name=r[0], raw=r, floors=list(map(int, r[39:41])),
            source_template=int(r[7]), size=list(map(int, r[41:45])), entry_map=int(r[9]), entry_rect=list(map(int, r[10:14])),
            end=list(map(int, r[15:18])), end_rect=list(map(int, r[16:20])), source_warp_graphics=list(map(int, r[30:38])),
            pool=pool, runtime_registered=False,
            qualification='Required source branch. Original random layout, per-floor level curve, entrance and follow-on execution remain unverified.'))
        for number in range(1, 10):
            floors.append(dict(config=config, number=number, encounter=pool['id'], groups=pool['groups'],
                source_level_interval=pool['levels'], next_encounter=pool['next_encounter'], next_probability=pool['next_probability'],
                runtime_registered=False, original_layout_verified=False, original_floor_level_curve_verified=False))
    used = sorted({m[0] for g in groups.values() for m in g['members']}); contracts = []
    bank = ROOT / 'assets/characters/crossgate/guard_pets'
    hashes = {n: recovery.digest((bank / n).read_bytes()) for n in ['motions.json', 'frames.bin']}
    for i in used:
        s = species[i]; assert s['bank'] == 'companion'
        assert int(manifest['variants'][s['skin']]['id']) == s['id']
        contracts.append(dict(index=i, appearance=s['id'], bank=s['bank'], skin=s['skin'], key=s['key'],
            motions_sha256=hashes['motions.json'], frames_sha256=hashes['frames.bin'], native_available=True,
            qualification='Existing native source cache; complete source-frame, scale, motion and rendered party review are separate.'))
    assert len(floors) == 171 and len(contracts) == 8
    return dict(schema=1, species=species, reused_species=[dict(index=i, **species[i]) for i in used], zones=[],
        pools=pools, groups=groups, bosses={}, scripted_fights=[], generated_branches=branches, generated_floors=floors,
        art_contracts=contracts, source_hashes={n: recovery.digest((TABLES / n).read_bytes()) for n in
            ['encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt']},
        limits=['Staged only; no runtime or travel activation.', 'Fixed rooms have no source ambient encounter row; preserve safety.',
            'Three source pools share group16023 but retain distinct continuation values1/30/65. Original denominator/execution remains unverified.',
            'Raw enemy levels1–1 retained separately from config intervals61–65; original per-floor curve is unverified.'])


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
    refs = json.loads((SOURCE / 'altar-approach-references.json').read_text()); configurations = configs()
    assert set(configurations) == CONFIGS
    markers = marker_sources(configurations)
    graph = json.loads((REPORT.parent / 'Source events/source-graph.json').read_text())
    existing = json.loads((ROOT / SERVER).read_text())['maps']
    with lib.connection() as db:
        files = {r['path']: r['id'] for r in db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    maps = {}; evidence = []; variations = []; used = set(); reused = []
    for ref in refs:
        number = int(ref['file'].split('_')[0]); assert number in IDS
        server = (SOURCE / ref['file']).read_bytes()
        assert len(server) == ref['bytes'] and recovery.digest(server) == ref['sha256']
        assert hashlib.sha1(b'blob ' + str(len(server)).encode() + b'\0' + server).hexdigest() == ref['git_blob_sha1']
        path = f'BlueCrossgate/map/0/{number}.dat'
        if number in REUSED:
            row = existing[path]; raw = restored = active_raw(row)
            completion = dict(cells=row['cells'], completed=0, recorded=0, source_flags_available=False, existing_server_owner=True)
            reused.append(dict(id=number, path=path, owner=SERVER, source_sha256=ref['sha256'],
                runtime_row_sha256=recovery.digest(json.dumps(row, sort_keys=True).encode())))
        else:
            raw = lib.source_file(files[path])[1].read_bytes(); restored, completion = restore(raw, server, number, markers)
        w, h, ground, objects, flags = lib.parse_map(restored); _, _, values, title = reference_map(server, number); cells = w*h
        for i, (client, pinned) in enumerate(zip(ground + objects, values)):
            if client != pinned:
                x, y = i % cells % w, i % cells // w
                assert i >= cells and pinned == 0 and (number, x, y, client) in markers, (number, i//cells, x, y, client, pinned)
                variations.append(dict(map=number, layer=1, cell=[x,y], client=client, server=pinned,
                    source_configs=markers[(number,x,y,client)]))
        assert restored[20+cells*4:] == raw[20+cells*4:]
        walk = navigation_grid(w,h,ground,objects,lookup); bits = bytearray((cells+7)//8)
        for i, opened in enumerate(walk):
            if opened: bits[i>>3] |= 1 << (i&7)
        if number not in REUSED:
            used.update({s for s in ground if s} | {s for s in objects if s >= 1000})
            maps[path] = dict(group='sokia_altar_approaches', id=number, title=title, size=[w,h], outdoor=number==15551,
                raw=recovery.encode(raw), sha256=recovery.digest(raw), restored_raw=recovery.encode(restored), restored_sha256=recovery.digest(restored),
                bytes=len(raw), walk=recovery.encode(bits), recorded=completion['recorded'], cells=cells, restored_cells=completion['completed'], layout_complete=True,
                warp_cells=[[i%w,i//w] for i,v in enumerate(flags) if v&2], layout_reference=ref,
                source_floor_object_sha256=recovery.digest(server[44:]), source_flags_available=True, sokia_visual_only=True,
                fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map']==number],
                gate_status='Staged only; shared runtime registration held. Source gates, scenery and171generated floors remain required.')
        evidence.append(dict(id=number,title=title,size=[w,h],completion=completion,source=ref,client_flags_preserved=number not in REUSED,decoder_open_cells=sum(walk)))
    assert {r['id'] for r in maps.values()} == IDS-REUSED and len(reused)==4
    furniture = {**KIND,**PALACE_KIND,**CELLAR_KIND,**CIVIC_KIND,**ARENA_KIND,**FREYJA_KIND,**KINDS}
    furniture.update({n:'room_wall' for n in WALLS if n>=16000}); novel = used-set(map(int,shared)); pixels={}
    for serial in sorted(used):
        native=lookup[serial]; image=lib.image_from_record(native['pack'],native['row']); digest=recovery.digest(image.tobytes())
        if str(serial) in shared:
            g=shared[str(serial)]
            assert g['rgba_sha256']==digest and g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']],serial
        pixels[str(serial)]=dict(rgba_sha256=digest,pack=native['pack'],row=native['row'])
    pages,graphics,_=recovery.pack_graphics(novel,lookup,furniture,lib)
    surfaces=recovery.rock_surfaces(dict(graphics=graphics),pages); solids=solid_pages(graphics,pages)
    catalog=dict(schema=1,page_indices='local',surface_indices='local',maps=maps,graphics=graphics,
        requires=['east','sokia_wind_tower','sokia_desert_temple','sokia_server','sokia_dragon_summit'],
        pages=[f'sokia_altar_approaches/atlas-{i}.png' for i in range(len(pages))],
        surface_pages=[f'sokia_altar_approaches/surfaces-{i}.png' for i in range(len(surfaces))],
        solid_pages=[f'sokia_altar_approaches/solid-{i}.png' for i in range(len(solids))])
    actors=[r for r in rows('npc.txt') if len(r)==25 and r[8].isdigit() and int(r[8]) in IDS-REUSED
        and r[6]=='1' and r[0] not in ['Warp','HouseWarp2'] and int(r[3])<300000]
    npcs,atlas=prepare_npcs(catalog,{r[3] for r in actors if int(r[20])>1}); npcs['invisible_actor_ids']=[]
    references={r['file']:r for r in json.loads((ROOT/'assets/references/crossgate_sokia/events/references.json').read_text())}
    messages={r[0]:r[1].replace('\\n','\n') for r in rows('msg.txt') if len(r)>1}
    source_lines=(TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines()
    for r in actors:
        if int(r[20])>1: continue
        name=r[24]; payload=(ROOT/'assets/references/crossgate_sokia/events'/name).read_bytes()
        assert recovery.digest(payload)==references[name]['sha256']
        npcs['scripts'][name]=compile_script(payload); npcs['source_provenance'][name]=references[name]
        npcs['actors'][r[3]]=dict(id=r[3],source=int(r[8]),type=r[0],name=r[1],source_line=source_lines.index('\t'.join(r))+1,
            cell=list(map(int,r[9:11])),graphic=int(r[20]),direction=int(r[19])%8,script=name,raw=r,invisible=True,
            generated_by=None,dialogue_owner='sokia_server',token=f'{r[20]}:{int(r[19])%8}',quest_action='sokia_server:'+r[3],
            native_enemy=False,messages=[],qualification='Original graphic1 Event anchor; retain manual F interaction. Do not invent a visible statue or infer an automatic trigger.')
        npcs['invisible_actor_ids'].append(r[3])
    for actor in npcs['actors'].values(): actor['generated_by']=None
    for script in npcs['scripts'].values():
        for _,command in script['lines']:
            for ident in re.findall(r'\b(?:EndWindow|Window)\s+(\d+)',command,re.I): npcs['messages'][ident]=messages[ident]
    npcs['atlas_path']='res://assets/maps/original_crossgate/sokia_altar_approaches/events/npc-atlas.png'
    original_events=json.loads((ROOT/'assets/maps/original_crossgate/sokia_server/events/data.json').read_text())
    reused_actors=[dict(id=a['id'],source=a['source'],owner='assets/maps/original_crossgate/sokia_server/events/data.json',
        row_sha256=recovery.digest(json.dumps(a,sort_keys=True).encode())) for a in original_events['actors'].values() if a['source'] in REUSED]
    roster=encounters(configurations)
    proof=dict(goal_complete=False,runtime_registration_verified=False,source_scope=sorted(IDS),maps=evidence,reused_maps=reused,
        source_graphics=pixels,reused_graphics={str(s):owners[str(s)] for s in sorted(used-novel)},new_graphics=len(novel),original_graphics_repacked=0,
        protected_catalog_sha256=protected,recorded_client_variations=variations,reused_actors=reused_actors,
        fixed_ports=[r for r in graph['fixed_warps'] if r['source_map'] in IDS],
        boundary_ports=[r for r in graph['fixed_warps'] if (r['source_map'] in IDS)!=(r['target_map'] in IDS)],
        event_warps=[r for r in graph['event_warps'] if r['source_map'] in IDS or r.get('target_map') in IDS],
        missing_fixed_source_files=[],required_missing_runtime_maps=roster['generated_branches'],missing_native_appearances=[],missing_original_enemy_art=[],
        source_config_sha256=recovery.digest((ROOT/'assets/references/crossgate_sokia/events/dungeonconf.txt').read_bytes()),
        remaining=['Shared runtime registration held; no new maps or encounters activated.', 'All171generated floors/layouts and original per-floor level curve remain required.',
            'Native contacts, source-frame/motion review, fixed gameplay-camera scenery, source gates and original NPC choices remain unverified.',
            'Original count/probability/formation/AI and self-follow-on rules remain unverified; raw source values preserved.'])
    images={**{f'atlas-{i}.png':im for i,im in enumerate(pages)},**{f'surfaces-{i}.png':im for i,im in enumerate(surfaces)},
        **{f'solid-{i}.png':im for i,im in enumerate(solids)},'events/npc-atlas.png':atlas}
    return catalog,roster,npcs,images,proof


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,default=OUT); parser.add_argument('--check',action='store_true')
    args=parser.parse_args(); catalog,roster,npcs,images,proof=prepare()
    for name,data in [('catalog.json',catalog),('encounters.json',roster),('events/data.json',npcs),('source-preservation.json',proof)]:
        path=args.output/name; text=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check: assert path.read_text()==text,name
        else: path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text)
    from PIL import Image
    for name,image in images.items():
        path=args.output/name
        if args.check:
            with Image.open(path) as actual: assert actual.mode==image.mode and actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else: path.parent.mkdir(parents=True,exist_ok=True); image.save(path)
    print('ALTAR_APPROACHES_SOURCE',len(catalog['maps']),'new maps;4existing owners;',sum(m['restored_cells'] for m in catalog['maps'].values()),
        'recovered cells;',len(proof['source_graphics']),'graphics;',len(npcs['actors']),'new actors;171required generated floors. Staged only.')


if __name__=='__main__':
    main()
