# Skullpion editable source

## Enemy castle stone statue — 2026-10-30

The castle objective reuses this same master in its prepared `Castle_Cling` pose
at time zero. `tools/build_skullpion_stone_statue.gd` freezes the exported rigid
parts into `assets/models/forest/skullpion_stone_statue.res`: one shared surface,
all 1,037 original triangles, a stone engraving atlas and fitted part bounds.
The boss GLB, original texture pixels, source animations and Blender master stay
unchanged. This is static scenery, without a boss controller or AnimationPlayer.
Edit/export the master normally, refresh imports, then rebuild the statue:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_skullpion_stone_statue.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/enemy_statue_model_test.gd
```

The model test checks source hashes, every posed triangle and all four rotated
contact shapes. Do not edit the generated resource. Castle assembly, reused
pedestal and stone-block rubble are in `scripts/forest/forest_enemy_castle.gd`.
After a source edit also run the existing boss motion/contact checks below.

## Animated boss source

`Skullpion.blend` is the editable gameplay master prepared from the recovered ROM model.
The raw 22-part recovery and its 22 original motion streams stay unchanged in
`assets/characters/recovered_skullpion/skullpion.glb` and `motion.json`.

All 22 rigid mesh parts, texture pages/CLUT materials, UVs and source actions are
retained. `Castle_*` actions are prepared motion for this game's castle, with the
feet normalized to the model floor, the tail kept above that floor, and the
wall-facing contact plane fitted in Blender. Edit those actions rather than
rewriting the ROM recovery. The user requested a playable Skullpion on 2026-10-24. Its selected-player adapter reuses this same visual at the full enemy-boss scale; NPC encounter behavior remains native-owned.

Export saved edits without rebuilding geometry:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/enemies/skullpion/Skullpion.blend --python tools/export_skullpion.py
```

The exporter publishes `assets/models/enemies/skullpion.glb` and the adjacent
`skullpion_fit.json`. Native combat still owns travel, gravity and attack timing.
`tools/prepare_skullpion_blender.py` is a one-time source preparation tool; it
refuses to overwrite an existing master. Do not run it over artist edits.

Follow the root asset audit/preservation/import tests and review four angles,
feet, wall contact and the climb/jump/attack loop through the desktop launcher.

The wall plane is Blender Y = -1 (Godot Z = +1), matching the native
12-unit stand-off after the game's 12x model scale. Blender Z = 0 is the
hind-foot datum. Climb/fall use that wall contact; the prepared jump folds back
into the grounded idle pose while native gravity owns its trajectory.
Prepared clips use dense floor corrections; the exporter samples them at 120 Hz.
Keep the `Color` corner attribute as FLOAT_COLOR and export it explicitly by name.
Preserve the original unlit material node setup as well as that color attribute.
The 22 `Source__` clips are immutable ROM references; the exporter copies their
original samples exactly. Original texture pixels and UVs remain intact.
The recovery import and initial preparation scripts are provenance, not replacements
for this saved master and its subsequent foot/contact/color corrections.
