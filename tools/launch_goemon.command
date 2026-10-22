#!/bin/zsh
# Run the current editable game; app exports are only needed for distribution.
set -euo pipefail
GOEMON_PROJECT="${0:A:h:h}"
GOEMON_ENGINE="/Applications/Godot.app/Contents/MacOS/Godot"
GOEMON_LOGS="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration"
if [[ ! -x "$GOEMON_ENGINE" || ! -f "$GOEMON_PROJECT/project.godot" ]]; then
  print -u2 "Cannot find Godot or the current Goemon project."
  print -u2 "Godot: $GOEMON_ENGINE"
  print -u2 "Project: $GOEMON_PROJECT"
  if [[ -t 0 ]]; then read "?Press Return to close."; fi
  exit 1
fi
mkdir -p "$GOEMON_LOGS"
cd "$GOEMON_PROJECT"
if [[ "${1:-}" == "--editor" ]]; then
  shift
  print "Opening the current Goemon project in Godot."
  exec "$GOEMON_ENGINE" --editor --path "$GOEMON_PROJECT" --log-file "$GOEMON_LOGS/editor.log" "$@"
fi
# Kernel-owned lock spans both importing and the game process. It releases
# automatically on exit or crash; no stale PID can block a later launch.
zmodload zsh/system
GOEMON_LOCK="$GOEMON_LOGS/play.lock"
: >> "$GOEMON_LOCK"
if ! zsystem flock -t 0 -e -f GOEMON_LOCK_FD "$GOEMON_LOCK"; then
  print "Goemon is already starting or running."
  if [[ " $* " != *" --headless "* && -f "$GOEMON_LOGS/game.pid" ]]; then
    GOEMON_RUNNING_PID=$(<"$GOEMON_LOGS/game.pid")
    if [[ "$GOEMON_RUNNING_PID" == <-> ]] && kill -0 "$GOEMON_RUNNING_PID" 2>/dev/null; then
      /usr/bin/open -a "${GOEMON_ENGINE:h:h:h}"
    fi
  fi
  exit 0
fi
rm -f "$GOEMON_LOGS/game.pid"
print "Refreshing changed Goemon assets..."
"$GOEMON_ENGINE" --headless --editor --path "$GOEMON_PROJECT" --import --log-file "$GOEMON_LOGS/import.log"
print "Playing the latest Goemon source with painterly scenery."
print "Project: $GOEMON_PROJECT"
print -r -- "$$" > "$GOEMON_LOGS/game.pid"
exec "$GOEMON_ENGINE" --path "$GOEMON_PROJECT" --scene res://scenes/forest_shrine.tscn --log-file "$GOEMON_LOGS/play.log" "$@" -- --painterly-preview
