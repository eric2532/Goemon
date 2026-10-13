# Forest Shrine prototype validation

Requires Godot 4.6.1. Run from the repository root:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/simulation_test.gd
godot --headless --path . --script tests/forest-shrine/world_test.gd
godot --headless --path . --script tests/forest-shrine/integration_test.gd -- --test
godot --headless --path . --script tests/forest-shrine/lifecycle_test.gd
godot --path . --script tests/forest-shrine/integration_test.gd -- --test --visual
```

The model suite covers grid occupancy, explored placement, real prices and atomic wall lines, rotated entrances, gate routing, and remembered/shared vision. The simulation suite covers job reservations and previews, deliveries, no preparation income, repair, wounds, safe retreat, perimeter spawns, barrier breach, and the full five-wave victory loop.

The world suite checks actual construction colliders, friendly gate passage, and settlement bounds. Integration clicks a real build card and the actual 3D battlefield, checks phase/camera changes and combat building rejection, exercises live rally/pause, attacks a real raider with Goemon input, and rejects invisible auto-targets. Lifecycle checks cover main-menu launch, shrine defeat, retry, and return to the original menu.

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
