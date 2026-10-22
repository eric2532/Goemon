# Three-lane tower defense validation

Run the integrated scene with the same character controller and combat systems used by the other modes:

```sh
godot --headless --path . --fixed-fps 60 -- --tower-defense-test
godot --path . -- --tower-defense-visual
```

The suite exits with `TOWER_DEFENSE_RESULT failures=0` on success and a nonzero exit status on failure. The visual run saves menu, battlefield, solid cover, purchased cannon, shared gold-cloak flight, and shrine defeat PNGs in this directory.

Coverage includes:

- A separate main-menu choice, a large physical battlefield, evenly populated distant three-lane waves, and actual shrine-directed enemy movement while the hero is off the path. One real actor from each gate traverses its entire lane and the merged approach to the shrine; displaced raiders also recover around cover.
- The opening preparation window and time between waves; no early spawns; increasing second-wave size.
- Money from actual enemy deaths and cleared waves; no duplicate corpse rewards, practice-enemy farming, or breach rewards. Cannon kills cannot farm the hero's personal healing, progression, or attack chain.
- Physical F interaction, proximity and affordability checks, cannon construction, upgrades, and automatic cannon damage from real projectiles.
- Solid cover blocking a physics ray, normal hero movement, and a real thrown coin.
- Pause, including cannon cooldown and an in-flight shell; shrine damage and defeat; restart reset; and returning to the original survival and sky-descent modes.
- Shared walking, jumping, double jumping, evasion, pipe combo, Sky Strike, weapons, surge, gold-cloak flight, character switching, and Edo ranged combat.

The harness stops the encounter clock where necessary to isolate scenarios, but uses real enemy physics, world collision, player input events, and cannon shell updates. Test fixtures deliberately reposition actors and set money/health to exercise edge cases quickly.

Validated with Godot 4.6.1 on 2026-10-04: both headless and rendered Metal runs passed all 59 assertions with exit status 0 and no warnings or errors. See `headless.log` and `visual.log`. Full lane traversal uses a 3x simulation rate so its physics step still fits the existing crowd controller's 0.15-second motion intervals.

The universal macOS 2.19.0 export also booted directly into defense and ran 2,100 frames successfully (`exported-app.log`). Godot's forced headless exit reports one dummy-renderer shader RID allocation; the previous app produces the identical exit diagnostic. The normal rendered integration suite exits cleanly. The installed app is `build/Goemon.app`; the prior app is preserved under `build/Other Files/Goemon-before-Three-Gates-2026-10-04.app`.

The existing `--coin-scaling-test` regression suite also passes against the final code with `COIN_SCALING_RESULT failures=0` and no warnings/errors (`coin-regression.log`).
