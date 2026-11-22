# RETIRED — excluded from gameplay

The user rejected this character on 2026-11-11. Its runtime assets and tools
are archived in `assets/references/aoi/retired/`. This editable source is kept
only as a reference; the previous workflow below is historical.

# Aoi — original Cross Gate-style pipe adventurer

The user approved `assets/references/aoi/concept.png` on 2026-11-11 and chose
animated sprites like Kaz, with a pipe four times the concept's short version.
This is original fan-game artwork, not recovered Cross Gate artwork.

`aoi.blend` is the authoritative editable source. It reuses Goemon's 22-bone
rig/body and authored actions plus the existing Ren swept-hair mesh. The original
sources remain read-only. New costume, palette, face UVs and pipe belong here.
The short pipe ruler is .95 m; the full pipe is 3.8 m. Its right-hand grip stays
fixed. This changes the artwork, not the existing Cross Gate contact controller.

Initial creation: `Blender --background --python tools/build_aoi.py`.
Do not rerun initial creation over artist edits. Export the saved master with
`Blender --background assets/blender/characters/aoi/aoi.blend --python tools/export_blender.py`.
Bake sprites from the saved master with
`Blender --background --python tools/render_aoi_sprites.py`, then
`python3 tools/pack_aoi_sprites.py`.

The baker samples the existing Goemon actions offline at Kaz's action/frame
clock, in all eight original direction slots. The player's runtime uses only
the shared Cross Gate Sprite3D, combat adapter and native army presentation.
No runtime 3D rig or retargeter is added. New sprite frames and the receiving
character's attack contacts must be reviewed together. Camera, material and
bone changes require rebaking all directions; never paint the packed atlas.

The head/hair mesh is fitted to Cross Gate proportions without changing bone
rests or weights. Hurt samples include the source reaction peak; the jump guard
is one held source pose. During the fall, the baker rotates the pipe at its
unchanged palm grip to rest beside the body. This prepared correction is in
`tools/render_aoi_sprites.py`; it adds no runtime skeleton or weapon update.
Use `-- --actions 8 9` to rebake selected actions only when the master, clock and
camera pixel scale are unchanged. A wider render canvas preserves that scale
and keeps the long weapon inside the authoring frame.

Review images/logs belong in `build/Other Files/Asset Toolkit/Aoi/`.
