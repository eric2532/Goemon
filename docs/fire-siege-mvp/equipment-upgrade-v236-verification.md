# Fire Siege MVP v2.36.0 — equipment and skill verification

Continues the latest v2.35 MVP in `codex/fire-siege-mvp`, retaining the earlier
combat, facial depth, movement, construction and progression changes.

## Changes

Dragoon wears a dragon-shaped blue/teal/silver helmet; Magic Swordsman has a
violet helmet with a crystal crown. Samurai's red cloth wraps his neck and mouth,
with a separate long tail that waves at rest and more strongly while running.
Ninja's lower jaw and fitted mask are slightly fuller. Source models remain
editable and regenerate through `tools/style_rogue_roster.py`.

Dragoon Leap (right-click / 3) now immediately descends when used airborne.
Grounded use retains the forward arc. Wall or ceiling contact transitions into
descent; an actual floor collision is required before the three blue impact
pulses. Each pulse retains its 64 base damage. Normal doubled-height jumps remain.

Ranger primary timing is divided by three, and all Ranger arrows are twice the
visible size. The selected interpretation of “shoot three times faster” is
firing cadence. At 60 Hz, the measured interval is 13 frames (0.2167 seconds),
compared with the previous configured 0.62 seconds. Flight speed, range and
Samurai's bow remain unchanged.

## Source verification

| Suite | Checks | Failures |
| --- | ---: | ---: |
| New equipment combat and lifecycle tests | 41 | 0 |
| Existing v2.35 combat | 99 | 0 |
| Earlier Rogue combat upgrade | 76 | 0 |
| Controls | 136 | 0 |
| Motion | 95 | 0 |
| Weapon weight | 104 | 0 |
| Native weapon poses | 27 | 0 |
| Scarf mesh, wind, material and reset behavior | 13 | 0 |
| Actual MVP rendered equipment and ability tour | 95 | 0 |
| **Total runtime checks** | **686** | **0** |

The initial new combat regression failed 19 of 34 checks before the fix. Final
canonical logs are clean. An accelerated headless v2.35 diagnostic retained WAV
playback at process exit; its final normal-speed rerun has no warnings or errors.
Test teardown now releases shared audio streams. No production audio changes.

Art validation passes 1,929 checks. All 34 original pivots and 532 body/weapon
components remain exact. Goemon, the painted face atlas and the six other heroes
are preserved. The four revised GLBs and all ten palette atlases rebuild
byte-identically from tracked originals. New geometry and exported face UVs pass
validation. Four portraits and 64 Blender/source-export comparison images were
reviewed. The final in-game tour adds 29 captures covering four views, scarf
motion, airborne/grounded landings and enlarged arrows.

Independent review found no outstanding production issues. Visual QA corrected
Dragoon's helmet-eye inlay fit and widened test cameras to show the complete
helmets. Final imported models were recaptured after that correction.

Python compilation and `git diff --check` pass. Godot import retains only the
pre-existing warning about the ignored nested economy validation project.

## Reproduction and evidence

```sh
godot --headless --editor --path . --import
godot --headless --path . --script scripts/rogue_scarf_tests.gd
godot --headless --fixed-fps 60 --max-fps 120 --path . -- --rogue-equipment-combat-test
godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-equipment-upgrade-tour
```

Evidence is in `build/rogue-equipment-upgrade/`: canonical combat logs and
`combat/verification.json`, art validation/reproduction JSON, independent review
notes, and `tour/verification-manifest.json` with 29 rendered captures.

## Packaged delivery

The exported macOS app passed the 95-check rendered tour and 41-check combat
suite: **136 packaged checks, zero failures**, with no runtime warnings/errors.
Its four revised model hashes and measured Ranger cadence match source evidence.
Source and package verification total **822 runtime checks**.

Version **2.36.0** is installed at `build/final-macos/Goemon Fire Siege.app`.
Version 2.35.0 remains at `build/Goemon Fire Siege before Equipment Upgrade.app`.
The distributable archive is `build/Goemon Fire Siege Equipment Upgrade.zip`.
Strict code-signature verification passes; the installed executable and resource
PCK match the tested staging app byte-for-byte. Version, paths and SHA256 hashes
are in `build/rogue-equipment-upgrade/build-info.json`.

Final packaged screenshots are in `build/rogue-equipment-upgrade/packaged-tour/`;
the compact four-character preview is `equipment-in-game.png` in the parent
evidence directory. No remote release was published.
