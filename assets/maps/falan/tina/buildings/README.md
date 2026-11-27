# Tina building paint

The native-painted building families are prepared at map setup by
`scripts/forest/forest_original_map_solids.gd` and
`scripts/forest/forest_tina_building_details.gd`. These reuse shared coastal
building pieces and the existing cached spatial batches. Edit those profiles,
not a separate runtime model or duplicate placement list.

Roof and facade UV landmarks refer to the preserved native RGBA atlas and
`assets/maps/original_crossgate/building-surfaces.json`. The native palette,
snow paint, windows, signs and door hardware remain part of that source art.
Raised arches, gables, steps, rail openings and finials supply depth.

`11407-main-roof.png` is a generated underlay for the green house only. Its
original foreground bay hides part of the main roof. The preparer continues
the same roof plane's unobscured upper paint into that hidden region, smoothing
the enlarged pixels and borrowing subtle grain from an unobscured native roof patch. The actual bay uses the untouched native atlas separately.
This is a reconstruction of unseen paint; the original image is never edited.
`underlay.json` records the original and generated RGBA hashes and method.

Regenerate or verify from the project root:

```
python3 tools/prepare_tina_roof_underlay.py
python3 tools/prepare_tina_roof_underlay.py --check
python3 tools/recover_western_building_surfaces.py --check
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/tina_buildings_review.gd
```

There are no recovered original 3D meshes. Depth and unseen/rear views remain
inferred from the two painted faces. The review captures both sides of all six
families under `build/Other Files/Asset Toolkit/Tina Recovery/Building Review/`.

## Approach and small scenery — 2026-11-21

The native-painted building set also includes green approach house 11403 and
snow storage shed 11450. Existing shed 11451 now has source-painted storage
contents/end boards, posts fitted to its roof slope, a broken timber ridge and
icicles. Wood shelter 11452 uses its own snowy roof and hanging-hide paint over
shared posts and prepared logs. These source catalog variants retain their
original placements; they do not expand the playable road crop.

`forest_tina_building_details.gd` also traces all fourteen native rail connector
shapes (11363–11376), with matching snowy variants (11378–11391). End stubs and
corner branches are distinct; original map collision and entrance cells remain
authoritative. Posts are capped, and the native wood/rope paint comes from
11363. Shared crate bodies 11467/11468/11469 use each source's top/two faces and
raised corner trim. Loose timber 11462/11463 forms five logs in one row, with
bark and closed cut ends from 11462. The shelter's silhouette fit preserves the
round log cross-sections. All are baked into existing cached meshes/batches.

The seven added surface recipes live in
`tools/recover_western_building_surfaces.py`; small bark/end/fence crops use the
existing native-tone smoothing in `tools/build_village_building_surfaces.py`
to reduce enlarged palette-dither stripes. Originals and provenance hashes
remain intact. Two-face paint, mirrored shed backs and hidden depth remain
reconstructions.

Review via `Play Goemon.command --script
res://tests/forest-shrine/tina_remaining_scenery_review.gd`. The 16-piece review
checks source UVs, cached geometry, connector axes/end reach, snow direction,
flat log rows, closed cut ends and shelter-log proportions. `--baseline` captures
reference geometry before a future pass. Source/before/after evidence goes in
`build/Other Files/Asset Toolkit/Tina Recovery/Remaining Details/`.
For running Explorer captures, use `tina_explorer_review.gd -- --scenery-review`.

## Boats and signs — 2026-11-22

`forest_tina_harbor_details.gd` is the editable builder for native boats
11500/11501 and signs 11489/11495/11496/11497/11499. The existing original-map
mesh cache and spatial batches own their lifetime. `forest_original_map_details.gd`
delegates these source IDs to the same builder; other sign families retain their
existing path. No extra renderer, simulation, placement list or collider exists.

A boat's 1×1 graphic footprint is its placement marker, not its hull bounds.
Image landmarks recover the long hull, raised stems, cabin/roof/net, two lying
barrels or one upright barrel, benches, colored rails, mast, furled cloth,
rigging, tied mooring pole and rope. The existing map builder supplies the water
datum. Prepared boat decks sit 0.55 world units above it to prevent coplanar
water/deck flicker; the draft remains below the waterline. Original map cells
and X/Z anchors are unchanged.

Signs have explicit source board regions and facing axes, with native-alpha
contours instead of the unstable PCA band crop. Board printing is sampled from
the original RGBA atlas; sides/backs are plain native wood, avoiding reversed
letters. Tree trunks/roots/branches have solid depth. Leaf clusters preserve
their native paint, exclude board pixels, and render on both sides. The native
3/4 view needs 0.1 world units per vertical pixel to cancel the 8-pixel ground
shear at camera elevation 1.6; the old 0.045 value flattened these sign shapes.
The shared source projector and other scenery families are unchanged.

