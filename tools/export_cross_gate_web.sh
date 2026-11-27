#!/bin/zsh
# Run from the pinned source checkout with Emscripten 4.0.20 on PATH.
set -euo pipefail

if [[ $# != 1 ]]; then
  print -u2 "Usage: $0 /absolute/path/to/new-versioned-export"
  exit 2
fi
destination="${1:A}"
if [[ -e "$destination" || ! -d "${destination:h}" ]]; then
  print -u2 "Choose a new export folder under an existing parent."
  exit 2
fi

cd "${0:A:h:h}"
engine="${CROSS_GATE_GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
stage="$(mktemp -d "${TMPDIR:-/tmp}/cross-gate-export.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

native/terrain_math/build.sh --web
native/ed_psx_renderer/build.sh --web
if ! python3 tools/goemon_import_cache.py check "$PWD" "$engine"; then
  "$engine" --headless --path "$PWD" --editor --import
  python3 tools/goemon_import_cache.py record "$PWD" "$engine"
fi
"$engine" --headless --path "$PWD" --export-release "Cross Gate Web" "$stage/index.html"
python3 tools/audit_cross_gate_web.py "$stage/index.pck"
python3 tools/chunk_cross_gate_web.py "$stage" "$destination"
