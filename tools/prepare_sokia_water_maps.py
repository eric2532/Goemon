"""Stage the connected Catfish/Water Cave branch with exact client-preserving completion."""
import argparse
import json
from pathlib import Path
import sys

from PIL import Image
import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map
from prepare_sokia_server_maps import ROOT, SOURCE, OUT as SERVER_OUT, CATALOGS
from prepare_snow_region_population import rows

IDS = {13503, 13505, 13506, 13507, 13508, 13510, 13511, 13513, 13514, 13515}
BRANCH = set(range(13500, 13516))
CLIFF_FAMILIES = [13080, 13288, 13936, 17700, 17808]
OUT = SERVER_OUT / 'water'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps/Water Cave'


def continuous_cliffs(lookup, graphics, pages, lib, cliff_families=CLIFF_FAMILIES, cap_source=17808):
    """Reuse measured source contours and existing opaque stone paint on continuous masses."""
    from prepare_abanis_cliffs import measured_profile
    from recover_falan_architecture import opaque_paint
    from recover_falan_forts import native_stone
    profiles = {}; frames = {}; originals = {}; coverage = {}; voids = []; sparse = []
    for serial in [n for first in cliff_families for n in range(first, first+36)]:
        key = str(serial); native = lookup[serial]
        original = lib.image_from_record(native['pack'], native['row']); originals[serial] = original
        graphic = dict(origin=[native['x'],native['y']], footprint=[max(1,native['east']),max(1,native['south'])],
                       rect=[0,0,*original.size], rgba_sha256=recovery.digest(original.tobytes()))
        visible = original.copy()
        visible.putdata([(r,g,b,a if max(r,g,b)>45 else 0) for r,g,b,a in original.getdata()])
        colored = sum(p[3]>=128 for p in visible.getdata()); coverage[serial] = colored/(original.width*original.height)
        frames[key] = dict(origin=graphic['origin'], footprint=graphic['footprint'], rgba_sha256=graphic['rgba_sha256'])
        if colored == 0:
            voids.append(serial); continue
        if coverage[serial] < .05: sparse.append(serial)
        profile, _ = measured_profile(visible, graphic)
        profile.update(paint_source=serial, paint_rect=graphic['rect'])
        profiles[key] = profile
    for serial in [12834,12838,12839]:
        native = lookup[serial]
        frames[str(serial)] = dict(origin=[native['x'],native['y']],footprint=[max(1,native['east']),max(1,native['south'])])
    assert len(pages) == 1
    page = pages[0]; start_y = page.height-132
    assert max((g['rect'][1]+g['rect'][3] for g in graphics.values()), default=0) < start_y
    wall_tiles = {}; paint_sources = {}
    families = [first+offset for first in cliff_families for offset in [0,12,24]]
    for index, family in enumerate(families):
        serial = max(range(family, family+12), key=coverage.get); original = originals[serial]; best = None
        width, height = original.size; stride = width+1; sums = [0]*((width+1)*(height+1))
        pixels = original.load(); assert width>=32
        patch_height=min(64,height); first_y=25 if height>89 else 0
        for y in range(height):
            line = 0
            for x in range(width):
                pixel = pixels[x,y]; line += pixel[3]>=128 and max(pixel[:3])>45
                sums[(y+1)*stride+x+1] = sums[y*stride+x+1]+line
        for y in range(first_y, max(first_y+1,original.height-patch_height)):
            for x in range(max(1, original.width-32)):
                score = sums[(y+patch_height)*stride+x+32]-sums[y*stride+x+32]-sums[(y+patch_height)*stride+x]+sums[y*stride+x]
                candidate = (score, -abs(y-original.height*.4), x, y)
                if best is None or candidate > best: best = candidate
        assert best is not None
        _, _, x, y = best; box = [x,y,x+32,y+patch_height]
        assert best[0] == sum(p[3]>=128 and max(p[:3])>45 for p in original.crop(box).getdata())
        patch = native_stone(opaque_paint(original.crop(box)), .55).resize((128,128), Image.Resampling.BICUBIC)
        pixels = patch.load()
        for axis in [0,1]:
            for edge in range(8):
                weight = .5*(1-edge/8)**2
                for along in range(128):
                    a = (edge,along) if axis == 0 else (along,edge); b = (127-edge,along) if axis == 0 else (along,127-edge)
                    left = pixels[a]; right = pixels[b]
                    pixels[a] = tuple(round(q*(1-weight)+r*weight) for q,r in zip(left,right))
                    pixels[b] = tuple(round(r*(1-weight)+q*weight) for q,r in zip(left,right))
        assert patch.getchannel('A').getextrema() == (255,255)
        rect = [2+index*132,start_y+2,128,128]; page.paste(patch, rect[:2])
        for member in range(family,family+12): wall_tiles[str(member)] = rect
        paint_sources[str(family)] = dict(source_serial=serial, source_rgba_sha256=recovery.digest(original.tobytes()), body_patch=box,
            recipe='Existing opaque_paint, native_stone(.55) and fort edge join; derived paint occupies previously unused atlas pixels, every original graphic rectangle remains exact.')
    for key, profile in profiles.items(): profile['paint_rect'] = wall_tiles[key]
    return dict(profiles=profiles, graphics=frames, void_source_fragments=voids, sparse_visible_fragments=sparse, source_serials=sorted(originals),
        texture_page=0, minimum_crown_fraction=.7, original_palette=True, tile_unseen_faces=True,
        wall_tiles=wall_tiles, wall_tile_scale=[128/3,128/6], wall_preview=[], wall_paint_sources=paint_sources,
        cap_paint={name:wall_tiles[str(cap_source)] for name in ['rock','snow','cave','undersea','freyja']},
        limitation='Existing continuous cliff owner unions original footprints and clips original walk cells. Sparse visible source fragments retain their own origins/contours/heights and use their original12-graphic family paint; only completely empty color bodies are void. Opaque rear volume/cap corners are inferred. Source pixels and every anchor remain explicit.')


