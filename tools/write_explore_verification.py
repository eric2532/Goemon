#!/usr/bin/env python3
"""Join the source census to actual interaction evidence, retaining pending work."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/Other Files/Asset Toolkit/Explore Access"


def read(name, default=None):
    path = OUT / name
    return json.loads(path.read_text()) if path.exists() else ({} if default is None else default)


def cell(value):
    if isinstance(value, list):
        return tuple(map(int, value))
    return tuple(int(x.strip()) for x in value.strip("() ").split(",")) if value else ()


def main():
    census = read("map-checklist.json")
    inventory = read("runtime-inventory.json")
    maps = {int(row["map"]): row for row in census["maps"]}
    owners = {int(row["source"]): row for row in inventory.get("maps", [])}
    route_history = list(read("routes-history.json").values())
    boss_history = list(read("bosses-history.json").values())
    blockers = list(inventory.get("blockers", []))
    entrances = read("manual-access-routes.json").get("routes", []) + read("generated-access-routes.json").get("routes", []) + read("generated-floor-routes.json").get("routes", [])
    for entrance in entrances:
        if entrance.get('type') == 'Generated floor stair':
            source = int(entrance['source'])
            maps.setdefault(source, dict(map=source, name=entrance['name'], catalog='assets/maps/falan/explore-dungeon-specs.gd', layout_complete=True, staged=False, generated_owner=True, entrances=[], bosses=[]))
        row = maps.get(int(entrance["source"]))
        if row is None:
            continue
        if not any(cell(old["cell"]) == cell(entrance["cell"]) and old["target"] == entrance["target"] and cell(old["landing"]) == cell(entrance["landing"]) for old in row["entrances"]):
            row["entrances"].append(entrance)
    for row in maps.values():
        owner = owners.get(row["map"], {})
        row["runtime"] = owner.get("runtime", row["map"])
        row["runtime_owner"] = owner.get("runtime_owner", row.get("generated_owner", False))
        if row["map"] in [100, 300, 1000, 2000, 2400]:
            row["published_region_owner"] = {100: "Freyja region variants", 300: "Sokia region variants", 1000: "Falan city", 2000: "Il village in East region", 2400: "Alyut village in North region"}[row["map"]]
        row["ordinary_doors"] = owner.get("doors", [])
        row["npc_fixes"] = []
        row["interaction_evidence"] = []
        for entrance in row["entrances"]:
            matches = [test for test in route_history if int(test["source"]) == row["map"]
                       and int(test["target"]) == int(entrance["target"])
                       and (entrance.get("type") == "Generated branch access" or
                            cell(test.get("cell", "")) == cell(entrance["cell"]) and
                            cell(test.get("landing", "")) == cell(entrance["landing"]))]
            verified = [test for test in matches if test.get("passed") and test.get("verified_transition")]
            entrance["verification"] = ("ORDINARY_WALK_ENTER_LEAVE_PASSED" if verified[-1].get("status", "").startswith("Original") else "WALK_F_ENTER_RETURN_PASSED") if verified else "PENDING"
            entrance["tests"] = matches
            row["interaction_evidence"].extend(verified)
        tested = sum(e["verification"] != "PENDING" for e in row["entrances"])
        row["walk_interact_enter_leave"] = f"Script entrances {tested}/{len(row['entrances'])}; ordinary-door traversal pending"
        for boss in row["bosses"]:
            tests = [test for test in boss_history if (int(test["map"]) == row["runtime"] or int(test.get("source", -1)) == row["map"]) and str(test["boss"]) == str(boss["actor"])]
            boss["tests"] = tests
            passed = {test.get("choice", 0) for test in tests if test.get("passed") and test.get("retry", {}).get("passed")}
            declarations = list(dict.fromkeys(boss["declarations"]))
            expected = {boss["declarations"].index(declaration) for declaration in declarations}
            boss["visible_approach_defeat_portal_retry"] = "PASSED" if expected.issubset(passed) else "PENDING"
        tested = sum(b["visible_approach_defeat_portal_retry"] == "PASSED" for b in row["bosses"])
        row["boss_portal_retry"] = f"Source boss choices/retries {tested}/{len(row['bosses'])}"
    for name in ["npc-rendered.json", "npc-headless.json", "npc-wind-rendered.json", "npc-wind-headless.json"]:
        for npc in read(name).get("npcs", []):
            source = next((source for source, owner in owners.items() if int(owner["runtime"]) == int(npc["map"])), int(npc["map"]))
            if source not in maps:
                maps[source] = {"map": source, "name": "Legacy city interior", "catalog": "assets/maps/falan/interior_data.gd", "layout_complete": True, "staged": False, "runtime": npc["map"], "runtime_owner": "legacy indoor owner", "entrances": [], "bosses": [], "npc_fixes": [], "walk_interact_enter_leave": "NPC approach only; doors pending", "boss_portal_retry": "No dungeon boss required"}
            maps[source]["npc_fixes"].append(dict(npc, evidence=name))
    summary = {"source_maps": len(maps), "registered_original_owners": sum(row.get("runtime_owner") is True for row in maps.values()),
               "script_entrances_verified": sum(e.get("verification", "PENDING") != "PENDING" for row in maps.values() for e in row["entrances"]),
               "source_boss_actors_with_retry_verified": sum(b.get("visible_approach_defeat_portal_retry") == "PASSED" for row in maps.values() for b in row["bosses"]),
               "goemon_endpoints_with_retry_verified": len({test["boss"] for test in boss_history if str(test["boss"]).startswith("new-") and test.get("passed") and test.get("retry", {}).get("passed")}),
               "source_contract_blockers": len(blockers)}
    extra = [test for test in boss_history if not str(test["boss"]).isdigit() or str(test["boss"]) == "80023"]
    census.update(qualification="Source census joined to per-interaction evidence. Ownership and graph checks are not normal-play verification. PENDING items remain unfinished; preserved unowned archival maps are not automatically intended Explore areas.", maps=list(maps.values()), summary=summary, blockers=blockers, shared_encounter_tests=extra)
    (OUT / "map-checklist.json").write_text(json.dumps(census, ensure_ascii=False, indent=2) + "\n")
    with (OUT / "map-checklist.csv").open("w") as file:
        writer = csv.writer(file)
        writer.writerow(["source map", "name", "runtime", "registered owner", "script entrance verification", "boss/portal/retry verification", "NPC checks", "ordinary doors"])
        for source, row in sorted(maps.items()):
            writer.writerow([source, row["name"], row["runtime"], row["runtime_owner"], row["walk_interact_enter_leave"], row["boss_portal_retry"], len(row["npc_fixes"]), len(row.get("ordinary_doors", []))])
    (OUT / "blockers.json").write_text(json.dumps(blockers, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
