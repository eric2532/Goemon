# Late-game profiling, 21–22 October 2026

User request: keep exploring late-game lag, retaining the current complete painterly game and gameplay. Source iteration only; no app export.

## Backend scope

`Play Goemon.command` opens the complete painterly source with the existing `legacy` backend. The large-army benchmark explicitly enables the experimental native backend through SceneTree metadata. Native FPS results below do **not** describe the normal launcher, and this pass does not change that default. The shared crosshair optimization applies to both backends.

## Findings and changes

An experimental-native foreground Blood Gulch battle with 600 enemies and 240 allies reproduces the slowdown: the initial 60-second run averaged 48.75 FPS, with p95 frame time 31.15 ms. Unit populations, ordinary stats, simulation time and attack/damage/death activity are checked by the benchmark.

The phase profile identified about 2.06 ms per physics step in compatibility-state transfer, 1.54 ms in native combat, 1.30 ms in presentation effects and 1.24 ms in the world tick. These are different nested phases, not additive GPU timings. Metal GPU timings were unavailable.

- Towers now use the existing native spatial index before fitting original enemy hurt surfaces. Conservative bounds preserve rotated soldier contacts beyond the root-based range. Model insertion order, exact range/muzzle/visibility checks, new arrivals not yet imported, and articulated legacy giants are retained. This reduced world-tick cost in the exploratory run (1.24 to 1.06 ms), but overall FPS was essentially unchanged (48.75 versus 48.91).
- Unit facades share one typed, owned view of the native packed arrays per physics update. This removes repeated Dictionary field lookups while retaining the exact arrays, double-precision HP, individual poses/statuses and lazy contact snapshot lifetime. Every physics step still runs. The renderer consumes its existing Dictionary.
- A concurrently active game chat added native batching of the compatibility loop and helper mirrors. Its changes are preserved separately from this pass. The combined 120-second run showed compatibility work at 1.46 ms, but concurrent headless tests were observed during that run. Its FPS is **not** a valid before/after comparison and must not be presented as an improvement.

## Verification

Eight focused suites pass, 444 checks total: packed snapshot ownership and transitions (97), tower targeting against exhaustive contacts and a 2,000-soldier workload (165), presentation cadence (5), bunker lifecycle (27), hunting (12), hiring parity (62), player contacts (40), lifecycle/reset (36).

The pre-existing workforce query fixture needed wave phase enabled to exercise its tower assertions; with that correction all seven assertions pass, including the previously failing spatial-query assertion. Independent read-only review found no important issues in the tower and typed-snapshot changes.

The combined 120-second diagnostic kept at least 600 enemies and 240 allies throughout, simulated 119.98 seconds over 120.01 wall seconds, recorded 42,655 deaths/reinforcements and zero dropped events. It still failed the FPS/p95 performance thresholds; it is evidence of ongoing combat, not a sustained smoothness acceptance. Memory rose about 15.4 MB; this short run cannot establish long-soak stability.

## Remaining investigation

Extreme crowds still need work. The remaining measured costs include native combat, effect/corpse updates, loot collection and scene-object state transfer. The user authorized coordination with “Boost Ben and Ed attacks”; isolated source snapshots and exclusive CPU/GPU windows now separate the measurements. Do not lower populations, skip combat ticks, change attack timings or remove the new scenery to meet a benchmark.

Evidence (logs, profiles and JSON reports):
`/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Late Game Profile 2026-10-21/`


## Coordinated measurements and regular-launcher fix

The clean 60-second experimental-native comparison held current scenery and unrelated gameplay source constant, reverting only the other chat's native batching/query/helper changes for the baseline. Both runs retained at least 600 enemies and 240 allies, 100% foreground focus, 60.0167 seconds of simulation, normal stats, and zero dropped events. Process logs showed one Godot invocation at a time.

| Metric | Baseline | Native batching/query changes |
| --- | ---: | ---: |
| Average FPS | 48.82 | 54.75 |
| p95 frame time | 32.51 ms | 26.42 ms |
| p99 frame time | 37.11 ms | 31.05 ms |
| Compatibility transfer / physics step | 1.791 ms | 1.473 ms |
| Helper mirror / physics step | 0.402 ms | 0.229 ms |

This single pair still fails the benchmark's 55 FPS and 25 ms p95 targets. Later crosshair/latest foreground runs are invalid: the first lost focus and process timestamps jumped from 00:34:43 to 00:47:16; both exposed a non-fatal typed-array error in the initial crosshair implementation. They are retained with `MEASUREMENT-NOTE.txt` and must not be cited as performance results.

The actual launcher path's crosshair previously called `forest_enemy_visible` for every enemy before casting a ray. It now casts first, excludes any hidden enemy that was actually hit, and repeats the same finite ray until it reaches a visible target, cover, or empty space. An explicit `Ninja` type check protects the typed enemy array from terrain/static-body colliders. Player exclusion, auto-lock, exact convergence, maximum range and fog rules are preserved; no cache can return stale visibility.

A separate headless CPU comparison explicitly asserted the normal legacy backend. Each of six real-physics contact cases ran 500 queries with 600 off-ray enemies. This is **aim-query CPU cost only**, not gameplay FPS:

| Contact case | Before | After | Visibility checks before → after |
| --- | ---: | ---: | ---: |
| Two hidden enemies before visible target | 400.100 µs | 8.354 µs | 604 → 3 |
| Nearest visible target | 401.274 µs | 3.866 µs | 604 → 1 |
| All ray contacts hidden | 392.816 µs | 9.208 µs | 604 → 3 |
| Cover behind hidden enemies | 404.920 µs | 8.392 µs | 604 → 2 |
| Cover before the crowd | 402.328 µs | 3.260 µs | 604 → 0 |
| Deleted front enemies | 418.180 µs | 3.700 µs | 602 → 1 |

The six contact results remain exact and the fixed profiling logs contain no unexpected engine errors. Dense hidden bodies directly along the ray require repeated raycasts; this fixture does not establish a worst-case bound or a whole-game FPS gain.

## Additional validation

The new crosshair regression first failed all six query-work assertions with the original implementation while its six exact-position assertions passed. The final query includes the type guard discovered by rendered diagnostics. The army test runner now fails non-fatal engine errors too, while retaining its existing tolerance for known shutdown RID/resource leaks. Its filter was checked against actual captured pre-fix typed-array errors, fixed clean output, and a freed-object script error.

`modern_combat_test.gd` intermittently freed its target before later fog checks after earlier beam/melee attacks. This reproduced on both frozen before/after versions. The later fog scenario now creates and verifies its own living enemy rather than depending on the earlier combat victim surviving. An attempted high-health fixture did not resolve the failure and was removed. The test still requires real beam damage; game health and balance are unchanged.

Read-only review found no important correctness issue in the ray algorithm. The actual engine diagnostics additionally caught the static-body typed-array issue and led to the explicit type guard. The full-game late-wave FPS improvement in the regular launcher remains unverified; simulation, animation, contact and helper costs remain areas for further investigation.

New evidence lives under `coordinated-ab/`, `legacy-aim-cost/`, `crosshair-red/`, `crosshair-fixed/`, and `modern-repeat-*/` in the artifact folder above. Frozen source hashes distinguish comparisons. No app export was performed.

Final verification: all five targeting/control suites pass, **161 checks** (12 new crosshair,21 modern combat,39 crosshair preference,59 DDII combat view,30 character framing), with no unexpected engine errors. The actual `Play Goemon.command --headless --quit-after 3` import/play path exits0. Final logs are in `crosshair-verified/` and `launcher-final.log`.
