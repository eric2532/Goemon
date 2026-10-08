#!/usr/bin/env python3
"""Run the redesigned Fire Siege acceptance suites with bounded execution."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    ("state", ["--script", "scripts/fire_siege_state_tests.gd"], "FIRE_SIEGE_STATE_RESULT"),
    ("structures", ["--script", "scripts/fire_siege_structure_tests.gd"], "FIRE_SIEGE_STRUCTURE_RESULT"),
    ("integration", ["--", "--fire-siege-mvp-test"], "FIRE_SIEGE_MVP_RESULT"),
    ("campaign", ["--", "--fire-siege-campaign-test"], "FIRE_SIEGE_CAMPAIGN_RESULT"),
    ("controls", ["--", "--fire-siege-controls-test"], "FIRE_SIEGE_CONTROLS_RESULT"),
    ("three-gates", ["--", "--tower-defense-test"], "TOWER_DEFENSE_RESULT"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "build/verification")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for name, flags, marker in SUITES:
        command = [args.godot, "--headless", "--path", str(ROOT), *flags]
        log = args.output / f"{name}.log"
        with log.open("w") as stream:
            try:
                run = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=240)
                code = run.returncode
            except subprocess.TimeoutExpired:
                code = -1
        output = log.read_text()
        summary = next((line for line in output.splitlines() if line.startswith(marker)), "MISSING RESULT")
        errors = re.findall(r"^.*(?:SCRIPT ERROR:|ERROR:).*$", output, flags=re.MULTILINE)
        passed = code == 0 and marker in summary and "failures=0" in summary and not errors
        result = {"suite": name, "passed": passed, "exit_code": code, "summary": summary, "errors": errors, "log": str(log)}
        results.append(result)
        print(f"{'PASS' if passed else 'FAIL'} {name}: {summary}", flush=True)
        if errors:
            print("\n".join(errors[:10]), flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
