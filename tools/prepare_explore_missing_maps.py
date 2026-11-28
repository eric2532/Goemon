"""Recover the pinned Dragon Altar approach into the existing original-map owner."""
import hashlib
import json
import sys
import struct
from pathlib import Path
from types import SimpleNamespace

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map as classic_reference_map, solid_pages, expanded_lookup, navigation_function
from prepare_sokia_server_events import prepare as prepare_npcs, MESSAGE_ALIASES
from prepare_sokia_server_maps import KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND, KINDS, WALLS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/original_crossgate/explore_recovered"
OUTDOORS = {15551, 30001, 30010, 30012, 30013, 30017, 30114, 30312, 32034, 32035, 32134, 32341,
            32167, 32169, 32170, 32172, 32174, 32176, 32177, 32178, 32180,
            59502, 59503, 59504, 59521, 59524, 30002, 32200, 32201, 32202, 32205, 32353,
            59505, 59506, 59522, 59526, 15203, 30011, 30014, 32016, 32026,
            32240, 32241, 32242, 59527, 59956, 59958, 59959}


# Reviewed local EX namespaces: the unexpanded IDs resolve to unrelated UI icons.
FRONTIER_EX_NAMESPACES={
    32050:'b8eca0fd61253f7cf82f82eef244ce8a32f47ac2917e72258b099c91960bffbe',
    32051:'b61c5eff86e4e95db8c3822fa62b49cb29a76db817973a954be165cbc7dbb6eb',
    30195:'a325889af743cb915295cb525c6308c66c9c19c457eb556d13cf5cd6c32214f3',
    32203:'c89b015eba1d32e8677a6ed3d0c5ccec001315805690a0851b442a94baba20d2',
    32023:'6f729f0669a42e4555056f8bdd6ef82e4f95333052be359ae55a5ddf0ef06d88',
    32052:'d316af12fc286166d9a86de845897a9e6ee01df5c152a66dc3cae643dbc07ae7',
    32053:'f8c7c8a2b0e3eee4993acf8c027052cdcd2fe67e7b701a3c32ab07c40e20f2ce',
    32055:'f903fef4b2494f6d2cfbf54bb16bf1b2623b3a6113a9eb824f4a06714f422a3b',
    32056:'f7e4b2816aced2edebee744ed31ce0396570de7bb532d4adf2be09f13ac9b7a5',
    32057:'dce9acd604ecd752019157ad89827a50dcec4be7abf72c8254342295eedd9a9a',
    32063:'5b974f333ec9e749e47cdf491ccc6092c9850c2ea95da345fa227dfebc060b2d',
    32064:'0313b73faa995caa2f005ef1f1540578a8c2246f9ef71ae0f1596473e1253aa2',
    32065:'5c07f30d56f48e31ffff4894ec72000a3a01b1cc6a94691ab7b0a7a6c70755c2',
    32066:'3c53e0f7c0ef3475065fce5715b404b9a720223b579ab0f69a50be7f21935a64',
    32200:'f8f9e9d1afbbd77079ebdfec02c52d36b1192e9496d5b310288f2cc953935e40',
    32205:'9039bdc4e00be4ade231d65e019e93d44af8165e2020c54f4c3eb998f7a13f0d',
    32208:'1c74e6ff46158c7276444ad40ee3a8d6e2506c4a2b7aca8c21b490db54fd168e',
    32211:'e121d0d52ebb968ca5e08e641629e45020bd99f80b9605ca8b04d49b715322af',
    32296:'9256bcf8e20f15535ec3ec050a72a8392f3bac52030264a8762e3028fd125bda',
}


def reference_map(payload, ident):
    if payload[6:8] != b"\xff\xff":
        return classic_reference_map(payload, ident)
    # PUK2's original format adds a length-prefixed header and a third auxiliary plane.
    assert payload[:6] == b"LS2MAP"
    width, height = struct.unpack_from(">HH", payload, 40)
    header, source_id = struct.unpack_from(">II", payload, 44)
    assert header == 16 and source_id == ident
    assert len(payload) == 44 + header + width * height * 6
    values = struct.unpack_from(f">{width*height*3}H", payload, 44+header)
    title = payload[8:40].split(b"\0")[0].decode("gb18030").split("|")[0]
    return width, height, values[:width*height*2], title


