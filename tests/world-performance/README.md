# World performance pass

2026-10-02. Godot 4.6.1, Apple M3, Metal Forward+, High quality, 1280 × 800
window. This comparison starts from the sparse-cloud layout from the previous pass.

## Changes

- Split the ground into 80 m sections with the same 5 m triangle topology,
  shader and physical surface. Camera and shadow culling can now skip whole
  sections; no terrain is removed by a distance cutoff.
- Cull small ground scenery at 150–280 m, island decoration at 180 m, and
  furnishings/interior details at 90 m. Island land surfaces retain their 480 m
  range; furnished building shells remain visible to 420 m. Nearby art and
  graphics quality settings are unchanged. All collision remains active.
- Distant island patrols use the existing 0.15 s collision-tested segment
  interpolation, with full collision movement for nearby fights, airborne
  actors and knockback. Frozen actors stop immediately.
- Navigation checks its time budget after each expanded cell, with a target
  budget of 800 microseconds instead of 1,500 checked only every sixteen cells.
  A single cell can still exceed the budget; route results remain identical.
- Indoor-camera checks skip far rooms before computing inverse transforms.
  Previously hidden walls/roofs are still restored when leaving a room.

## Measurements

`godot --path . --disable-vsync --script res://scripts/world_performance_audit.gd -- --label=final`

The audit fixes quality, window resolution, viewpoint and island ID, suppresses
reinforcements and player movement, warms each view for 90 frames, then records
180 frames. Static views use frozen AI; `*_active` views enable normal enemy AI.
The active sky scene contains 66 enemies and the ground scenes contain 50 giants.
The baseline ran from an isolated copy of the pre-change scripts using the same
assets and audit. Runs were sequential, with no concurrent tests or export jobs.

Physics callbacks are timed directly from `SceneTree.physics_frame` to a final
high-priority physics callback. This measures script callbacks and their synchronous
collision queries, not the physics server's entire integration step. The engine's
separate physics monitor updates slowly and can retain a preceding scenario's value.
GPU timestamps returned zero on this Metal run and are **unavailable**, not a zero
GPU cost. Raw captures/JSON are ignored local diagnostics in this directory.

Each cell below is **before / final after**.

| Scene | Mean frame ms | P95 frame ms | Mean physics callbacks ms | Draw calls | Rendered primitives |
| --- | --- | --- | --- | --- | --- |
| dawn | 12.16 / 6.37 | 23.88 / 16.89 | 0.15 / 0.18 | 776 / 398 | 462,398 / 223,534 |
| middle | 16.65 / 16.65 | 23.26 / 22.34 | 0.17 / 0.19 | 994 / 548 | 982,936 / 359,731 |
| middle_active | 6.26 / 5.14 | 11.13 / 12.62 | 5.08 / 1.45 | 994 / 548 | 982,936 / 359,728 |
| ground | 5.22 / 5.47 | 11.51 / 12.20 | 0.10 / 0.11 | 989 / 908 | 945,508 / 438,534 |
| town | 5.57 / 5.49 | 10.68 / 11.80 | 0.09 / 0.09 | 566 / 524 | 928,410 / 419,066 |
| town_active | 5.58 / 7.35 | 11.70 / 15.57 | 2.13 / 1.76 | 564 / 522 | 928,372 / 419,028 |

The active sky physics callback cost fell about **71%** (5.08 → 1.45 ms), and
its rendered geometry fell about **63%**. Ground/town geometry fell about **54–55%**.
Frame timings remain variable: active sky average improved, while active town
average and P95 worsened in the final run despite lower callback work/geometry.
An earlier after run measured active town at 5.83 ms versus 7.35 ms in the final
run. These short desktop samples establish lower work in the targeted systems;
they do **not** establish an across-the-board FPS increase or a minimum FPS.

The smaller terrain volumes add roughly 600 scene nodes. This is an intentional
tradeoff for finer rendering and collision spatial partitioning.

## Validation

All suites passed:

- `--world-performance-test`: 10 checks covering distant patrol motion and floor
  contact, knockback, freeze, bounded terrain sections, both sides of every
  internal terrain seam, real player movement across a seam, nearby interior
  detail, navigation budget yielding and full-field equivalence.
- `--flight-test`: 24 checks, including all island/cloud collision surfaces,
  flight/boost, pause, character switching and streaming limits.
- `--descent-test`: 25 checks, including actual cloud traversal, layered landings,
  deterministic retries, defeat records, freefall and progression.
- `--district-test`: 48 checks, including live AI pursuit/damage, reinforcements,
  all six building entrances and cutaways, and ground giants.

Rendered sky and town captures were inspected. The universal macOS app was rebuilt from these sources, passed code-signature
verification, and passed both `--world-performance-test` (10 checks) and
`--flight-test` (24 checks) from the exported executable. The previous app/ZIP
are retained in `build/before-performance-20261002/`.

The audit uses the engine's [RenderingServer timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time)
alongside direct physics callback timing.
