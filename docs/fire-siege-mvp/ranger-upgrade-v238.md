# Fire Siege MVP v2.38 — Ranger

This update is based on `eb97bcc` in the latest `codex/fire-siege-mvp` worktree.
The older Desktop v2.27 checkout is clean and its app remains unchanged.

## Controls and appearance

- Full forest-green hat crown, swept brim and rear coverage, with a chestnut
  band and gold feather. The current painted face, hair, weapon and body remain.
- Ranger arrows are 20% larger than v2.37 (visual factor 2.4 instead of 2.0).
  His three-times primary fire rate, damage and triple travel range remain.
- RMB or 3 releases five arrows simultaneously in a forward fan, each dealing
  25 damage. Rain retains repeat fire while holding either binding.
- After the second jump, LMB fires five arrows downward toward the real ground
  ahead in camera-facing direction, with a downward bow pose. RMB/3 also points
  downward after a double jump. Landing restores the single primary arrow.
- C rolls in the movement direction, or forward without movement input:
  0.24 seconds at 23 metres/second, with a 0.75-second cooldown. The model
  tucks and tumbles around its body centre. Native cover collision remains.
- The current HUD labels Fan Shot, C Fast Roll and the aerial input.

## Verification

Art validation passes 358 checks, including coverage of all 515 sampled scalp
points, exact preservation of eight pivots, 121 body/weapon and six hair meshes,
and 72 protected asset hashes. The editable Blender source and standard rebuild
path are included. See `docs/art-direction/ranger-hat.md`.

Source runtime suites pass with zero assertion failures:

| Suite | Checks |
| --- | ---: |
| Equipment combat, fan ballistics, early/late double jump and roll | 63 |
| MVP economy, construction, waves, death and revival | 72 |
| Controls and native secondary skills | 136 |
| Combat upgrades | 76 |
| Poses | 27 |
| Scarf | 13 |
| Rendered Ranger tour | 30 |

The rendered tour uses the live MVP hero selector, styled model, actual input,
collision and enemies. Nine captures cover four hat angles, ground fan,
high double-jump downward fan, two roll phases and HUD. Independent gameplay
review found no actionable issues. Headless combat suites retain shutdown
resource warnings; the focused rendered tour exits without warnings/errors.

Evidence is under `build/ranger-redesign/`: art validation, source test logs,
and `tour/verification-manifest.json` with screenshots and imported mesh hash.

The packaged v2.38 app passes the same 63 equipment checks and 30 rendered
tour checks, with nine captures. The imported Ranger mesh hash matches the
source exactly. The rendered package exits without warnings/errors.
Strict code-signature verification passes; installed executable and PCK hashes
match the tested package.

Installed: `build/final-macos/Goemon Fire Siege.app` (2.38.0).
Backup: `build/Goemon Fire Siege before Ranger v2.37.app` (2.37.0).
Archive: `build/Goemon Fire Siege Ranger v2.38.zip`.
Packaged evidence: `build/ranger-redesign/packaged-tour/` and
`build/ranger-redesign/build-info.json`. No GitHub publication was requested.

```sh
godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-mvp-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-controls-test
godot --path . --fixed-fps 60 --max-fps 120 -- --ranger-redesign-tour
godot --headless --path . --export-release "Fire Siege macOS" "build/Goemon Fire Siege Ranger v2.38.zip"
```
