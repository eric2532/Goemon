# Fire Siege MVP v2.42 — Ranger higher jumps and held-Space slow fall

Latest `codex/fire-siege-mvp` worktree only, based on installed localv2.41.
User requested twice-high jumps and holding Space while airborne to descend
about three times slower while continuing arrow attacks. All prior Ranger
changes remain; the older Desktop checkout and v2.27 preset are untouched.

## Behavior

Ranger first and second jump launches multiply velocity by√2, producing twice
jump height at unchanged ordinary gravity. Existing level-based height
multipliers remain. Holding Space while rising does not reduce ascent or
automatically consume the second jump. Release and press for the double jump.

During descent, holding Space applies a3× divisor to actual vertical speed.
Ordinary gravity and55m/s terminal momentum continue behind the glide; the
body descends at one-third that ordinary speed. Releasing Space restores
ordinary momentum immediately. The divisor is applied once per step, so long
holds continue descending and cannot create a hover. Glide changes neither
horizontal control nor attack cadence/cooldowns and gives no extra invulnerability.

Existing ground LMB and double-jump downward five-arrow LMB fans continue while
Space is held, including third-shot green power, hit combo acceleration and Rain
powering every arrow. RMB/3 also remains available. Straight launch variance,
damage, arrow sizes, fitted hat and fast directional roll remain unchanged.

Landing clears glide and exhausted jump input to avoid auto-jump/bounce. Cancel,
pause, reset, switching and death clear/restore glide momentum; releasing Space
while paused resumes ordinary falling. Native incoming-hit hook restores
ordinary momentum before adding knockback, applying its impulse exactly once.
Held Space resumes glide after hit recovery. Other heroes retain their prior
jump and fall behavior; Dragoon retains its existing higher launch.

The Ranger description and latest HUD footer teach held-Space slow fall.

## Verification

- Initial RED:87 checks/9 failures againstv2.41 movement.
- Current combined air/precision suite: **93 checks, zero failures**. Real
  first/second peak heights, held first jump, deliberate second jump,3× speed
  and distance ratio, release, no hovering, unchanged ascent/other hero fall,
  LMB fans, third green/Rain, floor, cancel, switch, pause, death and revival.
  All70 retained straight-arrow/combo/roll assertions are included.
- Incoming-hit regression failed before the knockback hook correction and
  passed after it.
- Measured first apex: ordinary4.1607m, Ranger8.2441m. Second launch's added
  height: ordinary3.3600m, Ranger6.7903m. Finite physics-step differences are
  within the2× height tolerance.
- In24 falling frames from the same initial momentum, ordinary fall covers
  7.3000m at24m/s; held glide covers2.4333m at8m/s, exactly3× slower.
- Equipment:63 checks; controls:136; MVP:72. Zero assertion failures.
  Long-range fixture now includes horizontal/vertical coverage and elevated
  launch so legal upward aim variation can miss its old single-height row
  without falsely failing a range test. Diagnostic reproduced1.80/2.20m rays
  passing above the old1.075m target center; gameplay aim remains unchanged.
- Rendered source tour: **23 checks, zero failures**, three captures. Actual
  jump ratio1.9815, fall-speed/distance ratio3.0000, five primary aerial releases
  and five recorded green power arrows. Those gliding fans deal440 native ground
  damage in this run. The fitted Ranger model hash matchesv2.41 exactly.
- Review's two findings are addressed: native-hit restoration prevents impulse
  multiplication; the tour checks recorded third-shot releases after real
  collisions consume their meshes. No remaining actionable issue reported.
- Packaged universal macOS build: **179 checks, zero assertion failures**
  (93 combined air/precision +63 equipment +23 rendered). Three captures.
  Actual glide firing damages ground enemies, third-shot green and Rain are
  preserved, and the geometry hash matchesv2.41. Rendered package exits without
  errors. Strict code signatures pass and installed executable/PCK hashes match
  the tested export exactly.

Evidence: `build/ranger-air/`. The combined suite writes air-measurements.json;
rendered tours save screenshots, actual world paths and observations. Headless
runs retain existing shutdown resource warnings; assertions are separate.

```sh
godot --headless --path . --fixed-fps 60 -- --ranger-air-test
godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-controls-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-mvp-test
godot --path . --max-fps 120 -- --ranger-air-tour
```


## Local build

- Installed: `build/final-macos/Goemon Fire Siege.app` (**2.42.0**).
- Backup: `build/Goemon Fire Siege before Higher Jumps v2.41.app` (**2.41.0**).
- Archive: `build/Goemon Fire Siege Ranger Air v2.42.zip`.
- Captures/samples: `build/ranger-air/packaged-tour/`.
- Focused measurements: `build/ranger-air/package-air-measurements.json`.
- Verified versions/hashes/signatures: `build/ranger-air/build-info.json`.
- Legacy Desktop Git checkout remains clean. No commit or remote publication.

Package rendered measurements: `{"fall": {"held_drop": 2.43333435058594, "normal_drop": 7.29999923706055, "ratio": 2.99999843231685}, "glide_primary_releases": 5, "glide_target_damage": 440.0, "gliding_power_arrows": 5, "jump_heights": {"ordinary": 4.16048746556044, "ranger": 8.2439029738307, "ratio": 1.98147525790472}, "ranger_geometry_sha256": "9c6e21304429c59c2078e04ac4c5194485c5094c42750c7a405f7eb11ec99edd"}`.
