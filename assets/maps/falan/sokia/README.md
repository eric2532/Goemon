# Sokia around Kili and Great Wind Cave

`tools/recover_sokia.py` reads original `300.dat` through the sibling Magic Power
archive decoder. It preserves every known scenery anchor in the four existing
region crops, including overlapping placements shared by adjacent scenes:

| Region | Original bounds (x, y, width, height) | Anchors | Dry blocked tiles | Collision rectangles |
| --- | --- | ---: | ---: | ---: |
| Kili coast | 138, 160, 241, 241 | 4,705 | 5,999 | 794 |
| Great Wind desert | 370, 166, 209, 209 | 2,373 | 3,700 | 615 |
| Ghana road | 525, 99, 205, 205 | 2,449 | 4,558 | 571 |
| Ghana north | 623, -13, 165, 165 | 811 | 1,925 | 132 |

Out-of-map coordinates are void, never wrapped to the last source rows.
`provenance.json` records source map hashes and each native graphic's pack,
record and decoded RGBA hash. The masks contain native water, roads and paving,
without the old traced road widening or edge fade. `BLOCKS` merges the original
dry blocked-cell union without expanding it; both the existing model navigation
and player physics receive those same rectangles. Vertical collision heights
are fitted to the existing 3D hills, including Ghana's raised cliffs.

The shared `sokia_ground_index.png` and `sokia_ground_atlas.png` in the parent
directory now drive all four regions. Existing Cross Gate tree batches, palm
models, recovered Kili walls and sandstone cliff geometry supply compatible 3D
scenery. Other plants and props use unchanged original art in spatially grouped
MultiMeshes with one cached shader. Source pixel scale, 3D depth, cliff profiles,
palms, hills, lighting and camera projection remain fitted interpretations.
This is source tile/anchor restoration within these crops, not a claim of
pixel-identical 3D reconstruction of all 800 × 532 Sokia tiles. The shared game
still uses its existing 130% world scale and real-time encounters/water rules.

`forest_wind_meadow_art.gd` skips the old meadow scatter, mountain ring and outer
ground in these regions, including refreshes after construction. Original Goemon
assets and player-saved scenery remain intact for their other uses. All scenery
setup stays in the current world/model owners; no combat or targeting owner was
added. Meshes and material are cached, and native-art batches use 48 m chunks.

Regenerate and verify:

```sh
python3 tools/recover_sokia.py
python3 tools/recover_sokia.py --check
```

The check also independently rebuilds and compares the original Sokia ground
index and all 651 ground graphics. Use Play Goemon with
`--script res://tests/forest-shrine/sokia_desert_recovery_test.gd -- --east-il-road`
to check all four regions, walk the original 57-cell 海洞–Kili road using controls,
cross both Kili gates, traverse the cave entrances and the desert/Ghana seams.
Captures and logs belong in
`build/Other Files/Asset Toolkit/Sokia Desert Recovery/`. Review the images
separately from the technical checks; those checks do not establish final
sculptural fidelity or large-army performance.

Fresh verification on 2026-11-17: the desktop recovery fixture passed 3,091
assertions, the Kili regression passed 657 headless assertions, and the native
encounter fixture passed 4,808. Source regeneration, original ground pixels and
shared asset preservation checks passed; the saved adventure remained unchanged.

## Solid palm refinements — 2026-11-17

The 21 native palm graphics now select individual solid variants in these four
regions and Kili itself. The existing `assets/blender/environments/palm.blend`
and `assets/models/environments/palm.glb` remain unchanged. Their trunk and nine
complete curved frond paths supply the reusable parts; native crown bounds,
bark/leaf paint and single/twin/sapling arrangements distinguish each variant.
Folded feather leaflets and a second shorter crown layer on the drooping palms
replace the old plain triangular leaves. Each complete variant shares one
cached mesh/material, with 48 m placement batches and no new collision objects.
There are 324 / 148 / 7 / 18 archived palm anchors across the four crops.

`tools/prepare_sokia_fronds.py` reads the editable master through Blender into
`fronds.json`; it never saves over the master. `tools/recover_sokia_details.py`
recovers `details.gd`, `details.png` and `details.json`. Run the latter with
`--check` to reproduce the native bark/leaf paint derivatives, crown bounds,
30 cliff contour records and protected source hashes. The current procedural
assembly is `scripts/forest/forest_sokia_details.gd`; repeated placements reference
its complete cached mesh. Edit the master normally and use its matching export
workflow before regenerating these source records if the original palm changes.

