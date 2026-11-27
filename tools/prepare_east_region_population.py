"""Prepare pinned East Gate/overseas actors and encounters for existing native owners."""
import argparse
import ast
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "build/Other Files/Asset Toolkit/East Gate Region"
OUT = ROOT / "assets/maps/falan/east_region"
TABLES = ROOT / "build/Other Files/Asset Toolkit/Map Encounters/Source"
SOURCES = [("east", AUDIT / "Source Audit", "graph.json"),
           ("akelufa", AUDIT / "Akelufa Source Audit", "graph.json"),
           ("goral", AUDIT / "Verification/Goral Source Audit", "inventory.json"),
           ("harbor_quests", AUDIT / "Harbor Quest Source Audit", "graph.json"),
           ("version_expansion", AUDIT / "Version Expansion Source Audit", "graph.json")]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def rows(name):
    return [r for line in (TABLES / name).read_bytes().decode("gb18030").splitlines()
            if line and not line.startswith("#") and len(r := line.split("\t")) > 3]


def approved_height(bank, skin, manifest):
    if bank == "falan_encounters":
        text = (ROOT / "assets/maps/falan/map_encounter_data.gd").read_text()
        match = re.search(r"const HEIGHTS=(\[.*?\])", text)
    else:
        text = (ROOT / "scripts/forest/crowd/pet_dimensions.gd").read_text()
        match = re.search(r'^\s*"' + re.escape(bank) + r'"\s*:\s*(\[.*?\])', text, re.M)
    if match:
        return float(ast.literal_eval(match[1])[skin])
    proportions = (ROOT / "scripts/character_proportions.gd").read_text()
    kaz_height = float(re.search(r"^const GOEMON_HEIGHT=([\d.]+)", proportions, re.M)[1])
    return float(manifest["variants"][skin]["standing_height"]) / kaz_height


def compile_script(raw):
    """Retain original conditions/window order as data; never execute source programs."""
    lines = [[i, line] for i, line in enumerate(raw.decode("gb18030").splitlines(), 1)
             if line.strip() and not line.lstrip().startswith("#")]
    blocks = []
    for number, line in lines:
        match = re.match(r"^\s*block\b(.*)", line, re.I)
        if match:
            blocks.append(dict(line=number, condition=match[1].strip(), lines=[]))
        else:
            if not blocks:
                blocks.append(dict(line=number, condition="", lines=[]))
            blocks[-1]["lines"].append([number, line])
    return dict(sha256=sha(raw), lines=lines, blocks=blocks)


def source_data():
    actors = {}; scripts = {}; dungeons = {}; maps = set(); later = []; proofs = []
    for region, folder, name in SOURCES:
        graph = json.loads((folder / name).read_text())
        references = json.loads((folder / "references.json").read_text())
        index = {}
        for reference in references:
            if reference.get("missing") or "file" not in reference:
                continue
            path = folder / reference["file"]
            assert sha(path.read_bytes()) == reference["sha256"], path
            index[reference["path"]] = path
        source_actors = graph.get("actors", graph.get("classic_actors", []))
        maps.update(m if isinstance(m, int) else m["id"] for m in graph["maps"])
        later.extend(graph.get("excluded_later_inactive_actors", graph.get("later_or_disabled_actors", [])))
        for actor in source_actors:
            raw = actor["raw"]
            assert len(raw) == 25
            record = dict(id=str(raw[3]), type=raw[0], name=raw[1], source=int(raw[8]),
                          cell=list(map(int, raw[9:11])), direction=int(raw[19] or 0) % 8,
                          graphic=int(raw[20] or 0), script=raw[24], raw=raw,
                          source_line=actor["line"], region=region,
                          generated_by=actor.get("generated_by"))
            key = (record["source"], record["id"], record["generated_by"])
            actors.setdefault(key, record)
            path = index.get("gmsv/data/npc/" + record["script"])
            if path:
                compiled = compile_script(path.read_bytes())
                if record["script"] in scripts:
                    assert scripts[record["script"]]["sha256"] == compiled["sha256"]
                scripts[record["script"]] = compiled
        for dungeon in graph["dungeons"]:
            raw = dungeon["raw"]
            dungeons[str(dungeon["id"])] = dict(id=int(raw[3]), name=raw[0],
                source=int(raw[9]), entrance=list(map(int, raw[10:14])),
                target=int(raw[15]) if raw[15].isdigit() else 0,
                landing=list(map(int, raw[16:18])) if raw[16].isdigit() else [],
                floors=list(map(int, raw[39:41])), encounter=int(raw[49]),
                levels=list(map(int, raw[50:52])), raw=raw, region=region)
        proofs.append(dict(region=region, graph=str((folder / name).relative_to(ROOT)),
                           graph_sha256=sha((folder / name).read_bytes())))
    active_keys = {(r["source"], r["id"]) for r in actors.values()}
    later = [r for r in later if (int(r.get("map", r.get("raw", [""] * 9)[8])), str(r["id"])) not in active_keys]
    return list(actors.values()), scripts, dungeons, maps, later, proofs


