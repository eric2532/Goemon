# Castle humanoid acceptance

## Packaged release

The **2.24.0 macOS release passed all 30 packaged checks**, exit 0 without runtime warnings or errors (`packaged.log`). Its signature passed `codesign --verify --deep --strict`. The external `packaged-check.gd` harness ran against the exported PCK from an empty project directory, so the source checkout could not supply missing resources. It verified all ten models and portraits, actual Goemon controllers, physical H/G switching, pointer purchases, independent cooldowns, castle origins, mandatory drafts, cleanup, and purchases in both Beta and Hard mode. Dense upstream sculptures and editable Blender sources are excluded from the release.

Installed app: `build/Goemon.app`. Archive: `build/Other Files/Goemon-2.24.0-Castle-Heroes.zip`. Previous app: `build/Other Files/Goemon-before-Castle-Heroes-2.23.0.app`. `release.json` records archive and PCK hashes; `packaged-barracks.png` and `packaged-castle.png` show the released roster and courtyard. The export log contains the existing notice that the nested `asset_packs/cedar_pass` project is ignored; the export completed successfully.

To repeat packaged verification, use the full Godot executable with `--path <empty-directory> --main-pack <app>/Contents/Resources/Goemon.pck --script <absolute-path>/tests/defense-heroes/packaged-check.gd`. The native release executable does not support loading this external test script.

## Source acceptance

Run with Godot 4.6.1 from the project root:

```sh
godot --headless --path . --fixed-fps 60 -- --defense-hero-test
godot --path . -- --defense-hero-visual
godot --path . -- --defense-hero-benchmark
# Focused castle movement / spacing checks:
godot --headless --path . --fixed-fps 60 -- --defense-hero-route-test
godot --path . -- --defense-hero-route-visual
```

`scripts/defense_hero_tests.gd` uses the actual game, roster buttons, imported character rigs, wave-owned opponents, world collision and original controls. It does not replace attack damage, targets, enemy retaliation or the animation controller with stubs.

Coverage includes:

- All ten GitHub concept-pack identities, distinct exported models and portraits, skinned articulated bones, and authored clips required by the real `HeroModel` / `HeroLocomotion` controller.
- Every character moving its actual skeleton with `PipeCombo.sample`, landing the first real contact, and the full shared three-stage combo at 0.0952, 0.4092 and 0.8888 seconds. The same Goemon choreography drives the model and damage clock.
- Physical H opening the ten-character roster, actual mouse clicks, H/G switching between menus while paused, distinct close buttons, exact gold charges, invalid/insufficient purchases, independent three-second cooldowns, and simultaneous caps of eight dogs plus eight humanoids.
- Mandatory drafts, ordinary pause, injury interrupting the remaining combo, world cover, enemy bounties without personal hero XP/healing, death disposal, retry, shrine defeat, victory, menu and original-mode cleanup.
- Real travel through the castle gateway, at least one metre of sustained mixed-ally center spacing, floor escape recovery, nearest mixed-population enemy targeting, locked retaliation, stale-target cancellation, and actual final-boss damage/pause/cover protection for both ally types.
- The player's existing movement and full shared combat controls.

`asset-qa.json` records imported mesh/triangle/bone counts and combo durations. Visual mode saves the roster, shared combo, mixed castle defense and boss confrontation.

## Paired performance

The benchmark keeps 180 durable real wave-ten enemies, all 24 defenses and eight distinct dogs in both scenarios. It then adds eight humanoids with the full Goemon locomotion, foot IK and three-hit combat controller. When the functional asset report is present, it selects the eight distinct humanoid designs with the highest measured triangle counts and records their IDs. Camera, settings and population are otherwise the same. Each scenario warms up for about 2.2 seconds before a roughly four-second sample; raised fixture health preserves population while leaving real movement, combat and damage reactions enabled.

