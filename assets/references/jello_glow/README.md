# Approved character glow style — 2026-11-27

The user approved the colored silhouette border and small floating fairy lights
and requested this style and visual iteration process for future work.

Use approved-shape-borders.png and the three full in-game captures as the visual
reference. The border follows actual body/weapon alpha, keeping the original
interior art readable. Keep the small floating lights. Avoid generic cylinders,
ground rings, floor shapes and colored point-light pools unless requested. The
current border is about1.75source pixels inside the silhouette; original pixels
at/below the feet retain their uncolored ground-shadow/effect presentation.

Implementation: scripts/crossgate_model.gd, scripts/surge_aura.gd and
assets/materials/crossgate_body.gdshaderinc. The current frame's UV bounds prevent
sampling adjacent atlas poses. Per-instance uniforms isolate the player; inactive
models skip frame-bound updates. Existing fourteen rays supply the floating lights.
Golden Surge retains its separate original appearance. Original sprite files,
frame/body/hand/weapon anchors, geometry, combat clocks and native army ownership
are unchanged by the glow presentation.

Workflow: reuse existing resources, make a focused change, show an actual-game
image early, and incorporate the user's visual feedback before broad extension.
Review a short movement/attack/jump sequence where relevant. Keep technical tests
and visual acceptance separate. This approves the style, not every character,
pose, map or camera. Full current logs and retained earlier attempts are under
build/Other Files/Asset Toolkit/Jello Glow/Shape Border/.
