# Fire Siege movement and camera update

Verified 9 October 2026 on macOS with Godot 4.6.1, using the Fire Siege v2.32.0 MVP at `ed8c003` as the base. This is the edition with twelve arrow-tower construction sites and the goldmine. The earlier Desktop checkout was restored after the version mismatch was identified.

## Behavior

All twelve heroes face camera-relative movement, including backward and diagonal movement. Body rotation remains smooth. Attacks, airborne attack commitments, held shields, construction, and character abilities retain the current MVP controls.

The perspective camera follows backward travel immediately. Forward input allows one metre of actual travel before following, including restarting after backward movement or a stop. Lateral travel follows normally. Sprint zoom stays fixed during the buffer; walls do not consume it. Sky Strike recovery, downed right-drag orbit, collision probes and vertical tracking remain active.

## Verification

- `python3 tools/verify_fire_siege.py --output build/verification-movement`: all six MVP acceptance suites pass, 478 checks/assertions total. This includes the economy, authored structures, construction, all ten waves, shared controls and legacy mode transitions.
- `godot --headless --path . -- --movement-camera-test`: 103 checks, zero failures, covering all twelve heroes and camera reversals, sprint lag, diagonals, blocked input, pause, resets and Sky Strike recovery.
- `godot --headless --verbose --path . -- --fire-siege-turn-test`: 51 checks, zero failures, covering smooth full-body turns, idle camera orbit, committed attack aim and held Knight blocking.
- Exported macOS app: 103 movement/camera checks pass and the process exits zero. The headless dummy renderer reports one leaked shader RID during shutdown; this is recorded in `build/verification-movement/exported-movement.log`. The rendered MVP walkthrough exits cleanly.
- Exported Metal walkthrough `--fire-siege-mvp-tour`: completes tower construction, mine purchase/income, live arrows, character switching, death and revival. Tower and mine screenshots visually inspected.
- macOS code signature verification and `git diff --check` pass.

The 632 distinct source checks pass. Logs are in `build/verification-movement/`. Character, tower, goldmine and construction asset files have no changes.

## Local build

Updated app: `build/final-macos/Goemon Fire Siege.app`.
Updated archive: `build/Goemon Fire Siege Movement.zip`.
Previous app retained at `build/Goemon Fire Siege before movement.app`.

The GitHub release has not been changed by this local update.