The six added paint recipes in `recover_western_building_surfaces.py` bring the
western atlas to 57 crops. White boat paint and sign bark use the existing tone
smoothing to reduce magnified palette dithering. All originals and source
RGBA hashes are preserved. Hidden hull planking, component depth and rear
views remain reconstructions; this is not an original 3D mesh recovery.

Review with `tina_remaining_scenery_review.gd -- --boats-signs`, adding
`--baseline` only before a future edit. The focused review checks caching,
finite geometry, source UV bounds, sign-view calibration, cargo identities,
long hull bounds, water clearance and rear foliage. The older general asset
fixture's board-height bound is expressed in source pixels at this calibrated
scale. `tina_explorer_review.gd -- --harbor-review` captures the same boats and
signs in Explorer using inspection cameras. Evidence is under
`build/Other Files/Asset Toolkit/Tina Recovery/Boats Signs/`.

## Ruined walls and street containers — 2026-11-22

`forest_tina_street_details.gd` prepares source wall sections 11333–11347,
barrels 10017/10032/10033 and open wooden box 10055 in the existing original-map
mesh cache. The box previously fell into the 10050–10099 tree range and became
a Meadow tree in Explorer; its explicit kind now takes precedence. The barrel
sources retain one, three and seven individual casks, colored staves, dark hoops
and the intact original 10017 lid. The open box has four plank walls and a
recessed floor.

Walls use their native stone contour and front paint instead of generic capped
pillars. The calibrated 0.1 vertical-pixel scale preserves native-view brick
proportions. Two-pixel contour simplification removes pixel-sized ledges without
removing the large broken profiles. Maroon hidden ends and the grey checkerboard
cast-shadow palette are excluded from the contour. Closed ends and rear faces
reuse rectified regional stone; coping uses the native snow patch. Dominant-axis
edge UVs avoid collapsed, streaked end paint. Shared `Shapes.extrude` now handles
either polygon winding when closing sides; front/back triangulation is unchanged.
Hidden depth and backs remain inferred from the original 2D material.

The eight additional recipes bring the western atlas to 65 crops. Original RGBA
source images and hashes, map cells, anchors, navigation/collision, NPCs, services,
quests, saves and the 24-minute clock remain unchanged. Mesh/material preparation
runs at cache creation, with the existing spatial batches owning repeated props.

Review: `tina_remaining_scenery_review.gd -- --street-props`; use `--baseline`
only before a future change. The focused checks cover both extrusion windings,
source UVs/proportions, side texture area, closed geometry, cache reuse, cask
counts and an actually open box. `tina_explorer_review.gd -- --street-review`
captures the same props in Explorer. Source grids, before/after renders,
landmark hashes and logs live in `Tina Recovery/Street Props/` under Asset Toolkit.

## Carved timber and water props — 2026-11-22

Source 11482/11483 are carved timber troughs. The shared street
builder now gives them separate native axes, recessed open channels, wood rings,
brown bark and snow below the wood. Their original placements in Tina and the
road crop are unchanged. The same catalog pass prepares laundry tub 11464 with
its native painted washboard and water pail 11481 with an arched handle; these
two source placements lie outside the current southern-road crop. Both have
actual rims, inner walls and recessed water with continuous planar UVs.

Four new native paint crops bring the western atlas to 69 patches. The bark
uses 11482's brown wood rather than the snowy 11462 patch. Existing log variants
retain their paint. All parts share existing cached geometry/materials and
spatial batches. Original source pixels, anchors and collision remain intact;
unseen interiors/depth remain reconstructed.

Review the four source forms with `tina_remaining_scenery_review.gd -- --water-props`.
`--water-review` on `tina_explorer_review.gd` captures the carved timber in the
actual village and southern-road crop. Source and current front/rear evidence
is in `Tina Recovery/Night Encounters/Scenery/` under Asset Toolkit.

## Snowman, stacked firewood and cold campfires — 2026-11-22

`forest_tina_winter_details.gd` prepares 11460/11461, 11465 and 11484/11485 in
`forest_original_map_solids.gd`'s existing mesh cache. The stack uses three rows
of five logs with exposed cut ends, two lower supports and snow only on the
upper row. Opposite source axes and green/golden end variants remain distinct.
The existing `timber_log` helper accepts optional bark/end paint; its original
callers retain their defaults.

The two-ball snowman keeps the source's red eyes, brown mouth, raised left
mitten and forked right twig, with a native-view facing instead of a +Z face.
Rounded surfaces reuse the shared Geo sphere. The cold campfire forms have
crossed charred timber, scattered coal and low ash/snow patches; source graphics
show no flames. They replace the generic sharp rubble projection.

