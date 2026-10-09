# Fire Siege MVP — Rogue design pilot

Current status: the user approved the v2.34.1 pilots and requested the same
coordinated face/design update for the entire Rogue cast on 9 October 2026.
The accepted pilot assets remain intact; the remaining eight are documented in
[the roster rollout](rogue-roster-upgrade.md). The pilot chronology below is
retained as review history.

The user approved trying this direction on 9 October 2026 after supplying an
image of two anime adventure figures. Fire Siege MVP is the primary development
version. This first pass covers Magic Swordsman and Explorer; its appearance is
for user review before applying the direction across the remaining eight Rogue
characters.

## Agreed direction

Build head anatomy, painted feature placement, and hair as one design. Use a
broad upper face, deliberate cheek-to-jaw transition, compact chin, restrained
integrated nose volume, and large solid hair clumps. Check the profile as closely
as the front. Painted eyes and expressions remain part of the game's style.

Magic Swordsman keeps his silver hair, violet eyes, amethyst armor, asymmetric
mantle, and heavy claymore. Give him a focused face and a sharper, swept hair
silhouette. Explorer keeps her auburn braid, goggles, teal scarf, ochre coat,
freckles, and paired blades. Give her a softer compact face and lively expression.

The current pilot deliberately concentrates on the head/face/hair mismatch.
Retain each character's existing compact body, costume, colors, native animation
pivots, and equipment. Body proportion changes can be judged after this head
direction is reviewed. The Goemon master is preserved.

The supplied figure image informs anatomy, hair volume, and readability; it does
not replace the identities of these two Rogue characters. The new brief
supersedes the historical instruction to keep their old skulls and facial layout
exactly unchanged.

## Review method

- Save the preceding two editable models and exported GLBs before changing them.
- Compare old and new assets with identical actual-engine cameras and lighting.
- Inspect full front, side, three-quarter, and back views, plus facial close-ups.
- Render beside the unchanged Goemon master under shared Blender lighting.
- Check running and attack contact poses, then the actual Fire Siege map.
- Confirm native pivots, unaffected assets, weapon grips, and combat behavior.
- Package a local MVP preview with the preceding app retained.

## Implemented preview — v2.34.0

Both skulls now use explicit cheek, jaw, chin, forehead, orbital and restrained
nose shapes. Painted facial landmarks are refitted to the new anatomy. Their
shared atlas is byte-identical; the improvement comes from geometry and UV layout.
Magic Swordsman has broad swept silver locks and crown spikes. Explorer has a
solid auburn fringe and temple locks, retains the braid, and has seated goggles
with a strap fitted around the crown.

The editable Blender sources retain their individual components. Native pivots
and all body/weapon world vertices match the preceding version. All eight other
Rogue GLBs and the Goemon master are byte-identical to the saved baseline.
Magic Swordsman has 6,000 triangles in seven mesh batches; Explorer has 6,824
triangles in eight batches. The 30 new or changed mesh components pass closed
manifold, winding, and nondegenerate-face checks.

An initial export exposed a UV-layer mismatch: joining the new skull with the
other head components put the face coordinates on UV1 while the material read
UV0. The exporter now uses one common UV layer and validates the actual GLB face
coordinates. An intentionally broken export fails that check. Final source and
packaged game captures visibly retain the eyes, eyebrows, freckles and mouth.

Independent visual review passed after the Explorer goggles fit was corrected.
The before/after cameras, framing and lighting are identical for all 19 studio
captures. Shared Goemon comparisons include front, side, three-quarter and back.
Both pilots were also reviewed in the real MVP map and in attack contact poses.

