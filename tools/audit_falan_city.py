"""Inventory original Falan city buildings and reachable rooms without entering the countryside or palace."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

from PIL import Image

from recover_falan_proportions import CIVIC

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/Other Files/Asset Toolkit/Falan City Reconstruction"
DISTRICTS = {
    "northwest": "Northwest guild, workshop and residential lanes",
    "cathedral": "Northern cathedral and gardens",
    "northeast": "Northeast employment office and residential lanes",
    "west_gate": "West gate street and western hospital",
    "east_gate": "East gate street and eastern hospital",
    "castle_approach": "City-side castle ring and four bridge approaches",
    "west_market": "Western weapon, armour and magic shops",
    "east_market": "Eastern shops and bank",
    "south_boulevard": "Southern boulevard, plazas and south gate",
    "southwest": "Southwest arena and residential streets",
    "southeast": "Southeast mansion, inn and residential streets",
}


def district(x, y):
    if y < 70:
        return "northwest" if x < 135 else "northeast" if x > 170 else "cathedral"
    if y <= 105:
        return "west_gate" if x < 135 else "east_gate" if x > 170 else "castle_approach"
    if y <= 140:
        return "west_market" if x < 145 else "east_market" if x > 160 else "south_boulevard"
    return "south_boulevard" if 135 <= x <= 170 else "southwest" if x < 135 else "southeast"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_library as library

    directory = source / "godot/assets/exploration"
    world = json.loads((directory / "world.json").read_text())
    manifest = json.loads((directory / "manifest.json").read_text())["map"]
    native = source / "data/crossgate/source" / manifest["source"]
    width, height, ground, objects, _ = library.parse_map(native.read_bytes())
    assert sha(native) == manifest["sha256"], "The preserved city map must match its recovered manifest"
    architecture = json.loads((ROOT / "assets/maps/falan/city_architecture.json").read_text())
    specials = json.loads((ROOT / "assets/maps/falan/city_building_surfaces.json").read_text())
    known = {int(s) for s in architecture["graphics"]}
    known.update(r["reference_graphic"] for r in specials["composites"])
    known.update(r[0] for r in CIVIC.values())
    known.add(10601)  # The mansion's two pavilion components share its existing owner.
    lookup = library.serial_index()
    buildings = []
    missing = []
    for i, serial in enumerate(objects):
        e = lookup.get(serial, {})
        fort = 10640 <= serial <= 10662
        large = not fort and min(e.get("w", 0), e.get("h", 0)) > 150 and min(e.get("east", 0), e.get("south", 0)) >= 3
        if serial not in known and not large:
            continue
        x, y = i % width, i // width
        row = {"graphic": serial, "cell": [x, y], "district": district(x, y),
               "world_center": [3 * (y - 134) - 1.5 * (e["south"] - 1),
                                3 * (153 - x) - 1.5 * (e["east"] - 1)],
               "footprint": [e["east"], e["south"]], "represented": serial in known}
        buildings.append(row)
        if not row["represented"]:
            missing.append(row)
    pending = [1000]
    rooms = {1000: {"district": "castle_approach"}}
    edges = []
    boundaries = []
    for map_id in pending:
        for warp in world["portals"].get(str(map_id), []):
            target = warp["destination"]
            owner = district(*warp["sourceCell"]) if map_id == 1000 else rooms[map_id]["district"]
            row = dict(warp, source=map_id, district=owner)
            if target == 100 or 1500 <= target < 1540 or target >= 59500:
                boundaries.append(row)
                continue
            edges.append(row)
            if target not in rooms:
                rooms[target] = {"id": target, "district": owner, "via": map_id,
                                 "name": world["maps"][str(target)]["name"],
                                 "source": world["maps"][str(target)]["source"]}
                pending.append(target)
    del rooms[1000]
    encoded = (ROOT / "assets/maps/falan/interior_data.gd").read_text()
    grids = {int(i): (int(x), int(y), bytes.fromhex(bits)) for i, x, y, bits in re.findall(
        r'^ (\d+):\[Vector2i\((\d+),(\d+)\),Vector2\([^)]*\),"([a-f0-9]+)"\]', encoded, re.M)}
    for row in rooms.values():
        path = source / "data/crossgate/source" / row["source"]
        row["source_present"] = path.is_file()
        row["sha256"] = sha(path) if path.is_file() else None
        info = json.loads((directory / world["maps"][str(row["id"])]["file"]).read_text())["map"]
        navigation = info["navigation"]
        walk = (directory / navigation["file"]).read_bytes()
        sw, sh = navigation["width"], navigation["height"]
        cw, ch, bits = grids[row["id"]]
        expected = [bool(walk[y * sw + x]) for x in reversed(range(sw)) for y in range(sh)]
        actual = [bool(bits[i // 8] & (1 << (i % 8))) for i in range(cw * ch)]
        row["navigation_size"] = [cw, ch]
        row["navigation_matches"] = (cw, ch) == (sh, sw) and expected == actual
        row["navigation_sha256"] = sha(directory / navigation["file"])
    runtime_doors = {}
    current = None
    for line in encoded.split("const DOORS={", 1)[1].splitlines():
        match = re.match(r" (\d+):\[", line)
        if match:
            current = int(match[1])
            runtime_doors[current] = []
        for match in re.finditer(r"\[Vector2\(([-\d.]+),([-\d.]+)\),(\d+),Vector2\(([-\d.]+),([-\d.]+)\)\]", line):
            runtime_doors[current].append(tuple(map(float, match.groups())))

    def point(map_id, cell):
        x, y = cell
        if map_id == 1000:
            return 3 * (y - 134), 3 * (153 - x)
        h, w, _ = grids[map_id]
        return 3 * (y - h // 2), 3 * (w // 2 - x)

    for edge in edges:
        at = point(edge["source"], edge["sourceCell"])
        arrival = point(edge["destination"], edge["destinationCell"])
        candidates = [r for r in runtime_doors.get(edge["source"], []) if int(r[2]) == edge["destination"]]
        distance = lambda r: max(math.dist(r[:2], at), math.dist(r[3:], arrival))
        edge["runtime_delta"] = min(map(distance, candidates), default=999.0)
    return {"sources": {"city": str(native), "city_sha256": sha(native),
                        "world_sha256": sha(directory / "world.json"), "warp_reference": world["reference"],
                        "warp_notes": world["notes"]},
            "dimensions": [width, height], "districts": DISTRICTS, "buildings": buildings,
            "missing_buildings": missing, "rooms": list(rooms.values()), "warps": edges,
            "boundary_connections": boundaries,
            "empty_trimmed_rows": all(v == 0 for v in ground[291 * width:] + objects[291 * width:])}, manifest


def overview(directory, manifest):
    scale = .2
    canvas = Image.new("RGBA", tuple(round(v * scale) for v in manifest["size"]), "#273b38")
    for row in manifest["groundTiles"] + manifest["scenery"]:
        with Image.open(directory / row["file"]) as image:
            image = image.convert("RGBA")
            image = image.resize(tuple(max(1, round(v * scale)) for v in image.size), Image.Resampling.LANCZOS)
            canvas.alpha_composite(image, tuple(round(v * scale) for v in row["position"]))
    canvas.convert("RGB").save(OUT / "original-city-overview.jpg", quality=94)


def checklist(data):
    lines = ["# Falan City source checklist", "", "Generated from the preserved 300 × 300 map and original warp references.",
             "World coordinates: `(3 × (source_y − 134), 3 × (153 − source_x))`; 3 metres per source tile.",
             "The omitted final nine source rows contain no ground or objects.", "",
             "| District | Original building components | Reachable city rooms/floors | Status |", "|---|---:|---:|---|"]
    for key, title in DISTRICTS.items():
        count = sum(r["district"] == key for r in data["buildings"])
        rooms = [r["id"] for r in data["rooms"] if r["district"] == key]
        lines.append(f"| {title} | {count} | {', '.join(map(str, rooms)) or '—'} | Addressed: source layout retained; changes and checks recorded in the reconstruction report. |")
    lines += ["", "## Every reachable city room", "", "| Map | Parent map | District | Original reference title | Original walking grid |",
              "|---:|---:|---|---|---|"]
    for row in data["rooms"]:
        lines.append(f"| {row['id']} | {row['via']} | {row['district']} | {row['name']} | {'exact' if row['navigation_matches'] else 'MISMATCH'} |")
    lines += ["", "## Scope boundaries", "",
              "Map 100 is countryside. Maps 1500–1539 are the castle connection/interior boundary. The three city-access annexes 1540, 1541 and 1542 are listed and their original grids/returns are verified, with existing interior art preserved. No palace interior is rebuilt. Elsa content is excluded.",
              "", f"All {len(data['warps'])} scoped original warp records retain their destination. Existing adjacent trigger cells may share one doorway marker, within one original 3-metre tile; these preserved groups are recorded individually in source-inventory.json.",
              "", "## Reference limitations", "",
              "The project's cached world.json connections are reconstructed community-reference warps. This pass verifies against that supplied graph; it does not establish original live-server restrictions. The graph identifies many rooms only as 建築內部, without independently verified shop identities. Original isometric art constrains the visible faces; unseen rear faces, depth and physical heights are inferred continuations. The raw warp/NPC/rental-event batch is recorded in Visual Continuation/fallback-audit.json: one duplicate generic entrance was resolved to existing room 1542; 31 unmatched entrances retain their reusable rooms. Graphic 10310 has conditional NPC routes to raw maps 1193/1194 and 21005, but their item/event predicate semantics are missing, so existing behavior is preserved."]
    runtime = OUT / "after/runtime.json"
    if runtime.is_file():
        homes = json.loads(runtime.read_text()).get("fallback_homes", [])
        lines += ["", "## Preserved extra entrances with a specific source blocker", "",
                  f"All {len(homes)} entrances below retain the existing reusable room and their own return context. Batch checks found no verified matching static or event route; per-building evidence is in Visual Continuation/fallback-audit.json.",
                  "", "| Saved house anchor | Door in world X/Z | Blocker |", "|---|---|---|"]
        for home in homes:
            lines.append(f"| {home['anchor']} | {home['at']} | No matching original room/warp reference. |")
    (OUT / "source-checklist.md").write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT.parent / "Magic Power")
    parser.add_argument("--overview", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    data, manifest = inventory(args.source)
    (OUT / "source-inventory.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    checklist(data)
    if args.overview:
        overview(args.source / "godot/assets/exploration", manifest)
    assert not data["missing_buildings"], data["missing_buildings"]
    assert len(data["rooms"]) == 80 and all(r["source_present"] for r in data["rooms"])
    assert all(r["navigation_matches"] for r in data["rooms"])
    assert all(e["runtime_delta"] <= 3.01 for e in data["warps"]), [e["id"] for e in data["warps"] if e["runtime_delta"] > 3.01]
    assert data["empty_trimmed_rows"]
    print(f"PASS: {len(data['buildings'])} original building components; all {len(data['rooms'])} city rooms including three preserved annexes; no unrepresented large building")


if __name__ == "__main__":
    main()