def battle_ids(actors, scripts):
    battles = []
    for actor in actors:
        if actor["type"] == "StandEnemy":
            fields = actor["script"].split("|")
            if len(fields) > 9 and fields[9].isdigit():
                battles.append(dict(actor=actor["id"], source=actor["source"],
                    generated_by=actor["generated_by"], encounter=int(fields[9]),
                    command=actor["script"], script="inline StandEnemy"))
        for line, text in scripts.get(actor["script"], {}).get("lines", []):
            match = re.match(r"^\s*Encount\s+(.+)", text, re.I)
            if match:
                fields = match[1].split("|")
                if len(fields) > 9 and fields[9].isdigit():
                    battles.append(dict(actor=actor["id"], source=actor["source"],
                        generated_by=actor["generated_by"], encounter=int(fields[9]),
                        command=text, script=actor["script"], line=line))
    item_path = OUT / "items.json"
    if item_path.exists():
        for item in json.loads(item_path.read_text())["items"].values():
            for line, text in (item.get("program") or {}).get("lines", []):
                match = re.match(r"^\s*Encount\s+(.+)", text, re.I)
                if match:
                    fields = match[1].split("|")
                    if len(fields) > 9 and fields[9].isdigit():
                        battles.append(dict(actor="item:" + str(item["id"]), item=int(item["id"]),
                            source=-1, generated_by=None, encounter=int(fields[9]),
                            command=text, script=item["argument"], line=line))
    return battles


