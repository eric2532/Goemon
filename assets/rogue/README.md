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
