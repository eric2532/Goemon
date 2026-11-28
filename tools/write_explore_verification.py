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
    for row in maps.values():
        row['entrances'] = [e for e in row['entrances'] if not e.get('type', '').startswith('Generated ') and e.get('type') != 'Native field door']
    owners = {int(row["source"]): row for row in inventory.get("maps", [])}
    route_catalog = json.loads((ROOT / 'assets/maps/falan/explore-access.json').read_text())
    for source, owner in owners.items():
        if source not in maps and owner.get('available_source'):
            maps[source] = dict(map=source, name=owner['name'], catalog=owner.get('source_catalog', 'Existing native map owner'),
                                layout_complete=owner['layout_complete'], staged=False, native_layout_defined=True,
                                entrances=route_catalog['routes'].get(str(source), []), bosses=route_catalog['bosses'].get(str(source), []))
    route_history = list(read("routes-history.json").values())
    live_bosses = read("bosses-history.json")
    field_archive = {"%d:%s:%d:%s" % (int(row['map']), row['boss'], int(row.get('choice', 0)), key.rsplit(':', 1)[-1]): row
                     for key, row in read("field-continuous-journeys.json").get("encounters", {}).items()}
    field_archive.update({key: row for key, row in live_bosses.items() if row.get('setup_contract') == 'one-field-setup-then-walk-f-v1'})
    (OUT / "field-continuous-journeys.json").write_text(json.dumps(dict(qualification="Latest continuous field journey per encounter; local presentation reruns remain separate.", encounters=field_archive), ensure_ascii=False, indent=2) + "\n")
    boss_history = [dict(row,evidence_mode=key.rsplit(":",1)[-1]) for key,row in live_bosses.items()]
    alternative_cycles = read("ninja-selection-cycles-rendered.json").get("cycles", [])
    boss_history.extend(dict(row,evidence_mode=key.rsplit(":",1)[-1],evidence_file="field-continuous-journeys.json") for key,row in field_archive.items() if live_bosses.get(key, {}).get('setup_contract') != 'one-field-setup-then-walk-f-v1')
    blockers = list(inventory.get("blockers", []))
    landing_audit = read("landing-access-gaps.json")
    landing_blockers = landing_audit.get("script_landing_blockers", [])
    recovered_events = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/events/data.json').read_text())
    recovered_catalog = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())
    completed_sources = {int(row['id']) for row in recovered_catalog.get('layout_overrides', {}).values()}
    layout_review = [row for row in read('partial-layout-compatibility.json').get('maps', []) if int(row['source']) not in completed_sources]
    layout_pending = [row for row in layout_review if row.get('compatibility') == 'EXACT_RECORDED_TUPLES' or int(row['source']) in [15525,15530] and row.get('differences') == 1]
    layout_blockers = [dict(row, reason='The pinned reference differs from recorded client cells; a matching original layout is required before completing the uncached cells.')
                       for row in layout_review if row not in layout_pending]
    dialogue_blockers = recovered_events.get('message_blockers', [])
    script_blockers = recovered_events.get('script_blockers', [])
    active_scripts = read('active-script-access-gaps.json')
    for item in active_scripts.get('script_blockers', []):
        if not any(str(row.get('actor'))==str(item['actor'])and row.get('script')==item['script']for row in script_blockers):script_blockers.append(item)
    command_blockers = [dict(row,reason='Malformed original Warp command; no destination or executable repair is inferred.')for row in active_scripts.get('other_warps',[])]
    for item in dialogue_blockers:
        item['actors'] = [dict(actor=row['id'], source=row['source'], name=row['name']) for row in recovered_events['actors'].values() if row['script'] in item['scripts']]
    entrances = read("manual-access-routes.json").get("routes", []) + read("generated-access-routes.json").get("routes", []) + read("generated-return-routes.json").get("routes", []) + read("generated-floor-routes.json").get("routes", []) + read("native-field-routes.json").get("routes", []) + read("native-maze-floor-routes.json").get("routes", [])
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
        if owner.get("generated_terminal_bosses"):
            row["bosses"] = owner["generated_terminal_bosses"]
        row["runtime"] = owner.get("runtime", row["map"])
        row["runtime_owner"] = owner.get("runtime_owner", row.get("generated_owner", False))
        if row["map"] in [100, 300, 1000, 2000, 2400]:
            row["published_region_owner"] = {100: "Freyja region variants", 300: "Sokia region variants", 1000: "Falan city", 2000: "Il village in East region", 2400: "Alyut village in North region"}[row["map"]]
        row["landing_blockers"] = [entry for entry in landing_blockers if int(entry["source"]) == row["map"]]
        row["ordinary_doors"] = owner.get("doors", [])
        row["npc_fixes"] = []
        row["interaction_evidence"] = []
        for entrance in row["entrances"]:
            matches = [test for test in route_history if int(test["source"]) == row["map"]
                       and int(test.get("runtime", row["runtime"])) == int(row["runtime"])
                       and int(test["target"]) == int(entrance["target"])
                       and (entrance.get("type", "").startswith("Generated ") or
                            cell(test.get("cell", "")) == cell(entrance["cell"]) and
                            cell(test.get("landing", "")) == cell(entrance["landing"]))]
            verified = [test for test in matches if test.get("passed") and test.get("verified_transition")
                        and (test.get('return_walked') or test.get('ordinary_walk_contract') == 'continuous-entry-exit-v1' or test.get('after_full_victory'))]
            if entrance.get('victory_only'):
                entrance['access_stage'] = 'AFTER_FULL_BOSS_VICTORY'
                verified = [test for test in verified if test.get('after_full_victory')]
            entrance["verification"] = ("ORDINARY_WALK_ENTER_LEAVE_PASSED" if verified[-1].get("status", "").startswith("Original") else "WALK_F_ENTER_RETURN_PASSED") if verified else "PENDING"
            entrance["tests"] = matches
            if entrance.get('type', '').startswith('Generated '):
                entrance['tested_seeds'] = sorted({int(test['seed']) for test in verified if 'seed' in test})
            row["interaction_evidence"].extend(verified)
        tested = sum(e["verification"] != "PENDING" for e in row["entrances"])
        row["walk_interact_enter_leave"] = f"Script entrances {tested}/{len(row['entrances'])}; ordinary-door traversal pending"
        for boss in row["bosses"]:
            identities = [str(boss['actor'])]
            if row['map'] == 16508 and str(boss['actor']) == '81000':identities.append('ruby_slot')
            tests = [test for test in boss_history if (int(test["map"]) == row["runtime"] or int(test.get("source", -1)) == row["map"]) and str(test["boss"]) in identities]
            boss["tests"] = tests
            boss["alternative_cycle_tests"] = [dict(proof, evidence="ninja-selection-cycles-rendered.json") for proof in alternative_cycles if str(proof["actor"]) == str(boss["actor"])]
            passed = {test.get("choice", 0) for test in tests if test.get('visibility_contract') == 'prepared-original-pages-v1' and test.get('party_presentation_contract') == 'all-required-members-v1' and test.get("passed") and test.get("retry", {}).get("passed") and test.get("retry", {}).get("portal_walked")}
            rendered = {test.get("choice", 0) for test in tests if test.get("evidence_mode")=="rendered" and test.get('visibility_contract') == 'prepared-original-pages-v1' and test.get('party_presentation_contract') == 'all-required-members-v1' and test.get("passed") and test.get("retry", {}).get("passed") and test.get("retry", {}).get("portal_walked")}
            declarations = list(dict.fromkeys(boss["declarations"]))
            expected = {boss["declarations"].index(declaration) for declaration in declarations}
            boss["controls_portal_retry"] = "PASSED" if expected.issubset(passed) else "PENDING"
            boss["visible_approach_defeat_portal_retry"] = "PASSED" if expected.issubset(rendered) else "PENDING"
        tested = sum(b["visible_approach_defeat_portal_retry"] == "PASSED" for b in row["bosses"])
        controls = sum(b["controls_portal_retry"] == "PASSED" for b in row["bosses"])
        row["boss_portal_retry"] = f"Source boss controls/retries {controls}/{len(row['bosses'])}; rendered {tested}/{len(row['bosses'])}"
    for name in ["npc-rendered.json", "npc-headless.json", "npc-wind-rendered.json", "npc-wind-headless.json"] + [path.name for path in sorted(OUT.glob("npc-map-*.json"))]:
        for npc in read(name).get("npcs", []):
            source = next((source for source, owner in owners.items() if int(owner["runtime"]) == int(npc["map"])), int(npc["map"]))
            if source not in maps:
                maps[source] = {"map": source, "name": "Legacy city interior", "catalog": "assets/maps/falan/interior_data.gd", "layout_complete": True, "staged": False, "runtime": npc["map"], "runtime_owner": "legacy indoor owner", "entrances": [], "bosses": [], "npc_fixes": [], "walk_interact_enter_leave": "NPC approach only; doors pending", "boss_portal_retry": "No dungeon boss required"}
            maps[source]["npc_fixes"].append(dict(npc, evidence=name))
    journeys = []
    for path in sorted(OUT.glob("*-continuous-journey.json")):
        proof = read(path.name)
        journeys.append(dict(evidence=path.name, source_maps=proof.get('source_maps', []),
                             checks=proof.get('checks', 0), failures=proof.get('failures', 0),
                             passed=proof.get('passed', False), qualification=proof.get('qualification', ''),
                             stages=len(proof.get('stages', []))))
    for proof in boss_history:
        if proof.get('setup_contract') != 'one-field-setup-then-walk-f-v1':
            continue
        journey_maps = {int(stage['floor']) for stage in proof.get('field_route', []) if int(stage['floor']) > 0}
        journey_maps.add(300 if int(proof['map']) == 47017 else 100)
        if proof.get("retry", {}).get("portal_walked"):journey_maps.add(1000)
        journeys.append(dict(evidence=proof.get('evidence_file', 'bosses-history.json'), boss=proof['boss'], mode=proof['evidence_mode'],
                             source_maps=sorted(journey_maps), setup_contract=proof['setup_contract'],
                             passed=proof.get('passed', False) and proof.get('retry', {}).get('passed', False)
                                    and proof.get('retry', {}).get('portal_walked', False),
                             qualification=proof.get('qualification', ''), stages=len(proof.get('field_route', []))))
    for row in maps.values():
        row['continuous_journeys'] = [proof for proof in journeys if row['map'] in proof['source_maps']]
    native_maze_floors = [row for row in maps.values() if row["map"] in [51301,51302] + list(range(51201,51213))]
    for floor in native_maze_floors:
        stairs = [row for row in floor["entrances"] if row.get("type") == "Native maze stair"]
        floor["native_stair_verification"] = "PASSED" if stairs and all(row["verification"] != "PENDING" for row in stairs) else "PENDING"
    summary = {"source_maps": len(maps), "registered_original_owners": sum(row.get("runtime_owner") is True for row in maps.values()),
               "script_entrances_verified": sum(e.get("verification", "PENDING") != "PENDING" for row in maps.values() for e in row["entrances"]),
               "source_boss_actors_with_retry_verified": sum(b.get("controls_portal_retry") == "PASSED" for row in maps.values() for b in row["bosses"]),
               "source_boss_actors_rendered_verified": sum(b.get("visible_approach_defeat_portal_retry") == "PASSED" for row in maps.values() for b in row["bosses"]),
               "goemon_endpoints_with_retry_verified": len({test["boss"] for test in boss_history if str(test["boss"]).startswith("new-") and test.get('visibility_contract') == 'prepared-original-pages-v1' and test.get('party_presentation_contract') == 'all-required-members-v1' and test.get("passed") and test.get("retry", {}).get("passed") and test.get("retry", {}).get("portal_walked")}),
               "source_contract_blockers": len(blockers),
               "source_landing_blockers": len(landing_blockers),
               "native_maze_floors": len(native_maze_floors),
               "native_maze_floors_walked": sum(floor["native_stair_verification"] == "PASSED" for floor in native_maze_floors)}
    extra = [test for test in boss_history if not str(test["boss"]).isdigit() or str(test["boss"]) == "80023"]
    for row in maps.values():
        row['native_encounter_tests']=[test for test in extra if int(test['map'])==row['runtime']or int(test.get('source',-1))==row['map']]
        if row['native_encounter_tests']:row['boss_portal_retry']+='; native/Goemon control tests attached; full native roster audit pending'
    census["continuous_journeys"] = journeys
    census.update(qualification="Source census joined to per-interaction evidence. Ownership and graph checks are not normal-play verification. PENDING items remain unfinished; preserved unowned archival maps are not automatically intended Explore areas.", maps=list(maps.values()), summary=summary, blockers=blockers, shared_encounter_tests=extra)
    census['native_maze_floors'] = [dict(map=floor['map'],runtime=floor['runtime'],name=floor['name'],verification=floor['native_stair_verification']) for floor in native_maze_floors]
    census['landing_access_audit'] = landing_audit
    census['source_zone_blockers'] = inventory.get('source_zone_blockers', [])
    census['missing_script_destinations'] = inventory.get('missing_script_destinations', [])
    census['source_dialogue_blockers'] = dialogue_blockers
    census['source_script_blockers'] = script_blockers
    census['source_command_blockers'] = command_blockers
    census['required_source_access_pending'] = active_scripts.get('required_actors',[])
    census['source_layout_blockers'] = layout_blockers
    census['source_layout_recovery_pending'] = layout_pending
    (OUT / "map-checklist.json").write_text(json.dumps(census, ensure_ascii=False, indent=2) + "\n")
    with (OUT / "map-checklist.csv").open("w") as file:
        writer = csv.writer(file)
        writer.writerow(["source map", "name", "runtime", "registered owner", "script entrance verification", "boss/portal/retry verification", "NPC checks", "ordinary doors", "continuous journeys passed"])
        for source, row in sorted(maps.items()):
            writer.writerow([source, row["name"], row["runtime"], row["runtime_owner"], row["walk_interact_enter_leave"], row["boss_portal_retry"], len(row["npc_fixes"]), len(row.get("ordinary_doors", [])), sum(proof["passed"] for proof in row["continuous_journeys"])])
    (OUT / "blockers.json").write_text(json.dumps(dict(boss_encounters=blockers, landing_access=landing_blockers, ambient_parties=inventory.get('source_zone_blockers', []), source_dialogue=dialogue_blockers, source_scripts=script_blockers, source_commands=command_blockers,
        partial_layouts=layout_blockers, missing_destinations=inventory.get('missing_script_destinations', [])), ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