`performance.json` records frame mean/p95/max, process/physics/render CPU, GPU timing availability, draw calls, peak nodes/projectiles, visible populations, actual dog/humanoid attack contacts and enemy retaliation. It checks that all eight humanoids attack and receive damage. This comparison measures incremental load in the existing desktop environment; background applications are not stopped. It is not a balance test or a minimum-FPS guarantee.

## Verification status

On **2026-10-04**, the final source build passed **132 headless checks** and **132 rendered checks**, both with successful exits and no runtime warnings or errors (`headless.log`, `visual.log`). Every final humanoid imports as one skinned mesh with 22 bones and 20,671–22,311 triangles; `asset-qa.json` records the final GLB SHA-256 hashes. All ten characters passed actual shared-pose, moving-skeleton and damage-contact checks.

The initial visual run exposed a genuine mixed-roster movement defect: a humanoid and dog could approach the same enemy and finish only **0.128 m** apart. Bounded steering now considers both companion rosters and sidesteps an occupied attack position. The final natural traversal and additional 90 combat frames maintained **1.243 m** minimum separation while the dog landed four contacts and the humanoid landed three. Focused headless and rendered route runs each passed four checks (`spacing-check.log`, `spacing-visual.log`). `04-mixed-close-combat.png` uses a second camera angle to show their separate bodies and feet clearly. The original bad capture remains `before-spacing-close-combat.png`.

Final visual acceptance followed the localized Nagi sleeve/trim binding correction and Banji torso-gear/portrait correction. The ten-card H roster now shows consistent bust portraits. Earlier captures/logs are explicitly prefixed `before-` or `initial-`; final unprefixed results use the repaired assets. Art review separately compared Sen's rear hair to its source and confirmed that silhouette was intentional.

After the shared dog hooks and enemy retaliation were generalized, the existing dog **128-check** and tactics **173-check** suites passed without warnings or runtime errors. The dog suite was rerun after the spacing correction and again passed all 128 checks. `regression-dogs.log` contains that latest result; `regression-tactics.log` retains the earlier clean shared-targeting regression. Those runs were not duplicated here.

## Measured paired result

The final rendered benchmark passed **15 checks** without warnings or runtime errors (`benchmark.log`, `performance.json`). It ran on **Apple M3, Metal Forward+, 1280×800, quality 1**, with vsync disabled and a four-second sample per scenario:

| Metric | Eight dogs | Eight dogs + eight humanoids |
| --- | ---: | ---: |
| Measured frames | 240 | 240 |
| Mean frame time | 16.667 ms | 16.671 ms |
| 95th percentile frame time | 18.135 ms | 18.508 ms |
| Maximum frame time | 24.457 ms | 20.119 ms |
| Mean physics CPU | 7.193 ms | 8.780 ms |
| Mean render CPU | 0.839 ms | 0.785 ms |
| Mean draw calls | 883.8 | 925.0 |
| Visible/live enemies throughout | 180 | 180 |
| Fire towers / cannons firing | 12 / 12 | 12 / 12 |
| Peak nodes / shells | 2,626 / 9 | 2,828 / 9 |
| Dog contacts during sample | 17 | 18 |
| Humanoid contacts during sample | 0 | 31 |
| Enemy retaliation contacts during sample | 150 | 173 |

All eight humanoids attacked using their real rigs, and both populations remained at their separate eight-ally caps. The mixed sample used Kuren, Izumi, Shiro, Banji, Sen, Nagi, Touma and Raku, the eight distinct models with the highest triangle counts in the final asset report. Physics CPU increased by about **1.587 ms / 22.1%**; measured frame cadence stayed near 60 Hz in both samples, with a **0.03%** mean difference. GPU duration was unavailable from the backend.

The unrelated Rogue application was present throughout the paired run (PID 61646), with read-only CPU observations of 50.6% before and 52.5% after; it was not stopped. These brief samples describe this concurrent desktop environment. They do not establish a minimum frame rate on other machines or over the full campaign. The higher actor health is a measurement fixture, so these runs do not establish normal-play balance.

Final exported-package and installation verification are recorded separately by the release harness.
