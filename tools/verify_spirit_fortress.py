#!/usr/bin/env python3
"""Verify Spirit Fortress effects plus the existing and latest Fire Siege suites."""
import argparse
import json
import re
import subprocess
from pathlib import Path

from verify_fire_siege import ROOT, SUITES

LATEST = [
    ("auto-build", "AUTO_BUILD_RESULT"),
    ("auto-attack", "AUTO_ATTACK_RESULT"),
    ("ranger-precision", "RANGER_PRECISION_RESULT"),
    ("ranger-air", "RANGER_PRECISION_RESULT"),
    ("map-builder", "MAP_BUILDER_RESULT"),
    ("rogue-equipment-combat", "ROGUE_EQUIPMENT_COMBAT_RESULT"),
    ("rogue-combat-upgrade", "ROGUE_COMBAT_UPGRADE_RESULT"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot 4.6.3 or the exported app executable")
    parser.add_argument("--pack", type=Path, help="Test the exported PCK instead of project resources")
    parser.add_argument("--native", action="store_true", help="Run built-in acceptance suites using an exported app executable")
    parser.add_argument("--output", type=Path, default=ROOT / "build/spirit-fortress/verification")
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.6.3.stable"):
        parser.error("Godot 4.6.3 stable is required; found " + version)
    if args.native and args.pack:
        parser.error("Native exports find their own PCK; use --native without --pack")
    args.output.mkdir(parents=True, exist_ok=True)
    suites = list(SUITES)
    suites.extend((name, ["--", "--" + name + "-test"], marker) for name, marker in LATEST)
    suites.append(("spirit", ["--script", "res://scripts/spirit_fortress_tests.gd"], "SPIRIT_FORTRESS_RESULT"))
    suites.append(("neon", ["--script", "res://scripts/neon_shrine_tests.gd"], "NEON_SHRINE_RESULT"))
    suites.append(("crimson", ["--script", "res://scripts/crimson_combat_runner.gd"], "CRIMSON_COMBAT_RESULT"))
    if args.native:
        suites = [suite for suite in suites if suite[1][0] != "--script"]
    results = []
    for name, flags, marker in suites:
        command = [args.godot, "--headless"]
        if args.pack:
            command += ["--main-pack", str(args.pack.resolve())]
        elif not args.native:
            command += ["--path", str(ROOT)]
        command += flags
        log = args.output / (name + ".log")
        with log.open("w") as stream:
            try:
                code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=240).returncode
            except subprocess.TimeoutExpired:
                code = -1
        output = log.read_text()
        summary = next((line for line in output.splitlines() if line.startswith(marker)), "MISSING RESULT")
        errors = [line for line in output.splitlines() if "ERROR:" in line]
        warnings = [line for line in output.splitlines() if "WARNING:" in line]
        # These export-template shutdown diagnostics are recorded in v2.45's manifest too.
        diagnostics = [line for line in errors if re.search(r"RID allocations .* leaked at exit|resources still in use at exit", line)]
        blocking = [line for line in errors if line not in diagnostics]
        passed = code == 0 and marker in summary and "failures=0" in summary and not blocking
        results.append({"suite": name, "passed": passed, "exit_code": code, "summary": summary,
                        "errors": blocking, "warnings": warnings, "shutdown_diagnostics": diagnostics, "log": str(log)})
        print(f"{'PASS' if passed else 'FAIL'} {name}: {summary}", flush=True)
        if blocking:
            print("\n".join(blocking[:10]), flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