def encounters():
    original = json.loads((SERVER_OUT / 'encounters.json').read_text())
    palette = {row['id']: original['species_offset'] + i for i, row in enumerate(original['species'])}
    enemies = {r[2]: r for r in rows('enemy.txt')}; bases = {r[1]: r for r in rows('enemybase.txt')}
    source_groups = {r[2]: r for r in rows('group.txt')}; zones = []; groups = {}
    for raw in rows('encount.txt'):
        if int(raw[3]) not in IDS: continue
        choices = []
        for i, gid in enumerate(raw[14:24]):
            weight = int(raw[24+i] or 0)
            if not gid or not weight: continue
            g = source_groups[gid]; assert g[3:5] == ['-1', '-1'] and not any(int(v or 0) for v in g[25:35])
            members = []; details = []
            for j, eid in enumerate(g[5:15]):
                member_weight = int(g[15+j] or 0)
                if not eid or eid == '0' or not member_weight: continue
                enemy = enemies[eid]; base = bases[enemy[3]]; appearance = int(base[30])
                members.append([palette[appearance], int(enemy[4]), int(enemy[5]), member_weight])
                details.append(dict(enemy_id=int(eid), base_id=int(enemy[3]), appearance=appearance, raw_enemy=enemy, raw_base=base))
            key = 'server:' + gid; record = dict(members=members, raw=g, order=g[1], source_group=gid, details=details)
            if key in original['groups']: assert record == original['groups'][key]
            else: groups[key] = record
            choices.append([key, weight])
        zones.append(dict(id=int(raw[0]), map=int(raw[3]), bounds=list(map(int, raw[4:8])), probability=list(map(int, raw[8:10])),
                          maximum=int(raw[10]), priority=int(raw[11]), groups=choices, raw=raw))
    assert {r['id'] for r in zones} == {7035, 7036, 7038, 7040, 7041, 7042, 7043}
    assert set(groups) == {'server:7028', 'server:7030'}
    return dict(schema=1, zones=zones, groups=groups, reuses_species=original['species'], species_offset=original['species_offset'],
                rare_identity_contract='Enemy 7020/7022 retain distinct IDs and level 1 despite sharing appearances with 7021/7023; source AI/stat execution remains unverified.',
                adaptations=original['adaptations'], map_assessment={str(n): dict(ambient_rows=[r['id'] for r in zones if r['map'] == n],
                    status='Source rows prepared; no generic pool. Missing ambient rows alone do not certify complete original safe-zone/event behavior.') for n in sorted(IDS)})


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    from prepare_sokia_server_events import prepare as prepare_npcs
    lookup = lib.serial_index(); shared = {}; protected = {}
    for name in CATALOGS + [str((SERVER_OUT / 'catalog.json').relative_to(ROOT))]:
        path = ROOT / name; catalog = json.loads(path.read_text()); protected[name] = recovery.digest(path.read_bytes())
        for key, graphic in catalog['graphics'].items(): shared.setdefault(key, graphic)
    graph = json.loads((REPORT.parent.parent / 'Source events/source-graph.json').read_text())
    maps = {}; used = set(); evidence = []; overrides = {}
    references = sum([json.loads((SOURCE / name).read_text()) for name in
                      ['water-cave-references.json','water-cave-completion-references.json']], [])
    for proof in references:
        number = int(proof['file'][:5]); assert number in IDS or number in [13500,13501,13502]
        server = (SOURCE / proof['file']).read_bytes(); assert recovery.digest(server) == proof['sha256']
        with lib.connection() as db: ident = db.execute('SELECT id FROM files WHERE path=?', (f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        raw = lib.source_file(ident)[1].read_bytes(); restored, completion = complete_map(raw, server, number)
        assert completion['compatible'] and completion['layout_complete']
        w, h, ground, objects, flags = lib.parse_map(restored); _, _, values, title = reference_map(server, number)
        variations = [dict(cell=[i%w,i//w], client=[ground[i],objects[i]], server=[values[i],values[w*h+i]])
                      for i in range(w*h) if (ground[i],objects[i]) != (values[i],values[w*h+i])]
        expected = [dict(cell=[45,24],client=[7903,17953],server=[7903,0])] if number==13502 else []
        assert variations == expected and completion['preserved_client_variations'] == len(expected)
        assert restored[20+w*h*4:] == raw[20+w*h*4:]
        serials = {s for s in ground if s} | {s for s in objects if s >= 1000}; assert not serials - lookup.keys()
        used.update(serials); walk = navigation_grid(w, h, ground, objects, lookup); bits = bytearray((w*h+7)//8)
        for i, opened in enumerate(walk):
            if opened: bits[i >> 3] |= 1 << (i & 7)
        record = dict(group='sokia_water_fixed', id=number, title=title, size=[w,h], outdoor=False,
            raw=recovery.encode(raw), sha256=recovery.digest(raw), restored_raw=recovery.encode(restored), restored_sha256=recovery.digest(restored), bytes=len(raw),
            walk=recovery.encode(bits), recorded=completion['recorded'], cells=w*h, restored_cells=completion['completed'], layout_complete=True,
            warp_cells=[[i%w,i//w] for i, value in enumerate(flags) if value & 2], layout_reference=proof, source_flags_available=True,
            flag_contract='Every client marker byte, including uncached zeros, is preserved. LS2MAP contributes no flag plane.',
            source_floor_object_sha256=recovery.digest(server[44:]), source_background_serials=[100], sokia_visual_only=False,
            fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map'] == number],
            gate_status='Verified source layout/NPC/native dispatch. Unresolved Warp13/skill/capacity/multi-destination rules remain guarded; no inbound shortcut.')
        path = f'BlueCrossgate/map/0/{number}.dat'
        if number in IDS: maps[path] = record
        elif number == 13502:
            record['client_event_variations'] = variations
            record['client_event_variation_evidence'] = 'Original NPC Warp13 at45,24 uses graphic17953; preserve the client marker, not an invented server object.'
            overrides[path] = record
        evidence.append(dict(id=number, completion=completion, client_flags_preserved=True, source=proof, client_event_variations=variations))
    assert len(maps) == 10 and sum(r['completion']['completed'] for r in evidence) == 5896
    for serial in used:
        if str(serial) in shared:
            g = lookup[serial]; image = lib.image_from_record(g['pack'], g['row'])
            assert recovery.digest(image.tobytes()) == shared[str(serial)]['rgba_sha256'], serial
    novel = used - set(map(int, shared)); assert len(novel) == 43
    pages, graphics, _ = recovery.pack_graphics(novel, lookup, {s:'cave_crag' for s in range(17808,17844)}, lib)
    cliffs = continuous_cliffs(lookup, graphics, pages, lib)
    catalog = dict(schema=1, page_indices='local', maps=maps, layout_overrides=overrides, graphics=graphics, requires=['east','sokia_server'],
                   pages=[f'sokia_server/water/atlas-{i}.png' for i in range(len(pages))], source_cliffs=cliffs)
    surfaces = recovery.rock_surfaces(catalog, pages); solids = recovery.solid_pages(catalog, pages)
    catalog['surface_pages'] = [f'sokia_server/water/surfaces-{i}.png' for i in range(len(surfaces))]
    catalog['solid_pages'] = [f'sokia_server/water/solid-{i}.png' for i in range(len(solids))]
    npc_data, npc_atlas = prepare_npcs(catalog)
    assert len(npc_data['actors']) == 10 and not npc_data['excluded']
    images = {**{f'atlas-{i}.png': image for i,image in enumerate(pages)}, **{f'solid-{i}.png': image for i,image in enumerate(solids)},
              **{f'surfaces-{i}.png': image for i,image in enumerate(surfaces)}, 'events/npc-atlas.png': npc_atlas}
    proof = dict(maps=evidence, protected_catalog_sha256=protected, new_graphics=sorted(novel), source_npcs=sorted(npc_data['actors']),
                 branch_maps=sorted(BRANCH), fixed_ports=[r for r in graph['fixed_warps'] if int(r['source_map']) in BRANCH],
                 event_ports=[r for r in graph['event_warps'] if int(r['source_map']) in BRANCH or
                              any(int(d['target_map']) in BRANCH for d in r['candidate_destinations'])],
                 guarded_warp_actors=[dict(id=r[3],source_map=int(r[8]),cell=list(map(int,r[9:11])),graphic=int(r[20]),parameters=r[24],raw=r)
                                      for r in rows('npc.txt') if r[0] in ['Warp','HouseWarp2'] and r[6]=='1' and int(r[8]) in BRANCH],
                 source_rules='No source multi-destination selection, skill, inventory capacity or trigger condition is replaced with an unconditional route.',
                 visual_status='Normal dispatch follows417source/native/rendered checks and38fixed normal-camera views. The sparse-fragment repair is accepted; whole-map visual fidelity and NPC full-body readability remain incomplete. Back volume/cap corners are inferred.')
    return catalog, encounters(), npc_data, images, proof


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', type=Path, default=REPORT/'Staged'); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    catalog, encounter_data, npcs, images, proof = prepare()
    for name, data in [('catalog.json',catalog),('encounters.json',encounter_data),('events/data.json',npcs),('source-preservation.json',proof)]:
        path = args.output/name; text = json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check: assert path.read_text() == text, name
        else: path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text)
    for name, image in images.items():
        path = args.output/name
        if args.check:
            with Image.open(path) as actual: assert actual.size == image.size and actual.tobytes() == image.tobytes(), name
        else: path.parent.mkdir(parents=True,exist_ok=True); image.save(path)
    print('SOKIA_WATER_SOURCE maps=10 source-completed=5896 original-flags=preserved source-NPCs=10 new-graphics=43 zones=7 rare-groups=2; verified dispatch, unresolved gates guarded')


if __name__ == '__main__':
    main()
