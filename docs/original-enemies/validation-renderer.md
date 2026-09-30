# Enemy renderer verification — cloud, 2026-09-30

Godot 4.6.3, Linux cloud environment. No commands ran on the user's Mac.

- Editor import: no script errors.
- `godot --headless --path . --script tests/original-enemies/renderer_check.gd`: zero failures. Four distinct batches, one surface each, complete texture UVs, no per-actor visual children or skeletons, freeze/windup/strike encoding, survival lantern appearance without changing melee variant, and all-species menu cleanup.
- Actual Godot OpenGL compatibility render on Xorg dummy display / Mesa llvmpipe: shader compiled; same renderer checks passed. `game-lineup.png` captures all four designs in the main town. This software-rendered inspection is not a frame-rate benchmark or Mac performance measurement. Two GL texture-leak messages appear only on renderer shutdown (349,524 bytes each); headless checks exit cleanly.
- `--feel-test`: all 13 checks passed, including opposite-direction hit recoil, stronger heavy recoil, hit-stop release, damage once, evade, acceleration, braking and jump recovery. Recoil now transforms each batched instance; the test inspects that transform instead of a removed per-enemy torso node.

## Legacy combat regression maintenance

The exact fetched baseline `82b4e8307af1158dbec566cb67632eb5cdbbb6d2` was imported in a separate detached cloud worktree and ran `--combat-test`: **four existing failures**. They asserted hold-to-charge attacks even though baseline `player.gd` explicitly starts primary attacks on press and reserves charged spin/giant coin for surge. The implementation branch reproduced those same four failures. Its first run also hit the new population cap during the lab-spawn assertion; combat fixtures now disable autonomous survival waves, with cap saturation covered by the separate survival suite.

The combat suite now checks normal combo on press/hold, no phantom charged sweep on release, an actual R-surge press triggering a full sweep, and an R-surge giant coin piercing two enemies once. Production player controls, damage, projectile and collision behavior were not modified to satisfy tests.

Final maintained `--combat-test`: **25 checks passed, zero failures** (`COMBAT_TEST_RESULT failures=0`). `git diff --check` passed.
