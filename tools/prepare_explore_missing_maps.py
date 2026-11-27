"""Recover the pinned Dragon Altar approach into the existing original-map owner."""
import hashlib
import json
import sys
import struct
from pathlib import Path

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map as classic_reference_map, solid_pages
from prepare_sokia_server_events import prepare as prepare_npcs
from prepare_sokia_server_maps import KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND, KINDS, WALLS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/original_crossgate/explore_recovered"


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


def main():
    sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    import audit_explore_access as audit
    lookup, shared, existing_ids = lib.serial_index(), {}, set()
    protected = {}
    for name in audit.CATALOGS:
        if name.endswith("explore_recovered/catalog.json"):
            continue
        path = ROOT / name
        protected[name] = recovery.digest(path.read_bytes())
        previous = json.loads(path.read_text())
        existing_ids.update(int(row["id"]) for row in previous["maps"].values())
        for key, graphic in previous["graphics"].items():
            shared.setdefault(key, graphic)
    pins = json.loads((ROOT / "assets/references/crossgate_sokia/maps/server/altar-approach-references.json").read_text())
    pins += json.loads((ROOT / "assets/references/crossgate_sokia/maps/server/explore-extra-references.json").read_text())
    maps, evidence, used = {}, [], set()
    for pin in pins:
        ident = int(pin["map"]) if "map" in pin else int(pin["file"].split("_")[0])
        if ident in existing_ids:
            continue
        server = (ROOT / "assets/references/crossgate_sokia/maps/server" / pin["file"]).read_bytes()
        assert recovery.digest(server) == pin["sha256"]
        assert hashlib.sha1(b"blob " + str(len(server)).encode() + b"\0" + server).hexdigest() == pin["git_blob_sha1"]
        source_path = f"BlueCrossgate/map/0/{ident}.dat"
        with lib.connection() as db:
            entry = db.execute("SELECT id FROM files WHERE path=?", (source_path,)).fetchone()
        if entry:
            raw = lib.source_file(entry[0])[1].read_bytes()
            restored, completion = complete_map(raw, server, ident)
            if not completion["compatible"]:
                width, height, ground, objects, flags = lib.parse_map(raw)
                _, _, values, _ = reference_map(server, ident);cells = width*height
                differences = [i for i in range(cells) if flags[i]&0xc000 and (ground[i],objects[i])!=(values[i],values[cells+i])]
                assert differences and all(ground[i]==values[i] and objects[i]in [13996,13997,13998,13999,17990,17991] and values[cells+i]==0 and flags[i]&2 for i in differences), (ident,completion,differences)
                completed = bytearray(raw)
                for i in range(cells):
                    if flags[i]&0xc000:
                        continue
                    struct.pack_into("<H",completed,20+i*2,values[i])
                    struct.pack_into("<H",completed,20+(cells+i)*2,values[cells+i])
                restored = bytes(completed)
                for i in range(cells):
                    if flags[i]&0xc000:
                        assert raw[20+i*2:22+i*2]==restored[20+i*2:22+i*2] and raw[20+(cells+i)*2:22+(cells+i)*2]==restored[20+(cells+i)*2:22+(cells+i)*2]
                completion.update(compatible=True,layout_complete=True,compatibility_scope="Only recorded original warp-marked stairs differ from pinned zero; all recorded tuples/flags preserved.")
            assert completion["compatible"] and completion["layout_complete"], (ident, completion)
        else:
            w, h, values, _ = reference_map(server, ident)
            raw = b'MAP\x01'+bytes(8)+struct.pack('<II',w,h)+struct.pack(f'<{w*h*3}H',*values,*([0xc000]*(w*h)))
            restored = raw
            completion = dict(recorded=0, completed=len(raw), layout_complete=True, source_flags_available=False)
        width, height, ground, objects, flags = lib.parse_map(restored)
        _, _, _, title = reference_map(server, ident)
        cells = width * height
        assert raw[20 + cells * 4:] == restored[20 + cells * 4:]
        used.update({s for s in ground if s} | {s for s in objects if s >= 1000})
        walk = navigation_grid(width, height, ground, objects, lookup)
        bits = bytearray((cells + 7) // 8)
        for i, opened in enumerate(walk):
            if opened:
                bits[i >> 3] |= 1 << (i & 7)
        maps[source_path] = dict(id=ident, group="explore_recovered", title=title, size=[width, height], outdoor=ident==15551,
            raw=recovery.encode(raw), restored_raw=recovery.encode(restored), sha256=recovery.digest(raw),
            restored_sha256=recovery.digest(restored), bytes=len(raw), recorded=completion["recorded"], cells=cells,
            layout_complete=True, walk=recovery.encode(bits), warp_cells=[[i % width, i // width] for i, flag in enumerate(flags) if flag & 2],
            layout_reference=pin, source_floor_object_sha256=recovery.digest(server[60:60+cells*4] if server[6:8] == b"\xff\xff" else server[44:]))
        if server[6:8] == b"\xff\xff":
            maps[source_path]["source_auxiliary"] = recovery.encode(server[60+cells*4:])
            maps[source_path]["format_reference"] = "https://bbs.cgmsv.com/thread-8-1-1.html"
            maps[source_path]["source_flags_available"] = False
        evidence.append(dict(source=pin, completion=completion))
    specs = json.loads((ROOT / "assets/maps/falan/explore-dungeon-specs.gd").read_text().split("const SPECS=", 1)[1])
    for spec in specs.values():
        used.update([spec["ground"], *spec["stairs"]])
    assert used <= lookup.keys(), "Every generated/fixed source tile needs its original graphic"
    for serial in used & set(map(int, shared)):
        source = lookup[serial]
        graphic = shared[str(serial)]
        image = lib.image_from_record(source["pack"], source["row"])
        assert recovery.digest(image.tobytes()) == graphic["rgba_sha256"]
        assert graphic["origin"] == [source["x"], source["y"]]
        assert graphic["footprint"] == [source["east"], source["south"]]
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({n: "room_wall" for n in WALLS if n >= 16000})
    pages, graphics, _ = recovery.pack_graphics(used - set(map(int, shared)), lookup, furniture, lib)
    surfaces = recovery.rock_surfaces(dict(graphics=graphics), pages)
    solids = solid_pages(graphics, pages)
    catalog = dict(schema=1, maps=maps,
        graphics=graphics, pages=[f"explore_recovered/atlas-{i}.png" for i in range(len(pages))],
        surface_pages=[f"explore_recovered/surfaces-{i}.png" for i in range(len(surfaces))],
        solid_pages=[f"explore_recovered/solid-{i}.png" for i in range(len(solids))])
    from prepare_snow_region_population import rows, SOURCE as TABLES
    from prepare_east_region_population import compile_script
    from PIL import Image
    ids = {str(row["id"]) for row in maps.values()}
    additional_ids = {"806107", "806108", "806121", "806326", "1102644"}
    actors = [r for r in rows("npc.txt") if len(r) == 25 and r[8] in ids and r[0]not in ["Warp","HouseWarp2"] and r[6]=="1" and (int(r[3])<300000 or r[3] in additional_ids)]
    visible = {r[3] for r in actors if int(r[20]) > 1}
    if visible:
        npcs, npc_atlas = prepare_npcs(catalog, visible, additional_ids)
    else:
        npcs = dict(schema=1, actors={}, art={}, scripts={}, messages={}, source_provenance={})
        npc_atlas = Image.new("RGBA", (1, 1))
    events = ROOT / "assets/references/crossgate_sokia/events"
    references = {r["file"]: r for r in json.loads((events / "references.json").read_text())}
    messages = {r[0]: r[1].replace("\\n", "\n") for r in rows("msg.txt") if len(r) > 1}
    for raw_actor in actors:
        if int(raw_actor[20]) > 1:
            continue
        script = raw_actor[24];payload = (events / script).read_bytes()
        assert recovery.digest(payload) == references[script]["sha256"]
        npcs["scripts"][script] = compile_script(payload)
        npcs["source_provenance"][script] = references[script]
        npcs["actors"][raw_actor[3]] = dict(id=raw_actor[3], type=raw_actor[0], name=raw_actor[1], source=int(raw_actor[8]),
            cell=list(map(int, raw_actor[9:11])), direction=int(raw_actor[19]) % 8, graphic=int(raw_actor[20]),
            script=script, raw=raw_actor, source_line=0, invisible=True, generated_by=None,
            dialogue_owner="sokia_server", token=f"{raw_actor[20]}:{int(raw_actor[19]) % 8}",
            quest_action="sokia_server:" + raw_actor[3], native_enemy=False, messages=[])
    import re
    npcs["atlas_path"]="res://assets/maps/original_crossgate/explore_recovered/events/npc-atlas.png"
    for script in npcs["scripts"].values():
        for _, text in script["lines"]:
            for ident in re.findall(r"\b(?:EndWindow|Window)\s+(\d+)", text, re.I):
                npcs["messages"][ident] = messages[ident]
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
    for name, digest in protected.items():
        assert recovery.digest((ROOT / name).read_bytes()) == digest
    print("EXPLORE_MAP_RECOVERED", len(maps), sum(row["cells"] for row in maps.values()), "cells;", len(graphics), "novel graphics;", len(npcs["actors"]), "source actors")


if __name__ == "__main__":
    main()
