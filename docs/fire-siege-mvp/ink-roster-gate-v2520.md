# v2.52.0 Ink Brush and Shrine Gate Crosshair Preview

All twelve heroes share colored ink-brush attack and hit feedback. Melee ribbons follow authored blade poses, including both Explorer blades; projectile wakes keep each ability's silhouette. Native Goemon/Edo effects use a separate single clock and bounded feedback. Ranger retains fan spread, release deviation, curved flight and aerial aim. Samurai retains five cuts, the 150-damage red arrow, and ten-second five-times-speed ultimate; Magic Swordsman retains the wide 100-damage, 40-metre purple wave.

The projected target circle and LOCK text are hidden. J still acquires the nearest visible living enemy, and mouse camera control and the center crosshair remain available.

## Build the barrier

In standard expanded Fire Siege, approach the opening five metres ahead of the starting point and stand still on the ground for three seconds. The wall and transparent gate cost **10 gold** together. The gate begins with **5,000 HP**; rebuild for another 10 gold after it breaks. No tower upkeep is charged for it. First construction also waits until all future solid wall volumes are clear of players, enemies and allies. Live enemies inside the panel volume defer completion and payment until the opening clears.

Players and friendly attacks pass through the thirty-percent-opacity panel; enemies collide with it. Side walls and the frame are solid. Entrance-side wave raiders prioritize eight gate positions and use independent **1.25-second** strike clocks, each doing **20 base damage × archetype multiplier × enemy-damage tuning**. Other raiders wait at distinct legal points. Stun, freeze, hit pause, displacement, death and ownership retirement cancel contacts; a long update emits no catch-up burst.

When the gate breaks, its panel opens and survivors resume their ordinary route and shrine combat. Breaking it grants no kills or rewards. Rebuilding leaves inside actors and existing shrine assignments alone. Shrine health and its separate one-HP/2.5-second contacts remain unchanged. Wall geometry persists through destruction; the barrier resets for a new run. Custom maps receive no automatic gate. Exploration districts, discoveries, ice upgrades, tower/mine economy and ten defense waves remain included.

## Controls

WASD move; mouse look; LMB primary; RMB / 3 secondary; Space jump; Shift sprint; R ultimate; C evade; E utility; Q hero picker; J nearest-visible-target auto attack. Stand beside an unbuilt pad to construct. F upgrades an arrow tower into a zero-damage ice tower for 10 gold. Hold Y for three seconds to start the next wave. Esc pause/settings. Explore freely between waves.

## Verification and limits

- Exact engine: Godot 4.6.3.stable.official.7d41c59c4; Metal Forward+ visual captures.
- Combined source suite: 27 suites pass with zero gameplay assertions or script/runtime errors. New roster 442, gate unit 622, gate integration 368, and full ten-wave campaign 117 assertions are included. AttackChain has its own zero-failure summary without a reported count.
- Real input checks cover all heroes and preserved Samurai/Magic/Ranger abilities. Gate tests use a 300-actor owned wave, timed contacts, hero death, collision, real melee/wave/J passage, side-wall obstruction, pause, rebuilding, new runs and custom maps.
- Deterministic visual captures freeze effect aging or simulation to inspect each hero's primary/secondary, confirmed impacts, representative ultimates, and gate states. These captures are **not FPS measurements**.
- Legacy native `power-combat`, `coin-scaling` and `firecaster` suites have 11, 3 and 9 preexisting failures respectively, reproduced with identical assertion messages and result summaries in the untouched v2.51.3 game pack. Their obsolete native balance expectations and existing high-coin-count stress bounds were not changed to make this release appear green. Raw baseline/current/exported evidence is included with delivery.
- Some accelerated headless suites retain the existing audio/ObjectDB resources-at-exit diagnostic; native template checks may report the existing DummyShader RID at shutdown. These diagnostics are recorded separately from gameplay/script errors.
- Full-session playtesting and foreground FPS benchmarking remain deferred by the user. `fps_verified=false`; no stable-60-FPS claim.
- Universal architectures, ad-hoc signature, final archive extraction/CRC/hash, all 16 protected character-model hashes, and four older preview archives must pass the delivery assembly checks.

## Implementation rulings

1. Functional automation uses `--fixed-fps 60` to advance a fixed 60-Hz delta without real-time synchronization. It cannot establish real FPS; native/nominal checks supplement it. Risk if misinterpreted: misleading performance conclusions.
2. Ground combat fixtures wait for actual floor contact after resetting models/scale, so grounded attacks do not accidentally test a settling collider. Airborne/reset checks remain separate. Risk: a reset-time movement problem could be concealed by fixture waiting.
3. Three legacy native suites are compared exactly against the previous game pack rather than reported as all green. Their 23 existing failures remain; new Fire Siege input/appearance/lifecycle checks must pass. Risk: those older stress/balance issues remain in this preview.
4. Four campaign assertions were updated for surviving shrine attackers after all four failures were reproduced in untouched v2.51.3. The ten-wave fixture now exercises 3,000 actual deaths and a final timed shrine strike. Risk: a mistaken accounting expectation could hide a regression; direct wave/health/accounting checks cover it.

Independent review, exported-pack/native results, final source commit and delivery manifest accompany the finished preview. Local branch and worktree are preserved; this preview is not a GitHub publication.

Independent review found one important first-construction occupancy issue: side walls could enclose the builder or another actor. A real eligible-builder/other-body regression failed first; initial construction now checks every future solid collider before charging. Panel rebuilding keeps friendly passage. No critical or minor findings were reported. Full affected checks rerun after the fix.

5. Real-time FPS and full-session performance are outside this review, following the user's development-first instruction. Risk: stable 60 FPS remains unverified.
6. Repairing the 23 unchanged legacy native failures is outside this source change. Risk: those existing stress/balance issues remain.
7. Export/signing/archive are downstream of the reviewed source range and gated by exact native/pack/signature/CRC/extraction checks. Risk: packaging or real play could still fail beyond these checks.
8. Crosshair equipment tests aim the actual camera at the promised platform and long-range targets, and use a ground formation with depth for aerial spread. RED 63/7, then GREEN 63/0; gameplay is unchanged. Risk: a fixture layout mistake could miss another aim defect; dedicated alignment, deviation, curves, range and cover checks remain.

Deferred minor review findings: none.

Final verification: source 27/27 suites (2,645 counted checks plus AttackChain), final exported resources 27/27 (2,644 plus AttackChain), and the actual native app 7/7 (1,595 checks), all with zero functional assertions or script/runtime errors. The exported crosshair fixture omits the source-only feature-enable assertion, accounting for its one-check difference. All seven final-pack Metal captures rendered without script/shader errors and were inspected. The signature/archive/model/hash checks are enforced by the delivered assembly manifest.