Six native paint recipes bring the western atlas to 75 patches. New snow uses
stronger existing tone smoothing to avoid enlarged palette-dither stripes.
These rounded props share one owned lit atlas material and a constant brush;
the shared archive material stays unchanged. Explicit surface kind 5 prevents
the shader's default wood grain appearing on snow. Preparation stays at mesh
cache creation; placements, source planes, original art, collision/navigation,
NPCs, night encounters, quests, saves and clock timing are unchanged.

Review with `tina_remaining_scenery_review.gd -- --winter-props`; `--baseline`
is for capturing before a future edit. Use `tina_explorer_review.gd --
--winter-review` for live village snowman/campfire and southern-road stack views.
Evidence lives under `Tina Recovery/Winter Details/` in Asset Toolkit. Depth,
rear paint and component dimensions remain reconstructions from 2D source art.

## Pub corner and porch details — 2026-11-22

Graphic 11416 keeps its native roof, door, facade paint and placement at (46,55)
on both source 4200/4201. `forest_tina_building_details.gd::pub_details` replaces
the unrelated perpendicular sign, third keg and generic stacked boxes with two
unequal banded kegs, the first keg's small open mug, and a solid stepped corner
post painted from the original carved faces and cap. The lettering stays at its
source facade coordinates with a shallow frame depth. Pub rails use wider timber,
fewer uprights and height relative to the wall instead of the ankle-high default.
Other buildings retain their existing porch dimensions. Existing atlas paint,
mesh cache, batch owner, original graphics and collision/navigation remain shared.

Review the isolated front/rear with `tina_buildings_review.gd -- --pub` and the
actual Explorer placement with `tina_explorer_review.gd -- --pub-review`.
Evidence: `Tina Recovery/Pub and Larger Enemies/`. The raw source supplies only
the visible faces; depths, concealed faces and cap volume remain inferred.

## Northern snowy buildings and snow paint — 2026-11-22

The source-painted building set now includes 11411, 11412 and snowy pub 11415.
Their original roof faces, snow drifts, windows, timberwork, doors, signs and
facade details replace the generic repeated wall/roof tiles. Native facade
quads and roof landmarks live in the same authoritative Tina builder; door
frames and 11411's paired raised canopies reuse the existing helpers. The
snowy porch rails/posts have fitted proportions and small snow caps. The pub
reuses 11416's two unequal kegs, mug and carved corner post with its own source
paint offset, plus snow on the keg lids. Other building profiles keep their
existing dimensions and original palette.

Six facade recipes bring the western atlas to 81 patches. The shared `snowroof`
recipe now samples actual snow from 11411 at (155,65)–(171,79), rather than the
dark blue roof-shadow patch at (209,90)–(229,110). The existing tone filter reduces
palette dithering on this reusable paint. This also improves the generic snowy
bay/round-house roofs and small snow caps without adding new geometry. Original
atlas pages and recovered client art remain untouched. The Python source fixture
requires this paint to be opaque, bright and near-neutral to catch a shadow-only
crop returning.

Source 402 contains house 11411 at (171,143) and pub 11415 at (213,153), inside
the existing northern Explorer crop. House 11412 is a reusable catalog variant:
its recorded placements are outside the current cropped roads. No source cells,
anchors, collision, travel entries, NPCs, quests, encounter populations, enemy
sizes, clock or save data changed. Hidden faces/depth remain reconstructions.

Review three models front/back via `tina_buildings_review.gd -- --snow-buildings`;
`--baseline` captures pre-edit generic geometry. Live Explorer routes use
`tina_explorer_review.gd -- --snow-buildings-review`. Evidence is under Asset
Toolkit's `Tina Recovery/Snow Buildings/`, with source/before/after images and
separate live captures. Existing six-building and shared scenery reviews remain
regressions for the reused code and atlas. No app export is part of this pass.

Final verification: 18,198 isolated snowy-building checks, 21,998 existing
six-building checks, 71 shared scenery checks, two rendered Explorer routes,
four Python source tests and the 81-patch reproduction check passed. Asset
preservation passed; the audit read 319 assets with zero read errors. These
are focused correctness/visual checks, not a long-session performance result.

## Round houses, snowy bay and circular paint — 2026-11-22

The native-painted set now includes circular post office 11402, snowy hospital
11413 and snowy bay house 11408. Existing blue hospital 11414 also uses its own
curved wall paint, door, cross, windows, base and planting ring. The circular
houses reuse the same prepared ring/roof primitives; generic repeated windows,
white wall grids and the snow hospital's flat umbrella roof are removed. Their
source roof domes, cupolas and facade landmarks supply the painted detail.
Source entrance cells, map footprints, placement anchors and navigation remain
unchanged. Door surrounds and steps retain the shared frame builder.

