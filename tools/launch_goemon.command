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
GOEMON_SCENE_ARGS=(--scene res://scenes/forest_title.tscn)
GOEMON_SESSION=play
for GOEMON_ARG in "$@"; do
  [[ "$GOEMON_ARG" == "--" ]] && break
  if [[ "$GOEMON_ARG" == "--script" || "$GOEMON_ARG" == "-s" ]]; then
    GOEMON_SCENE_ARGS=()
    GOEMON_SESSION=script
    break
  fi
done

# Keep each session single-instance while allowing studies alongside the game.
zmodload zsh/system
GOEMON_LOCK="$GOEMON_LOGS/$GOEMON_SESSION.lock"
: >> "$GOEMON_LOCK"
if ! zsystem flock -t 0 -e -f GOEMON_LOCK_FD "$GOEMON_LOCK"; then
  if [[ "$GOEMON_SESSION" == script ]]; then
    print "A Goemon script is already starting or running."
    exit 0
  fi
  print "Goemon is already starting or running."
  if [[ " $* " != *" --headless "* && -f "$GOEMON_LOGS/game.pid" ]]; then
    GOEMON_RUNNING_PID=$(<"$GOEMON_LOGS/game.pid")
    if [[ "$GOEMON_RUNNING_PID" == <-> ]] && kill -0 "$GOEMON_RUNNING_PID" 2>/dev/null; then
      /usr/bin/open -a "${GOEMON_ENGINE:h:h:h}"
    fi
  fi
  exit 0
fi
if [[ "$GOEMON_SESSION" == play ]]; then
  rm -f "$GOEMON_LOGS/game.pid"
fi

# Both sessions write the same import cache, so serialize the refresh only.
: >> "$GOEMON_LOGS/import.lock"
zsystem flock -f GOEMON_IMPORT_FD "$GOEMON_LOGS/import.lock"
if python3 "$GOEMON_PROJECT/tools/goemon_import_cache.py" check "$GOEMON_PROJECT" "$GOEMON_ENGINE"; then
  print "Goemon assets are up to date."
else
  print "Refreshing changed Goemon assets..."
  "$GOEMON_ENGINE" --headless --editor --path "$GOEMON_PROJECT" --import --log-file "$GOEMON_LOGS/import.log"
  python3 "$GOEMON_PROJECT/tools/goemon_import_cache.py" record "$GOEMON_PROJECT" "$GOEMON_ENGINE"
fi
zsystem flock -u "$GOEMON_IMPORT_FD"

GOEMON_USER_ARGS=(--painterly-preview)
if [[ "$GOEMON_SESSION" == play ]]; then
  print "Playing the latest Goemon source with painterly scenery."
  print -r -- "$$" > "$GOEMON_LOGS/game.pid"
  GOEMON_USER_ARGS+=(--crossgate-pet-test)
else
  print "Running a Goemon script with painterly scenery."
fi
print "Project: $GOEMON_PROJECT"
exec "$GOEMON_ENGINE" --path "$GOEMON_PROJECT" "${GOEMON_SCENE_ARGS[@]}" --log-file "$GOEMON_LOGS/$GOEMON_SESSION.log" "$@" -- "${GOEMON_USER_ARGS[@]}"