def preserve_stair_variation(lib, raw, server, ident, completion):
    width, height, ground, objects, flags = lib.parse_map(raw)
    _, _, values, _ = reference_map(server, ident); cells = width * height
    differences = [i for i in range(cells) if flags[i] & 0xc000 and (ground[i], objects[i]) != (values[i], values[cells+i])]
    assert differences and all(ground[i] == values[i] and objects[i] in [13996,13997,13998,13999,17990,17991]
                               and values[cells+i] == 0 and flags[i] & 2 for i in differences), (ident, completion, len(differences))
    completed = bytearray(raw)
    for i in range(cells):
        if flags[i] & 0xc000:
            continue
        struct.pack_into('<H', completed, 20+i*2, values[i])
        struct.pack_into('<H', completed, 20+(cells+i)*2, values[cells+i])
    restored = bytes(completed)
    for i in range(cells):
        if flags[i] & 0xc000:
            assert raw[20+i*2:22+i*2] == restored[20+i*2:22+i*2] and raw[20+(cells+i)*2:22+(cells+i)*2] == restored[20+(cells+i)*2:22+(cells+i)*2]
    completion.update(compatible=True, layout_complete=True,
                      compatibility_scope='Only recorded original warp-marked stairs differ from pinned zero; all recorded tuples/flags preserved.')
    return restored, completion


def prepare_events(catalog, pins, frontier=False):
    maps = catalog["maps"]
    from prepare_snow_region_population import rows, SOURCE as TABLES
    from prepare_east_region_population import compile_script
    from PIL import Image
    ids = {str(row["id"]) for row in maps.values()}
    additional_ids = {"806107", "806108", "806121", "806326", "1102644"}
    if frontier:
        frontier_ids = {str(pin['map']) for pin in pins if pin['file'].startswith('frontier/')}
        additional_ids.update(r[3] for r in rows('npc.txt') if len(r) == 25 and r[8] in frontier_ids)
    actors = [r for r in rows("npc.txt") if len(r) == 25 and r[8] in ids and r[0]not in ["Warp","HouseWarp2"] and r[6]=="1" and (int(r[3])<300000 or r[3] in additional_ids)]
    visible = {r[3] for r in actors if int(r[20] or 0) > 1}
    if visible:
        npcs, npc_atlas = prepare_npcs(catalog, visible, additional_ids, frontier=frontier)
    else:
        npcs = dict(schema=1, actors={}, art={}, scripts={}, messages={}, source_provenance={})
        npc_atlas = Image.new("RGBA", (1, 1))
    events = ROOT / "assets/references/crossgate_sokia/events"
    references = {r["file"]: r for r in json.loads((events / "references.json").read_text())}
    references.update({r['file']: r for r in json.loads((events / 'explore-extra-references.json').read_text())})
    if frontier:
        references.update({r['file']: r for r in json.loads((events / 'frontier-references.json').read_text())})
    messages = {r[0]: r[1].replace("\\n", "\n") for r in rows("msg.txt") if len(r) > 1}
    if frontier:
        for missing, (original, _) in MESSAGE_ALIASES.items():messages[missing] = messages[original]
    for raw_actor in actors:
        if int(raw_actor[20] or 0) > 1:
            continue
        script = raw_actor[24]
        if script.endswith('.txt'):
            if script not in references or not (events / script).exists():
                assert frontier, ('Missing pinned original script', script)
                npcs.setdefault('script_blockers', []).append(dict(script=script, actor=raw_actor[3], source=int(raw_actor[8]), name=raw_actor[1],
                    reason='The original event script is absent from the pinned source tree; no program, destination or reward is inferred.'))
            else:
                payload = (events / script).read_bytes()
                assert recovery.digest(payload) == references[script]["sha256"]
                npcs["scripts"][script] = compile_script(payload)
                npcs["source_provenance"][script] = references[script]
        npcs["actors"][raw_actor[3]] = dict(id=raw_actor[3], type=raw_actor[0], name=raw_actor[1], source=int(raw_actor[8]),
            cell=list(map(int, raw_actor[9:11])), direction=int(raw_actor[19] or 0) % 8, graphic=int(raw_actor[20] or 0),
            script=script, raw=raw_actor, source_line=0, invisible=True, generated_by=None,
            dialogue_owner="sokia_server", token=f"{raw_actor[20]}:{int(raw_actor[19]) % 8}",
            quest_action="sokia_server:" + raw_actor[3], native_enemy=False, messages=[])
    import re
    npcs["atlas_path"]="res://assets/maps/original_crossgate/explore_recovered/events/npc-atlas.png"
    for script in npcs["scripts"].values():
        for _, text in script["lines"]:
            for ident in re.findall(r"\b(?:EndWindow|Window)\s+(\d+)", text, re.I):
                ident = str(int(ident))
                if ident not in npcs['messages']:npcs['messages'][ident] = messages[ident]
    return npcs, npc_atlas


