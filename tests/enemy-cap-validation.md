# Enemy population cap validation

Cloud Godot 4.6.3, 2026-09-30. Default: **200 active living enemies**; Lab setting 32–400 applies next run. The number preserves the opening two 100-enemy waves, then stops population growth. Lower settings trade crowd density for less simulation work. No claim of measured Mac FPS or production crowd performance.

All production creation paths share `game.enemy_spawn_capacity()`: survival waves, practice spawns, dormant expedition initialization (reserves guardian capacity), and dormant encounter replacements. Dead/queued/freed actors release active capacity; ordinary corpse visuals retain their brief existing cleanup. No living enemies are teleported or deleted to satisfy a lowered next-run setting.

Each wave replaces unplaced demand and only requests free slots. Overflow is skipped, not deferred. Clearing a saturated crowd cannot unleash old wave debt; replenishment waits for the next scheduled wave. Timer, 60-wave sequence and size progression continue. The pre-existing 12 spawns/frame and 3 ms budget remain.

## Sustained real-clock verification

`godot --headless --path . --script scripts/enemy_cap_sustained_tests.gd`: **zero failures**, AI enabled and invincible Goemon, no manual encounter ticks or accelerated time. The run covered **35.0167 gameplay seconds / 34.9582 wall seconds**, observed **2,102 physics frames**, and recorded **maximum 200 active enemies** across all four naturally scheduled waves (0, 10, 20, 30 seconds). Wave three was saturated with zero pending debt. Ten controlled kills at 21 seconds left exactly 190 active enemies, with no replacements before wave four. Wave four replaced exactly ten; final active count was 200 with zero pending, 210 total spawned, 190 skipped requests, and ten kills. Test victims suppress random drops only to exclude unrelated fire-orb chain kills. See `tests/enemy-cap-sustained.log`. This verifies sustained spawning at the default cap, not maximum-setting performance or rendered FPS.

## Verification

- `godot --headless --path . -- --survival-test --survival-load`: **zero failures**, cap and gameplay checks, including default saturation, no backlog, legacy/practice paths, dead/freed cleanup, pause/Lab, all 60 scheduled waves, victory/death, restart, configured 32 cap, last-slot practice ownership/cleanup, and pipe/T/beam combat. See local `tests/enemy-cap-survival.log`.
- `godot --headless --path . -- --firecaster-test`: **zero failures**, current Edo and Goemon combat regressions, including retry. See local `tests/enemy-cap-firecaster.log`.
- Quiet representative cloud sample, 200 living enemies and AI enabled, 120 physics frame notifications: 2,003.259 ms wall time; notification interval median 13.834 ms, p95 20.727 ms; 5,471 nodes. These are headless scheduling intervals, **not rendered FPS or per-frame CPU timings**. Engine last-reported physics value was 23.793 ms (a single monitor sample, not a percentile). No 400-enemy or 8,700-enemy stress run was used to select this bound.

Renderer checks and visual evidence belong to the asset integration validation. The default constrains simulation work; hardware-specific tuning still requires testing on that hardware.

## Full-session accelerated validation (pre-publication follow-up)

`godot --headless --path . --script scripts/enemy_cap_session_tests.gd` completed with **zero failures**. This is three complete 600-second encounter schedules, advancing each ten-second wave explicitly while using real actor creation, physics frames, death handling, reference cleanup and restart. AI is frozen in this invariant test; it does not replace the prior AI-enabled real-clock check or establish rendering performance.

| Configured cap | Waves | Simulated seconds | Maximum active | Sampled physics frames | Controlled deaths | Total spawned | Skipped demand |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 60 | 600 | 32 | 788 | 77 | 109 | 8,591 |
| 200 | 60 | 600 | 200 | 803 | 77 | 277 | 8,423 |
| 400 | 60 | 600 | 400 | 819 | 77 | 477 | 8,223 |

All runs reached saturation, tested practice and legacy replacement rejection at saturation, performed eleven seven-enemy death/cleanup cycles, and verified that no skipped demand refilled between waves. After each cleanup, weak references were released and the enemy registry equaled the living count. Each run paused during wave 17, rejected time/spawn advancement while paused, reached victory exactly at 600 scheduled seconds, rejected a 61st wave, and restarted with all prior actors freed and the configured opening-wave bound preserved. Spawned plus skipped demand equals all 8,700 scheduled requests in every run. Total test wall time: 47.636 seconds; this is accelerated test execution time, **not a performance result**.

Production creation-path audit (`rg 'Ninja.new' scripts`): survival waves, practice spawning, dormant `EndlessEncounters` replacements and dormant expedition initialization all consult the shared capacity. The first three have runtime coverage across these checks and the earlier last-slot tests. Expedition initialization remains unreachable with the compile-time `SURVIVAL_MODE` constant and was **statically inspected**, not falsely claimed as executed: it reserves guardian room and checks capacity before each allocation. The only other creation site is a test fixture in `combat_tests.gd`.

Evidence: `tests/enemy-cap-session.log`. No production gameplay files changed for this follow-up, and no push, PR, merge or deployment was performed.
