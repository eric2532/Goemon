# Forest Shrine validation — v2.54.1

Requires Godot 4.6.1. Run from the repository root:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/simulation_test.gd
godot --headless --path . --script tests/forest-shrine/world_test.gd
godot --headless --path . --script tests/forest-shrine/integration_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/lifecycle_test.gd
godot --headless --path . --script tests/forest-shrine/rogue_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/definitive_test.gd
godot --headless --path . --script tests/forest-shrine/transition_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/fog_target_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/review_regression_test.gd
godot --path . --script tests/forest-shrine/integration_test.gd -- --test --visual
godot --path . --script tests/forest-shrine/definitive_test.gd -- --forest-title --visual
```

The model suite covers grid occupancy, explored placement, real prices and atomic wall lines, rotated entrances, gate routing, and remembered/shared vision. The simulation suite covers job reservations and previews, deliveries, no preparation income, repair, wounds, safe retreat, perimeter spawns, barrier breach, and the full five-wave victory loop.

The world suite checks actual construction colliders, friendly gate passage, and settlement bounds. Integration clicks a real build card and the actual 3D battlefield, checks phase/camera changes and combat building rejection, exercises live rally/pause, attacks a real raider with Goemon input, and rejects invisible auto-targets. Lifecycle checks cover main-menu launch, shrine defeat, retry, and return to the Forest Shrine title. The review regressions verify repair access after construction, fresh rally input after pause, gradual tower exits through the entrance, staffed tower damage, and chain impacts hidden by fog.

The Rogue suite exercises every native class primary attack against real forest raiders, Fire Siege Crosshair perspective framing, Q roster transitions, health/cooldown preservation, fog filtering, shield bash, freeze/slow effects, and untargetable fighters. The definitive suite verifies normal launch, all twelve choices, preparation/combat transitions, selected-fighter retry, and Forest-only title return.

Rendered integration saves `preparation.png`, `placement.png`, `battle.png`, and `exploration.png` here. Inspect these for overlapping UI, ghost alignment, forest cutaway, and current/remembered fog. Generated images are ignored by Git.

Existing mode regression commands:

```sh
godot --headless --path . -- --tower-defense-test
godot --headless --path . -- --rogue-siege-tests
```

Both regression suites passed during implementation; Rogue Siege reported 173 checks. Tests print a `*_RESULT` marker and exit nonzero on assertion failures. Also inspect output for Godot script/render errors, which can occur independently of an exit code.

## Playtest

Open `build/Goemon.app`, select **PLAY FOREST SHRINE**, choose a fighter, then place one mine and one watchtower, then a gate and short wall. Begin a wave and hold **V** to lead available workers to a different job. Watch the assignment counts while holding; release to reserve those jobs. Use **WASD**, mouse attacks, and **C** to defend; **Escape** pauses. Between waves, recruit, repair, and expand. Wounded workers return in preparation.

Initial values need player feedback: two finite deposits, six workers, 400 starting gold, five finite waves, no save/load, and a fixed forest layout. Terrain art and worker animation are prototype assets. The mode intentionally starts with an empty buildable settlement around an existing shrine, rather than prebuilding the mines.

## Review and implementation decisions

A fresh independent review found four important defects: blocked repair access, key-repeat rally after pause, chain impact feedback in fog, and tower crews bypassing their entrance. Each was reproduced in a failing regression before correction; no minor findings were deferred.

The approved first-version scope uses two starter deposits beside the shrine. Extra forest deposits and expanded artwork remain future design work. Teardown warnings in a fast headless integration run were investigated separately: allowing the same short audio/effect settling interval used by the existing game produced three consecutive clean reruns.

Implementation decisions recorded during the work:

- Proceeded with implementation after the explicit approval to use the spec and build, superseding the earlier discussion-only request. All changes are recorded in Git.
- Built a separate scene that inherits existing game services. This preserves established modes, at the cost of maintaining the adapter when shared combat changes.
- Corrected a tower test fixture to use explored ground; unexplored placement rejection was the intended behavior.
- Removed an empty, stale worktree index lock only after checking its age and confirming no process held it. No index data was removed.
- Kept the nearby-deposit prototype scope from the latest request. Broader resource exploration will need a later map/economy pass.
- Treated the intermittent headless shutdown warning as a teardown timing issue after verbose inspection and clean repeated runs, rather than changing gameplay resource ownership without evidence.

## Previous delivered build — v2.28.0

macOS release **2.28.0** passed bundle-signature verification, headless main-menu and direct Forest Shrine launch, and rendered native launch on Apple M3 / Metal. Six Forest Shrine test suites passed; the model reported 20 checks, workforce/waves 34, and post-review regressions 15, alongside world/integration/lifecycle checks. Existing Tower Defense passed and Rogue Siege passed all 173 checks.

The main launch icon is `build/Goemon.app`. The prior 2.27.0 app is preserved under `build/Other Files/Goemon-v2.27.0-before-Forest-Shrine.app`. Release screenshots, logs, and ZIP are stored under `build/Other Files/Forest Shrine v2.28.0/`.

The forced headless main-menu shutdown prints one dummy-renderer shader allocation warning in both the prior 2.27.0 app and this build. Rendered native main-menu and Forest Shrine launches are clean; this is an existing headless-exit limitation, not a new gameplay failure.

## Definitive combat review — v2.29.0

A fresh review found that retained Goemon Sky Strike could automatically target a forest raider outside shared vision. A real-scene regression failed for both target selection and impact before correction. Selection and impact now check current forest visibility; visible targets retain normal damage. No minor findings were deferred.

## Current delivered build — v2.29.0

`build/Goemon.app` now launches the Forest Shrine title only. All eleven fighters use the original Rogue Siege combat and close battle camera, with overhead grid placement only between waves. Ten Forest suites and all 173 existing Rogue Siege checks passed after the final fog fix. The native bundle passed signature verification and headless launch; the exported PCK passed the definitive scene-flow suite. Rendered title, roster, preparation, and combat captures were inspected. Native UI automation was unreliable, so packaged scene-flow verification used the Godot test harness against the exported PCK.

The previous app is preserved at `build/Other Files/Goemon-v2.28.0-before-Definitive-Forest.app`. The release ZIP, screenshots, and test/export logs live in `build/Other Files/Forest Shrine v2.29.0/`.

Implementation decisions: historical modes remain available through explicit development commands while hidden from normal launch. The approved work was integrated locally into the existing feature branch. A stale, empty worktree index lock was removed after checking its age and confirming it had no process owner; no index data was removed.


## Definitive crosshair correction · v2.54.0

The current build merges the full Fire Siege Crosshair v2.53.1 baseline (`aa7f1d2`), preserving its camera, authored character assets, animations, combat actions and effects. The earlier v2.29 angled-camera release below is historical. Normal launch opens only Forest Shrine; the overhead grid is used only for preparation.

New checks:

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/crosshair_test.gd
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/modern_combat_test.gd
godot --path . --script tests/forest-shrine/crosshair_tour.gd
```