The shared circular projector now preserves `cos(angle)+sin(angle)` screen
horizontal position and reflects only rear depth. The old independent absolute
X/Z fold repeated and squeezed a central quarter of the image. Visible roofs,
curved walls, cupolas and base rings now reach both original silhouette sides;
rear views still reuse front paint because no original back view exists. This
also corrects the existing green bay roof 11407 and compatible shared roof calls.

11408 reuses the bay roof and curved-wall primitives with its own snow/wood art,
a right-facing entrance, shorter main wall depth, and open timber porch with
snow-capped rails/posts. A native 11408 window crop replaces unrelated tiny
window art, and the warm regional timber trim replaces the white grid. That
recipe brings the western atlas to 82 patches. Main-wall modular construction
and concealed volume remain inferred; this is not an original 3D mesh recovery.

`prepare_tina_roof_underlay.py --serial 11408` prepares the obscured main roof
behind its snowy bay from the same roof's upper paint and grain. The result is
`11408-main-roof.png` with `underlay-11408.json` provenance. Original atlas pixels
are preserved. `--check` still reproduces the existing green 11407 asset byte
for byte; the preparer also supports 11404 for the separate Jenova work.

Review with `tina_buildings_review.gd -- --round-buildings` (four models, front
and rear); add `--baseline` only before a future edit. Native-view projection,
original UV bounds, finite geometry and shared profiles are checked. Live
Explorer routes use `tina_explorer_review.gd -- --round-buildings-review`:
village hospital (36,27), northern bay (180,143), northern hospital (195,156),
and southern-road post office (239,451). Evidence is under Asset Toolkit's
`Tina Recovery/Round Buildings/`. No app export is part of this scenery pass.

Live review also corrected the circular wall/roof height split: the wall now
reaches 62% of prepared building height, with the main dome interpolated up to
the existing cupola base. This replaces the oversized egg-shaped roof with a
shallower dome and taller source-painted wall; source UVs/anchors are unchanged.

Final evidence: 21,411 isolated round-building checks (headless and Metal),
22,073 existing building checks, 71 shared scenery checks, 197 day/night checks,
four source tests and four rendered Explorer routes passed. The 82-patch atlas
and all three supported roof underlays reproduce; 11407 was preserved instead
of rewriting its generated baseline. Asset preservation passed; the audit read
319 assets with zero read errors. Existing teardown RID/resource warnings remain.
This does not establish long-session performance or literal 1:1 unseen geometry.

## Bay walls, ground-level porches and shutters — 2026-11-22

11407 and 11408 now use their original exposed main-wall strips instead of
repeated generic windows and the shared wall grid. Four facade recipes record
native wall coordinates. Hidden portions remain plain regional timber so bay
pixels are not painted twice onto the rear main wall. Original window shutters
have shallow solid depth using the shared native-quad builder. Both round bay
walls now use their own curved source paint, including timber, glass and base
bands. The main block of 11407 is narrower to expose its source side porch;
11408 retains its existing shallower main block. Placement anchors and entrance
positions are unchanged.

`Tina.bay_porch` reuses box/round primitives for uneven vertical boards, backing
rails and capped posts. Its two source orientations leave each original door
opening clear; snow caps apply to the winter variant. A native 11408 board crop
supplies the shared timber paint. Five new recipes bring the current western
atlas to 88 patches, including the adjacent Jenova additions already present.
The existing tone filter handles the small board sample. No original client
images, painted masters or raw map planes were edited.

The full rectangular wooden platform was removed from both houses. Stone
foundations now follow the main block and round bay; fenced porch ground stays
open to the map terrain. Some client floor cells under 11408 are unrecorded.
`forest_original_maps.gd::porch_floors` supplies visual land tiles only where
those bay-house footprint cells are zero, borrowing the nearest recorded 1x1
land tile within eight cells. It never replaces a recorded tile or selects
water. The source byte array, original placement count, navigation and physical
ground remain unchanged; `recovered_porch_floor_patches` records the derived
render placements separately. Setup reuses the normal floor mesh cache and
existing page batches. Remove this repair as original cells become available.

Review: `tina_buildings_review.gd -- --bay-walls`; `--baseline` captures a future
pre-edit state. The review checks facade coordinates/native UVs, finite cached
geometry, grounded fence bounds, clear source-facing door openings and blank-only
floor repair. Live routes use `tina_explorer_review.gd -- --bay-walls-review`
for village green house (30,61), northern snowy house (180,143), and southern
road green house (571,315). Evidence is under `Tina Recovery/Bay Walls/` in
Asset Toolkit. Concealed wall depth/paint, porch volume and unrecorded floor
paint remain reconstructions; there are still no original 3D building meshes.