## Reproduction and validation

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/sculpt_rogue_pilot.py -- magic-swordsman explorer
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/render_rogue_style.py -- magic-swordsman
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/render_rogue_style.py -- explorer
godot --headless --editor --path . --import
godot --path . --script scripts/rogue_design_pilot_tour.gd
godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-design-gameplay-tour
python3 tools/verify_fire_siege.py --output build/rogue-design-pilot/verification
```

The ordinary `style_rogue_roster.py` CLI also retains these two pilots when
regenerating the roster. The base generator was checked against the saved v2.33
sources: every pivot and mesh vertex matches, so reproduction needs no ignored
baseline files. `--baseline` is an optional development comparison input only.
Keep a `.gdignore` in local build/output directories that contain Blender backups;
Godot imports the exported GLBs, not those editable source backups.

Source verification: **741 checks, zero failures**, across state (65), structure
(71), integration (72), campaign (117), controls (136), three-gates (59), poses
(27), combat upgrade (76), movement/camera (103), and the rendered pilot gameplay
tour (15). Those final source logs contain no errors or warnings.

The exported app passed **91 checks**: 76 combat and 15 rendered gameplay checks.
The rendered package tour completed cleanly and produced 12 inspected captures.
The packaged headless combat test retains the known exit-only dummy-shader and
resource cleanup diagnostics (13 retained resources); all assertions pass and
the process exits zero. Those diagnostics do not occur in the rendered tour.

Python compilation, `git diff --check`, macOS code-signature verification and
version verification pass. The tested executable hash matches the app installed
at the existing launch path. Earlier movement/camera and Rogue combat work is
preserved. No remote release was published.

## Delivery

- App: `build/final-macos/Goemon Fire Siege.app` — **2.34.0**.
- Previous app: `build/Goemon Fire Siege before Design Pilot.app` — **2.33.0**.
- Archive: `build/Goemon Fire Siege Design Pilot.zip`.
- Before/after sheet: `build/rogue-design-pilot/before-after.png`.
- Runtime closeups: `build/rogue-design-pilot/runtime/`.
- Source MVP captures: `tests/rogue-design-pilot/`.
- Logs, reproduction check and hashes: `build/rogue-design-pilot/`.

This is the two-character direction for user review, not a claim that the entire
ten-character redesign has been completed or approved.

## Follow-up: facial depth

The user found the v2.34 side profiles too flat and recessed. The correction
targets the depth of the facial surface: bring the upper face and brow forward,
reduce the orbital indentation, support the cheek/mouth/chin profile, and give
the integrated nose a broader bridge and visible tip. Preserve the frontal
landmarks, painted artwork, skull back, hair, goggles and animation pivots.
Compare the actual v2.34 side and three-quarter captures against the new export
under identical cameras and lighting. Review evidence is saved separately under
`build/rogue-face-depth/` so the earlier pilot comparisons remain intact.

The v2.34.1 refinement moves the eye plane forward about 0.053 game units and
the nose tip about 0.062 units, with smaller increases in the brow, cheek, mouth
and chin. A stronger first nose pass was reduced after front/side review to keep
the tip rounded and restrained. The silhouette change comes from the facial
surface rather than stretching the entire head.

All 258 non-skull components match v2.34 exactly. The skull's width/height
landmarks, UVs, topology, transforms, and rear surface also match. Only facial
depth changes. Hair, goggles, costume, weapon grips and animation pivots remain
exact. Both exported GLBs retain the validated UV0 face mapping, and mesh
manifold/winding checks pass with unchanged triangle and batch counts.

Nineteen new actual-engine views use the same cameras as v2.34. Front, side,
three-quarter, running and attack contact views were inspected; independent
review passed after moderating the nose tip. Both portraits were regenerated,
with front/side/three-quarter/back comparisons beside Goemon. Source pose (27),
combat (76), and rendered live-MVP (15) checks pass: **118 checks, zero failures**.
No game rules or runtime character code changed for this correction.

The exported macOS app passed all 15 rendered live-MVP checks, including both
heroes' movement, primary hit contact and key-3 secondary attacks. Its signature
verified before and after installation. Version **2.34.1** is installed at
`build/final-macos/Goemon Fire Siege.app`; v2.34.0 is preserved at
`build/Goemon Fire Siege before Face Depth.app`. The archive is
`build/Goemon Fire Siege Face Depth.zip`. The comparison sheet, verification logs
and delivery hashes are in `build/rogue-face-depth/`.
