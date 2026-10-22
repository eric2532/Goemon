# Native Blood Gulch castle terrain

The original Xbox Blood Gulch BSP and diffuse/detail pixels were recovered
read-only from the user's local Halo: Combat Evolved disc. Nothing is downloaded.
`source.json` retains all 79 source material groups, all 5,503 source triangles,
original Halo-unit vertex positions/UVs, shader metadata, bitmap tag paths and
SHA-256 hashes. `source_*.png` pixels are unchanged. `source_data/` also retains
the extraction tool's original named PNGs; `.gdignore` prevents duplicate imports.

The playable Goemon adaptation is separate: `adaptation.json` holds the 161×161,
3 metre height/coverage grid and inspected attack routes; `provenance.json` lists
all transformations and removals. The 66 metre half-width castle pad and eight
36 metre wide attack corridors are flat, with 18 metre blended shoulders. These
are clear grassy approaches, recorded as `approach_routes` metadata rather than
authored road tiles. The bundled preset has `roads: []`, preserving the original
native painted dirt paths without extra tiled overlays; editor road tools remain
available. Removed
sci-fi bases become ground; original cliff/boulder triangles that obstruct these
clearings are clipped only below 12 metres of walker clearance. Convex volume
subtraction interpolates original UVs and preserves every native upper wall
vertex; it avoids deleting complete tall faces at the canyon skyline. The four-gate castle buildings
are preserved; obsolete mines are omitted because this preset has no deposits.

`terrain.res` and `collision.res` share the grid's exact triangle split. Only
cells with all four navigation corners covered are emitted: 8,660 cells /
17,320 triangles. A separate ground surface adds 2,800 exact native triangle
fragments at boundary cells, preserving original UVs and physical support right
to the cliff foot. These caps follow the original native footprint; they do not
restore extrapolated exterior grid rectangles or change navigation coverage.
Their outer height retains the original native source height without applying
castle/approach shoulder flattening at the cliff contact, and blends
continuously to the adjoining full grid edges. `adaptation.json` records the
original source face for every cap triangle. These caps are a deliberate
physical/visual exception outside authoritative covered navigation: NPCs still
use only the unchanged covered grid. Actual retained cliff-foot vertex checks
verify that this boundary support does not pull away from native rock walls. The
resource `surface.res` provides the same float32 heights to navigation.
`cliffs.res` contains 2,437 boundary triangles derived from the native faces
(955 original faces unchanged, 414 geometrically clipped, 21 omitted), preserving
source UVs and textures; these receive their own static collision and never become navigation
coverage. Native ground UVs are barycentrically resampled; only filled footprints
and exterior underlay use nearest available original UVs. Native ground alpha is
the sand/grass blending mask, not transparency. Original lighting/lightmaps are
replaced by the requested bright daylight treatment in the dedicated shader.

Reproduce from the user's disc (Python environment requires Refinery/Reclaimer
and Pillow as in `tools/halo/requirements.txt`):

```sh
/private/tmp/goemon-halo-research/venv/bin/python tools/halo/extract_blood_gulch.py '/private/tmp/goemon-halo-research/disc/Halo - Combat Evolved (USA).iso'
python3 tools/build_blood_gulch.py --output=/private/tmp/goemon-blood-gulch-bake.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/bake_blood_gulch.gd -- --input=/private/tmp/goemon-blood-gulch-bake.json
python3 tests/halo-terrain/test_blood_gulch_assets.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/halo-terrain/blood_gulch_bake_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/halo-terrain/blood_gulch_boundary_support_test.gd
```

The extraction log defaults to the primary project's
`build/Other Files/blood-gulch-castle/extraction.log`; `--log` overrides it. Bake
interchange belongs in temporary storage. No app export is needed for development.

The default castle preset now uses `terrain_scale: 1.2`, stretching width/depth by 20% (44% more horizontal area) with unchanged heights, meshes and triangle count. Rendering, collision, height sampling, native army field origin/spacing, navigation bounds, minimap and camera all use this scale. Castle/gate dimensions stay unchanged. Existing custom Blood Gulch maps without this optional field remain at scale 1.0. Fog of war is disabled for all maps; physical line of sight and cover remain active.