def encounter_data(actors, scripts, dungeons, maps):
    encounter_rows = {int(r[0]): r for r in rows("encount.txt")}
    group_rows = {r[2]: r for r in rows("group.txt")}
    enemies = {r[2]: r for r in rows("enemy.txt")}
    bases = {r[1]: r for r in rows("enemybase.txt")}
    battles = battle_ids(actors, scripts)
    boss_ids = {r["encounter"] for r in battles}
    while True:
        follow = {int(encounter_rows[i][12]) for i in boss_ids & encounter_rows.keys()
                  if encounter_rows[i][12].isdigit() and int(encounter_rows[i][12]) > 0
                  and int(encounter_rows[i][13] or 0) > 0}
        if follow <= boss_ids:
            break
        boss_ids |= follow
    generated_ids = {d["encounter"] for d in dungeons.values()}
    wanted = boss_ids | generated_ids
    wanted |= {i for i, r in encounter_rows.items() if int(r[3]) in maps
               or r[3] == "100" and int(r[6]) >= 440 and int(r[5]) < 360}
    pets = json.loads((ROOT / "assets/characters/crossgate/guard_pets/motions.json").read_text())["variants"]
    prepared = {}
    for skin, row in enumerate(pets):
        prepared.setdefault(row["id"], dict(bank="companion", skin=skin, key=row["key"]))
    east_manifest = ROOT / "assets/characters/crossgate/east_region/motions.json"
    east_heights = {}
    if east_manifest.exists():
        east_heights = {r["id"]: r.get("height", 1.0) for r in json.loads(east_manifest.with_name("species.json").read_text())}
        for skin, row in enumerate(json.loads(east_manifest.read_text())["variants"]):
            prepared.setdefault(row["id"], dict(bank="east_region", skin=skin, key=row.get("key", "")))
    # Existing dedicated boss sheets are retained when they are absent from the shared companion bank.
    for path in sorted((ROOT / "assets/characters/crossgate").glob("*/motions.json")):
        if path.parent.name in ["guard_pets", "east_region"]:
            continue
        manifest = json.loads(path.read_text())
        if not isinstance(manifest.get("variants"), list):
            continue
        for skin, row in enumerate(manifest["variants"]):
            if isinstance(row, dict) and "id" in row and "standing_height" in row:
                prepared.setdefault(row["id"], dict(bank=path.parent.name, skin=skin,
                    key=row.get("key", ""), motions=str(path.relative_to(ROOT))))
    species = []; species_index = {}; groups = {}; blockers = []
    preparation = OUT / "native-preparation-blockers.json"
    contracts = {r["id"]: r for r in json.loads(preparation.read_text())} if preparation.exists() else {}
    def get_species(base):
        appearance = int(base[30])
        if appearance not in species_index:
            species_index[appearance] = len(species)
            match = prepared.get(appearance)
            if match is None:
                contract = contracts.get(appearance)
                match = dict(bank="unavailable", skin=-1, key=(contract.get("source_keys") or [""])[0] if contract else "")
                blockers.append(dict(kind="native_enemy_contact" if contract else "native_enemy_art", appearance=appearance,
                    name=base[0], reason=contract["reason"] if contract else "No existing native bank matches this source appearance.",
                    source_contract=contract))
            species.append(dict(id=appearance, name=base[0], height=east_heights.get(appearance, 1.0), **match))
        return species_index[appearance]
    def get_group(gid):
        if gid in groups:
            return True
        if gid not in group_rows:
            blockers.append(dict(kind="missing_group", id=gid))
            return False
        raw = group_rows[gid]; members = []; details = []
        for index, eid in enumerate(raw[5:15]):
            weight = int(raw[15 + index] or 0)
            if eid in ["", "0"] or not weight and raw[25 + index] != "1":
                continue
            if eid not in enemies or enemies[eid][3] not in bases:
                blockers.append(dict(kind="missing_enemy", group=gid, id=eid)); continue
            enemy = enemies[eid]; base = bases[enemy[3]]; member = get_species(base)
            members.append([member, int(enemy[4]), int(enemy[5]), weight])
            details.append(dict(species=member, enemy=eid, raw_enemy=enemy, raw_base=base))
        groups[gid] = dict(members=members, order=raw[1], raw=raw, details=details)
        return bool(members)
    zones = []; bosses = {}; generated_pools = {}
    for ident in sorted(wanted):
        if ident not in encounter_rows:
            blockers.append(dict(kind="missing_encounter", id=ident)); continue
        raw = encounter_rows[ident]; chosen = []
        for index, gid in enumerate(raw[14:24]):
            weight = int(raw[24 + index] or 0)
            if gid and weight and get_group(gid):
                chosen.append([gid, weight])
        zone = dict(id=ident, map=int(raw[3]), bounds=list(map(int, raw[4:8])),
                    probability=list(map(int, raw[8:10])), maximum=int(raw[10]),
                    priority=int(raw[11]), groups=chosen, raw=raw,
                    next_encounter=int(raw[12] or 0), next_probability=int(raw[13] or 0))
        if ident in boss_ids:
            bosses[str(ident)] = zone
        if ident in generated_ids:
            generated_pools[str(ident)] = zone
        if int(raw[3]) in maps or raw[3] == "100" and int(raw[6]) >= 440 and int(raw[5]) < 360:
            zones.append(zone)
    for dungeon in dungeons.values():
        dungeon["pool"] = generated_pools.get(str(dungeon["encounter"]), {})
    return dict(species=species, groups=groups, zones=zones, bosses=bosses,
                generated=dungeons, scripted_battles=battles, blockers=blockers)


