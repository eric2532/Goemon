# Center Siege Beta validation

Historical single-wave validation: this report records the earlier 600-enemy, all-cannon beta. The current game has ten growing waves and mixed flame/artillery defenses; use `--defense-fire-test`, `--defense-fire-visual`, and `--defense-fire-benchmark`, documented in `tests/defense-fire/README.md`, for current acceptance checks. Results below remain useful as a baseline and do not describe the current campaign's full behavior.

```sh
godot --headless --path . --fixed-fps 60 -- --tower-defense-beta-test
godot --path . -- --tower-defense-beta-visual
godot --path . -- --tower-defense-beta-benchmark
```

`tower_defense_beta_tests.gd` checks the finite 600-enemy center-lane wave, short opening countdown, all 24 prebuilt guns at six stations, upgrades, 180-enemy live cap, deferred arrivals, smaller user-configured cap, pause including a live shell, single-wave victory, retry, and the existing shared movement/attack abilities. Functional and visual runs finish with `TOWER_DEFENSE_BETA_RESULT failures=0` on success.

The rendered benchmark uses the same 1280×800 window, fixed camera, quality setting 1, disabled VSync, and unlimited FPS for both 36 and 180 living attackers. Both samples include all 24 cannons firing physical artillery. Enemies run their normal AI and receive real damage; high-health fixtures retain the requested population throughout the measurement. Attackers are distributed across all six stations so the benchmark exercises the complete battery.

After a 2.2-second warmup, each population is measured for approximately four seconds (120–480 rendered frames). A third sample puts all 180 attackers close to the first wall with the hero behind cover and a normal close camera; all 24 guns remain installed and the front battery fires at the visible swarm. `performance.json` records mean, 95th percentile, and maximum frame, process, physics, rendering CPU, and GPU times; draw calls; peak node, shell, blast, and projectile counts; actual live-enemy counts; shots and target scans; and the number of firing cannons. Unsupported GPU timing is explicitly marked unavailable instead of interpreting a zero as free rendering. The benchmark requires a real renderer and fails if run headless. The comparison measures the added cost of the larger active swarm; it does not promise identical frame rates on different machines.

Screenshots are written here for the ready cannon line, central swarm, beta completion, shared gold flight, and both benchmark populations. The original three-lane regression remains available through `--tower-defense-test`, which selects the standard defense configuration.

2026-10-04: the headless and rendered functional runs each passed all 36 assertions with exit status 0 and no warnings or errors; see `headless.log` and `visual.log`. The standard three-lane regression also passed its 59 assertions (`standard-regression.log`). An initial audio-thread shutdown warning was resolved in the harness by stopping playback and yielding 300 milliseconds of real time before exit.

The rendered benchmark completed with no failed checks on Apple M3 using Godot 4.6.1, Forward Plus/Metal. Each measured sample contained 240–242 frames over approximately four seconds, after warmup. Results from `performance.json`:

| Scene | Live attackers | Cannons firing / installed | Mean frame | Frame p95 | Mean physics | Mean render CPU | Peak nodes / shells |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Same-camera baseline | 36 | 24 / 24 | 16.67 ms | 18.37 ms | 3.96 ms | 0.91 ms | 1,602 / 24 |
| Same-camera larger swarm | 180 | 24 / 24 | 16.53 ms | 18.42 ms | 3.53 ms | 0.92 ms | 2,172 / 24 |
| Close frontline and cover | 180 | 8 / 24 | 16.67 ms | 18.79 ms | 4.53 ms | 0.78 ms | 2,147 / 8 |

Both overview cases fired 48 real artillery shots during sampling; the close view fired 16 from the eight guns within range. All samples retained their full requested live population and averaged approximately 60 FPS. GPU timing was unavailable from the Metal backend. These short samples show the larger swarm maintaining this machine's observed frame cadence, not a guarantee of identical performance on all hardware or a long-duration rendered soak. `benchmark.log` contains the raw results.

A separate natural headless run used the normal 24 level-I cannons, an invincible stationary hero off the road, and no hero attacks, upgrades, forced kills, or later repositioning. All 600 enemies were delivered and killed in 132.52 gameplay seconds: zero breaches, shrine 100/100, no surviving or stuck actors, and peak live population 180. The run reached the completion screen normally; see `natural-wave.log`. Its accelerated headless wall time is not an FPS measurement.

Release: universal macOS 2.19.1, installed as `build/Goemon.app`. The preceding Three Gates build is retained as `build/Other Files/Goemon-before-Center-Siege-Beta-2.19.0.app`.

The signed packaged app also ran 1,800 frames directly in beta mode and exited with status 0 (`exported-app.log`). Its forced headless `--quit-after` shutdown reports the pre-existing dummy-renderer shader allocation and an ObjectDB retention warning while audio is active; the functional harness with orderly teardown exits cleanly in both headless and Metal runs.
