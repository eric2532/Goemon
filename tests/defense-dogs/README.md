# Castle companion acceptance

Run from the project root with Godot 4.6.1:

```sh
godot --headless --path . --fixed-fps 60 -- --defense-dog-test
godot --path . -- --defense-dog-visual
godot --path . -- --defense-dog-benchmark
```

The functional harness is `scripts/defense_dog_tests.gd`. It uses imported dog scenes, the real kennel and game UI, actually spawned wave-owned enemies, original hero controls, world collision, and production health/economy paths. Manual clocks isolate attack contact and pause behavior; the castle traversal uses normal dog physics without relocation.

Coverage includes:

- Ten distinct model files and portraits, visible meshes, keyed idle/run/attack/hurt/death clips, moving attack poses, and agreement between the authored one-second attack and its combat contact marker. `asset-qa.json` records mesh/triangle counts and clip durations.
- G opening and closing the roster, pointer activation of its close and purchase buttons, exact gold charges, invalid IDs, insufficient gold, the three-second simulation cooldown, an eight-living-dog cap, a released death slot, and castle-origin spawning while the hero is elsewhere.
- Mandatory card draft, ordinary pause, victory, loss, retry and main-menu guards; immediate retirement and eventual disposal; enemy capacity remaining independent of the pack.
- Real bite damage at the animation contact, a single hit per attack, paused pose/contact, interruption by injury, wall occlusion, bounties only from owned enemy kills, and death animation cleanup.
- Catalog traits: each armor percentage, shield/armor piercing, temporary visible slow, capped cleave with reduced secondary damage, and Suzu's timed/ranged/capped living-pack healing.
- Continuous travel from the castle through its gateway to an opponent; floor escape recovery; enemy windup/contact/cover/locked-target behavior; actual final-boss warning and slam against dogs, pause, one contact, and wall protection.
- The existing movement, double jump, evade, pipe combo, ranged coins, chain sweep, spin, Sky Strike, surge, gold flight and Edo controls.

Visual mode saves roster, bite, support-pack, castle and boss screenshots. Rendered output and `headless.log` are written by their respective runs; a script existing here does not itself establish a passing result.

## Performance fixture

The rendered benchmark compares zero and eight dogs in the same process, camera and quality settings. Each scenario warms up for about 2.2 seconds and samples about four seconds with 180 durable real wave-ten attackers, including the boss, and 24 mixed defenses. The eight distinct dogs retain real animation, movement, targeting, attacks, damage reactions and healing. All actors receive extra fixture health to retain the intended population; this is performance evidence, not normal-play balance evidence.

`performance.json` records average/p95/maximum frame times, process and physics CPU, render CPU, draw calls, peak node/projectile/flame counts, living population, actual dog contacts and enemy retaliation, and paired mean ratios. It requires all eight dogs to land attacks. GPU timings are marked unavailable if the backend supplies zero. Background desktop applications are not stopped, so results describe the measured environment rather than an isolated machine or a minimum FPS guarantee.

## Verification status

On 2026-10-04 the headless functional suite passed **128 checks**, exited successfully, and reported no warnings or runtime errors (`headless.log`). All ten imported models have one skinned mesh, 11,528–14,474 triangles, and five keyed clips: idle 2.0 seconds, run 0.8, attack 1.0, hurt 0.45 and death 0.9. Actual attacks use the catalog's 0.38-second contact marker.

The initial fixture checked a boss warning after only 0.01 seconds, before the deliberately staggered target-acquisition scan could find its newly positioned dog. The corrected fixture steps normal physics until that bounded scan begins the warning; the actual warning, slam damage, pause and cover checks then all pass. A typed-array assertion was also corrected to compare objects without asking the enemy-only array to validate a dog as an enemy.

The combat agent separately reran the original three-lane **59-check** suite and tactical **173-check** suite after integrating dog retaliation; both passed without warnings or runtime errors. Those regressions were not duplicated here.

The full rendered functional run also passed **128 checks** without warnings or runtime errors (`visual.log`). `01-ten-dog-roster.png` shows all ten cards and distinct portraits; the other captures show a real bite, pack healing, castle traversal and a boss targeting a dog. This roster screenshot predates a final card-height/portrait-size adjustment; the packaged check verifies that final layout.

The paired rendered benchmark passed **11 checks** (`benchmark.log`, `performance.json`) on **Apple M3, Metal Forward+, 1280×800, quality 1**, with vsync disabled:

| Metric | No dogs | Eight dogs |
| --- | ---: | ---: |
| Frames (about four seconds) | 172 | 164 |
| Mean frame time | 23.313 ms | 24.403 ms |
| 95th percentile frame time | 49.896 ms | 49.135 ms |
| Maximum frame time | 92.857 ms | 125.062 ms |
| Mean physics CPU | 20.000 ms | 21.709 ms |
| Mean render CPU | 1.971 ms | 2.024 ms |
| Visible/live enemies throughout | 180 | 180 |
| Fire towers / cannons firing | 12 / 12 | 12 / 12 |
| Peak nodes / shells | 2,533 / 11 | 2,618 / 9 |
| Animated dogs / dogs landing attacks | 0 / 0 | 8 / 8 |
| Dog bite contacts during sample | 0 | 18 |
| Enemy retaliation contacts during sample | 0 | 150 |

Adding eight dogs increased mean frame time by **4.67%** and mean physics CPU by **8.54%** in these paired samples. The pack remained at its eight-dog cap; all eight attacked, enemies retaliated, Suzu healed, and effect pools stayed bounded. The unrelated Rogue game remained running on the desktop throughout both samples. The resulting frame times were variable, and the backend did not provide GPU durations. These results quantify incremental cost in that shared environment, not isolated performance or a minimum frame rate. Raw process-CPU samples remain in the JSON as diagnostics; short timing windows can include monitor outliers, so frame statistics are the primary comparison.

The **2.23.0 macOS release passed all 26 packaged checks**, exit 0 with no warnings or runtime errors (`packaged.log`). Its signature passed `codesign --verify --deep --strict`. The release harness exercises the actual exported PCK: all ten models/portraits/five clips, physical G and card input, pointer purchase, exact costs, cooldown pause, castle origin, mode cleanup, and a Hard-mode Iwa purchase from its 650-gold budget. `packaged-kennel.png` shows the final larger portraits and padded cards; `packaged-castle.png` shows the released courtyard.

Run the editor binary with `--path` pointing to an empty temporary directory, `--main-pack` pointing to the app's `Contents/Resources/Goemon.pck`, and `--script` pointing to the absolute `packaged-check.gd` path. An empty working project prevents Godot's filesystem fallback from reading excluded source files in the repository. The first source-directory run correctly exposed this test-environment issue; the isolated run confirms the dense original sculptures and editable Blender sources are absent from the package. No game change was needed.

Installed app: `build/Goemon.app`. Release archive: `build/Other Files/Goemon-2.23.0-Castle-Companions.zip`. Prior app preserved at `build/Other Files/Goemon-before-Castle-Companions-2.22.0.app`.
