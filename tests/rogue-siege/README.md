# Rogue Siege validation

The integration suite drives the real main menu, difficulty and fighter selectors, Hero inputs, imported Rogue actions and animations, actual Ninja targets, and the existing Fire Siege director. Enemy AI and the director are frozen only during isolated combat fixtures.

Run from the project directory:

```sh
/opt/homebrew/bin/godot --headless --path . -- --rogue-siege-tests
/opt/homebrew/bin/godot --path . -- --rogue-siege-visual
```

Source runs write captures and `class-qa.json` here; recorded validation logs are saved alongside them. Exported application runs write generated captures and JSON under `user://tests/rogue-siege`, keeping the signed application resources unchanged. `class-qa.json` records the loaded model path, native attack style, and measured first-hit damage for every fighter. The suite hashes loaded mesh surface arrays to prove all ten models have distinct geometry. Source runs additionally record and verify original GLB SHA-256 values; exported runs leave that source-file field empty because Godot remaps those files into imported scene resources.

## Results

The expanded Goemon, larger-character, and walking-camera suite passed **173 checks with zero failures** in the source rendered run and the packaged 2.27.0 headless run. Current evidence is in `../rogue-siege-polish/rendered.log` and `../rogue-siege-polish/packaged.log`. All three Goemon stages ran at attack speed 1.000; contact was observed at 0.167, 0.167, and 0.150 seconds, within the one-physics-frame sampling tolerance around 0.15 seconds. The source rendered run shut down cleanly.

Preliminary runs exposed two fixture cleanup issues: the Goemon-first dummy remained before the director-owned bounty fixture, and the real bounty kill's dropped orbs could grant attack speed during the following baseline timing test. The suite now removes that dummy before scheduling the wave and retires leftover pickup nodes before resetting Goemon's timing fixture. Timing assertions explicitly require base attack speed and retain their original contact bounds. Neither correction changed gameplay.

The initial release was validated on 2026-10-04 with Godot 4.6.1. Its rendered run completed **141 checks with zero failures**; see `rendered.log`. Every native primary damage value below was measured against a real target. The initial headless integration run passed its 127 checks before the focused cover, range, defensive-kit and menu-route cases were added. `class-qa.json` is overwritten by the latest suite run.

The first rendered run exposed a test-harness timing error in the Knight riposte check: its wait helper returned during hit-stop before a buffered primary began. The helper now waits for buffered actions as well as active attacks; the final run confirms the expected 76-damage riposte. This did not require a gameplay change.

### Exported release

The **2.27.0** package passed **173 checks with zero failures**, using `--headless --fixed-fps 60 --max-fps 240 -- --rogue-siege-tests`. Its export is `build/Other Files/Goemon-Rogue-Siege-Polish.zip`; current validation artifacts are under `tests/rogue-siege-polish/`. The packaged headless shutdown emitted a dummy-renderer shader allocation error, an ObjectDB leak warning, and an error reporting 15 resources still in use. These were shutdown diagnostics, not failed test assertions. The packaged Metal launch completed 120 frames and exited cleanly, without warnings or errors; see `../rogue-siege-polish/packaged-rendered-launch.log`. The installed `build/Goemon.app` passed signature verification after testing and replacement; `../rogue-siege-polish/build-info.json` records the release, backup, and verification results.

The historical signed **2.26.0** release passed **141 checks with zero failures** (`packaged.log`). Its ten loaded model geometries have distinct SHA-256 fingerprints; see `packaged-class-qa.json`. Its export remains `build/Other Files/Goemon-Rogue-Siege.zip`, and `build-info.json` in this directory records that initial installation and signature verification. The app predating that release was preserved at `build/Other Files/Goemon-before-Rogue-Siege-2026-10-04.app`.

The first packaged run confirmed the source-file hash audit was unavailable after GLB import remapping. The assertion now validates loaded geometry in both source and exported runs, while retaining the original-file audit where the source GLBs exist. This changes the test's asset evidence, not gameplay or model loading.

## Coverage