def pack_new_species(data):
    """Use the existing offline native importer; preserve unsupported cue contracts explicitly."""
    sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
    import cg_assets as cg
    import cg_sounds
    from recover_habaru_encounter import body_rows, recover
    output = ROOT / "assets/characters/crossgate/east_region"
    catalog = cg.catalog()["entries"]
    _, _, clips = cg.actor("ex:1727")
    idle = next(c for c in clips if c["action"] == 0 and c["direction"] == 4)
    top, foot = body_rows(cg.frame_parts("ex:1727", idle["index"], 0)[0])
    reference_height = foot - top
    candidates = []; blockers = []
    required = {(action, direction) for action in [0, 1, 3, 5, 8, 9, 10] for direction in range(8)}
    for species in data["species"]:
        if species["bank"] in ["companion", "east_region"]:
            continue
        if species["bank"] != "unavailable":
            existing = json.loads((ROOT / "assets/characters/crossgate" / species["bank"] / "motions.json").read_text())
            if {0, 1, 3, 5, 8, 9, 10} <= set(existing["actions"]):
                continue
        choices = [r for r in catalog if r["id"] == species["id"]]
        choices.sort(key=lambda r: 0 if r["key"].startswith("original:")
                     and 2800 <= int(r["key"].split(":")[1]) < 3000 else 1)
        selected = None; issues = []
        for candidate in choices:
            _, _, source = cg.actor(candidate["key"])
            if not required <= {(c["action"], c["direction"]) for c in source}:
                continue
            problems = []
            for clip in source:
                if clip["action"] != 5:
                    continue
                cues = cg_sounds.clip_cues(clip)
                contacts = {c["id"] for c in cues if 10000 <= c["flag"] < 20000}
                sounds = {c["id"] for c in cues if not 10000 <= c["flag"] < 20000}
                if not 0 < len(contacts) <= 20 or len(cues) > 20:
                    problems.append(dict(direction=clip["direction"], source_cues=cues,
                        reason=f"Native importer requires source contact markers and at most 20 cues; source has {len(contacts)} contacts/{len(cues)} cues."))
            if not problems:
                selected = candidate; break
            issues.append(dict(key=candidate["key"], problems=problems))
        if selected is None:
            blockers.append(dict(id=species["id"], name=species["name"],
                reason="Source action/contact/audio contract needs an explicit native importer extension.",
                candidates=issues, source_keys=[r["key"] for r in choices]))
            continue
        _, _, source = cg.actor(selected["key"])
        idle = next(c for c in source if c["action"] == 0 and c["direction"] == 4)
        top, foot = body_rows(cg.frame_parts(selected["key"], idle["index"], 0)[0])
        height = (foot - top) / reference_height
        previous_fit = None
        if species["bank"] != "unavailable":
            height = approved_height(species["bank"], species["skin"], existing)
            previous_fit = dict(bank=species["bank"], skin=species["skin"])
        candidates.append(dict(id=species["id"], name=species["name"], key=selected["key"],
            height=height, source_body_pixels=foot - top, prepared_from=previous_fit,
            source_scale_reference=dict(key="ex:1727", body_pixels=reference_height)))
    (OUT / "native-preparation-blockers.json").write_text(json.dumps(blockers, ensure_ascii=False, indent=2) + "\n")
    if candidates:
        output.mkdir(parents=True, exist_ok=True)
        previous = json.loads((output / "species.json").read_text()) if (output / "species.json").exists() else []
        stage = AUDIT / "Native Additions" / sha(json.dumps([r["id"] for r in candidates]).encode())[:12] if previous else output
        recover(ROOT.parent / "Magic Power", shalena=True, species_override=candidates, output_override=stage, raw_cues=True)
        (stage / "species.json").write_text(json.dumps(candidates, ensure_ascii=False, indent=2) + "\n")
        if previous:
            append_native_bank(output, stage, list(range(len(candidates))), candidates)
    print("EAST_NATIVE_PREPARED", len(candidates), "new variants;", len(blockers), "explicit source cue contracts remain")


