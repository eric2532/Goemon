# Running the current game from Godot

Double-click `/Users/eric/Desktop/Play Goemon.command` to run the latest editable game with painterly scenery. The launcher refreshes imports after changes and skips the editor importer when the source and imported files are unchanged. Close and reopen it after code changes. Repeated clicks while it is starting or running no longer create another game; the existing Godot application is activated once the game has started. It reads the complete source directly from `/Users/eric/Desktop/Projects_Codex/Sonic`.

Double-click `/Users/eric/Desktop/Edit Goemon.command` to open that same project in Godot. Press F5 to run; the editor launch arguments keep painterly scenery enabled.

The shared entry point is `tools/launch_goemon.command`. Logs are in `/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration/`. No app export is needed for development iterations. Export an app only on explicit request, following AGENTS.md.

Standalone `--script` runs use their own session lock and `script.log`, so a replay can stay open while you start the game. Both sessions share the import lock and release it before launching Godot.

If the complete source project moves, update the two desktop wrapper paths. Keep them pointed at the complete source on `main`; do not select a checkout merely because its modification time is newer.

The import step also discovers the native terrain math library in `native/terrain_math/`. Its checked-in universal macOS library is ready to run; rebuild it with `native/terrain_math/build.sh` only after changing the C++ source. Restart the game after native or script changes.

The repeat-launch check is `tools/goemon_import_cache.py`. Its disposable snapshot
lives in `.godot/goemon_import_snapshot.json` and is written only after a successful
import. Added, edited, renamed or deleted source/import files, import settings,
class/extension cache content changes and an engine update trigger a refresh.
Godot's byte-identical rewrites of its class cache are ignored. Ignored asset
workbenches and `build/Other Files/` do not invalidate it. Delete the snapshot to
force a refresh; never delete editable assets to speed up startup.

## Cross Gate browser preview

From the same source checkout the desktop launcher uses, install the official
Godot 4.6.1 export templates and activate Emscripten 4.0.20. The browser uses
WebGL 2 and runs the native C++ army simulation as threaded WebAssembly.

```sh
source "$HOME/.cache/cross-gate-web/emsdk/emsdk_env.sh"
cross_gate_releases="$PWD/build/Other Files/Cross Gate Web Release"
mkdir -p "$cross_gate_releases"
cross_gate_export="$cross_gate_releases/$(date +%Y%m%d-%H%M%S)"
tools/export_cross_gate_web.sh "$cross_gate_export"

python3 -m venv ~/.cache/cross-gate-web/preview-venv
~/.cache/cross-gate-web/preview-venv/bin/python -m pip install "aiohttp>=3.10,<4"
~/.cache/cross-gate-web/preview-venv/bin/python tools/serve_cross_gate_web.py \
  --export-dir "$cross_gate_export" --port 8062
```

If Godot is installed elsewhere, run the export with
`CROSS_GATE_GODOT=/absolute/path/to/Godot tools/export_cross_gate_web.sh "$cross_gate_export"`.
The export checks the resource pack. Chrome downloads it in resumable ranges,
checks each part against the SHA-256 in the export shell, and mounts the parts
as one seekable pack. Completed parts can survive an interrupted load or reload
in that profile's browser cache. Chrome fetches any missing or invalid part.
The server can send the large engine module compressed, with the same decoded bytes.
Open <http://127.0.0.1:8062/> on this Mac after starting the server. The server's
default invocation still serves the earlier `build/Other Files/Cross Gate Web`
path on port 8060. Use `--export-dir` for a versioned export.

Choose **Freyja and Falan** from the browser title. Its bundled document
contains the adventure layout. The current gameplay code and asset catalogs
supply its routes, characters and encounters. Arena Slime Waves is desktop
only. Browser saves are stored per origin and Chrome profile, so a new Quick
Tunnel hostname has its own saves.

Choose **Host Co-op**, select a fighter and enter the city. Copy the address
from the browser's address bar. Up to three friends can open that address
and choose **Join Co-op** while the room is open. Players see each other in
the same area and contribute to one 20-hit practice target near the city
spawn. Enemy combat, loot and progress elsewhere are managed by each
player's game. The room closes when everyone leaves.

For a shareable address, point an HTTPS tunnel at the loopback preview server.
Forward the website and the `/room` WebSocket with the public Host header.
The server makes the export files available with these browser isolation
headers. Keep the existing preview running while testing a new version. The
new export is a candidate until the parity checks pass and Chrome loads that
version through the public URL.

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## Historical preparation tools: enemy castles and larger maps

The current start flow is map → fighter → Equipment hub → Enter Map. Enter Map
saves each character/pet's separate Character Gear, Skill Items and Cosmetics
records and starts play. Build and Mercenaries no longer appear on the map HUD. The following notes describe the earlier valley
preparation workflow; its source, assets and saved maps remain preserved.

During preparation in Wind Meadow Valley, open **Build → 4 · Enemy castle**.
Placement costs zero ryo, including with an empty treasury. R rotates the full
castle and its marked reinforcement exit; click to place repeatedly, then right
click or Escape to exit. The tool clears trees in its reserved footprint and
exit, requires level supported ground, protects existing structures and actors,
and allows up to sixteen total enemy castles. New castles use the existing keep,
wall-panel HP, wave mix, spawn groups, native army and destruction behavior.
They are run edits; restart drops unsaved placements. To keep a layout, open
Map Editor, Save, and use Play map to begin it again.

**Tools → Bigger map** opens a preview of Large Wind Meadow Valley. It is 1.5×
wider and longer than the default valley, giving 2.25× the area. **Play map**
starts that preset as a fresh run; **Back** restores the exact current run.
The editor's **Map size…** menu offers Standard and Large Meadow. Save a custom
map to keep the chosen size and edits. Loading another size uses the editor's
existing unsaved-change protection.

The large preset reuses the central four-gate fort, four enemy castles, painterly
models and terrain generator. Its authoritative files are
`assets/maps/forest_wind_meadow_large.json` and
`assets/maps/wind_meadow/castles_large/{surface,terrain,collision}.res` plus
`roads.png`. Rebuild only that preset with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_wind_meadow_map.gd -- --large
```

The ordinary generator invocation still rebuilds only the standard valley.
Terrain height queries, rendering, collision and native navigation use the same
bake; no runtime terrain deformation or separate army owner is added. Run
`tests/forest-shrine/enemy_castle_placement_test.gd` headlessly or through the
desktop launcher (`-- --visual` captures under `build/Other Files/Enemy Castle Testing/`).
