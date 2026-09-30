"""Prepare the previous published world for same-camera comparison; no source edits."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
source = subprocess.check_output(["git", "show", "79d45358323779b8f4a310a1b2f73a15660d8d27:scripts/world.gd"], cwd=root, text=True)
source = "extends Sanctuary\n\n" + source[source.index("func _ready():"):source.index("func lighting():")]
out = root / "tests/tidefall-town/baseline"
out.mkdir(exist_ok=True)
(out / "world.gd").write_text(source)
