# Forest Shrine prototype validation

Requires Godot 4.6.1. Run from the repository root:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/simulation_test.gd
godot --headless --path . --script tests/forest-shrine/world_test.gd
godot --headless --path . --script tests/forest-shrine/integration_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/lifecycle_test.gd
godot --headless --path . --script tests/forest-shrine/review_regression_test.gd
godot --path . --script tests/forest-shrine/integration_test.gd -- --test --visual
```

The model suite covers grid occupancy, explored placement, real prices and atomic wall lines, rotated entrances, gate routing, and remembered/shared vision. The simulation suite covers job reservations and previews, deliveries, no preparation income, repair, wounds, safe retreat, perimeter spawns, barrier breach, and the full five-wave victory loop.

The world suite checks actual construction colliders, friendly gate passage, and settlement bounds. Integration clicks a real build card and the actual 3D battlefield, checks phase/camera changes and combat building rejection, exercises live rally/pause, attacks a real raider with Goemon input, and rejects invisible auto-targets. Lifecycle checks cover main-menu launch, shrine defeat, retry, and return to the original menu. The review regressions verify repair access after construction, fresh rally input after pause, gradual tower exits through the entrance, staffed tower damage, and chain impacts hidden by fog.

Rendered integration saves `preparation.png`, `placement.png`, `battle.png`, and `exploration.png` here. Inspect these for overlapping UI, ghost alignment, forest cutaway, and current/remembered fog. Generated images are ignored by Git.

Existing mode regression commands:

```sh
godot --headless --path . -- --tower-defense-test
godot --headless --path . -- --rogue-siege-tests
```

Both regression suites passed during implementation; Rogue Siege reported 173 checks. Tests print a `*_RESULT` marker and exit nonzero on assertion failures. Also inspect output for Godot script/render errors, which can occur independently of an exit code.

## Playtest

Open `build/Goemon.app`, select **Forest Shrine**, place one mine and one watchtower, then a gate and short wall. Begin a wave and hold **V** to lead available workers to a different job. Watch the assignment counts while holding; release to reserve those jobs. Use **WASD**, mouse attacks, and **C** to defend; **Escape** pauses. Between waves, recruit, repair, and expand. Wounded workers return in preparation.

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

## Delivered build

macOS release **2.28.0** passed bundle-signature verification, headless main-menu and direct Forest Shrine launch, and rendered native launch on Apple M3 / Metal. Six Forest Shrine test suites passed; the model reported 20 checks, workforce/waves 34, and post-review regressions 15, alongside world/integration/lifecycle checks. Existing Tower Defense passed and Rogue Siege passed all 173 checks.

The main launch icon is `build/Goemon.app`. The prior 2.27.0 app is preserved under `build/Other Files/Goemon-v2.27.0-before-Forest-Shrine.app`. Release screenshots, logs, and ZIP are stored under `build/Other Files/Forest Shrine v2.28.0/`.

The forced headless main-menu shutdown prints one dummy-renderer shader allocation warning in both the prior 2.27.0 app and this build. Rendered native main-menu and Forest Shrine launches are clean; this is an existing headless-exit limitation, not a new gameplay failure.