Final evidence: 16,521 focused checks in headless and Metal reviews, 24,257
existing building checks, 71 shared scenery checks, 197 day/night checks, four
Python source tests, 88-patch reproduction, asset preservation and three live
Explorer routes passed. Final routes/day-night runs have no script errors;
initial unrelated Falan-fort startup assertions are retained in Diagnostics.
The asset audit read 319 assets with zero read errors. This is focused
correctness/visual evidence, not a long-session performance result.


## Stockade walls, blue porches and carved pillar — 2026-11-22

11140/11142/11143/11145/11146 now reuse `Street.wall_mesh` instead of the
identical generic six-log stockade. Their own native alpha contours, stepped
heights, stone faces and timber paint remain distinct. Source-pixel baselines
record the two wall orientations; a measured timber/stone join divides closed
depth into regional stone, bare bark and end-grain surfaces. Bare wood uses the
existing 11482 bark crop, avoiding the snowy 11462 wood. This remains a thin
closed reconstruction of the original visible face, not recovered round-log
geometry. Adjacent placements keep their source anchors and normal mesh cache.

11314 reuses `Tina.pub_post` with its existing optional profile/face arguments.
Its tall shaft, two stepped collars and pointed cap use the pillar's own native
paint, with source-view height calibration. Hidden ornament repeats the two
available painted sides. No separate renderer or editable duplicate was added.

11409/11410 porches now have only their source-facing side (left/right), closely
spaced vertical balusters, heavier posts and supporting legs beneath a thin
board deck. Main stone footings no longer cover the open porch with a solid
wooden platform. Timber paint is rectified from a 11409 porch post in
`recover_western_building_surfaces.py`; the shared small-crop tone filter keeps
its native brown colour. 11410 facade recipes now include the lower stone wall,
and its door outline follows the actual entrance instead of neighbouring
window/porch pixels. This fixes its below-ground frame and detached-looking
step. Generic horizontal wall bars no longer cross the native Tina facades.
The current combined western atlas contains 90 recipes, including concurrent
Jenova work. Original graphics, raw map planes, entrance triggers and navigation
remain unchanged.

Review `tina_remaining_scenery_review.gd -- --boundary-props` for the six props;
`tina_buildings_review.gd -- --blue-porches` for both houses. `--baseline` captures
a future pre-edit state. Focused checks cover native paint/UVs, closed depth,
separate wood/stone sides, source-view proportions, clear porch entrances,
grounded supports and positive door thresholds. Live Explorer routes use
`tina_explorer_review.gd -- --boundary-porches-review`: village blue house
(36,38), night house (21,54), stockade corner (65,48), pillar (38,31), and the
southern-road stockade (608,302). Evidence is in Asset Toolkit's
`Tina Recovery/Stockades and Porches/`, including original/before/after images.

Fresh checks: 65 focused prop checks, 5,609 blue-house checks in Metal, 23,045
shared building checks, 17,115 snow-building checks, 158 older street-prop checks,
71 reused scenery checks, 197 day/night checks, four Python source tests and
five rendered Explorer routes passed without script errors. The 90-recipe native atlas reproduces; asset preservation passed and the audit
read 319 assets with zero read errors. Existing Godot teardown RID/resource
warnings remain. Unseen sides and porch volume are inferred from the original
sprites; no app export or long-session performance test is part of this pass.


## Area polish: roof alignment, snowy ruins and notice sign — 2026-11-23

11403/11409/11410/11411 now derive wall widths, eave height and roof rise from
the same measured native facade coordinates. The two visible roof slopes use
that facade's camera calibration. Raised door/window dormers are clipped out
of the roof's painted triangles so their paint is not duplicated over the
raised arch. The inferred rear slopes share the same ring vertices, keeping
all roof seams joined. Finials follow the prepared apex. 11403 door and gable
trim now uses its authoritative full-height Jenova/Tina facade rather than the
older shorter crop; its original red door and artwork remain unchanged.

Snowy broken walls 11348–11356, 11358 and 11361/11362 reuse Street.wall_mesh.
All 32 supported wall/stockade contours are prepared from original CPU image
pixels in wall-outlines.json. Regenerate with Godot --headless --path .
--script res://tools/prepare_tina_wall_outlines.gd, adding -- --check to verify.
The file pins each original RGBA hash and is included in the existing export
presets. Runtime wall preparation no longer reads GPU textures back to trace
contours; this avoids malformed/missing walls seen during overlapping Metal
reviews. The original front paint and closed side/depth builder are shared.
Their own source contours and stone/snow paint replace the generic repeated
pillars, preserving thin closed depth and a grounded snow drift. Native 11466
reuses Tina.crate with its own snowy top, diagonal boards and base snow.
11491 is the curved notice board with lettering, red/green garland, paired
posts and snow caps; it now uses Harbor.sign_mesh instead of a rail-fence form.
No signs execute NPC services or quest logic.