def main(frontier=False, complete_partial=False):
    sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
    import cg_library as lib
    import cg_assets as cg
    from recover_elsa_island import cut_records, cut_header, cut_image
    navigation_grid = navigation_function(lib)
    import audit_explore_access as audit
    lookup, shared, existing_ids = lib.serial_index(), {}, set()
    packed_lookup = lookup.copy()
    cut_graphics, cut_images, cut_dedup = {}, {}, {}
    protected = {}; previous_maps = {}; override_ids = set()
    for name in audit.CATALOGS:
        if name.endswith("explore_recovered/catalog.json"):
            continue
        path = ROOT / name
        protected[name] = recovery.digest(path.read_bytes())
        previous = json.loads(path.read_text())
        previous_maps.update({int(row['id']): row for row in list(previous['maps'].values()) + list(previous.get('layout_overrides', {}).values())})
        existing_ids.update(int(row["id"]) for row in previous["maps"].values())
        for key, graphic in previous["graphics"].items():
            shared.setdefault(key, graphic)
    for key, graphic in shared.items():
        if 'cut' in graphic:
            cut_dedup[(tuple(graphic['cut']), bool(graphic['ground']), bool(graphic['animated']))] = int(key)
    next_cut = max(2000000, max(map(int, shared)) + 1)
    pins = json.loads((ROOT / "assets/references/crossgate_sokia/maps/server/altar-approach-references.json").read_text())
    pins += json.loads((ROOT / "assets/references/crossgate_sokia/maps/server/explore-extra-references.json").read_text())
    if frontier:
        pins += [dict(pin, file='frontier/' + pin['file']) for pin in json.loads((ROOT / 'assets/references/crossgate_sokia/maps/server/frontier/frontier-references.json').read_text())]
    old_catalog = json.loads((OUT / 'catalog.json').read_text()) if (OUT / 'catalog.json').exists() else {}
    override_pins = {row['id']: row['layout_reference'] for row in old_catalog.get('layout_overrides', {}).values()}
    if complete_partial:
        review = json.loads((ROOT / 'build/Other Files/Asset Toolkit/Explore Access/partial-layout-compatibility.json').read_text())
        for item in review['maps']:
            if item.get('compatibility') != 'EXACT_RECORDED_TUPLES' and not (item['source'] in [13502,15525,15530] and item.get('differences') == 1):
                continue
            if audit.source_layout_complete(previous_maps[item['source']]):continue
            override_pins[item['source']] = dict(item['reference'], map=item['source'], file='completion-review/' + item['reference']['file'])
    override_ids = set(override_pins)
    pins.extend(override_pins.values())
    maps, overrides, evidence, used = {}, {}, [], set()
    for pin in pins:
        ident = int(pin["map"]) if "map" in pin else int(pin["file"].split("_")[0])
        if ident in existing_ids and ident not in override_ids:
            continue
        server = (ROOT / "assets/references/crossgate_sokia/maps/server" / pin["file"]).read_bytes()
        assert recovery.digest(server) == pin["sha256"]
        assert hashlib.sha1(b"blob " + str(len(server)).encode() + b"\0" + server).hexdigest() == pin["git_blob_sha1"]
        source_path = f"BlueCrossgate/map/0/{ident}.dat"
        with lib.connection() as db:
            entry = db.execute("SELECT id FROM files WHERE path=?", (source_path,)).fetchone()
        variant_selected = False
        if entry:
            raw = lib.source_file(entry[0])[1].read_bytes()
            comparison_source = server
            if ident in override_ids and server[6:8] == b'\xff\xff':
                w, h, values, _ = reference_map(server, ident)
                comparison_source = server[:6] + struct.pack('>H', ident) + server[8:44] + struct.pack(f'>{w*h*2}H', *values)
            try:
                restored, completion = complete_map(raw, comparison_source, ident)
            except ValueError:
                assert frontier and pin['file'].startswith('frontier/'), ident
                _, _, _, _, native_flags = lib.parse_map(raw)
                restored = raw
                completion = dict(recorded=sum(bool(f & 0xc000) for f in native_flags), completed=0, compatible=False, layout_complete=False)
            if not completion["compatible"]:
                if frontier and pin['file'].startswith('frontier/'):
                    # Same existing regional policy: retain the client master and use
                    # the complete pinned layout, never a hybrid of different maps.
                    w, h, values, _ = reference_map(server, ident)
                    restored = b'MAP\x01' + bytes(8) + struct.pack('<II', w, h) + struct.pack(f'<{w*h*3}H', *values, *([0xc000] * (w*h)))
                    variant_selected = True
                    completion.update(layout_complete=True, active_layout_variant='pinned-reference',
                                      compatibility_scope='Complete pinned layout selected for a previously unbundled destination; original client bytes retained separately.')
                else:
                    restored, completion = preserve_stair_variation(lib, raw, server, ident, completion)
            assert (completion["compatible"] or variant_selected) and completion["layout_complete"], (ident, completion)
            if ident in override_ids:
                assert completion['compatible'] and not variant_selected, ('An existing layout cannot select a different reference variant', ident)
                assert previous_maps[ident]['sha256'] == recovery.digest(raw), ('An existing layout retains its original client master', ident)
        else:
            w, h, values, _ = reference_map(server, ident)
            raw = b'MAP\x01'+bytes(8)+struct.pack('<II',w,h)+struct.pack(f'<{w*h*3}H',*values,*([0xc000]*(w*h)))
            restored = raw
            completion = dict(recorded=0, completed=len(raw), layout_complete=True, source_flags_available=False)
        width, height, ground, objects, flags = lib.parse_map(restored)
        _, _, _, title = reference_map(server, ident)
        cells = width * height
        if not variant_selected:
            assert raw[20 + cells * 4:] == restored[20 + cells * 4:]
        serials = {s for s in ground if s} | {s for s in objects if s >= 1000}
        cut_path = cg.SOURCE / f'Puk2/cutdat/{ident}.cut'
        cut_map = cut_path.exists()
        expanded = Path(pin['file']).name.lower().startswith(('ex_', 'cg2_', 'tw_'))
        map_lookup, aliases = expanded_lookup(lib, serials, lookup) if expanded else (lookup, {})
        if cut_map:
            assert server[6:8] == b'\xff\xff', ('CUT map requires original auxiliary collision plane', ident)
            records = cut_records(ident); header = cut_header(ident)
            aliases = {}
            for serial in sorted(serials):
                assert 1000 <= serial < 1000 + len(records), (ident, serial)
                record = records[serial - 1000]; floor = serial - 1000 < header[2]
                animated = serial - 1000 >= header[2] + header[3]
                token = (record, floor, animated)
                if token not in cut_dedup:
                    graphic_id = next_cut; next_cut += 1
                    image, origin, _ = cut_image(ident, serial)
                    cut_images[graphic_id] = image
                    packed_lookup[graphic_id] = dict(pack='explore-cut', row=graphic_id, x=origin[0], y=origin[1], east=1, south=1, ground=floor)
                    cut_graphics[graphic_id] = dict(cut=list(record), cut_map=ident, cut_serial=serial, animated=animated,
                        family='void' if not animated and record[4:6] == (0,0) else 'floor' if floor else 'prop' if image.getbbox() else 'void')
                    cut_dedup[token] = graphic_id
                aliases[serial] = cut_dedup[token]
            walk = [not value for value in struct.unpack_from(f'>{cells}H', server, 60 + cells * 4)]
        elif frontier and pin['file'].startswith('frontier/'):
            if ident in FRONTIER_EX_NAMESPACES:
                assert pin['sha256']==FRONTIER_EX_NAMESPACES[ident]
                from prepare_east_region_maps import expanded_lookup
                map_lookup,aliases=expanded_lookup(lib,serials,lookup)
            else:
                # Some pinned maps omit the regional filename prefix. Resolve only
                # absent IDs, retaining every existing unprefixed graphic identity.
                for serial in serials - map_lookup.keys():
                    with lib.connection() as db:
                        match = db.execute('SELECT pack,row,serial,x,y,w,h,east,south,ground FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1', (serial + 200000,)).fetchone()
                    if match is not None:
                        map_lookup = map_lookup.copy(); map_lookup[serial] = dict(match)
                        aliases[serial] = 1000000 + int(match['serial'])
        missing = set() if cut_map else serials - map_lookup.keys()
        assert not missing, ('Unresolved source map graphics', ident, sorted(missing)[:30], len(missing))
        if not cut_map:
            for serial in serials:
                packed_lookup[aliases.get(serial, serial)] = map_lookup[serial]
        used.update(aliases.get(s, s) for s in serials)
        if not cut_map:
            walk = navigation_grid(width, height, ground, objects, map_lookup)
        bits = bytearray((cells + 7) // 8)
        for i, opened in enumerate(walk):
            if opened:
                bits[i >> 3] |= 1 << (i & 7)
        maps[source_path] = dict(id=ident, group="explore_recovered", title=title, size=[width, height], outdoor=ident in OUTDOORS,
            raw=recovery.encode(raw), restored_raw=recovery.encode(restored), sha256=recovery.digest(raw),
            restored_sha256=recovery.digest(restored), bytes=len(restored), recorded=completion["recorded"], cells=cells,
            layout_complete=True, walk=recovery.encode(bits), warp_cells=[[i % width, i // width] for i, flag in enumerate(flags) if flag & 2],
            layout_reference=pin, source_floor_object_sha256=recovery.digest(server[60:60+cells*4] if server[6:8] == b"\xff\xff" else server[44:]))
        if variant_selected:
            maps[source_path].update(reference_variant_raw=recovery.encode(restored), reference_variant_sha256=recovery.digest(restored), active_layout_variant='pinned-reference')
        if aliases:
            maps[source_path]['graphic_aliases'] = {str(k): v for k, v in aliases.items()}
        if cut_map:
            maps[source_path]['cut_sha256'] = recovery.digest(cut_path.read_bytes())
            maps[source_path]['collision_contract'] = 'Original PUK2 auxiliary collision plane; CUT-local graphic IDs use their own exact source crops and anchors.'
        if server[6:8] == b"\xff\xff":
            maps[source_path]["source_auxiliary"] = recovery.encode(server[60+cells*4:])
            maps[source_path]["format_reference"] = "https://bbs.cgmsv.com/thread-8-1-1.html"
            maps[source_path]["source_flags_available"] = False
        if ident in override_ids:
            completed = maps.pop(source_path)
            for key in ['group','title','outdoor','inferred_roofless','sokia_visual_only','east_existing_owner']:
                if key in previous_maps[ident]:completed[key] = previous_maps[ident][key]
            overrides[source_path] = completed
        evidence.append(dict(source=pin, completion=completion))
        print('EXPLORE_MAP_SOURCE', ident, width, height, 'pinned variant' if variant_selected else 'compatible', flush=True)
    specs = {}
    for path in ['assets/maps/falan/university_region/dungeon_specs.gd', 'assets/maps/falan/east_region/dungeon_specs.gd',
                 'assets/maps/falan/sokia/cape/dungeon_specs.gd', 'assets/maps/falan/explore-dungeon-specs.gd']:
        specs.update(json.loads((ROOT / path).read_text().split('const SPECS=', 1)[1]))
    for spec in specs.values():
        used.update(n for n in [spec['ground'], *spec['stairs']] if 0 < n < 65536)
    missing = sorted(used - packed_lookup.keys() - set(map(int, shared)))
    assert not missing, ('Every generated/fixed source tile needs its original graphic', missing)
    for serial in used & set(map(int, shared)):
        graphic = shared[str(serial)]
        if 'cut' in graphic:
            image, origin, _ = cut_image(graphic['cut_map'], graphic['cut_serial'])
            assert recovery.digest(image.tobytes()) == graphic['rgba_sha256'] and list(origin) == graphic['origin']
            continue
        source = packed_lookup[serial]
        image = lib.image_from_record(source["pack"], source["row"])
        assert recovery.digest(image.tobytes()) == graphic["rgba_sha256"]
        assert graphic["origin"] == [source["x"], source["y"]]
        assert graphic["footprint"] == [source["east"], source["south"]]
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({n: "room_wall" for n in WALLS if n >= 16000})
    image_source = SimpleNamespace(image_from_record=lambda pack, row: cut_images[row] if pack == 'explore-cut' else lib.image_from_record(pack, row))
    pages, graphics, _ = recovery.pack_graphics(used - set(map(int, shared)), packed_lookup, furniture, image_source)
    for ident, record in cut_graphics.items():
        graphics[str(ident)].update(record)
    surfaces = recovery.rock_surfaces(dict(graphics=graphics), pages)
    solids = solid_pages(graphics, pages)
    catalog = dict(schema=1, maps=maps, layout_overrides=overrides,
        graphics=graphics, pages=[f"explore_recovered/atlas-{i}.png" for i in range(len(pages))],
        surface_pages=[f"explore_recovered/surfaces-{i}.png" for i in range(len(surfaces))],
        solid_pages=[f"explore_recovered/solid-{i}.png" for i in range(len(solids))])
    npcs, npc_atlas = prepare_events(catalog, pins, frontier)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in [("catalog.json", catalog), ("events/data.json", npcs), ("preservation.json", dict(
        maps=evidence, protected_catalogs=protected, reused_graphics=sorted(used & set(map(int, shared))),
        novel_graphics=sorted(used - set(map(int, shared))), recorded_flags_preserved=True))]:
        path = OUT / name;path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n")
    for prefix, images in [("atlas", pages), ("surfaces", surfaces), ("solid", solids)]:
        for i, image in enumerate(images):
            image.save(OUT / f"{prefix}-{i}.png")
    npc_atlas.save(OUT / "events/npc-atlas.png")
    (OUT / 'map_ids.gd').write_text('extends RefCounted\n## Prepared complete source destinations; graph and interaction verification remain separate.\nconst IDS=' + json.dumps(sorted(int(row['id']) for row in list(maps.values()) + list(overrides.values()))) + '\n')
    for name, digest in protected.items():
        assert recovery.digest((ROOT / name).read_bytes()) == digest
    print("EXPLORE_MAP_RECOVERED", len(maps), 'missing maps;',len(overrides),'completed existing maps;',sum(row["cells"] for row in list(maps.values()) + list(overrides.values())), "cells;", len(graphics), "novel graphics;", len(npcs["actors"]), "source actors")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frontier', action='store_true')
    parser.add_argument('--complete-partial', action='store_true')
    args=parser.parse_args();main(frontier=args.frontier,complete_partial=args.complete_partial)
