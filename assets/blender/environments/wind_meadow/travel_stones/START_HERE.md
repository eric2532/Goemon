# Falan solid travel-stone kit

`travel_stone_kit.blend` is the authoritative editable master. It contains four
named meshes/collections at the same ground origin: **Crescent**, **Post**,
**Lectern**, and **Crystal**. Hide the other collections while editing one part.
The Crystal origin is at its widest belt; the runtime raises it 3.05 metres.
All other pivots are on the ground. One Blender unit is one metre. The crescent
opens along Blender +X; the city rotates that one mesh to face the shrine centre.

The original references are preserved in `assets/maps/falan/travel_stone*`.
Graphics 17237–17240 show the crescent in four orientations; 17235/17236 show the
two-tier inscription stand, and 17241 shows the turned post and hollow cup.
Original animation 3171 supplies the cyan facet paint and eight-frame turn.
The six crystal positions and all seven existing ornamental shrine groups retain
the original city grid. No sprites/billboards are used by this 3D kit.

The master has genuinely thick crescents with convex faces, flared bronze feet,
raised C-scroll relief, stepped capital/base courses, recessed post cups and
separate pitched stone tablets. Preserve their silhouette and source palette.
Unseen faces repeat the reference's motifs; the available source is isometric
artwork, not an original 3D model, so unseen topology is a reconstruction.

Export saved edits with the normal exporter; do not rerun the initial generator:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/environments/wind_meadow/travel_stones/travel_stone_kit.blend \
  --python tools/export_blender.py
```

Runtime export:
`assets/models/environments/wind_meadow/travel_stones/travel_stone_kit.glb`.
The existing `forest_wind_meadow_assets.gd` cache shares its meshes/materials;
`forest_travel_stone_art.gd` chooses a named part and its original orientation.
Keep the four object names and zero transforms. Do not apply building painterly
material overrides: the kit has its own recovered surface paint and matte stone.
The crystal's shared shader rotates vertices **and normals** by a quarter-turn
per 800 ms. There is no per-stone process function or animation controller.

`tools/prepare_travel_stone_surfaces.py` rectifies eight opaque paint/inscription
patches and crops the original crystal's colored facets, excluding its shadow.
Outputs live in `assets/textures/wind_meadow/travel_stones/`; all source crop
coordinates are recorded in `source_patches.json`. Rebuild these derivatives
from the preserved originals and repack edited textures in Blender before export.
Use ordinary UV texture paint on the solid surfaces; do not restore whole-sprite
projection, alpha cutouts or billboard meshes.

`tools/build_travel_stone_kit.py` was initial authoring only. Its overwrite guard
protects later saved UV, carved-relief, material and facet refinements in this
master. The saved master supersedes the initial geometry recipe.

Audit reports the four-part library together: 16,304 triangles, four meshes,
five surfaces, three materials and two embedded textures (1024×512 and 56×60).
The combined library exceeds the generic 8,000-triangle scenery warning. This
warning was reviewed; it is not permission to decimate the approved silhouette
or carvings. No optimized derivative or new routing override is required.

Run `test_travel_stone_3d.py` and `test_falan_travel_stones.py`, asset preservation,
then refresh Godot imports. Through Play Goemon, run
`travel_stone_3d_review.gd` for four-angle/component captures and
`falan_gate_shortcuts_test.gd -- --east-il-road` for all travel routes, original
anchors, real mesh depth and the absence of retired sprites. Inspect actual city
views too. Evidence belongs under
`build/Other Files/Asset Toolkit/Falan Travel Stones 3D/`. App export is separate
and only performed on request.
