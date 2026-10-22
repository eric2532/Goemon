#!/bin/zsh
set -euo pipefail
GOEMON_PROJECT="${0:A:h:h}"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$GOEMON_PROJECT" --script res://tests/forest-shrine/large_army_benchmark.gd "$@"
