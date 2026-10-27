# Blender → Godot workflow

Read [the Blender asset instructions](../assets/blender/AGENTS.md) and the nearest asset-specific instructions before editing a master.

## Sources and runtime data

- `assets/blender/`: editable Blender masters, excluded from automatic Godot conversion.
- `assets/models/`: GLB exports used by the game.
- `assets/animations/`: exported authored motion data.
- `assets/textures/`, `assets/references/`: textures, supplied references, and attribution.
- `docs/*-motion-workbench/`, `docs/*-weapon-workbench/`: editable pose/weapon workbenches with local `START_HERE.txt` guides.

Asset-specific guides define scale, facing, pivots, bone names, materials, and exporter requirements. Those contracts differ across the original hero, Rogue characters, environment kits, and economy assets. Preserve existing names, grips, packed textures, and attachment origins.

## Reuse before authoring

The user's standing direction is to reuse similar buildings and assets. Search
the existing library and nearest asset guides first. Reuse a compatible model,
or assemble its existing wall, block, door, arch, roof, timber and foliage parts;
make only missing geometry. Share textures and immutable mesh/material resources
for repeated placements. Keep one authoritative editable master, preserve its
scale, pivots, sockets and gameplay contracts, and keep visual variations
isolated from other users of a shared material. Record reusable parts and their
source/export paths beside the asset. Do not run initial generators over artist
edits just to obtain another copy.

The Wind Meadow building kit is documented in
`assets/blender/environments/wind_meadow/buildings/START_HERE.md`.

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


## Recovered playable Kojiro

Use [the Kojiro workbench](../assets/blender/characters/kojiro/AGENTS.md) and
[recovery guide](recovered-kojiro.md). The saved master uses the existing rigid
character exporter. Preserve its fifteen parts and 30 FPS motion, rebuild the
`kojiro` toolkit candidate, refresh imports and verify the original and optimized
poses plus rendered gameplay. No runtime retargeter or army bake is needed for
this player-only character.

## Recovered Warcraft playable heroes

Use the [Warcraft workbench](../assets/blender/characters/warcraft/AGENTS.md) and
[port guide](recovered-warcraft.md). Export the saved original masters with
`tools/export_warcraft_characters.py`; retain all skin clips plus the paired
30 Hz opacity/particle sidecars. Every geoset is independently addressable.
Rebuild the two named toolkit candidates, inspect imported motion and rendered
comparisons, then verify gameplay through the desktop launcher.

## Recovered Human Peasant worker

The original worker uses the same read-only Warcraft Blender exporter with
`-- Peasant`, followed by its named toolkit recipe and the existing army-format
pose bake `tools/bake_warcraft_worker.gd`. Its authoritative body/portrait masters
remain in the adjacent Warcraft asset package. Preserve all 22 body actions,
six geosets and original sound samples; rebuild affected worker data and portrait
and verify the native hand/bow/socket plus job and audio behavior through Play
Goemon. See [the worker guide](../assets/characters/warcraft/peasant/README.md).
