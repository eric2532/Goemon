# Fire Siege MVP v2.41 — straight Ranger arrows with human aim variation

User-approved correction: arrows should fly straight, with slight differences
in the firing angle so a human archer's shots do not follow exactly the same
trajectory. Add horizontal, vertical and diagonal variation, preserving every
other Ranger change. Work is only in the latest `codex/fire-siege-mvp` checkout,
based on the installed local v2.40. The legacy Desktop game is untouched.

## Behavior

A Ranger arrow samples its aim once before muzzle placement and collision.
Normal launch angles vary within ±2° horizontally and ±1.25° vertically around
the aimed direction. Green arrows vary within ±2.5° and ±1.5°. Independent
horizontal/vertical samples create diagonal variation as well. These are small
bounded offsets; every arrow then keeps its launch direction, speed, orientation
and straight ray for its whole flight. Camera movement cannot redirect it.
There are no mid-flight sweeps, knots, zigzags, or range-end bends.

Each of the five fan arrows adds its own subtle launch variation around its
existing fan ray. Aerial fans add variance around their committed downward
rays. Native muzzle obstruction, swept enemy/terrain collision, range/lifetime,
physical arrow meshes and collision-clipped efficient trails remain.

The third released LMB attack is still green power (67/101 ground damage;
25/38 per fan arrow). Rain still powers every release for10 seconds. Hit combos
still accelerate firing up to3× base and expire normally. Five-arrow RMB/3,
double-jump downward LMB, the fitted hat and larger arrows remain. C still
performs a0.15-second,6.9-metre camera-relative WASD roll, with diagonal input
and body-facing fallback. Roll cooldown remains0.55 seconds.

## Verification

- The updated focused suite failed70 checks/7 assertions against v2.40's
  mid-flight curves, then passed **70 checks, zero failures** after correction.
  It samples actual normal/green flight, confirms fixed direction after camera
  turns, all four launch variance quadrants, bounded aim, successive variation,
  fan count, full range across growth scales and horizontal/vertical/diagonal
  headings, collision/trails, release/power lifecycle, fire cadence and rolls.
- Equipment: **63 checks**; retained flight: **28 checks**; controls: **136**;
  MVP: **72**. Zero assertion failures.
- Rendered source tour: **38 checks**, eight captures, zero failures. Native
  fan damage125, powered aerial damage190, roll6.900m. Actual seven hit links
  accelerate to1.84×. Native Ranger geometry hash exactly matches v2.40.
- Sustained source render:79 concurrent powered arrows,137 FX, with3× combo and
  2.25× upgraded base speed. Three simulated seconds took2.9997 wall seconds.
  This fixture verifies sustained effects/rendering, not full-wave performance.
- Read-only review compared to saved v2.40 and found no actionable flight
  defects; unrelated power/fan/cadence/roll/actor/effect implementations match
  the preserved baseline. A test-flag parser error was fixed before final runs;
  all final logs above confirm successful parsing and zero assertion failures.

Evidence: `build/ranger-precision/`. Screenshots and sampled world positions,
aimed directions and launch directions accompany the rendered reports.
Headless runs have existing shutdown resource warnings; assertion failures are
reported separately. Package verification and installed hashes follow below.

```sh
godot --headless --path . --fixed-fps 60 -- --ranger-precision-test
godot --headless --path . --fixed-fps 60 -- --ranger-flight-test
godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-controls-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-mvp-test
godot --path . --max-fps 120 -- --ranger-precision-tour
```

The historical `--ranger-storm-test` flag aliases the current precision suite.
Historical storm/flight tour flags alias the current rendered tour.


## Verified local package

The universal macOS export passes **199 checks, zero assertion failures**
(70 precision +63 equipment +28 flight regression +38 rendered). Eight rendered
package captures verify the retained hat, straight fan, Rain, aerial power,
combo HUD, roll and sustained fire. Strict code-signature verification passes;
installed executable and PCK SHA-256 match the tested app exactly.

- Installed: `build/final-macos/Goemon Fire Siege.app` (**2.41.0**).
- Backup: `build/Goemon Fire Siege before Straight Arrows v2.40.app` (**2.40.0**).
- Archive: `build/Goemon Fire Siege Ranger Precision v2.41.zip`.
- Captures and samples: `build/ranger-precision/packaged-tour/`.
- Versions, signatures, hashes and measurements: `build/ranger-precision/build-info.json`.
- Legacy Desktop Git checkout remains clean. No commit or remote publication.

Package flight evidence: 267 arrows, 11313 actual world positions; maximum deviation from each fixed launch ray 0.00000839 metres (float precision).

Package sustained fire: `{"base_rate": 2.25, "combo_rate": 3.0, "peak_arrows": 79, "peak_effects": 132, "physics_frames": 180, "wall_seconds": 2.983474}`.
