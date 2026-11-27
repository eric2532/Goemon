"""Publish source doors while retaining actor conditions, time masks and battle relocations."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "build/Other Files/Asset Toolkit/East Gate Region"
OUT = ROOT / "assets/maps/falan/east_region/routes.json"
GRAPHS = [REPORT / p for p in ["Source Audit/graph.json", "Akelufa Source Audit/graph.json",
    "Verification/Goral Source Audit/inventory.json", "Harbor Quest Source Audit/graph.json",
    "Version Expansion Source Audit/graph.json"]]


def normalize(graph):
    if "edges" not in graph:
        return graph
    kinds = {"static_warp": "fixed warp", "event_warp": "script Warp",
             "encounter_victory": "script Encount", "inline_encounter_victory": "inline StandEnemy"}
    return dict(graph, maps=[row["id"] for row in graph["maps"]],
        boundaries=[int(row["target"]) for row in graph["boundaries"]],
        links=[dict(row, source=row["map"], landing=row.get("arrival"),
                    kind=kinds.get(row["kind"], row["kind"]), actor=row.get("npc_id"))
               for row in graph["edges"]])


def trigger_bounds(actor, script):
    """The broad phase includes source XPos/YPos tests; the event engine applies each exact condition."""
    x, y = actor["cell"]
    bounds = [x, y, x, y]
    for _, line in script.get("lines", []):
        for axis, op, value in re.findall(r"\b([XY])Pos\s*(==|>=|<=|>|<)\s*(-?\d+)", line, re.I):
            i = 0 if axis.lower() == "x" else 1
            value = int(value) + (1 if op == ">" else -1 if op == "<" else 0)
            bounds[i] = min(bounds[i], value)
            bounds[i + 2] = max(bounds[i + 2], value)
    return bounds


def compile_graphs(graphs, population, harbor):
    graphs = [normalize(g) for g in graphs]
    owned = set().union(*(set(g["maps"]) for g in graphs))
    owned.update(int(n["floor"]) for n in harbor.get("npcs", []))
    owned.update(m for ship in harbor.get("ships", {}).values() for m in ship["maps"])
    owned.discard(100)
    boundaries = set().union(*(set(g["boundaries"]) for g in graphs)) - owned
    fixed = {}; inline = {}; events = {}; gates = {}
    for graph in graphs:
        for link in graph["links"]:
            target = link.get("target"); source = link["source"]
            cell = link.get("cell"); landing = link.get("landing"); kind = link["kind"]
            if source not in owned and source != 100:
                continue
            if target not in owned | boundaries:
                continue
            key = (kind, source, tuple(cell or []), target, tuple(landing or []),
                   str(link.get("actor", "")), link.get("line"))
            if kind == "fixed warp":
                if source == 11033 and target == 11032:
                    gates[key] = dict(link, runtime="NPC 5649 retains the level/item/equipment gate.")
                elif cell and landing:
                    row = [source, *cell, target, *landing]
                    fixed[tuple(row)] = row
            elif kind == "inline Warp":
                fields = link.get("raw", "").split("|")
                inline[(source, str(link.get("actor")))] = dict(link,
                    time_mask=int(fields[4]) if len(fields) > 4 and fields[4].isdigit() else 15)
            elif kind == "HouseWarp2" and cell:
                reverse = next((r for r in graph["links"] if r["kind"] == "fixed warp"
                                and r["source"] == target and r["target"] == source), None)
                if reverse:
                    row = [source, *cell, target, *reverse["cell"]]
                    fixed[tuple(row)] = row
                else:
                    gates[key] = dict(link, runtime="Housing needs a source-confirmed return threshold.")
            elif kind.lower().startswith(("script", "inline")):
                events[key] = link
    automatic = []
    for actor in population.get("actors", []):
        if actor.get("generated_by") is not None or actor["type"] not in ["WatchEvent", "WatchEx", "Warp", "StandEnemy"]:
            continue
        row = dict(actor=str(actor["id"]), source=actor["source"], type=actor["type"],
                   bounds=trigger_bounds(actor, population.get("scripts", {}).get(actor["script"], {})),
                   cooldown_ms=max(750, int(actor["raw"][18] or 0)), source_line=actor["source_line"])
        if actor["type"] == "Warp":
            fields = actor["script"].split("|")
            row["time_mask"] = int(fields[4]) if len(fields) > 4 and fields[4].isdigit() else 15
        automatic.append(row)
    return dict(schema=2, fixed_maps=sorted(owned), fixed=sorted(fixed.values()),
        inline_warps=list(inline.values()), event_links=list(events.values()), automatic=automatic,
        gated_static_rows=list(gates.values()), boundaries=sorted(boundaries),
        limits=["Scripted and battle transfers stay attached to their source actors and condition programs.",
                "Source100 city/village seams retain the existing normal walking owner.",
                "Housing uses the source-confirmed reverse threshold; no new rooms or routes are inferred."])


def prepare():
    paths = [p for p in GRAPHS if p.exists()]
    population = json.loads((OUT.parent / "population.json").read_text())
    harbor = json.loads((OUT.parent / "harbor.json").read_text())
    result = compile_graphs([json.loads(p.read_text()) for p in paths], population, harbor)
    result["source_graphs"] = [dict(path=str(p.relative_to(ROOT)),
        sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths]
    return result


if __name__ == "__main__":
    data = prepare(); OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("EAST_ROUTES", len(data["fixed_maps"]), "maps;", len(data["fixed"]), "fixed doors;",
          len(data["inline_warps"]), "time-gated warps;", len(data["event_links"]), "actor transfers")