Native cliff contour widths now adjust the existing crag kit's individual
heights. The established sandstone paint and existing entrance cutouts remain.
Direct extrusion of the 2D cliff silhouette and per-graphic tiled cliff paint
were rejected during rendered review because they produced floating fragments,
hollow forms and conspicuous repeated patterns. Do not restore those attempts.

The focused `sokia_fine_scenery_test.gd -- --east-il-road` compares actual physics,
native plans and links against the preceding pass, checks complete variant reuse
and source anchor counts, and records front/back palm studies and matched map
views in `build/Other Files/Asset Toolkit/Sokia Fine Scenery/`. Crown depth,
secondary trunk spacing and unseen backs remain fitted; fine fruit contours
and exact leaf-by-leaf silhouettes still need further art recovery. The surface
paint is an original-color derivative, not a pixel-identical 3D projection.

Final continuation checks passed 480 desktop assertions, 3,080 headless route
assertions and 657 Kili assertions. The 21 cached meshes have one surface each;
single/clustered fan forms use 1,522/3,044 triangles and drooping forms use
2,872/5,744. These are prepared geometry counts, not frame-time measurements.
Native detail regeneration, source-master hashes and the shared asset checks
passed. The saved-map SHA-256 remains unchanged.

## Fruit, broad leaves and inset strata — 2026-11-17

Graphic 11204 now has a solid yellow fruit bunch beneath its crown. Recovery
records the original 131 gold pixels in `(74,78)–(100,124)`, their attachment at
pixel `(84,75)`, connected components and six fitted fruit lobes. The existing
Kili round-piece builder supplies the stalk and curved bodies inside the same
complete cached palm mesh. Native gold paint is softened toward its own average
to avoid enlarging palette dithering on every curved face. Other palms receive
no invented fruit.

Graphics 11194–11196 now have broader folded leaf blades with small edge tears
and varied pitches, replacing the generic upright feather fan. 11194's shorter
front crown uses its original dry gold leaf paint. The false second trunk on
11196 is removed; its original image has one trunk. The recovery now contains
44 native paint patches. The unchanged trunk/frond masters remain authoritative.

Sokia cliff contours select one shallow inset seam per crag where the native
profile supplies a suitable interior transition. Two rings add actual relief
within the established solid rock body. Original silhouette vertices, footprint,
peak and sandstone paint remain; original layer variation is interpolated at
the inserted rings. No collision or travel owner changes. This refines the
existing kit rather than repeating the rejected direct silhouette extrusion.

Run `sokia_fruit_relief_test.gd -- --east-il-road` through Play Goemon for the
matched coast/desert/Kili views, fruit close-up, cave-mouth review and physics/
plan/link baseline comparison. Fresh checks passed 28 desktop assertions and
476 headless palm-regression assertions. Native regeneration, protected source
hashes and shared asset checks passed; the audit read 319 GLBs with no errors.
Evidence is under `build/Other Files/Asset Toolkit/Sokia Fruit Relief/`.
Fruit depth and lobe splitting, exact leaf arrangement and cliff morphology
remain fitted from a single original view. These checks are not a long-session
or rendered frame-time benchmark, and no app was exported.

## Projected crowns and curved fruit profiles — 2026-11-18

`CLIFF_CROWNS` records nine exposed-height cues per original cliff graphic.
Recovery uses the archive origin and footprint, the established isometric
projection and the first colored source pixels at each crag column, excluding
black backplanes. Runtime blends those cues into the existing complete crags;
missing/unseen samples retain the prior kit. This changes the crown shape while
keeping solid bodies, native footprints, sandstone paint and cave cutouts.
It does not restore the rejected direct silhouette extrusion. Heights inferred
from a single view remain a 3D interpretation.

Palm leaflet widths now taper with the source frond width, avoiding wide paper
ends on narrow tips. The six fruit lobes use individual curved profiles from
their native pixel rows instead of the same round primitive. Raw row centers
and widths are preserved in `fruit_row_samples`; two three-row smoothing passes
fit the rendered centers/radii. Depth is fitted, and native gold paint is kept.
Complete palm meshes still share one surface and the existing cache/batches.

Kili itself now skips the old meadow scatter, mountain ring and outer ground,
including construction refreshes. Authored scenery, native props, buildings,
NPCs, collisions, links and saved maps remain intact.

