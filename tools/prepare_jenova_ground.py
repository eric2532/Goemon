"""Jenova's original paving/grass, with continuous native alpha joins."""
import json
from pathlib import Path

from native_floor_bake import bake_floor

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/falan/jenova/street_art"


def prepare():
    catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())
    proof = bake_floor(catalog, 4000, OUT / "ground-continuous.png")
    proof["method"] = "Native BG diamonds composited in source-cell order then rectified once; replaces two-style scope blend only"
    proof["inferred_surfaces"] = "None; original floor selection, footprint and source road pattern retained"
    (OUT / "ground-continuous.json").write_text(json.dumps(proof, indent=2) + "\n")
    print(f"Prepared Jenova continuous native ground; {len(proof['source_tiles'])} RGBA hashes verified")


if __name__ == "__main__":
    prepare()
