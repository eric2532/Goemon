# Fire Siege Rogue upgrade — v2.33.0

Completed 9 October 2026 in `/Users/eric/.codex/worktrees/fire-siege-mvp/Sonic`, branch `codex/fire-siege-mvp`, based on `ed8c003` plus the existing uncommitted movement/camera work. That work remains present and passed its regression suite. The older Desktop checkout was left untouched. This is a local macOS build; no remote release was changed.

## Delivered behavior

- All ten Rogue fighters have revised weapon poses. The Magic Swordsman supports the heavy claymore with both hands on his right side; Pirate carries his sword high; Knight and Samurai use neutral carries; Ranger aims his bow forward; Ninja and Explorer use reverse grips. Samurai wears the bow on his back except while shooting.
- RMB and **3** share secondary press, hold, and release behavior for the ten Rogue fighters. Samurai's bow and Ninja's enlarged shuriken are on **E**; **C** remains evade. Goemon's numbered attacks are preserved.
- Ninja performs a long cutting dash. Explorer alternates evasive underhand primary attacks and performs a dashing cross slash. Samurai has an eight-metre red energy slash with a deliberate windup.
- Dragoon's thrust is longer and wider. Leap lands with three expanding blue damage pulses.
- Mage releases a fireball on LMB release, with charge tiers at one, two, and three seconds. Frost nova freezes nearby enemies for three seconds and deals no damage.
- Master Thief has faster, wider, growth-scaled swings and a stationary, red-glowing pipe guard while secondary is held, capped at three seconds.
- Knight has longer sword reach and a two-second defensive window that counters an incoming hit with a large navy energy shield bash. Existing R signature effects remain functional.
- Four mines build and earn independently; three are near spawn. Construction accepts any accessible side within range. Build circles are removed. Nearby structures show an in-range prompt, and untouched or completed structures hide construction bars.

Reverse-grip pose reference: the official [Good Smile figma Levi gallery](https://www.goodsmile.com/en/product/1978/figma%20Levi). The game poses adapt the low, outward reverse-grip silhouette to these character rigs.

## Verification

All source suites completed with zero assertion failures: **976 checks across 12 suites**.

| Suite | Checks |
| --- | ---: |
| Fire Siege state | 65 |
| Construction structures | 71 |
| MVP integration | 72 |
| Campaign | 117 |
| Controls | 136 |
| Three-gate tower defense | 59 |
| Rogue combat upgrade | 76 |
| Rogue poses | 27 |
| Movement and camera | 103 |
| Turning | 51 |
| Weapon weight/carry | 104 |
| Motion | 95 |

The exported macOS app also passed **251 checks**: combat 76, MVP integration 72, and movement/camera 103. Tests cover charge tiers, overlapping keyboard/mouse secondary holds, guard expiry and cancellation, directional/swept hit coverage, cover blocking, growth scaling, three leap pulses, freeze without damage, independent mine income, and construction from different sides.

Independent review found and fixed two regressions before export: Samurai's secondary briefly selected his bow pose during the slash, and Master Thief's E action left a stale guard pose. Added regression assertions pass in source and package.

Rendered Metal walkthroughs completed for abilities and construction without script errors or shutdown diagnostics. Inspected all ten idle/run carries plus charge, guard, bow, dash, slash, ice, shield, and leap effects. The packaged construction tour confirms the nearby prompt, hidden untouched bars, partial build progress, completed mine income, live combat, death, and revival.

Headless shutdown diagnostics remain: the source combat and motion suites report retained audio resources at process exit; packaged headless tests report a dummy-renderer shader allocation and, in combat/movement, retained resources. These are exit-time cleanup diagnostics, not assertion failures. They do not appear in the two rendered packaged walkthroughs. Logs retain the exact output rather than suppressing it.

Logs and machine-readable summaries are in `build/verification-rogue-upgrade/`, including `source-results.json`, `packaged-*.log`, and `build-info.json`. Export completed successfully, `git diff --check` passed, and the installed app passed `codesign --verify --deep --strict`. Its executable hash was unchanged when moved from the tested staging location to the launch location.

## Local delivery

- Updated app: `build/final-macos/Goemon Fire Siege.app`
- Previous app backup: `build/Goemon Fire Siege before Rogue upgrade.app`
- Export archive: `build/Goemon Fire Siege Rogue Upgrade.zip`
- App version: **2.33.0**
- Archive SHA-256: `2bd109a4b67c947a118a6c46200fc9cb274ae7bc5f8197604fff13f007de420f`

Rendered package captures are under `~/Library/Application Support/Godot/app_userdata/Goemon Fire Siege/tests/rogue-upgrade/` and `~/Library/Application Support/Godot/app_userdata/Goemon Fire Siege/fire-siege-mvp-captures/`.
