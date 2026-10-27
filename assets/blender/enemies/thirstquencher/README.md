# Approved soldier light polish

The user selected the light-polish design on 2026-10-23. These three editable
masters preserve the recovered red sword, blue gun and green spear soldiers.
The recovered originals in `assets/characters/thirstquencher/` remain unchanged.

The approved changes weld disconnected triangle corners, add 0.006 m two-segment
bevels and use rough lit surfaces. Keep the original silhouette, painted artwork,
nearest texture filtering, 11 rigid part IDs, 12 bones and all source STEP actions.
No runtime retargeting or new per-soldier scene trees are needed.

Export saved edits from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/export_soldier_polish.py
```

This exporter reads the masters without saving or regenerating geometry, writes
`assets/models/enemies/thirstquencher/soldier_1.glb` through `soldier_3.glb`, and
preserves the recovered ACTIONS/STEP and zero-based 30 Hz tick contract. Do not
use `recover_thirstquencher_rigs.py` to export these edited masters: it rebuilds
the original recovered models.

After export, audit, optimize and compare `soldier-light-1`, `soldier-light-2` and
`soldier-light-3` using `tools/goemon_assets.py`. Activate only the reviewed
profiles, refresh imports, then rebuild the shared GPU resources:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/bake_thirstquencher_runtime.gd
```

Run toolkit preservation/import checks and `scripts/thirstquencher_asset_tests.gd`,
`scripts/thirstquencher_gameplay_tests.gd`, `army_soldier_batches_test.gd` and
`army_soldier_combat_test.gd` in `tests/forest-shrine/`. The rendered
`soldier_polish_render_test.gd` captures idle, run and attack samples from four
angles through the native buffers in the painterly game world. Review weapon
grips and feet in those images before integration.

Evidence lives in `build/Other Files/Asset Toolkit/Soldier Polish/`. The light
models have 2,916–2,998 triangles each, compared with 356–390 recovered triangles;
the final renderer still uses three texture batches per soldier type. Keep this
cost visible and repeat a matched foreground army benchmark after geometry or
lighting changes. A short run does not establish long-session stability.
