"""Prepare source trial/mine caves, reusing existing art and mixed native banks."""
import argparse
import json
from pathlib import Path
import sys

from PIL import Image
import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map
from prepare_sokia_server_maps import ROOT, SOURCE, CATALOGS
from prepare_sokia_server_events import prepare as prepare_npcs
from prepare_sokia_water_maps import continuous_cliffs
from prepare_snow_region_population import SOURCE as TABLES, rows

IDS = (set(range(11006, 11015)) - {11012}) | set(range(11500, 11503))
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves'
OUT = REPORT / 'Staged'


def encounters():
    east = json.loads((ROOT / 'assets/maps/falan/east_region/population.json').read_text())
    indices = {int(row['id']): i for i, row in enumerate(east['species'])}
    enemies = {r[2]: r for r in rows('enemy.txt')}; bases = {r[1]: r for r in rows('enemybase.txt')}
    source_groups = {r[2]: r for r in rows('group.txt')}; groups = {}; zones = []
    for raw in rows('encount.txt'):
        if int(raw[3]) not in IDS: continue
        choices = []
        for slot, gid in enumerate(raw[14:24]):
            weight = int(raw[24+slot] or 0)
            if not gid or not weight: continue
            source = source_groups[gid]; members = []; identities = []; details = []
            for i, eid in enumerate(source[5:15]):
                member_weight = int(source[15+i] or 0)
                if not eid or eid == '0' or not member_weight: continue
                enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
                assert east['species'][index]['bank'] in ['companion', 'east_region']
                members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=source[25+i]=='1'))
                details.append(dict(species=index, enemy=eid, name=base[0], raw_enemy=enemy, raw_base=base))
            key = 'trial:'+gid
            groups[key] = dict(members=members, raw=source, source_group=gid, order=source[1], source_members=identities, details=details)
            choices.append([key, weight])
        zones.append(dict(id=int(raw[0]), map=int(raw[3]), bounds=list(map(int, raw[4:8])),
                          probability=list(map(int, raw[8:10])), maximum=int(raw[10]), minimum=1,
                          priority=int(raw[11]), groups=choices, raw=raw, freyja_trial_source=True))
    assert len(zones) == 8 and len(groups) == 4
    appearances = {int(d['raw_base'][30]) for g in groups.values() for d in g['details']}
    assert appearances == {101250, 101332}
    used = sorted({m[0] for g in groups.values() for m in g['members']})
    art_contracts = []
    for index in used:
        species = east['species'][index]; bank = 'guard_pets' if species['bank']=='companion' else species['bank']
        path = ROOT/'assets/characters/crossgate'/bank/'motions.json'; manifest = json.loads(path.read_text())
        variant = manifest['variants'][species['skin']]; assert int(variant['id'])==int(species['id'])
        upstream = manifest.get('variant_sources', [None]*len(manifest['variants']))[species['skin']]
        key = variant.get('key', species.get('key',''))
        if upstream:
            source = ROOT/'assets/characters/crossgate'/upstream['bank']/'species.json'
            original = json.loads(source.read_text())[upstream['skin']]
            assert int(original['id'])==int(species['id']); key=original['key']
        art_contracts.append(dict(id=species['id'],index=index,bank=bank,skin=species['skin'],source_key=key,
            prepared_from=upstream,motions_sha256=recovery.digest(path.read_bytes()),
            qualification='Existing appearance/skin/source-chain evidence; new map native and rendered review remains required.'))
    return dict(schema=1, species=east['species'], reused_species=[dict(index=i, **east['species'][i]) for i in used],
                zones=zones, groups=groups, art_contracts=art_contracts,
                source_hashes={name:recovery.digest((TABLES/name).read_bytes()) for name in ['encount.txt','group.txt','enemy.txt','enemybase.txt']},
                map_assessment={str(n):dict(ambient_rows=[z['id'] for z in zones if z['map']==n],
                    qualification='No ambient rows does not establish safe/scripted semantics; source NPCs and gates remain separately required.') for n in sorted(IDS)},
                limits=['Existing shared native owner and shuffle bags; preserve source IDs, weights, ranges, member caps and flags.',
                        'Group-size/probability execution, source formation and AI remain qualified adaptations.',
                        'Names belong to source enemy/base identities. The reused101250 companion appearance also has another scripted alias; do not rename it globally.'])


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    lookup = lib.serial_index(); shared = {}; protected = {}; owners = {}
    for name in CATALOGS:
        path = ROOT/name; catalog = json.loads(path.read_text()); protected[name] = recovery.digest(path.read_bytes())
        for key, graphic in catalog['graphics'].items():
            if key not in shared: shared[key] = graphic; owners[key] = name
    graph = json.loads((REPORT.parent/'Source events/source-graph.json').read_text())
    refs = json.loads((SOURCE/'trial-cave-references.json').read_text()); maps = {}; evidence = []; used = set()
    for proof in refs:
        number = int(proof['file'].split('_')[0])
        if number == 11012: continue
        assert number in IDS
        server = (SOURCE/proof['file']).read_bytes(); assert recovery.digest(server) == proof['sha256']
        with lib.connection() as db:
            ident = db.execute('SELECT id FROM files WHERE path=?', (f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        raw = lib.source_file(ident)[1].read_bytes(); restored, completion = complete_map(raw, server, number)
        assert completion['compatible'] and completion['layout_complete'] and not completion['preserved_client_variations']
        w, h, ground, objects, flags = lib.parse_map(restored); _, _, values, title = reference_map(server, number)
        assert tuple(ground) + tuple(objects) == tuple(values)
        assert restored[20+w*h*4:] == raw[20+w*h*4:]
        serials = {s for s in ground if s} | {s for s in objects if s >= 1000}; used.update(serials)
        walk = navigation_grid(w,h,ground,objects,lookup); bits = bytearray((w*h+7)//8)
        for i, opened in enumerate(walk):
            if opened: bits[i>>3] |= 1 << (i&7)
        path = f'BlueCrossgate/map/0/{number}.dat'
        maps[path] = dict(group='freyja_trial_caves', id=number, title=title, size=[w,h], outdoor=False,
            raw=recovery.encode(raw), sha256=recovery.digest(raw), restored_raw=recovery.encode(restored), restored_sha256=recovery.digest(restored), bytes=len(raw),
            walk=recovery.encode(bits), recorded=completion['recorded'], cells=w*h, restored_cells=completion['completed'], layout_complete=True,
            warp_cells=[[i%w,i//w] for i,value in enumerate(flags) if value&2], layout_reference=proof,
            source_floor_object_sha256=recovery.digest(server[44:]), source_flags_available=True, source_background_serials=[100],
            sokia_visual_only=True, fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map']==number],
            gate_status='Review-only; original fixed doors and quest predicates require native/rendered checks. No shortcut or job grant.')
        evidence.append(dict(id=number,title=title,completion=completion,client_sha256=recovery.digest(raw),client_flags_preserved=True,
                             source=proof,decoder_open_cells=sum(walk)))
    assert len(maps)==11 and sum(r['completion']['completed'] for r in evidence)==545
    assert not used-set(map(int,shared)), 'Reuse every existing original graphic; do not repack its atlas'
    for serial in sorted(used):
        native = lookup[serial]; image = lib.image_from_record(native['pack'], native['row'])
        assert recovery.digest(image.tobytes()) == shared[str(serial)]['rgba_sha256'], serial
    pages = [Image.new('RGBA',(1024,256))]
    cliffs = continuous_cliffs(lookup, {}, pages, lib, [13432,13468], 13432)
    catalog = dict(schema=1,page_indices='local',maps=maps,graphics={},requires=['east'],
                   pages=['freyja_trial/cliff-paint.png'],surface_pages=[],solid_pages=['freyja_trial/cliff-paint.png'],source_cliffs=cliffs)
    npc_data, npc_atlas = prepare_npcs(catalog)
    assert len(npc_data['actors'])==6 and len(npc_data['excluded'])==3
    npc_data['atlas_path']='res://assets/maps/original_crossgate/freyja_trial/events/npc-atlas.png'
    proof = dict(maps=evidence,source_scope=sorted(IDS),reused_graphics={str(s):owners[str(s)] for s in sorted(used)},
                 protected_catalog_sha256=protected,original_graphics_repacked=0,source_cliff_profiles=len(cliffs['profiles']),
                 source_npcs=sorted(npc_data['actors']),excluded_later_actors=npc_data['excluded'],
                 fixed_ports=[r for r in graph['fixed_warps'] if r['source_map'] in IDS],
                 branch_boundary_ports=[r for r in graph['fixed_warps'] if (r['source_map'] in IDS)!=(r['target_map'] in IDS)],
                 geographically_unverified_layouts=[dict(id=11012,source='11012_cave_fA',title='地下道',reason='Recovered adjacent-numbered source file has no fixed/event link in the current source graph. ID adjacency is not geographic evidence; not bundled or activated by this package.')],
                 scripted_fights=[r for r in graph['fight_triggers'] if r['source_map'] in IDS],
                 activation='Staged only; no map/roster/entrance activation or visual approval.',
                 limitations=['All recorded client tuples and flags are exact;545uncached cells use pinned server layers.',
                              'Existing continuous cliff owner and original72fragment contours are reused; unseen volume/cap corners are inferred.',
                              'Later IDs remain documented, not treated as authenticated original-release NPCs.',
                              'Original quest/job/skill conditions and all source entrances still need focused verification.'])
    return catalog, encounters(), npc_data, {'cliff-paint.png':pages[0],'events/npc-atlas.png':npc_atlas}, proof


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,default=OUT); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    catalog, roster, npcs, images, proof = prepare()
    for name, data in [('catalog.json',catalog),('encounters.json',roster),('events/data.json',npcs),('source-preservation.json',proof)]:
        path=args.output/name; text=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check: assert path.read_text()==text,name
        else: path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    for name, image in images.items():
        path=args.output/name
        if args.check:
            with Image.open(path) as actual: assert actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else: path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
    print('FREYJA_TRIAL_SOURCE',len(catalog['maps']),'maps545completed',len(proof['reused_graphics']),'reused-graphics',len(catalog['source_cliffs']['profiles']),'cliff-profiles6NPCs8zones4groups; staged only,11012geography-unverified')


if __name__=='__main__': main()
