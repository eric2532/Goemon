# Fire Siege MVP v2.37 — closed masks and Samurai proportions

This follows the user's correction to v2.36: Samurai's neck was too long, and
Dragoon and Magic Swordsman should have face-covering helmets/masks.

## Art changes

- Samurai's head/helmet assembly is lowered 0.13 source units. His neck is
  shortened from 0.313844 to 0.183844 (41.42%), retaining its lower attachment.
  The scarf wrap is shorter and fitted to the lowered jaw using a surface ray
  projection with cloth clearance. The smaller side knot and tail root sit 0.08
  lower. The long wind-animated tail retains its exact geometry and motion.
- Dragoon has a closed blue/teal/silver dragon faceplate with wrapped cheek/jaw
  armor and narrow teal visor slits. The old small dragon snout above the open
  face is replaced by armor covering the actual face.
- Magic Swordsman has a purple demon mask with strong brow, angular cheeks,
  narrow violet visor slits and small fangs, beneath the existing crystal crown.
  One obsolete hidden frontal hair clump was removed because its tip protruded
  through the crown. The rear/side hair remains.

Editable Blender sources, exported models and three portraits are updated.
The regular `tools/style_rogue_roster.py` path remains reproducible through
`equip_rogue_roster.py` and the new `rogue_face_masks.py` module. Existing combat
and wind behavior are unchanged.

## Verification

The focused scope validator passes 4,326 checks with zero failures. It confirms
394 exact body/weapon meshes, 33 preserved file hashes including the other seven
heroes, Goemon master and face atlas; 32 closed positive-volume new/reshaped
meshes; and all 29 mask components present in the actual GLBs. Painted facial UVs
and embedded texture hashes remain exact beneath the masks.

Native mask inspection found no exposed front skull samples across 705 Dragoon
and 673 Magic Swordsman samples. Visual review also checked front, profile,
three-quarter and rear views beside Goemon and in the game. Samurai's initial
chin breakthrough was fixed by fitting the wrap to the actual lowered skull.

Source runtime verification passes 27 pose checks, 13 scarf checks and 58 focused
tour checks. The tour produced 26 captures, all reviewed at full resolution,
including running, moving scarf, sword contact, power slash and drawn/stored bow.
No outstanding fit issue was found. The files remain within the latest MVP
worktree. The user subsequently requested GitHub publication; release details
are recorded in `release-notes-v237.md`.

Evidence: `build/rogue-mask-refinement/scope-validation.json`,
`source-visual-review.json`, `poses.log`, `scarf.log` and `tour/`.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python tools/verify_rogue_mask_refinement.py -- build/rogue-mask-refinement/baseline build/rogue-mask-refinement/scope-validation.json
godot --headless --path . --script scripts/rogue_pose_tests.gd
godot --headless --path . --script scripts/rogue_scarf_tests.gd
godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-mask-refinement-tour
```

The packaged macOS app also passes all 58 focused checks with 26 captures and
zero runtime warnings/errors. Its three model geometry hashes match the source
tour exactly. Source and package total 156 runtime checks.

Version 2.37.0 is installed at `build/final-macos/Goemon Fire Siege.app`; version
2.36.0 is backed up at `build/Goemon Fire Siege before Mask Refinement.app`.
The archive is `build/Goemon Fire Siege Mask Refinement.zip`. Strict code-signature
verification passes, and installed executable/PCK hashes match the tested app.
Installation hashes and paths are in `build/rogue-mask-refinement/build-info.json`.
The final preview is `build/rogue-mask-refinement/mask-refinement-in-game.png`.
