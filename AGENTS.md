# Goemon build and delivery policy

The user wants exactly one playable app in the build folder: `build/Goemon.app`.

## Iteration workflow

- For development changes, run the latest source with `/Users/eric/Desktop/Play Goemon.command`; use `/Users/eric/Desktop/Edit Goemon.command` to open the same project in the Godot editor.
- Do not export or replace the app on every iteration. Export an app only when the user explicitly asks for an app build or distribution.
- The launchers use the current complete source on `main` and enable painterly scenery. Keep them pointed at the complete source if it moves.
- The app delivery rules below apply when an app export is requested.

## App delivery rules

- Publish the latest complete game with its current painterly scenery and gameplay. Do not keep separate original/preview apps or version-named app copies.
- The complete painterly source now lives in this project on `main`. Use its `Painterly Preview macOS` export preset; it publishes the app as **Goemon**. Do not substitute a stale original-look branch build for the latest game.
- Export and unpack into a temporary directory outside `build/`. Verify the staged app, then replace the single canonical app atomically.
- Move superseded app bundles and app-only export ZIPs to macOS Trash; do not empty Trash. Do not create `Before ...` copies, parallel apps, or retained release ZIPs unless the user explicitly asks.
- Keep logs, screenshots, reports, and other development artifacts in `build/Other Files/`. Leave only `Goemon.app` and `Other Files` as visible entries at the build folder root.
- Preserve source files, editable assets, saved maps, preferences, and user data during cleanup. Use Git for source history.

## Game art inspiration

- The user selected [Game Art Style](https://gameartstyle.loopyhop.com/) as a reference for game art inspiration. Consult it when exploring visual styles, environments, characters, or interface art for this project.
