# Running the current game from Godot

Double-click `/Users/eric/Desktop/Play Goemon.command` to refresh changed assets and run the latest editable game with painterly scenery. Close and reopen it after code changes. Repeated clicks while it is starting or running no longer create another game; the existing Godot application is activated once the game has started. It reads the complete source directly from `/Users/eric/.codex/worktrees/painterly-gate-preview/Sonic`, rather than the exported app or the older source checkout.

Double-click `/Users/eric/Desktop/Edit Goemon.command` to open that same project in Godot. Press F5 to run; the editor launch arguments keep painterly scenery enabled.

The shared entry point is `tools/launch_goemon.command`. Logs are in `/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration/`. No app export is needed for development iterations. Export an app only on explicit request, following AGENTS.md.

If the complete source project moves, update the two desktop wrapper paths. Do not select a checkout merely because its modification time is newer: the primary Sonic checkout currently contains older gameplay.

The import step also discovers the native terrain math library in `native/terrain_math/`. Its checked-in universal macOS library is ready to run; rebuild it with `native/terrain_math/build.sh` only after changing the C++ source. Restart the game after native or script changes.
