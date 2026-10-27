# Rogue character assets

Imported on 2026-10-04 from the sibling `../Rogue` project to support Sonic's optional Rogue combat modes. The source project remains unchanged.

- `models/`: the ten playable classes from Rogue's `public/models/`, copied byte for byte.
- `portraits/`: matching original `public/art/*-portrait.png` files, copied byte for byte.
- `data/classes.json`: original class names, descriptions, weapon names, cooldowns and ability metadata.
- `audio/`, `icons/`, `shaders/blade_trail.gdshader`: original native combat assets.
- `scripts/actor.gd`, `effects.gd`, `audio.gd`: native procedural poses, visual effects and audio playback with local resource paths. Audio ambience is opt-in because Sonic already owns environment audio. Effects accept world positions and retain the supplied terrain height; no ground-at-zero conversion is introduced.
- `scripts/class_actions.gd`: native class actions adapted separately for Sonic's combat adapter.

`provenance.json` records each original source path and SHA-256. Native script hashes identify their source versions before the documented integration changes. Models and portraits use the original class IDs, including `magic-swordsman` and `master-thief`.

The project bridge is in `scripts/rogue_roster.gd`, `scripts/rogue_hero_model.gd`, and `scripts/rogue_roster_combat.gd`. Sonic keeps its original playable IDs 1–2; these ten classes use IDs 3–12. The model wrapper turns the native +Z-facing actor by π so Sonic's existing -Z-facing movement convention remains consistent.

## Magic Swordsman energy and sound (2026-10-24)

The sword ribbon and traveling wave reuse `scripts/effects.gd` and
`shaders/magic_ink_brush.gdshader`. The owned `purple_energy` material parameter
adds a white-violet edge, dark core and moving filaments; other palettes keep it
disabled. The wave uses two prepared `_blade` crescents in the longitudinal XZ
plane: the bright convex rim leads in +Z and both pointed tips trail behind.
Five upright/diagonal rolls cycle around the flight direction; they never turn
the cutting edge backward or steer the projectile. Reuse the existing projectile
cache, clock reset, reduced-flash setting and authored blade-tip sampling.
No model, rig, Blender master, animation or combat data was replaced.

`scripts/sound_library.gd` in the project root maps character 9's sword/dive
slots to `assets/audio/recovered_musashi/lumina_swing.wav` and wave slots to
`lumina_rotation.wav`. The latter is the cue Musashi's **Mighty Strike** counter
actually plays. Existing recording, gain, mute and move-ticket rules apply.
Verify with `tests/forest-shrine/magic_energy_test.gd` through the desktop Play
launcher; its reports and captures live in `build/Other Files/Asset Toolkit/Purple Energy/`.

## Goemon art direction (2026-10-07)

The active roster now loads `styled/models/` and `styled/portraits/`. These are
new derivatives; the original `models/`, `portraits/` and their provenance hashes
remain unchanged. Editable sources are in `assets/blender/rogue/`, with the three
original Rogue Blender collections preserved under `originals/`. The adaptation
script is `tools/style_rogue_roster.py`; comparison/portrait rendering is
`tools/render_rogue_style.py`. Per-character build reports record triangle counts,
mesh batches and removed microdetails. See `docs/art-direction/rogue-roster.md`
for the identity comparisons, measured master baseline and known reference limits.
# Painted faces (2.29.1)

The latest user correction supersedes the earlier enlarged head treatment.
Styled heroes now have smaller heads and painted facial features on the skull UVs.
Knight keeps his closed helmet. The source atlas and generation/edit prompts are
in `styled/faces/`; all editable Blender files embed the painted image.
