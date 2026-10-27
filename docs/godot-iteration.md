# Running the current game from Godot

Double-click `/Users/eric/Desktop/Play Goemon.command` to run the latest editable game with painterly scenery. The launcher refreshes imports after changes and skips the editor importer when the source and imported files are unchanged. Close and reopen it after code changes. Repeated clicks while it is starting or running no longer create another game; the existing Godot application is activated once the game has started. It reads the complete source directly from `/Users/eric/Desktop/Projects_Codex/Sonic`.

Double-click `/Users/eric/Desktop/Edit Goemon.command` to open that same project in Godot. Press F5 to run; the editor launch arguments keep painterly scenery enabled.

The shared entry point is `tools/launch_goemon.command`. Logs are in `/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration/`. No app export is needed for development iterations. Export an app only on explicit request, following AGENTS.md.

If the complete source project moves, update the two desktop wrapper paths. Keep them pointed at the complete source on `main`; do not select a checkout merely because its modification time is newer.

The import step also discovers the native terrain math library in `native/terrain_math/`. Its checked-in universal macOS library is ready to run; rebuild it with `native/terrain_math/build.sh` only after changing the C++ source. Restart the game after native or script changes.

The repeat-launch check is `tools/goemon_import_cache.py`. Its disposable snapshot
lives in `.godot/goemon_import_snapshot.json` and is written only after a successful
import. Added, edited, renamed or deleted source/import files, import settings,
class/extension caches and an engine update trigger a refresh. Ignored asset
workbenches and `build/Other Files/` do not invalidate it. Delete the snapshot to
force a refresh; never delete editable assets to speed up startup.

## Free enemy castles and larger maps

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
