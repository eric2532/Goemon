# Azure Ember 2.6 performance validation

Godot 4.6.1, macOS Metal Forward+, Apple M3, 1280×800 window. Each measured case uses 24 warm-up frames and 120 sampled frames. FPS below is 1000 / mean frame time. The large maps and all 541 coast enemies are retained.

| Scenario | Before mean frame time | After mean frame time | After average FPS |
|---|---:|---:|---:|
| Full-map pursuit | 342.6 ms | 19.2 ms | 52.0 |
| Player running / pursuit | Not sampled | 21.1 ms | 47.4 |
| 541 enemies concentrated, idle | 263.7 ms | 16.8 ms | 59.7 |
| 541-enemy fight | Not sampled | 28.6 ms | 35.0 |
| Crowded fight with rapid T stomps | Not sampled | 37.4 ms | 26.8 |

The moving and active-combat cases were added after the initial baseline. The crowded idle comparison uses the same placement recipe. Full-map samples naturally differ in crowd convergence because the old build advances very slowly. These are local measurements, not a guaranteed frame rate on other machines. The final gravity correction affects distant airborne enemies and was made after these measurements.

- Ordinary enemy mesh: 9,648 triangles originally; 2,694 for close rigs; 777 for the GPU crowd mesh.
- At most 32 ordinary close rigs, with guardian and practice/target exceptions; the remainder use one batched draw with limb animation.
- Cached route decisions and frame-budgeted navigation rebuilds; collision-checked short movement segments remain smooth between probes. Full physics retained for knockback, airborne actors and guardians.
- Goemon: reduced run/sprint foot travel and clearance, earlier heel recovery and increased hip clearance. Player speeds and ability timings are unchanged.
- 75 locomotion assertions passed, including planted feet, fixed bone lengths, backward running, strafing, turning, jumps, slopes and wall contact.
- Wall regression caught and fixed selection of a route across blocked space. The final isolated wall test passed.
- Rendered crowd and running sequences inspected.

Raw measurements: `before.json`, `verified.json`, `combat.json`. Source backup and previous build: `backups/performance-legs/`. Exported gameplay validation is recorded in `release.log`.

Exported 2.6.0 build: 42 combat/navigation checks passed, exit status 0. This includes all four full populations, pursuit over 300m, wall routing, Goemon AoE/rapid T, Edo held beam, smoke teleport, safe random landings and cancellation. Ad-hoc code signature and bundle version verified. Combined with the 75 locomotion assertions, 117 checks passed. The existing Metal particle-shader shutdown allocation warning remains after test completion; there were no gameplay script errors.
