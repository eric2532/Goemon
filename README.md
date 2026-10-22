# Goemon

Goemon is a Godot action and defense game. Forest Shrine is the current player experience: prepare the fort, build defenses, assign workers, and fight waves with twelve playable characters. Four Gates is the default map; Twin Ramparts, Original Map, and named custom maps are available in the map editor.

## Play and edit

Open `/Users/eric/Desktop/Play Goemon.command` to run the latest complete source with painterly scenery. Open `/Users/eric/Desktop/Edit Goemon.command` for the same project in Godot.

The launchers currently target `codex/painterly-gate-preview` at `/Users/eric/.codex/worktrees/painterly-gate-preview/Sonic`. This checkout is `feat/original-enemies-town-cap`; use the launchers for the complete game. Verify the launcher's target if the source moves.

Godot 4.6 is used by the project. Runtime GLBs and animation data are supplied; Blender is needed for art editing, not ordinary play.

## Development

- `scripts/`, `scenes/`: game logic and scenes.
- `assets/models/`, `assets/animations/`: exported runtime art and motion data.
- `assets/blender/`, `assets/textures/`, `assets/references/`: editable masters and references.
- `assets/maps/`: bundled map presets. Preserve user maps, preferences, and recordings outside the app bundle.
- `tools/`: asset authoring, export, and verification tools.
- `tests/`: executable regressions and focused usage notes. Start with [Forest Shrine tests](tests/forest-shrine/README.md).

Run checks from the source checkout being changed. For example:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
```

Use the installed Godot executable if `godot` is not on PATH. Native render and input checks need a real window; inspect their script arguments before running them.

## Art and audio

Read [the Blender workflow](docs/BLENDER_PIPELINE.md) and the [character art standard](docs/art-direction/goemon-character-standard.txt) before editing masters. Animation and weapon workbenches under `docs/` keep their own `START_HERE.txt` instructions beside the editable files. Follow the relevant asset's README and provenance rather than an old milestone report.

[Sound Studio](docs/SOUND_STUDIO.md) documents recording and replacing attack sounds. The selected visual inspiration reference is [Game Art Style](https://gameartstyle.loopyhop.com/).

## App delivery

Export only when an app build or distribution is requested. Follow [AGENTS.md](AGENTS.md): stage and verify outside `build/`, then atomically replace the single `build/Goemon.app`. The complete painterly source currently uses the **Painterly Preview macOS** preset. Keep development artifacts in `build/Other Files/`; move superseded apps and app-only ZIPs to Trash.

Keep this README focused on current entry points. Git contains the release history, completed implementation plans, and retired reports.
