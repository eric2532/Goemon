"""Register missing source-configured branches in the existing maze adapter.

Original fixed maps are untouched. Generated topology remains the game's existing
room-graph adaptation; source dimensions, floor counts, art and party pools persist.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    base = ROOT / "assets/maps/original_crossgate"
    dragon = json.loads((base / "sokia_dragon_summit/encounters.json").read_text())
    desert = json.loads((base / "sokia_desert_temple/encounters.json").read_text())
    specs = {}
    branches = dragon["generated_branches"] + [desert["generated_approach"]]
    assert sum(int(b["raw"][39]) for b in branches) == 77
    laboratory = json.loads((base / 'explore_recovered/encounters.json').read_text())
    branches.append(laboratory['generated_branch'])
    for branch in branches:
        raw = branch["raw"];config = int(branch["config"])
        assert int(raw[3]) == config
        spec = dict(first=7400000+config*100, minimum=int(raw[39]), maximum=int(raw[40]),
            size=list(map(int, raw[41:45])), ground=int(raw[22]), stairs=list(map(int, raw[34:36])),
            title=raw[0], entry=[int(raw[9]), int(raw[10]), int(raw[11])], end=list(map(int, raw[15:18])),
            entry_rect=list(map(int, raw[10:14])), frozen=False, outdoor=False, east=True, sokia=True,
            range_bags=True, source_levels_exact_interval=True, config=config, source_template=int(raw[7]),
            source_entrance_graphics=list(map(int, raw[30:32])), source_fixed_markers=list(map(int, raw[32:34])),
            source_warp_graphics=list(map(int, raw[30:36])), source_decorations=[],
            source_walls=list(map(int, raw[25:30])), terminal_enemy=0, terminal_enemy_count=0, terminal_npc=0,
            terminal_placement=-1, box_amount=int(raw[54]), encounter=int(raw[49]), levels=list(map(int, raw[50:52])),
            qualification="Source configuration with existing Goemon generated topology; no claim of original random layout parity.")
        specs[f"sokia_{config}"] = spec
    output = ROOT / "assets/maps/falan/explore-dungeon-specs.gd"
    output.write_text('extends RefCounted\n## Prepared by tools/prepare_explore_dungeons.py; fixed source layouts remain unchanged.\nconst SPECS='+json.dumps(specs, ensure_ascii=False, indent=1)+'\n')
    print("EXPLORE_GENERATED_BRANCHES", len(specs), 'configured floors', sum(s['minimum'] for s in specs.values()), 'to', sum(s['maximum'] for s in specs.values()))


if __name__ == "__main__":
    main()