All geometry prepares in the existing original-map mesh cache and spatial
batches. No extra actor, update loop, collision map or renderer was added.
Original atlas pages, map planes, source placements, entrance triggers and
native roaming encounters remain unchanged. Unseen faces/depth are inferred;
there are no recovered original 3D building meshes.

Review: tina_area_polish_review.gd (add --baseline before a future change),
tina_explorer_review.gd -- --area-polish-review, tina_night_encounters_test.gd.
The focused review checks the roof/facade projection, dormer separation,
closed rear roof seams, all reused wall profiles, snowy wall proportions,
source paint, finite geometry and cache reuse. Source/before/after pictures,
statistics and live Explorer evidence belong in Tina Recovery/Area Polish/
under Asset Toolkit. No app export is part of this pass.

Final evidence: 130 focused headless checks, 126 focused Metal checks, 23,183
shared building checks, 16,947 snowy-building checks, 71 reused-scenery checks,
197 day/night checks, 1,976 rendered monster checks and seven final rendered
Explorer routes passed. Four Python source tests, all 32 prepared contours and
the native surface atlas reproduce; 14 original catalog/atlas files are
unchanged. Asset preservation passes; the audit read 319 assets with zero read
errors. Final listed runs have no script errors or Metal fence timeouts. Initial
failures are retained under Area Polish/Diagnostics. Existing exit cleanup
warnings remain; this is not a long-session performance result.


## Remaining pubs and street props — 2026-11-23

11412/11415/11416 join the existing ALIGNED_HIPS profile set, deriving facade
width, eave height, roof rise and source paint from the same native landmarks.
They retain curved hips and joined rear rings; 11412's finial follows its apex.
The pub's red doors, original lettering, mugs, two kegs, snow and carved corner
post keep their existing detail builder. 11412 is present at Magic University
(134,50); its other source placements lie outside the current road crops.

Street.bench_mesh prepares open plank bench 10037 and backed bench 11041.
The former has its original high plank and lower footrest, four fitted supports
and end braces; the latter has the long native seat, weathered back board and
four continuous supports. Original top/back paint is sampled inside its board
edges to exclude cast-shadow pixels. Undersides, edges and supports reuse the
existing native wood kit. Native crate 11016 reuses Tina.crate with its own
top and two diagonal-board faces. Hidden faces remain reconstructed.

Street.mushrooms_mesh replaces the generic four-cap arrangement with the
source's three caps (11098) and five caps (11099), at the native relative
positions. Existing sphere/cylinder primitives provide solid caps and stems.
Their original copper and green stem tones come from pinned opaque pixels in
their own original atlas regions, excluding source transparency/shadows. An
owned lit material and constant brush soften the rounded shading without
changing the shared archive material. This is a 3D reconstruction of tiny
source sprites, not recovered original 3D geometry.

All forms prepare once in the existing original-map mesh cache and spatial
batches. No placements, source planes, collision/navigation, clock, NPC
features or native encounter behavior were added or changed.

Review tina_area_polish_review.gd -- --remaining-street (add --baseline before
future edits), and tina_explorer_review.gd -- --remaining-street-review.
The eight live destinations cover day/night Tina, its southern approach, the
northern pub and Magic University. Evidence goes in Tina Recovery/Remaining
Street Polish/ under Asset Toolkit; monsters use tina_night_encounters_test.gd.

Fresh checks: 111 focused headless and 111 focused Metal checks, 4,119 pub
building checks, 17,169 snowy-building checks, 130 previous-polish checks,
197 day/night checks, 1,976 rendered encounter checks and eight rendered
Explorer placements pass. Four source tests and the native surface atlas
reproduce; 14 original catalog/atlas files are unchanged. Asset preservation
passes; audit reads 319 assets with zero read errors. Final runs have no script
errors or Metal fence timeouts. Existing exit cleanup warnings remain. These
are focused correctness/visual checks, not a long-session performance claim.

## Round hospitals and original grave markers — 2026-11-23

Round hospitals 11413/11414 now use `Tina.circular_profile` and
`calibrated_circular`, deriving wall height, roof, cupola and garden rings from
their original image coordinates. The former independently stretched shell
made them tall towers and displaced the front window. The native projector now
fits those rings together; the foundation and garden share one closed inner
edge. Door frames/steps reuse `round_door`, with grounded thresholds and an
unscaled structural ring. The existing solid finial replaces the transparent
pinched cupola tip. Jenova 11402 and the bay-house profiles retain their own fits.

