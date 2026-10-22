# Blender → Godot workflow

Read [the Blender asset instructions](../assets/blender/AGENTS.md) and the nearest asset-specific instructions before editing a master.

## Sources and runtime data

- `assets/blender/`: editable Blender masters, excluded from automatic Godot conversion.
- `assets/models/`: GLB exports used by the game.
- `assets/animations/`: exported authored motion data.
- `assets/textures/`, `assets/references/`: textures, supplied references, and attribution.
- `docs/*-motion-workbench/`, `docs/*-weapon-workbench/`: editable pose/weapon workbenches with local `START_HERE.txt` guides.

Asset-specific guides define scale, facing, pivots, bone names, materials, and exporter requirements. Those contracts differ across the original hero, Rogue characters, environment kits, and economy assets. Preserve existing names, grips, packed textures, and attachment origins.

## Edit and export

1. Identify the actual source and its exporter from the asset's guide or current tool. Keep the artist's latest saved or unsaved work safe.
2. Edit the existing source. Initial build/generator scripts can overwrite authored meshes and poses; use the normal exporter for hand edits.
3. Preserve the rig hierarchy, native transforms, UVs, material names, and runtime attachment contracts unless the change explicitly requires updating them.
4. Export the matching GLB or animation JSON. Some classes use authored JSON pose drivers; saving a Blender action alone does not update gameplay.
5. Reimport in Godot and run focused checks for that asset. Inspect front, side, back, attachments, and movement from the gameplay camera.
6. Run the latest game with the desktop launcher. Export the app only when requested; see [delivery policy](../AGENTS.md).

The game controller owns travel, collision, hit timing, and damage. Animation previews do not establish gameplay physics or attack timing. When adopting authored poses, retime them to the existing gameplay events.

## Original Goemon assets

`assets/blender/characters/kai.blend` and its GLB retain the historical `kai` path. Supplied character and hair references, textures, and attribution live under `assets/references/goemon_original/` and `assets/references/goemon_sudden_impact/`. Preserve the reference geometry and UVs when changing poses.

`tools/export_blender.py` exports saved source edits. One-time reference import and initial generation tools rebuild assets; inspect their write targets before using them. Specialized characters and workbenches use their own exporters under `tools/`.

Keep provenance and useful editing instructions beside assets. Use Git for old migration notes, design iterations, and release evidence.