`sokia_crown_shapes_test.gd -- --east-il-road` captures matched before/after map,
leaf/fruit and cave-mouth views. Final checks passed 37 desktop assertions,
657 Kili and 476 palm-regression assertions. Native regeneration and shared
asset preservation passed; the audit read 319 GLBs with no errors. Evidence is
in `build/Other Files/Asset Toolkit/Sokia Crown Shapes/`. Exact frond arrangement,
cliff depth and unseen surfaces still need art refinement. No app was exported;
no long-session or rendered frame-time benchmark was performed.


## Native fruit-palm ribs and village low plants — 2026-11-18

Graphic 11204 now uses nine crown ribs traced from the original sprite rather
than the generic drooping crown and its duplicated rotated layer. Recovery
records each source point, snaps it to original foreground and samples leaf
widths across the rib. The original attachment pixel `(84,75)` and graphic
origin place the shared trunk/leaf/fruit crown at `(0,5.983,0)` at `.031` units
per pixel. Four-pixel leaf bases meet the existing trunk without an added cap;
leaflet length now tapers with width. Only 11204 has this traced arrangement;
the other 20 variants continue to reuse the established frond kit. Depth,
width fitting at the root/tip and unseen leaf faces remain interpretations.

Valid `CLIFF_CROWNS` samples now set their corresponding crag heights directly,
replacing the previous 65-percent blend. Missing or unseen samples retain the
solid kit. Complete bodies, inset seams, sandstone, source footprints and cave
cutouts remain. This is still source-guided 3D, not an exact original model.

Kili replaces 84 generic shrub/flower placements with 25 native low-plant
graphics already in the shared Sokia atlas (11625–11710 and 12160–12180).
`kili_prop` selects those source rows; `build` accepts explicit rows and reuses
existing spatial batches, shader and atlas. These small plants use original-art
cards; palms, trees, walls and architecture retain their existing 3D owners.
Source cells, player physics, travel links and saved data are preserved.

Run `sokia_native_fronds_test.gd -- --east-il-road` through Play Goemon for the
matched maps, leaf/fruit gallery, close fruit and cave-mouth views. Fresh final
checks passed 111 desktop assertions, 476 palm assertions and 657 Kili
assertions. Detail regeneration, protected palm sources and shared asset checks
passed; the audit read 319 GLBs without errors. Evidence is in
`build/Other Files/Asset Toolkit/Sokia Native Fronds/`. Final captures were
visually inspected separately from the checks: the 11204 crown has upright,
arching and hanging ribs, native yellow fruit and a clearer source silhouette;
leaf fullness and unseen depth remain approximate. No app was exported and no
long-session or rendered frame-time benchmark was performed.


## Fuller leaf surfaces and the Falken trail — 2026-11-18

11204 now samples widths up to 24 source pixels rather than clipping every wide
leaf at eight. Traced blades use their original XY cross-section, with fitted
Z depth, so side leaves show their broad face. Shared boundary widths, rib
heights and centered tangents join adjacent panels continuously. Folded ribs
and reused leaflet edges retain volume; the six native-profile fruit lobes and
stalk now share smooth normals. Other broad-leaf variants also gain continuous
width taper. The fruit palm remains one cached 3,200-triangle surface.

Crags now use two separated contour-guided inset seams where samples permit.
Original crest heights, complete bodies, collision and cave cutouts remain.
This refines the existing solid kit; exact cliff morphology remains unfinished.

A dry trail of labels from Great Wind's desert exit leads to the ancient person
at original (540,350) and a playable Falken route. Original Sokia terrain and all
old links remain intact. See `../falken/README.md` for the direct route, recovered
maps, monsters and unfinished original quest/spells. This pass does not add
another meadow-scatter or furniture owner.

Final desktop verification passed 237 assertions (including the prior 111
scenery assertions), and shared native map encounters passed 4,808. Captures
under `build/Other Files/Asset Toolkit/Falken Route/after/` were inspected: leaf
surfaces are fuller and joined, fruit remains beneath its source attachment,
the cave recess stays open and the original Falken sprite visibly fights the
player. Native source regeneration and shared asset checks passed; the audit
read 319 GLBs without errors. This is closer to the source, not completed 1:1
3D art. No app export or long-session/rendered frame-time benchmark was run.
