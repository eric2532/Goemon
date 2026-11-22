"""Prepare the archived ranged charge and hit sprites for Maze's Blade Dance."""
import argparse
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets/characters/crossgate/maze"


def recover(source: Path):
    sheets = source / "godot/assets/humanoid-spells"
    clips = json.loads((sheets / "manifest.json").read_text())["clips"]

    def pixels(resource):
        path = sheets / f"{resource}.png"
        assert hashlib.sha256(path.read_bytes()).hexdigest() == clips[str(resource)]["sha256"]
        return path

    charge = clips["110103"]
    assert (charge["frames"], charge["columns"], charge["bounds"], charge["sounds"][0]["id"]) == (
        9, 8, [-38, -44, 50, 47], 251)
    (OUT / "blade-dance-charge.png").write_bytes(pixels(110103).read_bytes())

    impact = clips["110473"]
    assert (impact["direction"], impact["frames"], impact["columns"], impact["duration"]) == (0, 6, 6, 500)
    assert not impact["sounds"]
    (OUT / "blade-dance-impact.png").write_bytes(pixels(110473).read_bytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    recover(parser.parse_args().source)