def append_native_bank(output, source, skins, records):
    """Append prepared native rows, preserving old frames and reusing immutable atlas pages."""
    old = json.loads((output / "motions.json").read_text())
    new = json.loads((source / "motions.json").read_text())
    assert old["actions"] == [0, 3, 5, 8, 10, 1, 9]
    assert set(old["actions"]) <= set(new["actions"])
    width = int(old["table_width"])
    def unpack(folder, manifest):
        raw = (folder / "frames.bin").read_bytes()
        table = list(struct.iter_unpack("<4f", raw))
        clips = table[:manifest["clip_count"]]
        count = max(int(row[0] + row[1]) for row in clips)
        return clips, table[manifest["clip_count"]:manifest["clip_count"] + count * 2]
    clips, frames = unpack(output, old)
    source_clips, source_frames = unpack(source, new)
    preserved_clips = list(clips); preserved_frames = list(frames)
    paths = list(old.get("atlas_paths", ["res://" + str((output / f"atlas-{i}.png").relative_to(ROOT)) for i in range(old["pages"])]))
    source_paths = new.get("atlas_paths", ["res://" + str((source / f"atlas-{i}.png").relative_to(ROOT)) for i in range(new["pages"])])
    staged = source.is_relative_to(ROOT / "build")
    if staged:
        retained = []
        prefix = sha(str(source).encode())[:12]
        for i, path in enumerate(source_paths):
            target = output / f"append-{prefix}-atlas-{i}.png"
            target.write_bytes((ROOT / path.removeprefix("res://")).read_bytes())
            retained.append("res://" + str(target.relative_to(ROOT)))
        source_paths = retained
    page_map = {}
    for i, path in enumerate(source_paths):
        if path not in paths:
            paths.append(path)
        page_map[i] = paths.index(path)
    palette = Image.open(output / "palette.png").convert("RGBA")
    added_palette = Image.open(source / "palette.png").convert("RGBA")
    assert palette.width == added_palette.width == 256
    palette_offset = palette.height
    merged = Image.new("RGBA", (256, palette.height + added_palette.height))
    merged.paste(palette, (0, 0)); merged.paste(added_palette, (0, palette.height))
    old_stride = len(old["timelines"]) // len(old["variants"]) // 8
    new_stride = len(new["timelines"]) // len(new["variants"]) // 8
    timelines = []
    for start in range(0, len(old["timelines"]), old_stride):
        row = old["timelines"][start:start + old_stride]
        assert len(row) <= 42
        timelines.extend(row + [0] * (42 - len(row)))
    for skin, record in zip(skins, records):
        target_skin = len(old["variants"])
        assert int(new["variants"][skin]["id"]) == record["id"]
        for action in old["actions"]:
            for direction in range(8):
                row = source_clips[(skin * len(new["actions"]) + new["actions"].index(action)) * 8 + direction]
                start, count, duration, scale = row
                clips.append((len(frames) // 2, count, duration, scale))
                for frame in range(int(start), int(start + count)):
                    rect, other = source_frames[frame * 2:frame * 2 + 2]
                    frames.extend([rect, (other[0], other[1], page_map[int(other[2])], other[3] + palette_offset)])
        for direction in range(8):
            row = new["timelines"][(skin * 8 + direction) * new_stride:(skin * 8 + direction + 1) * new_stride]
            assert len(row) <= 42
            timelines.extend(row + [0] * (42 - len(row)))
        for key, path in new["sounds"].items():
            owner, cue = key.split(":") if ":" in key else (None, key)
            if owner is None or int(owner) == skin:
                if staged and not path.startswith("res://"):
                    raw = (source / path).read_bytes()
                    target = output / Path(path).name
                    if target.exists():
                        assert target.read_bytes() == raw, target
                    else:
                        target.write_bytes(raw)
                    path = "res://" + str(target.relative_to(ROOT))
                old["sounds"][f"{target_skin}:{cue}"] = path if path.startswith("res://") else "res://" + str((source / path).relative_to(ROOT))
        old["variants"].append(new["variants"][skin])
    assert clips[:len(preserved_clips)] == preserved_clips and frames[:len(preserved_frames)] == preserved_frames
    table = clips + frames
    table.extend([(0, 0, 0, 0)] * (-len(table) % width))
    (output / "frames.bin").write_bytes(b"".join(struct.pack("<4f", *row) for row in table))
    merged.save(output / "palette.png")
    old.update(pages=len(paths), atlas_paths=paths, clip_count=len(clips), timelines=timelines, timeline_stride=42)
    (output / "motions.json").write_text(json.dumps(old, separators=(",", ":")) + "\n")
    previous = json.loads((output / "species.json").read_text())
    assert not {r["id"] for r in previous} & {r["id"] for r in records}
    (output / "species.json").write_text(json.dumps(previous + records, ensure_ascii=False, indent=2) + "\n")


def combine_existing_species(data):
    output = ROOT / "assets/characters/crossgate/east_region"
    for bank in sorted({s["bank"] for s in data["species"]} - {"companion", "unavailable", "east_region"}):
        rows = [s for s in data["species"] if s["bank"] == bank]
        source = ROOT / "assets/characters/crossgate" / bank
        manifest = json.loads((source / "motions.json").read_text())
        if not {0, 1, 3, 5, 8, 9, 10} <= set(manifest["actions"]):
            continue
        records = [dict(id=s["id"], key=s["key"], name=s["name"], height=approved_height(bank, s["skin"], manifest), prepared_from=dict(bank=bank, skin=s["skin"])) for s in rows]
        append_native_bank(output, source, [s["skin"] for s in rows], records)


def native_page_index(folder=ROOT / "assets/characters/crossgate/east_region"):
    path = folder / "motions.json"
    data = json.loads(path.read_text())
    paths = data.get("atlas_paths", ["res://" + str((folder / f"atlas-{i}.png").relative_to(ROOT)) for i in range(data["pages"])])
    sizes = {Image.open(ROOT / p.removeprefix("res://")).size for p in paths}
    assert len(sizes) == 1 and next(iter(sizes))[0] == next(iter(sizes))[1]
    table = list(struct.iter_unpack("<4f", (folder / "frames.bin").read_bytes()))
    skin_pages = []
    for skin in range(len(data["variants"])):
        pages = set()
        for clip in table[skin * len(data["actions"]) * 8:(skin + 1) * len(data["actions"]) * 8]:
            start, count = map(int, clip[:2])
            for frame in range(start, start + count):
                pages.add(int(table[data["clip_count"] + frame * 2 + 1][2]))
        assert pages and max(pages) < len(paths)
        skin_pages.append(sorted(pages))
    records = json.loads((folder / "species.json").read_text())
    assert [r["id"] for r in records] == [r["id"] for r in data["variants"]]
    approved = {}
    for source in sorted((ROOT / "assets/characters/crossgate").glob("*/motions.json")):
        if source.parent.name in ["guard_pets", "east_region"]:
            continue
        manifest = json.loads(source.read_text())
        if isinstance(manifest.get("variants"), list):
            for skin, row in enumerate(manifest["variants"]):
                if isinstance(row, dict) and "id" in row and "standing_height" in row:
                    approved.setdefault(row["id"], dict(bank=source.parent.name, skin=skin))
    heights = []
    for record, variant in zip(records, data["variants"]):
        previous = record.get("prepared_from") or (approved.get(record["id"]) if "source_body_pixels" not in record else None)
        if previous:
            record["prepared_from"] = previous
            manifest = json.loads((ROOT / "assets/characters/crossgate" / previous["bank"] / "motions.json").read_text())
            record["height"] = approved_height(previous["bank"], previous["skin"], manifest)
        heights.append(record["height"])
        variant["height"] = record["height"]
    data.update(page_size=next(iter(sizes))[0], atlas_paths=paths, skin_pages=skin_pages,
                frame_count=max(int(row[0] + row[1]) for row in table[:data["clip_count"]]),
                # Direct source-key variants borrow body dimensions, not their reference bank's frames.
                variant_heights=heights, variant_sources=[r.get("prepared_from") for r in records])
    (folder / "species.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    path.write_text(json.dumps(data, separators=(",", ":")) + "\n")


def stage_native_refresh(skins, destination):
    """Rebind cached rows after an upstream repack; preserve every combat/size row."""
    folder = ROOT / 'assets/characters/crossgate/east_region'
    before = (folder / 'frames.bin').read_bytes()
    original = json.loads((folder / 'motions.json').read_text())
    manifest = json.loads(json.dumps(original))
    records = json.loads((folder / 'species.json').read_text())
    table = list(struct.iter_unpack('<4f', before)); output = bytearray(before)
    palette = Image.open(folder / 'palette.png').convert('RGBA')
    paths = list(manifest['atlas_paths']); changed = set(); reports = []
    for skin in skins:
        assert 'source_body_pixels' not in records[skin], 'Direct original-source art must not be refreshed from its body-fit reference'
        source = manifest['variant_sources'][skin]
        assert source and source['bank'] != 'east_region'
        upstream = ROOT / 'assets/characters/crossgate' / source['bank']
        data = json.loads((upstream / 'motions.json').read_text())
        raw = (upstream / 'frames.bin').read_bytes()
        rows_ = list(struct.iter_unpack('<4f', raw)); source_skin = int(source['skin'])
        assert data['variants'][source_skin]['id'] == manifest['variants'][skin]['id']
        page_paths = data.get('atlas_paths', [f'res://{upstream.relative_to(ROOT)}/atlas-{i}.png' for i in range(data['pages'])])
        frames = set(); pages = set()
        with Image.open(upstream / 'palette.png') as image:
            source_palette = image.convert('RGBA')
        def color_row(image, index):
            columns = image.width // 256
            x, y = index % columns * 256, index // columns
            return image.crop((x, y, x + 256, y + 1)).tobytes()
        for action_index, action in enumerate(manifest['actions']):
            for direction in range(8):
                clip = table[(skin * len(manifest['actions']) + action_index) * 8 + direction]
                source_clip = rows_[(source_skin * len(data['actions']) + data['actions'].index(action)) * 8 + direction]
                assert clip[1:] == source_clip[1:], 'Frame count, duration and pixel scale must stay exact'
                for offset in range(int(clip[1])):
                    frame, source_frame = int(clip[0]) + offset, int(source_clip[0]) + offset
                    rect, placement = rows_[data['clip_count'] + source_frame * 2:data['clip_count'] + source_frame * 2 + 2]
                    old = table[manifest['clip_count'] + frame * 2 + 1]
                    assert placement[:2] == old[:2], 'Refresh must not move original anchors'
                    assert color_row(source_palette, int(placement[3])) == color_row(palette, int(old[3])), 'Palette repair needs separate review'
                    path = page_paths[int(placement[2])]
                    if path not in paths: paths.append(path)
                    page = paths.index(path); pages.add(page); frames.add(frame)
                    row = manifest['clip_count'] + frame * 2
                    output[row * 16:(row + 2) * 16] = struct.pack('<8f', *rect, *placement[:2], page, old[3])
                    changed.update([row, row + 1])
        manifest['skin_pages'][skin] = sorted(pages)
        reports.append(dict(skin=skin, id=manifest['variants'][skin]['id'], upstream=source,
                            clips=len(manifest['actions']) * 8, frames=len(frames),
                            upstream_frames_sha256=sha(raw), upstream_motions_sha256=sha((upstream / 'motions.json').read_bytes())))
        manifest.setdefault('reused_source_hashes', {})[source['bank']] = {
            name: sha((upstream / name).read_bytes()) for name in ['frames.bin', 'motions.json', 'palette.png']}
    # Reject aliased frame ownership; a requested refresh cannot change another skin.
    for skin in range(len(manifest['variants'])):
        if skin in skins: continue
        for clip in table[skin * len(manifest['actions']) * 8:(skin + 1) * len(manifest['actions']) * 8]:
            assert all(manifest['clip_count'] + frame * 2 not in changed for frame in range(int(clip[0]), int(clip[0] + clip[1])))
    assert all(before[i:i+16] == output[i:i+16] for i in range(0, len(before), 16) if i // 16 not in changed)
    manifest['atlas_paths'] = paths; manifest['pages'] = len(paths)
    report = dict(skins=reports, old_frames_sha256=sha(before), new_frames_sha256=sha(output),
                  old_motions_sha256=sha((folder / 'motions.json').read_bytes()),
                  changed_frame_rows=len(changed), unrelated_rows_preserved=True,
                  palette_and_original_pages_preserved=True, activation='Staged; original RGBA and rendered review required.')
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'frames.bin').write_bytes(output)
    (destination / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
    (destination / 'preservation.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def actor_art(actors, scripts, dungeons, output=OUT):
    sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
    import cg_assets as cg
    import cg_library as lib
    catalog = cg.catalog()["entries"]
    animations = {}
    for row in catalog:
        animations.setdefault(row["id"], []).append(row["key"])
    art = {}; images = {}; npcs = []; blockers = []
    harbor = json.loads((OUT / "harbor.json").read_text()) if (OUT / "harbor.json").exists() else {}
    harbor_owners = {r["id"] for r in harbor.get("npcs", [])}
    # Terminal templates have a source-confirmed floor; ordinary template placement remains unverified.
    terminal_ids = {str(d["raw"][97]) for d in dungeons.values() if d["raw"][97].isdigit()}
    terminal_ids |= {str(d["raw"][99]) for d in dungeons.values() if d["raw"][99].isdigit()}
    for original in actors:
        row = dict(original); graphic = row["graphic"]; direction = row["direction"]
        row["inline_args"] = row["script"] if row["script"] not in scripts else ""
        row["quest_action"] = "east_event:" + row["id"]
        row["native_enemy"] = row["type"] == "StandEnemy"
        row["invisible"] = graphic in [0, 1] or row["type"] in ["Warp", "HouseWarp2", "Watch", "WatchEx"]
        row["token"] = f"{graphic}:{direction}"
        row["scenery"] = graphic < 14000 or row["type"] in ["HouseMaster", "Dengon", "Billboard", "Windowman"]
        row["rendered_elsewhere"] = False
        row["messages"] = ["這裡的原始對話尚待恢復。"]
        row["harbor_owner"] = row["id"] in harbor_owners
        original.update(row)
        terminal = row["generated_by"] is not None and row["id"] in terminal_ids
        if row["invisible"] or row["native_enemy"] and not terminal or row["generated_by"] is not None and not terminal or row["harbor_owner"]:
            continue
        token = row["token"]
        if token not in art:
            found = None
            for key in animations.get(graphic, []):
                _, _, clips = cg.actor(key)
                clip = next((c for c in clips if c["action"] == 0 and c["direction"] == direction), None)
                if clip is not None:
                    im, ox, oy = cg.frame_parts(key, clip["index"], 0)
                    found = dict(key=key, source_direction=direction); break
            if found is None:
                with lib.connection() as db:
                    source = db.execute("SELECT * FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1", (graphic,)).fetchone()
                if source is not None:
                    source = dict(source); im = lib.image_from_record(source["pack"], source["row"])
                    ox, oy = source["x"], source["y"]
                    found = dict(key=f"graphic:{graphic}", pack=source["pack"], row=source["row"])
            if found is None:
                blockers.append(dict(kind="npc_art", id=row["id"], source=row["source"],
                    graphic=graphic, direction=direction, reason="Exact source appearance/facing unavailable; event record retained."))
                row["art_missing"] = True
                if row["generated_by"] is None:
                    npcs.append(row)
                continue
            box = im.getbbox() or (0, 0, 1, 1); im = im.crop(box)
            images[token] = im
            art[token] = dict(origin=[ox + box[0], oy + box[1]],
                              rgba_sha256=sha(im.tobytes()), **found)
        if row["generated_by"] is None:
            npcs.append(row)
    positions = {}; x = y = line_height = 0; page = 0
    for token, im in images.items():
        assert im.width + 2 <= 2048 and im.height + 2 <= 16384, token
        if x + im.width + 2 > 2048:
            x = 0; y += line_height; line_height = 0
        if y + im.height + 2 > 16384:
            page += 1; x = y = line_height = 0
        art[token].update(atlas=page, rect=[x + 1, y + 1, *im.size])
        positions[token] = (page, x + 1, y + 1)
        x += im.width + 2; line_height = max(line_height, im.height + 2)
    paths = []
    for number in range(page + 1):
        height = max((py + images[token].height + 1 for token, (p, px, py) in positions.items() if p == number), default=1)
        atlas = Image.new("RGBA", (2048, height))
        for token, (p, px, py) in positions.items():
            if p == number:
                atlas.paste(images[token], (px, py))
        filename = "npc-atlas.png" if number == 0 else f"npc-atlas-{number}.png"
        output.mkdir(parents=True, exist_ok=True)
        atlas.save(output / filename)
        paths.append("res://" + str((output / filename).relative_to(ROOT)))
    return dict(npcs=npcs, art=art, atlas_paths=paths, art_blockers=blockers)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--pack", action="store_true", help="Prepare unimported compatible native enemy sheets once.")
    parser.add_argument('--refresh-native-skins', type=int, nargs='+', help='Stage reused skins against their current upstream atlas coordinates.')
    parser.add_argument('--native-refresh-output', type=Path, default=AUDIT / 'Native Refresh')
    args = parser.parse_args()
    if args.refresh_native_skins:
        assert not args.pack and not args.check
        report = stage_native_refresh(args.refresh_native_skins, args.native_refresh_output)
        print('EAST_NATIVE_REFRESH_STAGED', len(report['skins']), 'skins; unrelated rows preserved')
        return
    if args.check:
        data = json.loads((OUT / "population.json").read_text())
        actors, scripts, dungeons, maps, later, proofs = source_data()
        assert data["source_graphs"] == proofs
        assert data["scripts"] == scripts
        assert len(data["actors"]) == len(actors)
        for row in data["npcs"]:
            assert isinstance(row["id"], str) and row["quest_action"] == "east_event:" + row["id"]
        atlases = [Image.open(ROOT / path.removeprefix("res://")).convert("RGBA") for path in data["atlas_paths"]]
        for token, row in data["art"].items():
            image = atlases[row["atlas"]]
            x, y, w, h = row["rect"]
            assert sha(image.crop((x, y, x + w, y + h)).tobytes()) == row["rgba_sha256"], token
        for group in data["groups"].values():
            assert all(0 <= member[0] < len(data["species"]) for member in group["members"])
        manifests = {}
        for species in data["species"]:
            if species["bank"] == "unavailable":
                assert species["skin"] == -1
                continue
            bank = "guard_pets" if species["bank"] == "companion" else species["bank"]
            if bank not in manifests:
                manifests[bank] = json.loads((ROOT / "assets/characters/crossgate" / bank / "motions.json").read_text())
            assert int(manifests[bank]["variants"][species["skin"]]["id"]) == species["id"]
        for manifest in manifests.values():
            for bank, dependencies in manifest.get('reused_source_hashes', {}).items():
                for name, expected in dependencies.items():
                    assert sha((ROOT / 'assets/characters/crossgate' / bank / name).read_bytes()) == expected, f'Stale reused native bank: {bank}/{name}'
        print("EAST_POPULATION_CHECK", len(actors), "source actors; native pixels, scripts and member indices preserved")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    actors, scripts, dungeons, maps, later, proofs = source_data()
    data = dict(schema=1, source_maps=sorted(maps), source_graphs=proofs, actors=actors,
                scripts=scripts, later_or_inactive=later)
    data.update(encounter_data(actors, scripts, dungeons, maps))
    if args.pack:
        pack_new_species(data)
        data.update(encounter_data(actors, scripts, dungeons, maps))
        combine_existing_species(data)
        native_page_index()
        data.update(encounter_data(actors, scripts, dungeons, maps))
    data.update(actor_art(actors, scripts, dungeons))
    data["source_hashes"] = {n: sha((TABLES / n).read_bytes()) for n in ["encount.txt", "group.txt", "enemy.txt", "enemybase.txt"]}
    data["limits"] = ["Original scripts are inert data with original conditions, window order and source line numbers. Unknown conditions must remain gated.",
        "Native single-view NPC art retains original pixels/origins; unseen faces are unavailable.",
        "Encounter membership, levels, weights and follow-on pools are source data. The existing native combat owner adapts turn-based behavior."]
    (OUT / "population.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("EAST_POPULATION", len(actors), "actors;", len(data["npcs"]), "NPCs;", len(data["art"]), "native appearances;", len(data["species"]), "species;", len(data["groups"]), "groups;", len(data["bosses"]), "boss pools;", len(data["blockers"]), "encounter and", len(data["art_blockers"]), "art blockers")


if __name__ == "__main__":
    main()