`Street.TOMBS` covers all eleven native markers: 11048/11050/11051/11053/11056/
11058/11062 and 11470/11471/11473/11474. `Street.tomb_mesh` reuses the existing
profile extrusion and source atlas, retaining original outlines, inscriptions,
bouquets, ribbons and snow instead of generic slabs, grooves and pebble flowers.
11050 lies on the ground. 11062 separates the upright stone and low slab at the
measured native join line y = 0.75x + 21.25, through source pixel (29,43).
Other markers stand upright. Closed added depth is 0.10, or 0.14 for the larger
flower markers; the source art already includes its painted three-quarter edge.

`tools/prepare_tina_wall_outlines.gd` prepares all eleven markers alongside the
existing 32 wall contours. It preserves separate visible components, excludes
the grey checkerboard shadow and pins each original RGBA hash. The shared
`wall-outlines.json` stores original contours, upright/flat parts and an opaque
native stone pixel for the unseen edges/back. Runtime uses cached geometry and
one owned lit backing material per source page, without GPU image readback or
changes to the shared source material. This remains a reconstruction from 2D:
rear paint, depth, hidden surfaces and rear hospital rings are inferred.

Review `tina_area_polish_review.gd -- --round-stone` (add `--baseline` before
future edits), `tina_explorer_review.gd -- --round-stone-review` and
`prepare_tina_wall_outlines.gd -- --check`. Evidence is in Asset Toolkit's
`Tina Recovery/Round and Stone Polish/`, including source/before/after images,
per-graphic triangle/surface statistics and eight live Explorer destinations.
The two hospitals use 1,540 triangles each; markers use 100–572 each, two
surfaces per graphic. They reuse the existing spatial batches and original
placements; collision/navigation, the clock and native encounter ownership are
unchanged. Tina NPC gameplay remains removed.

Fresh scenery verification passes 161 focused headless and 161 focused Metal
checks, 22,791 round-building checks, 111 previous street-prop checks, 130 earlier
polish checks, 197 day/night checks and eight live Explorer placements. Five
source tests pass, the 32 wall plus 11 grave contours reproduce, and all 14
original catalog/atlas files are unchanged. Asset preservation passes; the
audit reads 319 assets with zero read errors. Existing teardown RID/resource
warnings remain. These checks do not establish a long-session performance gain.

The final rendered encounter regression passes 1,976 checks: 64 night-village,
192 southern-road and 85 northern-road enemies populate through the native
owner. A live night attack reduces player HP, dusk/dawn cleanup and bounded
repopulation pass, and repeated settled ticks add no nodes/resources. Final
listed logs have no script errors or Metal fence timeouts. The launcher script
lock was busy during the final Explorer and monster reviews, so both used the
same Godot and complete source directly after attempting Play Goemon. See
`verification.json` for results and scope. No app export was requested or made.


## Village-only appearance pass — 2026-11-23

`forest_tina_scenery.gd` supplies isolated scenery variants only when the source
map is 4200/4201 (the day/night village) or one of its fourteen existing Tina
room maps (4206/4208/4209/4210/4211/4212/4213/4214/4220/4221/4222/4230/4232/4299).
It intercepts those
graphics before the generic flower/tree paths, then uses the existing source
anchors, immutable meshes/materials and 48 m spatial batches. Other villages,
roads and Arena retain their previous builders. Original room walls, floors
and stairs remain on their existing rendering path. No shared GLB, Blender
master, source PNG, map plane, collision, NPC, dialogue, entrance, transition,
clock, combat or save-data owner was edited.

Applied corrections:

- Three original tree crowns (10089/10092/10093) replace the single generic
  silverleaf crown. They redistribute the existing complete leaf quads using
  the same source-sampling method as `prepare_crossgate_trees.py`, with each
  graphic's own pale-leaf painting, outline and proportions. Existing trunk
  topology is retained; shared tree masters and materials remain unchanged.
- Native 11626 flowers, fourteen cream-tipped reed variants 11660–11673 and
  four rose bushes 11692–11695 retain their individual source-facing contours
  and paint instead of all becoming `flowers_ivory`. Original 12471–12485
  fronds retain their green/ochre/red variants and low spreading silhouettes
  instead of repeating nine procedural leaves. Small plants use the existing
  contour extrusion helper with shallow depth; fronds lie near the ground.
- Storage shelter 11015 has its long sloping roof, original timber roof paint,
  exposed supports, stacked logs and yellow hanging hides. It replaces the
  generic peaked roof and four-row log pyramid. It reuses existing roof-face,
  rod and rounded-log primitives and the existing native timber atlas.

