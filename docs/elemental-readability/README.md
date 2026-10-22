# Fire / ice character readability

Visual-only follow-up to PR #2, based on `65fa8b1`. The 1.7× orb fire explosion's tall flame lobes and twelve opaque rising smoke billows obscured the player at the normal gameplay camera. Ice's sixteen tall bright shards and nearby frozen-enemy crystals added foreground clutter. A surge shield increased overlap further.

## Changes

- Fire burst scale 1.7 → 1.0; eight lobes instead of twelve, flattened and positioned close to the ground. Flame alpha peaks at 0.70; smoke alpha at 0.28 with a fade. Smaller, lower smoke rises at 0.45m/s instead of 1.6m/s; flash light energy drops from 4 to 1.5.
- Ice burst uses eight 0.85m shards instead of sixteen 1.8m shards, half the width, lower placement and 0.55 alpha. The radial travel still reaches seven metres.
- Frozen-enemy crystals are narrower, 1.25m rather than 2.3m tall, and use 0.40 alpha. The batched freeze tint remains.
- Blue surge shield remains the same size, with lower center/rim/ripple opacity; its attack radius and timers are unchanged.
- Standard-material alpha blending is explicit so flames, smoke and crystals remain translucent on the compatibility renderer as well as other backends.

The explosion visual is shared by orb fire, dodge, giant-fireball impact and meteor impact, so all get the lower silhouette. Projectile core/flight visuals were inspected and left unchanged: they are smaller moving cues, not the large surrounding smoke obstruction. No character model, Blender master, enemy-cap logic, collider, range, damage, cooldown, timing, audio or ability rules changed. Orb radius remains 7m, fire damage 100× existing multiplier, and freeze duration 2s.

## Before / after evidence

`before-after-contact.jpg` shows paired crops from full 1280×800 Godot captures. Full `before-*.png` and `after-*.png` frames remain beside it. All six pairs have the exact same logged camera transform: normal 14m gameplay distance, pitch 0.36 and FOV 63. They cover no effect, fire at 0.18s, smoke at 0.55s, ice at 0.18s, three simultaneous fire/ice pairs aged 0.18/0.30/0.42s, and that overlap with Edo's full-size blue surge shield. The effects remain visible while the face and body are readable. This is cloud visual inspection, not a Mac FPS measurement.

`tests/elemental-readability/capture.gd` is the reproducible capture harness; pass `--after` for the revised images. `compare.py` verifies camera equality, checks test result markers and builds the cropped contact sheet.

## Validation

Final unchanged gameplay regression suites, all zero failures / exit code 0:

- `--elemental-orbs-test`: 27 checks including damage, seven-metre exclusion, two-second freeze, cover, multiple sets, magnet overlap, pause/restart and cleanup.
- `--firecaster-test`: 49 checks including giant-fireball damage/hit radius, upgraded beam/shield, dodge explosion, pause and existing Goemon attacks.
- `--meteor-test`: 31 checks including 240-damage impacts, finite radius, attack-speed upgrades, queued casts, pause and cleanup.

No script or shader errors. Cloud captures log the existing pair of OpenGL texture warnings at renderer shutdown; some test/capture exits also report objects/resources still in use at shutdown. All test assertions and exit codes pass; no claim of a completely warning-free shutdown. Raw logs remain under `tests/elemental-readability/` locally and in the scoped delivery ZIP. `git diff --check` passes.

No push, merge, deployment or Mac relaunch was performed for this follow-up. The separate Edo redesign is outside this change.
