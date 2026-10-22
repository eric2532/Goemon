# Ninja poses in the game — 2026-10-17

Integrated the user's `Ninja_Animation_Workbench.blend` edits:

- Idle: authored frame **0**, retaining subtle breathing and a seamless loop.
- Right-click slash: frame **0** is the start, frame **1** is the finish. The game interpolates these anchors over Ninja's existing 0.42-second dash, then returns to idle over 0.16 seconds. Attacks, shots, jumps and dodges interrupt that visual recovery immediately.
- Sword: keeps the user's enlarged mesh and slight rotation. Its purple ribbon follows the actual blade tip.
- Run: existing game animation, blending out of the new idle.

The original workbook and all its old template keyframes are preserved. Source frame numbers identify poses; frames 0–1 are retimed for gameplay rather than played as a one-frame attack. The other older slash template keys are not part of the newly approved cut.

`tools/export_ninja_animations.py` exports these anchors into `assets/animations/ninja_approved.json` and transfers only the sword mesh's local transform into Ninja's live asset. `tools/build_ninja_weapon.py` preserves the approved transform on regeneration. `verify_approved.py` checks source preservation, Blender/runtime agreement, body/UV/rig preservation and the actual mesh tip.

Before snapshots, live unsaved capture, test logs, native gameplay screenshots and app export are in `build/Other Files/ninja-authored-poses-20261017/`.
