#!/usr/bin/env python3
"""Inventory prepared Explore geography and explicit source-script transfers.

This is a source inventory, never evidence that a player traversed a route.
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/Other Files/Asset Toolkit/Explore Access"
ROUTES = ROOT / "assets/maps/falan/explore-access.json"
CATALOGS = [
    "assets/maps/original_crossgate/catalog.json",
    "assets/maps/falan/sokia/fixed/catalog.json",
    "assets/maps/original_crossgate/university/catalog.json",
    "assets/maps/original_crossgate/elsa/catalog.json",
    "assets/maps/original_crossgate/east/catalog.json",
    "assets/maps/original_crossgate/sokia_server/catalog.json",
    "assets/maps/original_crossgate/sokia_server/water/catalog.json",
    "assets/maps/original_crossgate/freyja_trial/catalog.json",
    "assets/maps/original_crossgate/sokia_wind_tower/catalog.json",
    "assets/maps/original_crossgate/sokia_desert_temple/catalog.json",
    "assets/maps/original_crossgate/sokia_dragon_summit/catalog.json",
    "assets/maps/falan/sokia/cape/access/catalog.json",
    "assets/maps/falan/black_prayer/events/return-maps/catalog.json",
    "assets/maps/original_crossgate/explore_recovered/catalog.json",
]
EVENTS = [
    "assets/maps/falan/east_region/population.json",
    "assets/maps/falan/black_prayer/events/data.json",
    "assets/maps/falan/sokia/cape/access/events/data.json",
    *[str(p.relative_to(ROOT)) for p in sorted((ROOT / "assets/maps/original_crossgate").glob("*/events/data.json"))],
    "assets/maps/original_crossgate/sokia_server/water/events/data.json",
]


def transfers(actor, scripts):
    result = []
    if actor.get("type", "").lower() == "warp":
        fields = actor.get("script", "").split("|")
        if len(fields) >= 4 and all(re.fullmatch(r"-?\d+", x) for x in fields[:4]):
            result.append(tuple(map(int, fields[:4])))
    script = scripts.get(actor.get("script", ""), {})
    lines = script.get("lines", [])
    if not lines:
        lines = [line for block in script.get("blocks", []) for line in block.get("lines", [])]
    for _, text in lines:
        match = re.match(r"\s*Warp\s+0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$", text, re.I)
        if match:
            result.append((0, *map(int, match.groups())))
    return sorted(set(row for row in result if row[0] == 0 and row[1] > 0))


def build():
    maps, routes, bosses = {}, {}, []
    for path in CATALOGS:
        data = json.loads((ROOT / path).read_text())
        for row in data["maps"].values():
            source = int(row["id"])
            maps[source] = {
                "map": source, "name": row.get("title", ""), "catalog": path,
                "layout_complete": row.get("layout_complete", row.get("recorded", 0) == row.get("cells", -1)),
                "staged": row.get("sokia_visual_only", False),
                "entrances": [], "npc_fixes": [], "bosses": [],
                "walk_interact_enter_leave": "PENDING", "boss_portal_retry": "PENDING",
            }
    seen = set()
    for path in EVENTS:
        data = json.loads((ROOT / path).read_text())
        actors = data.get("actors", [])
        if isinstance(actors, dict):
            actors = actors.values()
        for actor in actors:
            source = int(actor["source"])
            for _, target, x, y in transfers(actor, data.get("scripts", {})):
                cell = list(map(int, actor["cell"]))
                key = (source, *cell, target, x, y)
                if key in seen:
                    continue
                seen.add(key)
                row = {"actor": str(actor["id"]), "type": actor.get("type", ""), "name": actor.get("name", ""), "source": source, "cell": cell,
                       "target": target, "landing": [x, y], "evidence": path, "script": actor.get("script", "")}
                routes.setdefault(str(source), []).append(row)
                if source in maps:
                    maps[source]["entrances"].append(row)
            text = actor.get("script", "")
            script = data.get("scripts", {}).get(text, {})
            lines = script.get("lines", []) or [line for block in script.get("blocks", []) for line in block.get("lines", [])]
            fights = [text] if actor.get("type", "").lower() == "standenemy" else [t for _, t in lines if re.match(r"\s*Encount\b", t, re.I)]
            if fights:
                boss = {"actor": str(actor["id"]), "source": source, "cell": actor["cell"], "name": actor.get("name", ""), "declarations": fights, "evidence": path, "visible_approach_defeat_portal_retry": "PENDING"}
                bosses.append(boss)
                if source in maps:
                    maps[source]["bosses"].append(boss)
    return maps, routes, bosses


def main():
    maps, routes, bosses = build()
    OUT.mkdir(parents=True, exist_ok=True)
    by_source = {}
    for boss in bosses:
        by_source.setdefault(str(boss["source"]), []).append(boss)
    ROUTES.write_text(json.dumps({"schema": 1, "routes": routes, "bosses": by_source}, ensure_ascii=False, indent=1) + "\n")
    inventory = {"qualification": "Source census only. PENDING is not reachable/verified. Includes preserved maps outside the normal Explore graph.", "maps": list(maps.values()), "scripted_fights": bosses}
    (OUT / "map-checklist.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n")
    with (OUT / "map-checklist.csv").open("w") as f:
        writer = csv.writer(f)
        writer.writerow(["source map", "name", "staged", "layout complete", "script entrances", "script fights", "walk/interact/enter/leave", "boss/portal/retry"])
        for source, row in sorted(maps.items()):
            writer.writerow([source, row["name"], row["staged"], row["layout_complete"], len(row["entrances"]), len(row["bosses"]), row["walk_interact_enter_leave"], row["boss_portal_retry"]])
    print(f"{len(maps)} source maps; {sum(map(len, routes.values()))} explicit transfers; {len(bosses)} fight declarations. Traversal verification pending.")


if __name__ == "__main__":
    main()