- Existing village rooms recover their own original furniture paint where
  generic materials had replaced it: wood grain, upholstery, crockery, produce,
  baskets, stoves, shelves, piano, clock and decorative objects. Already
  source-painted surfaces retain their existing paint. Unseen rear/underside
  faces keep their prior materials and UVs; only source-facing surfaces receive
  newly recovered paint. Plain table/counter
  segments no longer inherit a rounded book-covered desk, extra books, quills
  or shelf dividers. Segment support legs follow the opaque native leg strips.
  The long plain bench 16500 has a plank and two trestles instead of a padded
  bench. Six potted-plant variants use their actual conifer/leaf/flower/vase
  contours instead of an unrelated urn and repeated fern. All other furniture
  keeps its complete existing geometry; only its source paint changes.

There are 136 outdoor replacement placements in each village phase. All are on, or
one source cell from, the existing connected walkable village component. No
new reachability, remote map crop or prop placement was introduced. Look at
the flowers beside the blue house (36,39), roses beside the pub (47–51,57),
the boundary reeds/ferns, the distinct trees at (76,49)/(14,59), and the timber
shelter near the northern bank (47,6). Coordinates are original source cells.
Also look at the pub counter, hospital furniture/potted plants, the plain
bench in the village homes, and the chief's room furnishings. These are review
locations, not a scripted walkthrough.

Source and uncertainty ledger:

| Category | Disposition / specific limit |
| --- | --- |
| Main houses, hospital, pub and shed | Existing native facade, roof and landmark profiles retained; no additional clear mismatch established from the supplied faces. Their hidden/rear surfaces and green bay's obscured roof paint are not shown in the archive. Leave these reconstructions unchanged pending an original rear/obscured view. |
| Shelter | Visible slope, timber painting and hides corrected. The source does not resolve the hidden roof underside or the full number of concealed logs; their depth/support volume remains a reconstruction. |
| Trees | Source crowns/paint corrected. The archive does not provide rear branch topology; reuse the existing trunk rather than inventing branches. Crown depth uses the existing recovered-tree method and is not original 3D data. |
| Reeds, flowers, roses and ferns | Original visible shapes/colors corrected. Unseen thickness/back-facing botanical detail is not recoverable; shallow backing reuses the visible paint. This needs in-game visual review, particularly from the rear. |
| Streets, snow, ground colors/textures | Original floor serials, per-cell paint and source anchors already retained. Keep them. Existing missing ground beneath the bay house is an approximation; no original concealed floor tile is available to replace it confidently. |
| Walls, rails, graveyard, signs, containers, boats | Existing recovered source-specific profiles/paint and all original placements retained; no new reference-supported relocation identified. Concealed backs remain uncertain. |
| Shoreline | Preserve the current bank/water meshes. Native bank sprites combine painted rock and water; they do not give a reliable land/rock/water height split for a new 3D contour. Resolving that split is the blocker to further contour changes. |
| Lighting | Preserve current outdoor day/night lighting. The references contain baked 2D shading, not a matched 3D lighting/exposure or time-of-day reference; a village-specific lighting adjustment cannot be justified from them. |
| Existing village rooms | Original floors/walls/stairs, source placements and entrances retained. Clear desk/table/bench/plant substitutions and generic paint are corrected. Small painted tabletop objects, pot/cabinet backs, concealed support joints and upholstery depth have no separate original depth views; do not invent these details. The food shop (4206) and night gate room (4232) remain explicitly reference-only layouts, not verified BlueCG captures. |
| Roads / other regions | No changes. Only the two village phases and their already-accessible village rooms are in scope. Linked mines, quest regions, roads and other villages retain their current art. |

Preparation: run `Play Goemon.command --headless --script
res://tools/prepare_tina_scenery.gd`; add `-- --check` to reproduce the prepared
`assets/maps/falan/tina/scenery_profiles.gd`. It pins every original RGBA hash
and uses CPU images offline; there is no runtime image readback.

Nonvisual checks: `tina_appearance_test.gd` checks both village builds, unchanged
map/collision planes and door records, exact per-graphic placement counts,
finite/grounded geometry, source UV bounds, cache reuse, reused tree topology
rejection of non-Tina maps and unchanged room-furniture vertex geometry. The
1,692 focused checks pass, as do the five existing
Python Tina source tests, profile reproduction, and global asset/audio/cosmetic
preservation. The GLB audit reads 319 assets without read errors. The launcher
script lock was occupied, so the same Godot binary and complete source ran the
headless checks directly after attempting the launcher. Dummy-renderer resource
and RID warnings remain at test teardown; this is not a resource-soak result.

No walkthrough, rendered verification, verification screenshots, performance
benchmark or app export was performed. The source contact sheet in Asset
Toolkit's `Tina Recovery/Appearance Pass/` contains only archived reference art.
Status: ready for the user's in-game review; **not verified 1:1**.