The crosshair suite checks perspective/orthographic transitions, twelve heroes, pause/roster return, reticle state and battlefield continuity. Captured-cursor and mouse-look assertions also run in a real window because Godot's headless DisplayServer cannot capture a pointer. The modern-combat suite checks Samurai's five-cut combo and blade ink, Ranger's upward five-arrow curved fan, updated Edo beam, Goemon native effects, and visibility in auto-lock, center-ray targeting, projectile contact queries, elemental neighbors, meteor selection and fire impact presentation.

All twelve Forest suites passed behavioral assertions. Existing modern Fire Siege suites also passed: Edo redesign 19 checks, Samurai combat 42, Magic Swordsman ink 33, equipment combat 63, roster ink 442, and auto-lock 59. Some accelerated headless harnesses print audio-resource cleanup warnings on exit; they reported no gameplay script errors. A first fixed-fps rendered harness crashed in Godot 4.6.1 teardown after its assertions passed; the real-time rendered tour using normal `quit_clean()` completed and exited successfully. Its title, roster, preparation, battle, Samurai, Edo and pause captures were inspected.

The latest committed Edo assets are included. The separate chat's uncommitted `edo_new_design` work is intentionally not included or changed.

The macOS v2.54.0 bundle passed deep/strict signature verification and native headless boot. Its exported PCK passed definitive launch/retry/title flow, 15 crosshair checks and 20 modern-combat checks. Installed at `build/Goemon.app`; the v2.29 backup is `build/Other Files/Goemon-v2.29.0-before-Crosshair-Forest.app`. Release ZIP, rendered captures, and verification logs are in `build/Other Files/Forest Shrine v2.54.0/`.

## Surrounding forest atmosphere · v2.54.1

The existing woodland now remains visible beyond unexplored ground, with muted tree silhouettes, green ground, and successive rows fading into sage mist. Paths and the building grid still require exploration; enemies still require current shared vision. This is a renderer-only change: forest positions, collisions, navigation, buildings, workers, combat and camera settings are unchanged.

Run the rendered regression with `godot --path . --script tests/forest-shrine/atmosphere_test.gd`. It compares real pixels with the unknown forest drawn versus hidden, checks that showing scenery grants no exploration or vision, verifies unseen raiders are absent from crowd batches, and then verifies their appearance after scouting. It saves preparation, zoomed overview, four battle directions and the forest approach for inspection. Run it in a real window; headless rendering is explicitly rejected.

The regression failed with the original shader (zero forest pixels) and passed with the new shader. Model, simulation, world, fog targeting, crosshair, modern combat and definitive launch suites also passed. The accelerated fog-target and modern-combat harnesses retain their previously documented shutdown resource warnings; the rendered atmosphere run exits cleanly.

The v2.54.1 macOS bundle passed deep/strict signature validation, native headless boot, and definitive launch flow against its exported PCK. The same exported PCK passed the rendered atmosphere regression with 8,640 changed forest pixels and no failures. Set `FOREST_ATMOSPHERE_CAPTURE_DIR` to an external directory when running the rendered test against a packaged PCK. A fresh independent review reported no findings; the existing starting-camera worker occlusion and headless cleanup warnings were outside this visual change.

The current app remains `build/Goemon.app`. Its previous version is backed up as `build/Other Files/Goemon-v2.54.0-before-Forest-Atmosphere.app`; the v2.54.1 ZIP, packaged screenshots, and verification logs are under `build/Other Files/Forest Shrine v2.54.1/`. The other chat's uncommitted Edo redesign is untouched.