- The real launch route includes the main menu, Beta/Hard selection, Goemon plus all ten native fighters, and the mandatory opening card draft.
- Goemon can be selected before any native fighter has loaded. His plain-pipe attacks retain the original model and 22/22/30 base damage, with 0.48/0.48/0.576-second stages and contact near 0.15 seconds. Real input covers single taps, held three-stage repetition, late buffering, expired early taps, and the unchanged heavy-attack timing. His slash and sound effects use the same shared Rogue resources as the native fighters.
- Native/Goemon/native swaps preserve health percentage and native cooldowns. Pause freezes Goemon's pose and shared effects without replaying held input; restart remembers Goemon and clears his pending combat. Exiting with Goemon selected restores the previous original hero while remembering the siege selection.
- Every native fighter loads its own GLB, animates authored joints, performs its own primary windup and contact, and produces exactly one tap-triggered attack.
- Every native fighter keeps its 15 percent visual size increase while animating. The camera smoothly leads screen-forward walking, keeps its angle, returns to idle framing after movement stops, and ignores attack-lunge velocity when no movement is requested.
- Every secondary, movement utility and signature skill runs through real input. Additional checks cover Ninja's five stars, Ranger's four arrows, piercing waves, Knight blocking and riposte, Master Thief's charged fire and low stance, Pirate untargetability, Samurai's draw-cut, Mage cast speed, Explorer critical damage, and Grand Smoke's enlarged pipe.
- Physical cover blocks shots, close muzzle spawning, piercing effects, dashes, blinks and lance leaps. Real incoming hits retain knockback. Range pickups and growth increase both damaging reach and the emitted slash geometry.
- The original 24 defenses, cards, dogs, humanoid summons, first wave, and 12-gold owned-enemy bounty remain active. Hard retains four defenses, 650 gold and 50 shrine health.
- Pause freezes native timers and poses. Switching preserves health percentage and spent cooldowns. Restart clears all cached classes. Leaving restores the previous defense configuration, original hero and perspective camera. Goemon's original automatic triplet is checked afterward.

The suite samples the existing wave director and preserves its ten-wave configuration. The separate defense-tactics suite covers the full 6,000-enemy campaign.

## Native first-hit values

| Fighter | Attack style | Measured damage |
| --- | --- | ---: |
| Pirate | Cutlass | 25 |
| Samurai | Katana | 34 |
| Ninja | Short katana | 18 |
| Mage | Staff pulse | 64 |
| Knight | Broadsword | 42 |
| Dragoon | Lance thrust | 37 |
| Magic Swordsman | Claymore | 42 |
| Ranger | Power arrow | 67 |
| Explorer | Twin blades | 19 |
| Master Thief | Pipe | 62 |

## Captures

- `00-main-menu.png`: separate Rogue Siege entry.
- `01-difficulty-choice.png`: preserved Beta and Hard configurations.
- `02-starting-fighter-picker.png`: Goemon and all ten native playable fighters before launch.
- `03-opening-draft.png`: original three-card opening choice.
- `04-in-game-fighter-picker.png`: class switching during the paused siege.
- `05-goemon-first-contact.png`: Goemon's first actual contact before loading a native fighter.
- `06-goemon-third-contact.png`: Goemon's third stage with the shared native slash effect.
- `07-siege-camera-idle.png` and `08-siege-camera-forward.png`: idle framing and screen-forward walking lead.
- `primary-01-pirate.png` through `primary-10-master-thief.png`: each native fighter at actual attack contact.
- `18-range-pickup-span.png`: increased damaging reach and matching slash geometry.
- `20-hard-opening-draft.png`: selected Knight in the original Hard economy.

## Preserved-mode regressions

- `legacy-rogue-battle.log`: 48 checks passed for the existing Sky Descent cursor-combat mode.
- `legacy-defense-tactics.log`: 173 checks passed for the original Fire Siege cards, enemy defenses, campaign progression, and Goemon/Edo controls.

## Camera visibility update · 2.26.1

Rogue Siege now uses a 24-unit orthographic view and roughly 48° downward pitch, keeping its horizontal direction. The existing 141-check rendered suite passed with the new camera, and the packaged Metal build launched and exited cleanly after 120 frames. Camera before/after captures, logs, and installed-release metadata are in `../rogue-siege-camera/`. Other modes retain their previous camera.
