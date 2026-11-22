# Falan painted architecture

## Falan grounded foundation stone strips — 2026-11-23

The two long curtain-wall facings used short, overly projecting plain posts at
158 stations. Their visible stone faces now follow four controls measured from
each original drawing: about 2.731 metres high with 0.5625 metres of lean. Each
has a closed 10-centimetre stone body. The lower green wall reuses three closed
extrusions around a narrow local channel; all four strip back corners are embedded
in actual masonry. Global green foundation bounds remain exactly unchanged.
Upper crowns, other twenty template bounds, stations and gate contracts remain.

`tools/recover_falan_forts.py` rectifies the two original light stone faces into
`assets/maps/falan/city_fort_wall_spurs.png`, with duplicated edge gutters and
reduced palette chroma. The neighbouring baked shadow is not extruded as stone.
All twenty preceding fort PNGs remain byte-identical. Reuse the current shared
paint-material cache, archetype cache and placement batches. The measured kit is
88,774 triangles / 109 surfaces: an increase of 52 triangles / two surfaces,
plus one 136-by-196 RGBA texture (104.1 KiB uncompressed) and one shared material.
The 314 masonry returns retain 11,280 triangles / two surfaces. This is a visual
correction with no new frame loop, not a measured gameplay speed improvement.

Evidence is in `Falan Exterior Fidelity/Foundation Spurs/` under Asset Toolkit.
Source/before/after and four-angle renders show the grounded strips and local
channels. Whole assembled fortification silhouette overlap rises from 97.070%
to 97.532%; this does not measure exact colour or hidden construction. Earlier
202 tower-edge and 63 coping samples remain exact, and crown skyline samples are
unchanged. Fresh selected checks pass 19 art tests, recovery of 22 graphics,
319 audited assets with zero read errors, three preservation groups, 22 rendered
variants, 7,697 desktop gate checks, 7,685 headless gate checks and 1,800 city
checks. All 22 physical variants have closed, outward, consistently wound forms;
new painted triangles are backed, unobstructed and within 0.05 native pixels.
Existing fixture shutdown resource/RID diagnostics remain.

Verify through Play Goemon from the native view and low side/rear angles, then
walk west, east and south approaches. Final gate captures reflect the current
night lighting; the isolated detail captures provide the clearer material view.
One original view cannot certify unseen depth. Tiny cap/foot relief, baked light
and raster differences still prevent a complete exterior 1:1 claim. No app export,
long-session soak or army frame-time benchmark was run. Earlier sections below
retain their historical measurements.

## Falan varied wall crowns and terminal heads — 2026-11-23

The curtain-wall crowns repeated eight small square posts. The source instead
has narrow corner posts, broader battlement heads and a projecting terminal
piece. `WALL_CROWNS` now records seven native top-face controls per facing:
six battlements and one lower terminal head, repeated across 158 wall stations.
The opposite drawing uses `u = 143 - u`. Native centres are checked within
0.05 pixels. A separately cached narrow-stemmed variation reuses `merlon`;
its default mesh and the square/round tower callers retain their earlier forms.

`WALL_FRAMES` preserves the preceding measured wall shell. Changing crown shape
must not refit and stretch the entire wall. The new six heads rise from raw
15.4 to 16.6; the terminal head tops at 16.2. The terminal piece reuses closed
bevelled coping and a closed clipped loft, with slight volume overlap at the
head/stem joint. The front coping is extended to seat the broader blocks.
Every crown foot is tested inside actual masonry. Green foundation bounds match
the baseline exactly, and all twenty other template bounds remain. The two upper
wall bounds change slightly with the corrected crown height and overhang.

The wider coping also requires the original hanging-detail faces to stand at
0.85 metres of wall-normal relief. Their native UVs and projected outlines stay
fixed. Closed backings recede along the native camera ray with 0.95 metres of
normal offset, preserving the source-view outline. Each corner-overhanging form
requires at least three back vertices inside the original masonry, in addition
to closed topology, immediate face backing and unobstructed source-view triangle
centroids. A fully embedded-root candidate passed contact checks but created
large pale wedges; it was rejected in rendered review. Hidden backing depth and
the terminal cut remain reconstructions from a single drawing.

All twenty fort PNGs remain byte-identical; there are no new textures or
materials. The kit contains 88,722 triangles / 107 surfaces, an increase of
72 triangles and zero surfaces. One additional reusable merlon mesh is cached;
existing archetype caches and MultiMesh batches still own placements. The 314
masonry returns retain 11,280 triangles / two surfaces. There is no new frame-loop
preparation. These are asset costs, not a gameplay frame-time measurement.

Evidence lives in `Falan Exterior Fidelity/Wall Crowns/` under the Asset Toolkit:
source/before/after, four angles, all 22 variants, twelve gate views, exact
foundation comparisons, source hashes and logs. Across 103 exposed skyline
columns per facing, mean native-pixel error falls from 2.54 / 2.47 to about
0.76 / 0.78. Scores and remaining errors are recorded, not rounded into a 1:1
claim. Assembled fortification mask overlap improves from 96.898% to 97.070%;
this measures silhouette overlap, not colour or hidden-depth accuracy. The earlier
shaft and coping samples retain 202/202 and 63/63 matches.
Eighteen art tests, recovery of 22 graphics, the 319-asset audit (zero read errors)
and three preservation groups pass. Final checks cover 22 rendered variants,
7,697 desktop gate, 7,685 headless gate and 1,800 city checks, plus physical
closure, source controls and crown seating. Selected logs have no script errors;
fixture shutdown resource diagnostics remain. No app export, long-session soak
or army benchmark was performed.

To verify in Play Goemon, inspect wall crowns at each gate from the native view
and a low side angle. Heads should alternate in width, sit on coping and finish
in a connected projecting end plate. Keep original face art on its own surfaces;
compare rendered visibility as well as coordinates and closed geometry. Native
rasters, baked light and unknown rear construction still prevent a complete
exterior 1:1 certificate. Earlier sections retain historical measurements.

## Falan hanging wall-detail profiles — 2026-11-22

The two long-wall facings used four small regular blocks high in the coping.
The original drawings show three distinct hanging details per facing. Their six
visible profiles now use the measured native texel boundaries and separate face
crops, covering 158 wall stations: 474 source-facing forms and 948 closed
front/rear forms. `recover_falan_forts.py::WALL_SUPPORTS` owns the editable source
measurements; generated `Data.WALL_SUPPORTS` carries profiles, native bounds and
atlas regions. These are reconstructed relief forms, not independently recovered
structural corbels or a new claim about unseen masonry.

`forest_falan_fort_parts.gd::wall_supports` intersects the native camera ray with
the prepared sloping wall plane. The face relief is 0.60 metres and the closed
`pier_loft` body is 0.75 metres deep, overlapping the original masonry. The first
shallower candidate left part of the artwork behind the coping; increasing depth
along the fixed camera ray retained its projected outline. Native UVs are checked
within 0.05 pixels, with an explicit source-view occlusion check at every painted
triangle centroid. Immediate face backing and a wall contact within the solid
body depth are also required. Reverse forms reflect through the actual wall
midplane, repeating source art; their hidden depth and shape remain inferred.

Six crops share `city_fort_wall_supports.png`, a guttered 204-by-136 atlas
(110,976 RGBA bytes, about 108 KiB). The existing `native_stone` treatment keeps
mean source tone and luminance relief without magnifying palette dithering.
All nineteen preceding fort PNGs remain byte-identical. Profile vertices describe
texel edges, so preservation checks accept the opaque adjoining texel at exposed
boundaries. Original source images remain the visual reference.

The existing two archetype caches own the geometry; body faces merge into masonry
and the atlas adds one surface per template. The kit now contains 88,650 triangles
and 107 surfaces: +562 triangles and two surfaces across the templates. The 314
masonry returns remain 11,280 triangles / two surfaces. All 22 template outer
bounds, gate header bounds, stations, door contracts, previous tower details and
original curtain-wall openings remain. There is no new frame-loop preparation,
per-placement asset owner or whole-building projection. This records asset cost,
not a new gameplay frame-time result.

Evidence is in `Falan Exterior Fidelity/Wall Supports/` under the Asset Toolkit:
native profiles, original/before/after, all 22 variants, low front/rear views,
twelve gate captures, topology, source hashes and logs. Seventeen art tests,
recovery of 22 graphics, the 319-asset audit (zero read errors) and all three
preservation groups pass. Fresh final checks pass 22 rendered variants,
7,697 desktop gate checks, 7,685 headless gate checks and 1,800 city checks.
Physical masonry has no open boundaries, inward closed components or inconsistent
edge winding. The retained shaft and coping controls still match 202/202 and
63/63 samples. Whole-map silhouette overlap is recorded separately; correct
face registration and closed geometry do not certify the entire exterior 1:1.
Selected final logs have no script errors; fixture shutdown resource diagnostics
remain. No app export, long-session soak or army benchmark was performed.

To verify in Play Goemon, inspect both wall facings outside each gate and circle
a section at a low angle. All three details should remain seated in the stone,
with their painted fronts clear of the coping in the native source view. Preserve
the independent visibility check when changing depth: a correct projected UV can
still be hidden by another surface. Older sections retain historical evidence.

## Falan original curtain-wall openings — 2026-11-22

The two long sloping wall templates still used six equal dark bars. They now
use twelve individually recovered face quads from original 10640/10641,
preserving the native lean, width, height, endpoints and spacing for each facing.
Those templates cover 158 stations: 948 source-facing openings and 1,896 closed
front/rear detail backings. `wall_details` intersects the fixed native camera ray
with the actual transformed wall plane instead of placing another regular row.
The shallow backing reuses `pier_loft`; source-facing UV registration stays within
0.05 native pixels. Tests also require each detail to sit immediately against
both its own backing and the original wall skin, including the reverse side.

The rear row reflects through the actual prepared wall midplane, including its
slope and thickness. It repeats the original front artwork and remains inferred.
These are painted recess faces on closed backing solids; the existing solid wall
and collision contract remain. All 22 template outer bounds, gate headers,
station placements, door contracts and previous tower repairs are unchanged.

`recover_falan_forts.py::WALL_SLITS` owns the twelve native quads. Generated
`Data.WALL_SLITS` and `city_fort_wall_openings.png` share a guttered 216-by-392
atlas (338,688 RGBA bytes, about 331 KiB). The established `native_stone`
treatment keeps native mean tone and luminance relief while suppressing enlarged
palette-dither chroma. This is source-derived artwork; the unmodified originals
remain the reference. All eighteen preceding fort PNGs are byte-identical.

Both wall archetypes reuse the existing mesh cache and one shared atlas material.
Backing stone merges into the original masonry surface; paint adds one surface
per template. Removing the generic bars and adding the closed details changes
the complete kit by 48 triangles and two surfaces, to 88,088 / 105. The 314
masonry returns remain 11,280 triangles / two surfaces. No frame-loop geometry,
per-placement resource preparation or new army owner was introduced. These are
asset measurements, not a gameplay frame-time result.

Fresh evidence is in `Falan Exterior Fidelity/Wall Openings/` under the Asset
Toolkit: original/before/after for both facings, four angles, all 22 variants,
twelve gate captures, source hashes and topology. Sixteen art tests and recovery
of 22 original graphics pass. The audit reads 319 assets without errors; all
three preservation groups pass. Final verification passes 22 rendered variants,
7,697 desktop gate checks, 7,685 headless gate checks and 1,800 city checks.
Physical masonry has zero open boundaries, inward closed components or winding
errors. The retained shaft/coping samples remain 202/202 and 63/63 exact. Whole
fortification silhouette IoU stays 96.898%; this internal-detail correction does
not claim improved outer alpha overlap or complete exterior pixel equality.
Selected final logs have no script errors; existing fixture shutdown resource
diagnostics remain. No app export, long-session soak or army benchmark was run.

To verify, approach west, east and south gates through Play Goemon, then inspect
a curtain wall from low front and rear angles. Openings should follow the wall
slope, retain their individual ends and stay seated in the stone. Preserve the
original quads and the setup-only plane intersection when adding compatible wall
variants. One original view cannot independently determine hidden depth; do not
replace that uncertainty with a whole-picture projection. Earlier sections keep
their historical measurements.

## Falan square-tower stone courses and foundation boundary — 2026-11-22

Eight square-tower archetypes, used at 139 stations, were missing two raised
stone courses. Their green-brick footing also began too high. The fort owner
now reuses the existing closed bevelled `gallery_coping` module for both rings.
Four original 10650 face quads determine their width, height and painted-face
registration; the prepared half-width is `63/(2*Fit.HORIZONTAL)`. The footing
top changes from raw 4.2 to `SQUARE_FOUNDATION_HEIGHT = 3.45`, with its ground
footprint retained. Foundation metadata follows that boundary so masonry returns
still meet the towers. Gate header bounds, stations and doorway contracts remain.

`recover_falan_forts.py` generates `Data.SQUARE_COURSES` and one shared guttered
520-by-72 atlas (149,760 RGBA bytes, about 146 KiB). Its four original crops use
the established `native_stone` treatment: native mean tone and luminance relief
remain, while enlarged palette dithering no longer becomes rainbow bands.
All seventeen preceding fort PNGs remain byte-identical. Source-facing UVs stay
within 0.05 native pixels and their paint has immediate solid backing. Reverse
faces repeat those crops and remain inferred rather than independently recovered.

`forest_falan_fort_parts.gd::square_courses` caches one immutable module shared
by all eight variants. Stone is merged into the existing masonry surface; the
atlas adds one surface per variant. The reused coping transform reflects its
axes, so its triangles must reverse winding and normals use inverse transpose
when merging. Keep the closed bevelled body behind the detail paint. There is
no whole-picture building projection or per-frame mesh/material preparation.

The kit now contains 88,040 triangles / 103 surfaces, an increase of 576 triangles
and eight surfaces across the templates. The 314 masonry returns remain 11,280
triangles / two surfaces. These are asset costs, not a new gameplay frame-time
measurement. Whole-fortification silhouette IoU changes from 96.908% to 96.898%;
the added internal course detail is not a claim of improved overall alpha overlap.
Clipped source silhouettes, tiny artwork and unknown rear depths still prevent
an honest complete-exterior 1:1 claim.

Evidence lives in `Falan Exterior Fidelity/Square Courses/` under the Asset
Toolkit: source/before/after, all 22 variants, four angles, twelve gate captures,
source hashes and physical topology. The earlier shaft and coping controls retain
202/202 and 63/63 exact samples. Fifteen art tests, recovery of 22 original graphics,
the 319-asset audit (zero read errors) and three preservation groups pass. Final
checks cover 22 rendered variants, 7,697 desktop gate checks, 7,685 headless gate
checks and 1,800 city checks. Physical masonry has no open boundaries, inward
closed components or inconsistent edge winding. Selected checks have no script
errors; existing fixture shutdown resource diagnostics remain. No app export,
long-session soak or army benchmark was performed.

To verify visually, run Play Goemon and inspect each gate from outside, then
circle a square tower at a low angle: both rings should stay seated on the wall,
and the lower ring should cover the transition to the green foundation. Reuse
the original quads and cached module for future variants instead of fitting each
placement separately. Older sections below retain their historical measurements.

## Straight round shafts and original lower openings — 2026-11-22

The original 10657 shaft has a constant 136-pixel envelope over rows 110–210;
the imported model tapered throughout. All six round variants now reuse a
64-sided straight shaft and short lower flare, with a narrower, higher brick
footing. `ROUND_RADIUS`, `ROUND_FOOTING_HEIGHT`, `ROUND_FOOTING_RADIUS`,
`ROUND_FLARE_TOP`, `ROUND_BASE_RADIUS` and `ROUND_SETBACK` own the profile.
`ROUND_CENTER` preserves the half-native-pixel shaft/crown registration.
The checked shaft span matches all 202 boundary positions exactly. Small closed
foundation ledges use their original native top quads. The original imported
model and common tower crown frame remain intact. Hoods retain their source
projection while moving outward along the native camera ray to meet the shaft.

`recover_falan_forts.py` generates `Data.LOWER_SLITS`, `Data.ROUND_COURSE` and
`Data.ROUND_FEET`. Their original drawings share `city_fort_arrow_details.png`,
a guttered 544-by-216 atlas (470,016 RGBA bytes). All sixteen earlier fort PNGs
remain byte-identical. The six square and seven round source-facing openings
have closed shallow backing volumes, and reverse rows reuse the source art.
The narrow division strip follows the measured drawing on the curved skin;
solid side trim connects its repeated rear continuation. Those hidden details
remain reconstructions. Keep the strip subdivided so its chords stay outside
the shaft. Native UV registration and immediate stone backing are checked.

`forest_falan_fort_parts.gd::lower_details` prepares this geometry once per
cached archetype, using `round_surface` for the curved profile. Fourteen templates
cover 181 stations. The shared courtyard/default tower callers retain their
original openings; the source-merlon path delegates to this recovered owner.
Keep original paint on individual details, without whole-building projection.

Core geometry is 87,464 triangles / 95 surfaces: +19,920 triangles and fourteen
surfaces. One atlas material serves all new paint. The 314 masonry returns stay
11,280 triangles / two surfaces. Evidence in `Falan Exterior Fidelity/Slits and
Cornices/` includes source/before/after, all 22 variants, four angles, three gates,
edge measurements, hashes and checks. The earlier coping span retains 63/63 exact
samples. Plain-round IoU improves from 91.14% to 96.35%; the assembled overview
improves from 96.52% to 96.91%. Original clipped sprites, tiny raster art and
missing rear drawings still prevent a complete 1:1 claim.

Fourteen art tests and recovery of 22 source graphics pass. The 319-asset audit
has zero read errors and all three preservation groups pass. The verification
report records 22 passing rendered variants, zero physical topology failures,
7,697 desktop gate, 7,685 headless gate and 1,800 city checks. Selected final
logs have no script errors; existing shutdown diagnostics remain. No new Blender
master, app export, long-session soak or army benchmark was introduced. Previous
sections retain their historical measurements.

## Paired tower ribs and original covered openings — 2026-11-22

`forest_falan_fort_parts.gd::tower_braces` replaces rearward single braces with
the native paired rows on ten variants / 161 stations. `BRACE_SIDES` includes
both sides of 10658 and the missing 10660 row. The square and round exposed
curves have sixteen archive alpha controls; cap rows have their own native
registration. Reuse `Shapes.extrude`, `merlon` and `pier_loft`: two closed fins
and capped heads per row, with a closed ledge entering the shaft. Twelve
template rows yield 344 placed ribs/caps. The common tower crown frame remains.

The fixed camera-ray lean adjusts hidden depth while retaining projected source
controls and grounded feet. It is setup-only solid geometry. Its inferred depth
must be reconsidered if another original view becomes available. Keep mirrored
winding and inverse-transpose normals; do not crop a solid to every transparent
region of an overlapping source sprite or restore whole-picture building paint.

`recover_falan_forts.py::HOODS` records both original 10655/10656 hood outlines
and ornamental window profiles. `Data.HOODS` carries native coordinates and crop
rectangles. `round_hood` replaces the broad, low canopy and generic lancet with
closed curved geometry and a shaped metal backing, fitted independently of the
tower crown. Its small original drawing appears only on source-facing hood and
window surfaces; hidden faces retain the owned native blue/dark material colours.
The two new 124-by-232 PNGs use about 225 KiB RGBA together. All fourteen earlier
fort PNGs remain byte-identical. Three placed covered openings reuse the cache.

Core templates now total 67,544 triangles / 81 surfaces, down 4,276 triangles
with no added surfaces. The 314 returns remain 11,280 triangles / two surfaces.
Evidence is under `Falan Exterior Fidelity/Tower Details/` in the Asset Toolkit:
source/before/after, low/rear angles, all 22 variants, all three gates and logs.
Physical topology is closed and consistently wound across all 22 variants.
Source recovery verifies 22 graphics, twelve art tests pass, the 319-asset audit
has zero errors and all three preservation groups pass. Gate verification passes
7,697 desktop, 7,685 headless and 1,800 city checks; the prior coping span retains 63/63 exact
samples. The assembled mask IoU improves from 96.38% to 96.52%; isolated scores
remain mixed and are recorded without claiming complete 1:1 fidelity. No rear
source drawings, app export, soak or army benchmark were introduced. Earlier
sections retain their historical counts.

## Coping contours and closed rear returns — 2026-11-22

`forest_falan_fort_parts.gd::gallery_coping` reuses closed bevelled profiles for
the gate parapets and South projecting caps, including rear edges and undersides.
The South far end follows `v - 0.75u = -61.25`, u=175 and y=19.86. Its 0.04 m
inner mitre overlap retains the outside footprint. `south_corbel` extrudes six
native silhouette controls to 0.64 m depth. Structural returns are recessed
behind the visible coping cut to avoid coincident rear faces. Preserve the
header X/Z bounds, native stations and door/beam contracts.

`recover_falan_forts.py` now derives `city_fort_gate_paving.png` from the native
10662 quad `(26,59), (18,65), (42,83), (50,77)`. It is 128 by 64 pixels, 32 KiB
RGBA; all thirteen earlier fort PNGs remain byte-identical. Gallery top faces
use this crop with fixed native-phase UVs and 2.25-by-0.75 m tile directions.
Keep source details on appropriate faces rather than projecting a whole sprite
over the assembly. The authoritative source remains the procedural owner and
recovery script; no separate Blender master was added.

The shared `pier_loft` accepts matching polygon rings and collects on-plane
vertices when a cut removes part of a solid. This closes cuts through existing
corners without duplicating an already retained face. Verify edge closure as
well as signed volume, since missing faces through the origin may not change
volume. Full/half coping and polygon-ring tests cover this. Physical topology
checks weld by Euclidean distance across adjacent cells at 0.1 mm; simple rounded
cell IDs can split nearly identical points. All 22 physical variants now have
zero open edges, inward closed components or inconsistent winding.

Core templates total 71,820 triangles / 81 surfaces, +250 triangles with no new
surfaces. The 314 masonry returns remain 11,280 triangles / two surfaces.
Evidence in `Falan Exterior Fidelity/Coping and Rear/` includes all 22 variants,
source/before/after coping, rear views and all three connected gate approaches.
The 63 checked exposed coping edge positions match exactly; South silhouette
IoU improves from 88.11% to 90.02%, while the overview remains about 96.38%.
This does not establish whole-kit pixel equality or independently prove hidden
rear geometry: only one source isometric drawing exists per variant.

Fresh checks pass 22 rendered variants, 7,697 desktop gate assertions, 7,685
headless, 1,800 city, nine source-art tests and 22 source-recovery checks. Audit
reads 319 assets without errors; all three preservation groups pass. Existing
shutdown diagnostics remain, without script errors or assertion failures in
the selected runs. No app export, long-session soak or army benchmark was run.
The sections below preserve earlier checkpoints and their historical counts.

## Original window variants and South support proportions — 2026-11-22

`recover_falan_forts.py` now records each square-tower face in `WINDOW_KINDS`
and its native control quad in `WINDOW_QUADS`. It recovers fifteen original
window crops into `assets/maps/falan/city_fort_windows.png`, with two-pixel
edge gutters, and writes `Data.WINDOWS` alongside the existing fort data.
Preserve the original archive and earlier twelve fort images. Do not hand-edit
the derived atlas or substitute one tall window for every source variant.

`forest_falan_fort_parts.gd::square_windows` reuses the arch outline and a
rectangular shutter profile, creates closed stone backs, and fits their paint
to the native quads after the tower crown scale is established. The original
source shows nine tall arches and six short shutters. Opposite faces repeat
their corresponding source face; their hidden details are inferred. The
right-hand 10661 source window region is occupied by adjoining gatework and
does not receive an extra generic arch. Ordinary courtyard/reference towers
retain their original window path through the default `castle_tower` call.

The eight templates cover 139 placed towers and 272 source-facing windows.
Frames reuse the masonry surface; all source patches share one atlas material.
Core geometry is 71,570 triangles / 81 surfaces, a net addition of 38 triangles
and no surfaces. The 314 existing masonry returns remain 11,280 triangles /
two surfaces. The window atlas is 272 by 528 pixels, about 0.55 MiB RGBA.

`SOUTH_WINDOW_MIN_U` preserves the original jamb's u=45 outer edge and its
native bottom. Its clipped cross-section retains physical depth and original
window support. `SOUTH_RETURN_BOTTOM` fits the far return to y=13.1 without
changing its width or top landing. Source-mask intersection/union improves
from 84.32% to 88.11%; this remains an improvement rather than exact equality.

Current evidence is under `Falan Exterior Fidelity/Proportion Refinement/` in
the Asset Toolkit: source/before/after window sheets, low/rear views, South
support comparison, all three gate approaches, source hashes and checks.
Fresh verification passes 22 rendered variants, 7,697 desktop gate checks,
7,685 headless, 1,800 city and seven source-art tests. All physical fort bodies
have closed, consistently wound geometry; every window has immediate stone
backing. Audit reads 319 assets without errors; all preservation groups pass.
No app was exported or full-army/long-session performance result claimed.

## Raster mapping and closed hidden faces — 2026-11-22

The authoritative editable owner remains `forest_falan_fort_parts.gd`. The
tapered 10661 carved leaf uses a static 4-by-32 bilinear UV grid matching its
original rectified crop; the other parallelogram leaf retains two triangles.
Checked interior centroid error is now 0.019 native pixels instead of 2.444.
Source corners, native crown frames, door/station contracts and all twelve
original fort image files are unchanged. Do not replace these small original
details with whole-picture projection across the fort assembly.

South cloth fronts/backs share closed side edges on their existing materials.
Its small emblem has a closed back. `hood_frame` reuses the lancet outline as a
closed stone extrusion for 10655/10656, retaining the original front plane and
seating its sides inside the tapered shaft. The shared loft keeps tiny valid
rail-cut triangles. Prepared physical bodies have no open edges or inward
closed components; 32 remaining flat stone layers are backed at 512 samples.

Final evidence is in `Falan Exterior Fidelity/Raster and Rear Faces/` under the
Asset Toolkit: all 22 variants, all three gates, source/current and low/rear
views, close-up before/after leaf and cloth edges, source hashes and check logs.
Fresh checks pass 7,697 desktop gate assertions, 7,685 headless, 1,800 city and
five source-art tests, with no script errors. Core geometry is 71,532 triangles
/ 81 surfaces; the 314 returns retain 11,280 triangles / two surfaces. Audit
reads 319 assets without errors; all three preservation groups pass.

Original tiny art remains low resolution. Unseen faces have consistent solid
forms and native materials but no independent rear source drawing; do not
claim exact 1:1 from the silhouette scores or technical checks. Historical
sections below record earlier checkpoints. No additional Blender/GLB master,
replacement texture or app export was introduced by this pass.

## Cap heads, native iron pitch and outward gallery faces — 2026-11-22

`CROWN_PROFILE` keeps the broad stem width supported by native alpha scanlines,
with a bevelled light head and darker stone sides. The profile and vertex finish
are shared by the square towers, walls, piers and gate heads. Round towers reuse
the same rectangular head along their tangent; the circular rim remains curved.
The prepared surface merger retains these owned cap vertex colours. Source
sprites, atlas/mask, cloth, windows and carved-leaf crops remain unchanged.

The West/East gallery now has eight rear and five front heads, including its
clipped end teeth. Their native pitch is 15 by 11 pixels. The front parapet sits
inside the floor edge and its support follows the original bottom control.
`WEST_EAST_FRAME` preserves the measured stone station frame independently of
iron bounds. All thirteen head feet are checked against real supporting stone.
The South rear heads use their measured 15-by-11-pixel row as well.

Both iron fields reuse solid boxes and closed, leaning pyramid tips. Native
archive tips establish an eight-pixel pitch and two rail levels. South Gate also
has the longer pendants visible in the source. Cached fields contain 15 front /
10 rear pickets for 10646 and 9 front / 15 rear for 10662; cropped/hidden members
continue the field beneath the header. Dark iron and collar tones follow the
native palette. `IRON_PIXEL_EDGES` records the small, facing-specific raster
registration against filled terminal pixels; it is static geometry calibration,
not a view-dependent texture projection. Original detail paint remains on its
individual faces.

Axis swapping in `gallery_box` previously reversed the input rings. That made
some clipped stone and metal faces point inward. The rings now retain outward
winding, including clipped heads and iron tips. An analytic full/half-box volume
test covers the helper; the existing loft, window backing, cap-seat and pillar
join checks remain. Do not judge a clipped gallery on bounds alone.

Current captures, native/before/current comparisons and verification are under
`build/Other Files/Asset Toolkit/Falan Exterior Fidelity/Caps and Ironwork/`.
`measure_details.py` reports both complete part masks and explicitly selected
unoccluded foreground iron regions. Thin-pixel antialiasing, cropped art and
inferred hidden faces still prevent certifying every rendered pixel as 1:1.

The editable owner remains `scripts/forest/forest_falan_fort_parts.gd`; no
additional Blender/GLB master or replacement texture was introduced. Current
verification passes 22 variants, 7,697 desktop gate checks, 7,685 headless gate
checks, 1,800 city checks and five source-art tests. Audit reads 319 assets with
zero errors; all three preservation groups pass. Final core geometry is 70,940
triangles / 81 surfaces; masonry returns retain 11,280 triangles / two surfaces.
These counts are not a frame-time improvement or a fresh army stress result.

## Partial piers and South Gate return contours — 2026-11-22

Piers 10642/10645 now use inclined closed cut faces, recorded in
`PIER_PROFILES`, instead of constant vertical cuts. Their separate crown
setbacks, coping overhangs and tooth proportions live in `PIER_CROWNS`.
`pier_loft` retains a zero-slope default for its existing wall, gate, leaf and
masonry-return callers. The preview verifies the inclined solid against an
analytic volume, in addition to the earlier closed-loft checks.

South Gate 10646 has a short five-tooth rear row and three taller front heads
at the measured `SOUTH_CROWN_TOPS`. The central walk stays at 18.5; the two end
landings rise to 19.65 with closed risers, thin coping and support piers. The
far end has a full stone return below its landing. The near pier is wide and
offset enough to support the original window crop: source-pixel alignment now
also requires actual stone immediately behind every window corner. Original
cloth stays on fixed faces in front of the projecting pillars. Ironwork remains
solid, with separately fitted front/rear spans. Beam bounds merge the three
real floor sections, retaining the existing gate-seat/collision owner.
The projecting pillar bodies overlap the main parapet; a material-specific
inside-solid check verifies stone on both sides of each of the three joints.

Source-camera comparisons improve the two partial piers from about 87% to 92%
silhouette intersection/union, and the South Gate from about 72% to 81%.
These are measured improvements, not complete pixel equality. Some cap,
ironwork, occlusion and hidden-depth differences remain. Original source
sprites, atlas/mask, small paint crops, stations and saved-map contracts remain
unchanged. Current evidence is under
`build/Other Files/Asset Toolkit/Falan Exterior Fidelity/Native Contours/`.
The earlier `Contours` section/report is a historical checkpoint.

Verification passes all 22 variants, 7,697 desktop all-gate checks, 7,685
headless all-gate checks, 2,562 focused South Gate desktop checks and 1,800
city regression checks. Four source-art tests and all three preservation groups
pass; the 319-asset audit has zero read errors. The final internal pillar-back
extension is covered by the latest variant/joint preview; the travel runs cover
the same header bounds and visible front positions. Current core geometry is
72,412 triangles / 81 surfaces; the unchanged masonry returns add 11,280
triangles / two surfaces. No export or stress-performance result is claimed.

## Exterior source contours and stone connections — 2026-11-21

Tower calibration now uses the shared native crown frame. All eight square
sprites have the same `[-63, -260, 128]` crown x/top/width; all six round sprites
have `[-68, -283, 137]`. `test_falan_fort_art.py` verifies these against the archive.
Clipped lower portions and wider foundations therefore cannot stretch the
upper tower. The source fort owner retains these controls and fits flared,
set-back foundations separately. Square roofs have an exposed recessed deck,
closed coping frames and connected collars; raised crown blocks do not float
above the shaft. Courtyard/reference callers retain their earlier defaults.

Walls 10640/10641 have separate thin bank profiles, knee heights and four broad
blocks per parapet row. Their small feet, corbels and paved walks remain solid
geometry. `WALL_PROFILES` records the fitted dimensions. South Gate 10646 uses
measured native row positions and station depth rather than fitting its poles
and walkway together. Five rear and three front blocks, returning end walls,
projecting supports, hanging ironwork and the two pole tips remain separate
forms in the cached mesh. `GATE_QUADS` places only the original small cloth,
end-window and lantern/badge images on fixed faces, with checked outward winding
and source-pixel alignment; no view-dependent building projection is used.

The six wall slits now follow the measured native spacing, shorter height and
wider openings. Square-tower slits and lancets likewise use native proportions.
Carved leaves 10647/10661 have independent grounded thin solids: `LEAF_QUADS`
recovers their four original corners rather than stretching them with the tower
crown. The preview verifies the front artwork within 0.05 native pixels and the
closed body's signed volume. Reverse faces reuse the other original leaf crop;
their unseen artwork remains a reconstruction.

`recover_falan_forts.py` now also prepares `city_fort_base.png`,
`city_fort_gate_window.png` and `city_fort_gate_badge.png`. The base rectifies
native bricks and restrains palette-dither chroma. The other two preserve their
tiny original artwork. Original sprites, atlas RGB/alpha, anchors and station
records remain intact; the derived recovery manifest gains the feature quads.

The 314 source wall junctions use closed masonry returns cached by
`forest_falan_fortifications.gd::junctions`. Levels include both foundation and
wall-knee changes so contact continues over the whole height. Actual triangle
sections determine contact, including round towers; the wider foundation AABB
does not establish an upper-wall connection. The same rule now governs all six
gate seats. Returns share stone/brick materials and one cached two-surface mesh;
their 314 boxes join the existing physical and native collision owners. This is
setup work, with no new per-frame or per-enemy loop. Saved map records and gate
ownership remain unchanged. Historical collider comparisons rebuild their old
station list explicitly; current contacts and collisions are checked separately.

Use the desktop launcher with `falan_fort_preview.gd`,
`falan_gate_coverage_test.gd -- --east-il-road` and
`falan_city_proportions_test.gd -- --east-il-road`. The preview checks all 22
styles, native crown frames, solid roof joins, native face details and structural
contacts. It captures 132 colour part views, 22 silhouettes, seven full-resolution
assemblies and a complete 364-station overview. The overview uses a fixed
3840-by-2160 SubViewport; macOS window resizing must not change its camera scale.
Reports and native/current/difference images are in
`build/Other Files/Asset Toolkit/Falan Exterior Fidelity/Contours/`.
The final current-source checks pass: 22 variants, 7,697 desktop gate checks,
7,685 headless gate checks, 1,800 city regression checks and four source-art
tests. Catalog audit finds 319 assets / zero read errors; preservation passes
all three groups. Earlier `Fine Shapes/verification.json` is superseded by the
`Contours/verification.json` report; shared capture paths now show this pass.

The complete defense silhouette overlaps the source by 96.32% at overview
resolution (3.56 native pixels per rendered pixel). Crown and small-face controls
fit within 0.05 native pixels. These measurements show improved source contours;
they do not certify every outline pixel, hidden face or inferred masonry return
as original geometry. Native tiny heraldic art remains visibly low resolution.
The cached core has 72,272 triangles / 81 surfaces across 22 variants; returns
add 11,280 triangles / two surfaces. No frame-time gain or app export is claimed.

## Curved roofs, mouldings and carved bands — 2026-11-21

`forest_falan_houses.gd::source_roof_profile` now reuses the recovered 10077/10078
gable controls instead of the seven-point A-shaped approximation. Concave
gables use polygon triangulation; roof UVs follow accumulated curve length.
Raised cross-roof caps have closed rounded covers, timber undersides and stone
supports. The colored shops also have a two-window bay, raised rosette frames,
arched timber door surrounds, window reveals, cornices and alternating quoins.
These are parts of the existing cached meshes, with two material surfaces.

The facade material marks only structural stone faces in vertex alpha. The
`architecture_facade` shader branch adds joints to those faces while leaving
the original window, door, shield and medallion crops untouched. Rounded slate
shading is limited to `architecture_roof`; other materials retain their existing
shader path. Source images and saved placements remain authoritative.

The bank uses short rounded dormer hoods that join the main roof without the
former tilted wedges. Its blue roof rims are collected into one mesh per roof;
`forest_falan_building_shapes.gd` caches the raised window/portal mouldings and
turned gallery balusters. The native frieze repeats at its proper proportions
instead of stretching one short motif across the whole end wall. City carving
depths and the pale limestone derivative are prepared by
`tools/recover_falan_carvings.py`; the full original color atlas is unchanged.
Only the bank band requests one-pixel relief sampling. Existing furniture
callers keep their previous two-pixel sampling and limits.

Regenerate/check `city_proportion_fit.gd` after changing geometry; do not edit
its fitted values. Recalibrate the shield's prepared local position against its
existing source pixel station if the house fit changes. Run
`falan_ornate_fidelity_test.gd`, the 40-archetype surface review, the city
proportions tour and carving checks through Play Goemon. Evidence belongs in
`build/Other Files/Asset Toolkit/Falan Ornate Fidelity/`. Compare the original,
previous and new renders visually; dimension checks alone do not certify shape
or decorative fidelity. No app export is needed.

The final 2026-11-21 runs passed 66 focused fidelity checks, 7,339 surface
checks across 40 archetypes and four views each, 2,001 city/return-travel checks,
and 706 carving integration checks. Source reproduction and asset preservation
also passed. The city fixture now duplicates cached fortification bounds before
normalizing its comparison signature; it must not overwrite the live gate cache.
Existing fixture teardown resource warnings remain. These checks do not measure
frame cost or establish an exact visual match to every original ornament.

## Source details and restrained weathering — 2026-11-21

The first fidelity implementation raises the ordinary houses' cross-roof
supports out of the roof, moves the colored shops' round bays beyond the front
wall and replaces their pointed cones with the source's truncated curved hoods.
The bank's front caps now rise into its barrel roof; three smaller rear caps
restore the repeated roof detail. These are prepared meshes, not attached
per-frame scenery. Regenerate and check `city_proportion_fit.gd` with the existing
preparer after geometry changes; native doors and placement remain authoritative.

`tools/recover_falan_buildings.py` adds the original 10079 medallion and silver
shield to two previously unused atlas tiles. Its editable `FEATURE_MASKS` retain
the ornament rather than the surrounding roof pixels. All 45 prior tiles are
byte-identical and the atlas stays 512 × 1536. The medallion serves the compatible
colored gables; only the green armor-shop family gets the armor shield. Its
source-camera anchor is checked against original pixel (258,186). Originals,
the separate architecture atlas and saved records remain untouched. Never paint
over the generated atlas; change the recovery controls and repeat with `--check`.

Roof wear samples the recovered slate's luminance with restrained native colors.
Using its full dithered RGB at large scale produced blotches and was rejected.
The bank uses cached owned material copies with finer, low-contrast weathered
masonry; `weathered_masonry_strength` defaults to 1 for existing fort callers.
Benches retain their footprints, use slimmer supports and share a prepared wood
material. Their front/back facings now show the source's open seat correctly.
Double/triple-arm lamps use the source's round globes, staggered arms and tall
finials; the separate caged-lantern families retain their own shapes. Lamp bases
and stems share aged stone/metal materials. Planter geometry, native
paint, foliage and all source stations are preserved.

`falan_fidelity_test.gd` captures matched source, gameplay-height and reverse
views plus the street props through Play Goemon. Before/after renders and logs
belong in `build/Other Files/Asset Toolkit/Falan Fidelity Implementation/`.
Run `falan_surface_repair_test.gd` for all 40 archetypes and
`falan_city_proportions_test.gd -- --east-il-road` for the actual city, doors,
NPC clearance, travel, saved-edit guards and repeated mesh reuse. Technical
checks establish those contracts, not an exact visual recreation: ordinary
facades remain simpler than the original paint, and hidden depth is reconstructed.
No app export or frame-time claim is part of this change.

Fresh verification passes 46 focused render checks, 9,160 surface checks across
40 archetypes, 2,000 city integration checks and ten independent source tests.
The recovery reproduces with `--check`; toolkit preservation checks pass.
Godot fixture shutdown still reports the previously observed resource/RID warnings.

## Building surface repair — 2026-11-21

The current building path supersedes the whole-picture facade projection in the
earlier proportion pass below. A projected isometric building picture could
match the reference camera while painting windows, roof edges and stone across
unrelated 3D faces. It stretched badly at the gameplay camera and on rear faces.
Do not reapply that projection to complete houses or civic assemblies.

All 23 ordinary-house archetypes now reuse the complete matching family recipes
in `forest_falan_houses.gd`: curved roofs, ridge caps, dormers, projecting bays,
shop towers, chimneys, native window/door crops and timber. The archive graphic
still determines family, orientation, placement and source measurement target.
`forest_falan_architecture.gd` retains its existing mesh cache and MultiMeshes;
the 63 saved bindings and nine unmarked houses keep their source stations.
The old traced contour data, full pictures and original archives are preserved
as references rather than stretched over the runtime geometry.

`Houses.surface_mesh` separates the already-authored native facade UVs from roof
faces using their existing atlas patch IDs. Houses, six distinctive exteriors,
the workshop and magic shop share this setup-only recipe. Slate rows are shaded
in the existing painterly shader with blue, green, red, grey and purple native
palette colors, avoiding the old magnified/repeated roof samples. Body details
still use the original rectified atlas. Shared materials are never changed in
place. The old family builders remain available to other map owners.

The nine civic placements retain their individual stone, timber, window, sign,
carving and glazing materials. Their gable ends now use wall material separately
from sloping slate faces. The shared roof builder's optional gable material
preserves existing callers outside these civic assemblies. The coordinated
fortification repair also retires whole-picture projection on its 22 variants;
its shared projection helper remains available for compatibility.

Regenerate `city_proportion_fit.gd` with `falan_proportion_prepare.gd` after a
geometry change, then repeat with `--check`. Never edit its fitted values to
make a test pass. The reference rectangles still measure 2D source dimensions;
they do not establish exact original 3D contours or hidden depth.

`falan_surface_repair_test.gd` reviews all 40 building archetypes from four
sides, checks geometry/materials/cache reuse and writes its report and 160
captures under `build/Other Files/Asset Toolkit/Falan Surface Repair/After/`.
`falan_city_proportions_test.gd -- --east-il-road` exercises the actual city,
native doors/NPC clearance, edited-save guards, original room/gate returns and
cached reuse. Use Play Goemon for development; no app export is needed.

## Complete city views and all three connected exteriors — 2026-11-21

`forest_falan_frontier.gd::city_vista` now uses the complete saved city scenery
through the same `forest_wind_meadow_art.gd::trees` builder as the active city.
The former 300-metre district crop and generic building fallback are removed.
Every gate view includes all 72 source houses, eight distinctive exteriors,
nine civic buildings, all 226 planters, gardens, street furniture and 78 native
NPC stations. Meshes and original paint remain shared with the active city.
The cached view model supplies spatial data only: its wave, workforce and
economy controllers are cleared; the visited area keeps gameplay ownership.

The full city ground, water and interior bridges use the inverse gate frame.
Complementary shader masks replace the overlapping city strip without doubling
the current gate bridge or its railings. `map_frame` defaults to identity and
the adjoining-city crop defaults off in the shared Freyja surface include.
Other maps retain their original shader path. Gate exteriors stop before the
old random valley dressing/mountain ring and use their native ground palette;
original recovered ridge and tree placements remain under the exterior owner.
Keep established gate terrain/support arrays intact: clearing inherited cells
invalidates the existing saved gate footprints. Appearance is clipped using the
native masks, without changing saved map records or bridge support.

South now joins the same complete defense selection. Its quarter-turn is
applied to both visuals and native/physical bounds, and its inner gate is at
the original 36-metre wall line. It adds 344 city pieces and 337 wall bodies,
complementing its 18 existing outdoor pieces and two saved entrance beams.
Exact inner placeholder markers are now generated for south as well as west
and east. Raised/resized/rotated/moved user scenery remains user-owned.

`falan_gate_coverage_test.gd -- --east-il-road` checks all three exterior views,
complete city counts, exact wall transforms, native/physical collision parity,
open lanes, save loading/preservation, all three gate returns, the East–South
road and both onward Western/Southern Lakes connections. Use `--south-only`
for focused captures. The independent `test_falan_gate_archive.py` compares
fort stations, quarter-turn identities and exact legacy markers with the raw
client files; it also verifies every pixel of the complete 840 × 610 Freyja
ground index. Reports and rendered evidence are under
`build/Other Files/Asset Toolkit/Falan South Gate Recovery/`.
The final desktop run passed 5,051 checks and headless passed 5,039, with zero
failures; all 19 archive tests pass. The separate Il bridge test also passes
actual forward/backward player movement while preserving native army handles.

This establishes complete layout/scenery coverage and connected travel. It
does not recover unrecorded 3D surfaces from the original 2D art, or certify
every roof/tree silhouette as pixel-identical. Do not describe data fidelity as
proof of exact 3D geometry. No app export is part of this development change.

## Initial west and east exterior castle coverage — 2026-11-21

Both exterior maps now reuse the complete source-placed city defenses through
`forest_falan_frontier.gd::city_forts` and the existing
`forest_falan_fortifications.gd` builder. West adds 354 city pieces and east adds
348; each combines with its existing outdoor towers and two open gateway beams
to cover all 364 native city fortification stations. Geometry keeps its original
city coordinates under the inverse gate frame. The shared wall, coping,
buttress and tower pieces remain the authoritative sources; no new meshes,
textures, invented wall extensions or bridge copies are authored.

The same selected source bounds populate the existing exterior scenery plan:
347 extra wall bodies in west and 341 in east. The city fort builder creates
their physical shapes, so the outer scenery renderer skips duplicate bodies.
Saved gates retain ownership of both open entrances. Exact untouched inner
placeholder walls and towers now join the legacy marker list generated by
`tools/build_falan_approaches.py`; raised, moved, rotated and resized edits retain
their existing scenery ownership. Saved map records are not rewritten.

Run `Play Goemon.command --script
res://tests/forest-shrine/falan_gate_coverage_test.gd -- --east-il-road` for both
outside/front/flank/wide views, physical/native bounds checks, open center lanes,
saved-edit guards and two-way gate travel. Add `--headless` for the same logical
checks without captures. The current desktop run passed 2,520 checks; headless
passed 2,504. Before/after images and logs live in
`build/Other Files/Asset Toolkit/Falan Gate Coverage/`. This covers the exterior
defenses; the existing district view continues to own its background buildings
and terrain. No app export is part of this development change.

## Source fortifications and all three exteriors — 2026-11-21

`tools/recover_falan_forts.py` preserves all 22 native graphics (10640–10653,
10655–10662), their source hashes, footprints and native camera anchors in
`assets/maps/falan/city_fort_paint.*`. Its opaque paint derivative and separate
alpha mask preserve visible original RGB. `city_fort_masonry.png` rectifies a
native pale wall patch for exposed sides, mirrored into a seamless tile;
palette-dither chroma is removed while native mean hue and restrained luminance
remain. Originals remain untouched. `city_fort_window.png` and
`city_fort_banner.png` rectify the original 10652 lancet and 10646 heraldry.
The paired `city_fort_leaf*.png` retain the distinct 10647 front and 10661
reverse carvings on the corresponding solid leaf faces. Native 10657 rooftop
stone is rectified into `city_fort_paving.png`; only its palette-dither chroma
is neutralized, retaining the native tone and cobble relief.

`forest_falan_fort_parts.gd` reuses the existing round tower scene, courtyard
tower builder, extrusion helper and box collector. Sloped wall bodies,
open crowns, curved tower spurs, hanging ironwork and the South Gate's paired
finials/banner are cached as 22 solid meshes. Original stone/trim/quoin/iron
colors survive merging through correctly converted vertex colors. Rectified
windows and heraldry have their own surfaces and UVs. Explicitly normalize their vertex
formats when merging: `SurfaceTool.append_from` can drop preceding profile
geometry when later boxes introduce UVs. The native projected bounds calibrate
height/width/alignment; they do not certify every contour or hidden face.
Round variants 10655/56/58/59 retain their side braces; 10655/56 also retain the
blue ribbed window hoods. The broad front leaf on 10647 and narrow reverse leaf
on 10661 have separate source-facing proportions. Wall bases are separately
shaded solids, and the upper corbels remain geometry rather than painted bumps.

City and exterior owners share those meshes in spatial batches. Both native
navigation and physical collision use the same measured mesh bounds. Original
gate cells/rotations select their directional headers; moved/rotated custom
gates retain the existing complete arch. Both headers now have solid walkway
decks between separate parapets. The 10662 graphic ends at a cropped diagonal
join; its closed solids end on that plane inside the adjoining tower rather
than compressing the walkway into a thin beam. Since headers contain no ground
pixels, fitting retains their station depth and adjusts height along the native
camera ray. Gate coverage checks
those physical joins. Cached `gate_supports` adds solid stone seats/corbels where
the recovered beam ends otherwise miss the nearest source tower's solid coping.
They share the existing gate owner and material, overlap both pieces and have
matching physical collision above the walking lane. These unseen 3D junctions
are inferred, while the calibrated 22 core bounds and archived anchors remain
unchanged. South Gate's saved direction alias is
undone before applying its original city frame. Keep saved maps and anchors.

Run `recover_falan_forts.py --check`, `test_falan_fort_art.py`,
`falan_fort_preview.gd` and `falan_gate_coverage_test.gd -- --east-il-road`.
The preview checks all 22 bounds, actual camera projection and positive wall
volume, and captures native/reverse plus four low-angle views. Coverage checks complete city/fort
counts, physical/native bounds, clear gate lanes and two-way onward routes.
Evidence belongs in `build/Other Files/Asset Toolkit/Falan Exterior Fidelity/`.
Whole-building picture projection is absent from every fort surface. Masonry,
window and heraldic paint stays on the corresponding faces. Unseen construction
and small contour differences remain fitted; camera bounds do not prove 1:1 art.

### Exterior crowns, piers and fine shapes — 2026-11-21

Square crowns use the source's twelve broad bevelled blocks, rather than twenty
small cubes. Round crowns have ten solid curved teeth, a closed annular coping
and an exposed recessed deck. The original round scene still supplies the shaft;
the base courses form one fitted plinth instead of overlapping its old footing.
The existing source-derived paving belongs only on upward deck
faces. Warm lower courses, the shaft seam and upper rings remain geometry;
source-facing blue hoods, side braces and capped ledges remain distinct variants.
Square towers now use the native lancet's approximately 17-by-44-pixel face fit,
lower arrow slits and broader alternating red quoins. The optional source crown
argument keeps the earlier courtyard/reference tower callers unchanged.

Piers 10642–10645 no longer share a centred pyramid. `PIER_PROFILES` records four
offset shafts and taper/base profiles, including the two cut-back shapes. The
closed clipped loft helper also supplies the gallery's diagonal join. Reflected
parts reverse triangle order as well as transforming normals. Gate deck bounds
travel as mesh metadata: preparing a raw review mesh cannot corrupt cached gate
support coordinates. Wall feet, paved wall walks, hanging iron tips/collars and
the two adjacent native South Gate cloth strips are part of the same cached meshes.
Both strips belong on the front parapet; moving the blue strip to the opposite
side hides a visible original detail. Pole tips are small solid cross finials.

The preview additionally checks cap counts, closed clipped-box volumes, visible
recessed roofs, open gallery floors and all six gate joins. It records 132 colour
views plus 22 flat silhouettes. `Fine Shapes/` under the exterior fidelity
evidence folder contains native/current contour comparisons, contact sheets,
source-mask measurements and current verification. Those measurements expose
remaining contour differences; they are not a certificate of exact 3D recovery.
Some native graphics contain clipped/occluded portions and no rear views. Keep
those limits, and the original small heraldic resolution, explicit in reviews.

The final fine-shape gate runs pass 5,814 desktop and 5,802 headless checks with
zero failures; all 22 previews and three archive-art tests pass. The city
regression during this pass passed 1,799 checks. Final gate runs cover the later
small geometry/art refinements. The cached kit contains 72,040 triangles and 60
surfaces across all variants; this is a geometry count, not a frame-time result.
All thirteen previously recorded original fort asset files remain byte-identical.
`Fine Shapes/verification.json` records current hashes, logs, measurements,
reviewed views and remaining fidelity limits. No app export was requested.

## Measured source proportions and facade paint — 2026-11-21

The current source-proportion pass covers 40 archetypes / 89 city buildings:
72 ordinary houses, eight distinctive exteriors and nine civic placements.
`tools/recover_falan_proportions.py` owns the reference rectangles and original
paint. It assembles the cathedral, arena and mansion from their original tall
objects **and** ground-layer facade pieces; measuring only their upper sprites
would give the wrong height. The raw archive remains untouched.
The mansion excludes its flat green ground apron from building measurements.
Its three disconnected source silhouettes independently calibrate the main
rotunda and both pavilions, including their native relative placements. The full
unaltered compound picture remains in the review folder as
`native-civic_1301-with-ground.png`.

`forest_falan_proportions.gd` uses the source isometric frame: horizontal 32/3,
floor-depth 8 and vertical sqrt(2*((32/3)^2-8^2)) pixels per world unit. The review
camera uses one original pixel per rendered pixel. The authoring fixture
`falan_proportion_prepare.gd` measures actual mesh vertices and CPU-authored box
corners, including the arena's existing elliptical root scale. It prepares
`city_proportion_fit.gd` with a separate horizontal/vertical fit and alignment
for each archetype. Those fits are applied once to cached meshes or static civic
children. The old .045 value remains the raw authoring/UV convention; it no longer
determines the final visible building height.

The geometry checks compare the final projected left/top/width/height with the
original opaque reference rectangle within .05 source pixels. The rendered
fixture separately checks the real camera projection within .1 pixels. These
are measurements of overall source-view dimensions and alignment, not proof
that every silhouette edge, roof profile or hidden 3D surface is identical.
Keep that distinction when reporting fidelity.

Source-facing surfaces carry original facade, slate, window, sign and carving
paint in that same fixed source frame. Separate source alpha masks prevent
transparent margins from becoming stretched stripes. The mansion's flat green
source ground pixels are masked out of facade paint. Opaque native-colored
fallbacks keep the geometry solid; houses retain their existing prepared UVs on
unseen walls and roof slopes. Other maps keep the shader's original path because
the new source projection is disabled by default. Source paint materials are
shared within a building and house meshes remain cached/batched.
Rear-facing house roof slopes always use their prepared slate UVs; an upward
normal alone must not project the occluded front facade onto the reverse roof.

Civic collision now follows the corrected dimensions under the existing
scenery/nav owner. Source-coordinate entrance lanes split the affected body
bounds so the arena, mansion, inn and employment-office doorways remain clear.
The original doors/NPCs, all 226 planter stations and all saved records remain
under their existing owners. No new gameplay loop or save migration is added.
The historical collider fixtures normalize intentional source-building changes
before comparing the original unchanged baseline hashes; do not rewrite them.

```sh
python3 tools/recover_falan_proportions.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/falan_proportion_prepare.gd
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/falan_proportion_prepare.gd -- --check
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/falan_proportion_preview.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/falan_city_proportions_test.gd -- --east-il-road
python3 tools/recover_falan_proportions.py --check
python3 -m unittest discover -s tests/forest-shrine -p test_falan_proportions.py
```

Review original/native-camera/reverse comparisons, live city captures, source
hashes, measurement tables and route logs under
`build/Other Files/Asset Toolkit/Falan Proportions/`. Unseen depth and some relief
remain reconstructions from 2D art. No app export is needed for this iteration.

## Source-contour main-city architecture — 2026-11-21

The ordinary house families now use `scripts/forest/forest_falan_architecture.gd`.
It replaces the fitted family geometry at 63 unchanged saved markers and restores
nine original map-1000 houses that had no saved marker: 72 buildings from 23 native
graphics. `city_architecture.json` records every native graphic, paint hash,
foundation control, roof profile, marker binding and unmarked source station.
The earlier fitted studies below remain available for western-map callers and
historical comparisons. Civic and distinctive exteriors retain their own owners.

`tools/recover_falan_architecture.py` owns the editable source controls. It traces
opaque foundations and the main roof boundary; reviewed native-pixel controls
handle porches, ivy and chimneys that obscure a gable. Source floor projection is
32/24 pixels per 3-metre tile. The initial pass kept a .045 authoring fit. Its house-only metric-height trial
was reverted because the civic buildings had not been calibrated alongside it.
The measured pass above supersedes that temporary visible-height fit for all
89 buildings; .045 remains only the raw authoring/UV convention.
Models turn +90 degrees
into world space so the native picture's two visible faces keep their orientation.

The full RGBA atlas `city_architecture.png` is byte-preserved. The separate
`city_architecture_solid.png` extends only transparent edge colors for closed,
opaque walls and gable ends; visible native RGB remains intact. Roof slate uses
new large native blue/green/red samples appended to the existing shared
`city_building_surfaces` recipe. Closed curved roofs, rolled cross-ridge caps,
cream supports, hoods, capped chimneys, the long houses’ attached stacks,
projecting bays and shop turrets reuse
the existing source-mesh, extruder, hood and lathe builders. Each graphic has
one cached mesh and two shared material surfaces; repeated houses use MultiMeshes.

The native map footprints remain the ground collision authority. The existing
scenery/nav owner applies those footprints plus projecting bays; source artwork's
plinth/shadow pixels do not expand a whole building's collision. The nine unmarked
houses use that same archive obstacle owner. Original room doors and all NPCs
stay at their native coordinates. Generic fallback entrances use the recovered
body bounds and avoid planter rows. Exact legacy signatures guard replacements;
removed, raised, rotated or scaled saved houses keep their user ownership. No
save-file migration or new per-frame owner is introduced.

Regenerate and review through the existing launcher:

```sh
python3 tools/recover_falan_buildings.py
python3 tools/recover_falan_architecture.py
python3 tools/recover_falan_architecture.py --check
python3 -m unittest discover -s tests/forest-shrine -p test_falan_architecture.py
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/falan_architecture_preview.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/falan_architecture_test.gd -- --east-il-road
```

Matched originals, front/rear renders, city captures, collision checks and mesh
counts live under `build/Other Files/Asset Toolkit/Falan Architecture/`. Review
appearance separately from the technical results. Original reference art is 2D:
unseen faces, physical depth, some relief and generic fallback door placement
remain reconstructions, not recovered original 3D data or proof of a pixel-identical
city from every camera. Preserve the source atlas, previous editable masters and
user saves. Do not export an app for this scenery iteration.

## Main-city street details — 2026-11-21

`scripts/forest/forest_falan_street_details.gd` is the authoritative procedural
master for native 10413/10415/10416 noticeboards, 11496/11497 oval shop signs,
10419's pale bollard, 10417's iron panel, and four brick planter families
10426/10427/10452/10453. The source city has no 10417 placement; retain its
reusable mesh without adding a station. `forest_falan_market_goods.gd` selects
these source props at existing native anchors. The generic `signpost` helper
remains available for labeled countryside and village signs.

Solid sign frames reuse the lamp primitives and the existing solid-profile
extruder. Oval outlines trace the recovered face alpha; both faces carry
rectified original lettering. Planters have staggered solid brick courses and
recessed joints. Their footprints and high/low profiles follow the original
opaque masonry contour, excluding the native checkerboard ground shadow.
`city_planter_art.png` preserves all four original graphics byte for byte;
`city_planter_leaves.png` retains their native green/cyan RGB pixels with a
prepared foliage mask. Existing `leafy_shrub` geometry is fitted along each
native bed's long axis and repainted from those original pixels. Tall/short
masonry profiles are 1.17/.63 units under the existing .045 source art scale;
depth and unseen surfaces remain fitted interpretations.
Repeated beds share their four cached meshes through the existing 48-unit
spatial MultiMesh pattern; they do not add a mesh node for every brick or bed.
The noticeboard scrolls, unseen backs and depth remain interpretations.
All 226 native bed stations now render. Nine exact unchanged house markers use
their archived centers through `forest_falan_houses.gd`; physical bounds and
rendered transforms share the same guarded offset. `recover_falan_buildings.py`
generates those centers from the existing source bindings. Moved/scaled/rotated,
raised or removed user houses retain normal editor behavior. Four generic
residence entrances are kept clear of the native bed rows; native authored
doorways and NPC stations retain their original coordinates. Saved records
and existing navigation/interaction owners are preserved.

Regenerate the six atlas patches and source-image provenance with
`python3 tools/recover_falan_street_details.py`; append `--check` to verify
reproduction. Output is `assets/maps/falan/city_street_surfaces.*`. Original
graphics stay intact in the adjacent Magic Power library; review copies,
source/3D captures, procedural counts and logs are under
`build/Other Files/Asset Toolkit/Falan City Details/`. Run
`Play Goemon.command --script res://tests/forest-shrine/falan_street_details_test.gd -- --east-il-road`
for the rendered city review, source placements, cached-mesh reuse and original
three-gate round trips. The same fixture accepts `--headless`; it does not
replace the rendered appearance review or measure large-army performance.
For the complete 51-bed recovery, use `falan_planter_recovery_test.gd` with the
same launcher and `-- --east-il-road`. It checks all 226 unique GPU stations,
nine source-centered house transforms, four preserved generic room round trips,
all three city gate returns, native-painted foliage volume and mesh cache reuse.
`falan_planter_placement_test.gd` checks placement and edit guards without a
rendered tour. `falan_planter_preview.gd` provides quick front/back art review.

These are the editable metre-scale Blender masters for the new Falan assets.
The houses use steep slate roofs, dormers, pale walls, timber trim and arched
doors based on the recovered Falan exterior. The shop adds a striped awning.
The chapel uses a taller roof and belfry. The royal keep uses four blue-capped
turrets and a raised central hall. All four meshes use a single painted
vertex-color material. The Falan test shares Goemon's existing masonry walls,
round gate towers, foliage, scenery batching, and painterly material.
Window surrounds, gable timber, stone quoins, belfry courses, and keep banners
were added within the original scenery bounds. The keep also has a raised
entrance, layered balconies, and additional slate turrets. Map 1500's
source keep and annexes are assembled in
`scripts/forest/forest_falan_keep_exterior.gd` using the civic spire and
lancet meshes. The exterior stair and courtyard wall kit are in
`scripts/forest/forest_falan_courtyard.gd`. The Blender keep remains a
reusable editor asset.

City gardens reuse the Wind Meadow broadleaf, cedar and shrub masters in the
parent directory. The hedge borders, iron fence profiles and park statues
are authored directly in `forest_falan_gardens.gd` and
`forest_falan_garden_statues.gd` under `scripts/forest/`.

The first Freyja roads reuse these foliage and cliff meshes at recovered
placements. Their original grass, dirt, paving and river paint comes from
`assets/maps/falan/freyja_ground_atlas.png` and its tile index. Rebuild them
with `tools/build_freyja_surface.py`. The shared
`scripts/forest/freyja_surface.gdshaderinc` converts the 3D ground and water
back into the same source coordinates, including at the East/South seam.
Riverbank rocks use `forest_freyja_destination_art.gd`'s shared ridge mesh
and start at the waterline. Preserve the source map and the shared materials.

The 海洞–熊洞 corridor's finer crags reuse that same ridge geometry in
`crag_cluster` / `cave_crags`; their editable source is procedural, with no new
Blender master or replacement GLB. Native 12543 stone/moss paint crops and
rebuild instructions live in `assets/maps/falan/venoa_scenery/README.md`.
The road reuses these Wind Meadow tree variants at the recovered source anchors;
visual species choices preserve the existing native obstacle plan.

The market reuses the shop and townhouse masters below. The fitted portals,
trade plaques, turret trims and market fixtures are authored directly in
`forest_falan_shopfronts.gd` and `forest_falan_market_goods.gd`.

The city's cathedral and matching hospital exteriors are assembled from
Goemon's shared stone materials and code-authored roof, window and tower
pieces in `scripts/forest/forest_falan_civic_exterior.gd`. Their interior
fittings are editable in `scripts/forest/forest_falan_civic_rooms.gd`.

The arena's arcades, raised platforms, railings and furniture are assembled
in `scripts/forest/forest_falan_arena_art.gd`. The original colored floor
inlays are rebuilt with `tools/build_falan_room_art.py`.

The employment office uses the same civic roof and entrance pieces. Its
round porch is editable in `scripts/forest/forest_falan_civic_exterior.gd`,
and the stair and room fittings are in `scripts/forest/forest_falan_employment_art.gd`.

The guild uses the shared civic slate roof and portal. Its reception
counter and office fittings are editable in
`scripts/forest/forest_falan_guild_art.gd`.

The inn uses the same civic roof and stone pieces for its turreted bar
facade. Its counter modules and room furnishings are editable in
`scripts/forest/forest_falan_inn_art.gd`.

The bank facade is assembled in `scripts/forest/forest_falan_civic_exterior.gd`.
Its teller fittings, grilles and vault are editable in
`scripts/forest/forest_falan_bank_art.gd`.

The mansion reuses the civic stone and slate palette. Its ribbed rotunda,
smaller garden pavilions, recital piano, settees and study desks are
editable in `scripts/forest/forest_falan_mansion_art.gd`.

| Editable master | Runtime export |
|---|---|
| `falan_townhouse.blend` | `assets/models/environments/wind_meadow/falan/falan_townhouse.glb` |
| `falan_shop.blend` | `assets/models/environments/wind_meadow/falan/falan_shop.glb` |
| `falan_chapel.blend` | `assets/models/environments/wind_meadow/falan/falan_chapel.glb` |
| `falan_royal_keep.blend` | `assets/models/environments/wind_meadow/falan/falan_royal_keep.glb` |

Preserve the ground-centred origins and front along Blender −Y. Re-export a
saved master with `Blender --background PATH.blend --python tools/export_blender.py`.
Use the map scenery bounds in `forest_scenery.gd` for fitted collision. Run
the asset audit and preservation check, refresh imports, and inspect the
Falan saved maps through Play Goemon.


The Kili/Venoa coastal village pass reuses the shared palm at
`assets/models/environments/palm.glb` and Wind Meadow foliage.
Source footprints, wall IDs and ground atlases are recovered by
`tools/build_undersea_details.py` into `assets/maps/falan/coastal_village_data.gd`
and the `kili_` / `venoa_ground_` textures. Open columns and walls are editable in
`scripts/forest/forest_kili_art.gd`. Each original building now uses its own
silhouette and recovered facade paint, authored in `forest_coastal_buildings.gd`
with the shared projection helper `forest_coastal_mesh.gd`. Venoa's long shop
is one mesh with both original room links. The source footprint owns collision.

`tools/build_coastal_villages.py '../Magic Power'` recovers 14 building graphics,
complete room object placements and the floor atlas (including 48-pixel tiles).
Its generated files are `assets/maps/falan/coastal_building_art.*`,
`coastal_room_props.*` and `coastal_room_floors.png`; edit the exporter or the
procedural masters, not generated data. `forest_coastal_rooms.gd` assembles
missing fixtures with existing furniture, materials and static box batches.
Repeated painted walls/counters share cached meshes and MultiMeshes by source
graphic. The original Blender/GLB assets and shared materials remain unchanged.

Room layouts, objects, NPCs and link tiles come from the archive. Kili residences
3801/2/3/7 now use the original server maps in
`assets/references/crossgate_kili_houses/`; its README records provenance and
regeneration. Their new small furnishings extend `forest_coastal_rooms.gd` using
shared primitives and materials. Unseen building faces mirror the source paint;
3D depth and roof heights are interpretations of the original 2D silhouettes.
Il/Alyut's procedural masters in the same building renderer cover the round
thatched houses (11268/11269), round shop and side wings (11271), dormer houses
(11272/11273), canopy shop (11275) and blue-terrace church (10607). Reuse their
source-painted walls, roofs, round tiers and parapet helpers for compatible
variations. Il/Alyut now use rectified material/feature patches generated by
`tools/build_village_building_surfaces.py`, with source crop coordinates recorded
there and in `assets/maps/falan/village_building_surfaces.json`. Reuse these
patches through the mesh builder's tiled UVs and aspect-preserving detail panels.
Do not restore whole-sprite projection for these buildings. Prepared fitting and
UVs are cached by graphic and fit; the existing scenery bounds still own collision.
Source grass and small countryside placements are documented
in `assets/maps/falan/README.md`. Do not edit the generated atlases by hand.
Il/Alyut's existing scenery plans now also build directly in their surrounding
road world. Reuse `forest_freyja_regions.gd::village_transform` when placing local
village geometry: Il rotates into the East Gate frame and Alyut translates into
North Coast. Keep the source village coordinates and fitted collision bounds;
the shared terrain/native owner supplies the outdoor floor. The village query
context builds scenery only, with no wave controller or second army runtime.
Rendered checks: `freyja_villages_habaru_test.gd -- --coastal-kili` and
`--coastal-venoa` through Play Goemon. Captures and logs are in
`build/Other Files/BlueCG Map Study/Coastal Village Rooms/`.


The travel diamonds and shrine surrounds now use the solid shared
[travel-stone kit](../travel_stones/START_HERE.md). Reuse its named Crescent,
Post, Lectern and Crystal meshes for compatible recovered shrine ornaments.
Preserve original city anchors and cardinal orientation; do not replace these
parts with flat source sprites or the older simplified cellar furniture.

## Falan city cleanup — 2026-11-16

Falan no longer adds Wind Meadow's valley cliff rim, baked apron, random
ambient dressing or distant mountain ring. The reusable masters remain intact.
City source terrain and all three gate crossings are owned by
`forest_freyja_terrain.gd`; source street/garden scenery and saved edits still
use their existing owners. Exact retired tree markers are ignored by map
validation just as they are by the source garden loader; modified markers are
still validated normally.

The pond's six lily tiles (3880) and three plain-water tiles (5002) now reuse
the original pixels in `assets/maps/falan/city_pond_atlas.png`, replacing the
invented bank rocks, rushes and geometric lily pads. Rebuild with
`tools/build_falan_city_streets.py` (or its `pond_art` helper for this atlas
alone). Anchors are `Data.LILY_TILES` and `POND_WATER` in the existing garden
owner. The shared room-art projection/material is reused; collision and water
walking support remain with the existing terrain/water owners.

## Source-shaped solid trees — 2026-11-16

The city gardens and 海洞–熊洞 countryside now use the evergreen, woodland and
pale-leaf solid variants in `../crossgate_flora/START_HERE.md`. These reuse the
existing broadleaf trunk and all leaf quads, with native paint and sampled
original crown profiles. Keep the original meadow masters available for saved
scenery and other maps. The southern road no longer adds the generic distant
mountain ring, random grass/rock/shrub dressing or invented cliff-ledge shrubs.
Source cliffs, shoreline paint, flowers, houses and native obstacles remain
under their existing owners; small props and architecture still need further
individual source matching.

## Native city house families and street lamps — 2026-11-16

The remaining generic house appearances are now replaced at 57 unchanged saved
markers by two source-referenced solid roof families. Their editable geometry
is `scripts/forest/forest_falan_houses.gd`, reusing `forest_coastal_mesh.gd` and
the village facade-panel helper. Curved roofs, arched dormer hoods, pale ridge
cresting and timber gables use original city surface paint. The cached house
meshes retain the old saved bounds, rotations, scales and collider ownership.
Only exact known marker signatures match; moved, rotated, scaled or raised
user edits keep their existing asset appearance. The nine existing civic
exteriors and unmatched distinctive buildings are not replaced by a generic
roof family. The original Blender masters and GLBs remain reusable.

Recover `assets/maps/falan/city_building_surfaces.*` with
`python3 tools/recover_falan_buildings.py`; add `--check` for a read-only recipe
and binding comparison. It calls the shared `surface_atlas` preparation in
`build_village_building_surfaces.py`; that helper still reproduces the earlier
Il/Alyut images byte for byte. The source crops are rectified/resampled and
neutral wall/trim/stone crops use the existing smoothing recipe. Source-image
hashes, crop quads and nearby source references are in the generated JSON.
Nearby references and the fitted footprints are not claims of exact original
identity or dimensions for every saved house.

`forest_falan_lamps.gd` authors the seven solid pole/lantern/column styles from
10422/10423/10424/10428/10429/10611/10612. The city uses 113 existing source
stations after its usual NPC/door clearance filtering. Curved arms, hanging
lantern cages, the hooked lamp and stepped column bases replace the box-lamp
placeholder. The two column figures reuse the garden statue meshes. Shared
unit cylinders, spheres and boxes feed cached meshes and local MultiMeshes;
the existing gate bridges reuse the same owner. Do not add per-lamp scenes,
lights, runtime asset loading or separate navigation owners.

Run `falan_buildings_props_test.gd -- --east-il-road` through Play Goemon after
changes. It compares colliders, checks roof winding/bounds, all seven lamp
styles, actual source stations, saved-edit guards and mesh reuse on gate
returns. GPU instance transforms require desktop rendering; headless only
checks mesh geometry and instance counts. Source/model studies and matched
city images belong in `build/Other Files/Asset Toolkit/Falan Buildings and Props/`.

## Landmark facade paint and solid benches — 2026-11-16

The employment office (1091 / source 10607), guild (1092 / 10604), inn
(1101 / 10004), both hospitals (1111–1112 / 10602) and bank (1121 / 10010)
now reuse their original leaded window paint, native service signs, office
rosettes and healer engraving. The existing solid building bodies, frames,
porches and roof profiles remain the geometry masters in
`scripts/forest/forest_falan_civic_exterior.gd`. Native surface panels and
materials are shared by `forest_falan_landmark_details.gd`. Window frames sit
in front of the projecting stone courses so those courses cannot cut the paint.
The guild banner has a solid mounting bracket and frame. These fitted surfaces
are further recovery work, not a claim of exact original geometry or placement.
Cathedral, mansion and arena details still need their split source sprites
composed before closer individual matching.

Run `python3 tools/recover_falan_landmarks.py` to rebuild
`assets/maps/falan/city_landmark_details.*`; `--check` reproduces the paint and
source bindings without writing. It uses the existing rectification recipe.
The office window/rosette reference the existing village atlas, with no copied
bitmaps. Source-image hashes, crop quads and shared feature references are in
the JSON. The healer feature masks the source stone background while retaining
its original dark engraving, allowing the existing 3D wall to show through.
Never paint over the original archive or shared village atlas.

`forest_falan_benches.gd` is the editable solid bench master. It reuses the lamp
owner's unit boxes, cylinders and spheres for slatted seats, vertical spindles,
turned posts, finials and curved arms. Two cached meshes serve the eight source
facing families (10405–10408 / 10448–10451) in spatial MultiMeshes. The city's
70 filtered stations retain the same positions, width families and clearance
checks; the reverse source families now face the opposite direction. Other
courtyard/frontier uses of the old generic bench helper remain available.
There are no per-frame mesh/material allocations or added collision owners.

Use `falan_landmarks_test.gd -- --east-il-road` through Play Goemon for the six
landmarks, solid bench study and matched city views. It checks every GPU bench
station/facing, bounds, shared materials, collider signatures, custom civic
marker guards, all six door apertures and the three city gate returns. Headless
cannot read back MultiMesh transforms; it checks counts/geometry instead.
Evidence belongs in `build/Other Files/Asset Toolkit/Falan Landmarks/`. The first
review exposed cropped sign lettering and the healer's rectangular pale
background; both were corrected and the final rendered views inspected.

## Curved landmark shapes and fluted urns — 2026-11-16

The bank (10010), employment office (10607) and inn (10004) now use explicit
rounded roof profiles in `forest_falan_building_shapes.gd`. The civic roof
helper accepts a final optional profile; its default and existing arena/keep
callers retain their previous shapes. The office's two roof dormers are small
blue arched hoods with the recovered office panes, replacing the pointed caps.
The bank's three forward roof caps use the rounded profile as well.

`forest_falan_building_shapes.gd` is the editable code master for the bank's
solid end-wall crowns, scroll coping, capped crest posts and recessed gallery
with colonettes and four circular window frames. Both ends reuse four cached
meshes. The end-wall polygon is extruded and triangulated as a closed solid;
the existing lamp owner's primitive meshes form its raised moulding and gallery.
These are fitted interpretations from the original sprite, not recovered 3D
models or exact original dimensions. The source remains in the archive, and
the earlier procedural building bodies and reusable Blender assets are preserved.

The same master supplies the city's fluted flower urn (source 10403/10404).
Its turned foot, tapered bowl, hollow lip and twelve flutes replace the two
plain cylinders at all 36 existing filtered stations. Flower colors, flower
poses, station filtering, old pot height/width and ground ownership are unchanged.
All urns share one 1,440-triangle mesh. Roof, crown and urn preparation happens
only during scenery setup; there is no new frame processing or collision owner.

Run `falan_building_shapes_test.gd -- --east-il-road` through Play Goemon. The
fixture inherits landmark, bench, entrance, saved-edit and gate checks, then
checks outward roof/urn normals, closed crown volume, gallery bounds, exact
urn stations and cache reuse on city returns. Its matched captures include the
bank's end, all six civic facades and an isolated urn study. The first visual
review found oversized pale office dormers and gallery columns blending into
the wall; smaller blue hoods and a recessed gallery background corrected those.
Final evidence is in `build/Other Files/Asset Toolkit/Falan Building Shapes/`.
Carved masks, ornate friezes and some other civic shapes remain to recover.

## Carved facades and mansion finishing — 2026-11-17

`tools/recover_falan_carvings.py` recovers the office masks (10607), guild reliefs
(10604), bank scroll frieze (10010) and the mansion's frieze, portico carving and
glazing. The mansion reference composes the actual map-1000 ground tiles with
its split 10600 roof sprite in original draw order. The generated JSON records
the viewport, crop quads and hashes of every contributing source graphic.
`city_carvings.png` preserves the rectified original color crops;
`city_carvings_stone.png` is a separate limestone finish using the recovered
pale-stroke mask, and `city_carvings_depth.png` bounds shallow relief. Rebuild
with `python3 tools/recover_falan_carvings.py`; `--check` reproduces all three
textures, metadata and bindings without writing. Original archives and previous
atlases are preserved.

The shared `shallow_depth` helper in `prepare_arena_carvings.py` now accepts
rectangular stone panels. The original arena recipe still reproduces its old
carving-depth PNG byte for byte. Depth follows pale source strokes with sealed
edges, then `forest_falan_carvings.gd` prepares a cached raised mesh per feature.
This is shallow interpretation of the source shading, not recovered original
3D sculpture. The stone finish discards the photographic background so the
relief integrates with the solid wall. Native-color mansion glazing stays flat.
Two owned shared materials isolate those finishes from all existing scenery.

The selected exteriors use 25 raised panels: two office masks, two guild reliefs,
two bank friezes, seventeen mansion friezes and two mansion portico reliefs.
The mansion's three rotundas reuse 37 original glazing panels. Its main dome
now has a solid domed ribbed lantern, thirteen scalloped red valances replace the
rectangular banners, and the small pavilion roofs lose the generic gold balls.
The existing lamp primitives and the existing solid-profile extrusion supply
the lantern and cloth geometry. These editable masters remain code-native;
no new Blender export, simulation or collision owner is introduced. Preserve
existing saved marker signatures, body transforms, portals and ground support.

Use `falan_carvings_test.gd -- --east-il-road` through Play Goemon. It inherits
the building/bench/urn/save/gate tests, then checks relief bounds, outward
normals, source UVs, feature counts, material/mesh reuse and mansion clearance.
Matched views, source composites and close mask/lantern captures belong in
`build/Other Files/Asset Toolkit/Falan Carvings/`. Review appearance separately:
the first pass looked like bright rectangular plaques, so the original crops
were preserved and the masked stone finish added. Full original-depth sculpture,
more civic silhouettes and some facade proportions remain incomplete.

## First interior furniture recovery — 2026-11-17

`forest_falan_interior_furniture.gd` is the editable solid master for the inn's
17012/17013 bottle cabinets, the hospitals' 17541 medicine hutches and
17537/17538 beds, and the bank's 17533 padded waiting seats. It reuses the existing
lamp primitives and solid-surface helper. Cabinet lower cupboards/drawers,
two display shelves, shaped green bottles and pale labels replace the generic
book-like box rows. The medicine hutch has book shelves, a jar and a supply bag
instead of the same generic bottle-shelf treatment. Beds retain their source
head directions and gain soft pillows, a folded foot sheet and a waved blanket
surface. Waiting-seat cushions have rounded ends over the existing wood base.

The first pass is scoped to inn 1101, hospitals 1111/1112 and bank 1121.
`forest_falan_room_art.gd` delegates only those known fixture serials after
retaining their blocked cells; other rooms and furniture keep their existing
owners. The bank detail owner reuses the padded-seat master and retains its
original independent physics slab. Source fixture stations, counter layouts,
room art, NPCs, walls and entrances are unchanged. Assemblies are cached by
family/dimensions/head direction; repeated furniture and room returns reuse
meshes. There is no new frame processing, asset loading during play, collision
owner or army logic. Existing materials remain shared through their owners.

Original sprites and full room studies, source hashes, matched room/bed views
and close cabinet captures are under `build/Other Files/Asset Toolkit/Falan Interiors/`.
The silhouettes and folds are fitted 3D interpretations of those sprites,
not recovered original meshes. The source archive and reusable old assets are
preserved. Keep bottle cabinets facing into the room: the swapped orientation
uses -90 degrees, while beds retain the existing +90-degree convention.

Run `falan_interiors_test.gd -- --east-il-road` through Play Goemon. It walks
through all four original doors and returns to Falan, compares actual static
collision shape bounds/transforms plus the original floor walk bits, checks
source stations/footprints, upward cloth normals and cache reuse, and preserves
the saved adventure. Whole-room and bed cameras are matched; the original inn
cabinet close-up was partly obscured by a foreground wall, so the final cabinet
camera faces directly into its shelves. More interior art and furniture still
need individual recovery.

`tools/recover_falan_interior_details.py` recovers the original 10436/10495
arched clock faces and 17607 notice writing into `assets/maps/falan/interior_details.*`.
Run it with `--check` to verify the atlas and crop provenance. The shared unit
quad and three cached materials sit on the existing solid clock cases and
notice frame. Clock 10436 faces +X into the inn, clear of its adjacent cabinet;
10495 retains its bank-facing direction. The tiny original faces remain visibly
low resolution in close-ups, and the fitted case proportions need further work.
The final desktop fixture passed 183 checks; headless passed 170. These results
cover this furniture pass, not a general gameplay or performance benchmark.

## Employment office and guild interiors — 2026-11-17

The same `forest_falan_interior_furniture.gd` master now handles selected
original furniture in office 1091 and guild 1092: bookcases 17573/17587,
desks 17539/17572 and chairs 17027/17028. The wide case has two bays and five
book rows; the narrow case has five rows, contrasting spines and small bands.
The secretary desk has a lower book shelf, paper stack, stacked volumes and
quill; the broad writing desk has rounded corners, open lower compartments,
two ledgers and an ink/quill stand. The curved wooden chair backs face their
respective desks. Both chair orientations share one mesh.

Office 17013 reuses the inn bottle-cabinet assembly. The two 17532 waiting seats
reuse the bank cushion master, rotated into their source direction. Nine
17534 stools use a shared four-legged assembly with lower stretchers. The
office/guild detail owners delegate only their selected visual pieces; source
positions, stair geometry, native blocked cells and collision stay with their
existing owners. Other rooms and legacy reusable furniture are preserved.

17559 was previously drawn as a small notice: its source is a tall hanging-strip
doorway with a carved wooden header. Its solid frame and jointed strips now
use the same furniture master. The header paint, 17564 office notice and 17608
guild notice are reproduced by `tools/recover_falan_interior_details.py`.
The guild board now has a taller source-like frame rather than stretching the
original writing into the old narrow strip. The atlas's earlier clock and inn
patches remain in their original slots. All original room and sprite studies,
crop provenance, comparisons and metrics are in
`build/Other Files/Asset Toolkit/Falan Office Interiors/`.

The 21 selected furnishings use nine cached assemblies, including the two
reused masters. `falan_office_interiors_test.gd -- --east-il-road` reuses the
interior door/collision/save fixture and adds rendered-triangle checks for the
curved backs/rounded tops and source-derived chair facing. Index custom
SurfaceTool geometry before appending it to indexed primitive meshes: loose
vertices otherwise disappear from the rendered faces. Review the actual
captures separately. These remain fitted 3D interpretations; original wood
grain, tiny lettering, some proportions and the remaining generic cabinets
still need further recovery.

## Kili village and Sokia approach — 2026-11-17

The seven Kili building bodies and equipment arcade (11289/11290/11292–11295,
11297/11298) now reuse `forest_coastal_buildings.gd`'s source-specific solid
rooftop kit. The original facade atlas and original door/window paint remain
on the first surface. Solid parapets retain that paint where compatible;
the hospital uses its white-stone tile to avoid projecting its old bell paint
onto unrelated parapets. A second shared material supplies unwrapped roofs,
cloth, timber, pottery, leaves, bells, red medical markings and shop awnings.
Both surfaces belong to one cached mesh per original graphic. Venoa and the
Il/Alyut geometry paths retain their existing owners and materials.

The two houses have solid yellow canopies, hanging racks and roof planters;
the pub has its low plank platform and pottery row. The hospital has open
arched belfries, real bells/clappers, crosses, crates and medical packages.
The chief's two terraces and equipment-shop/arcade openings retain their source
positions and existing collision. Small prop placements, unseen faces and
sculpture depth are fitted interpretations, not original recovered meshes.

`tools/recover_kili_surfaces.py` prepares `assets/maps/falan/kili_surfaces.*`
from the adjacent archive. Use `--check` to reproduce all 15 native paint crops
and provenance. The tiny white-stone crop is averaged with its own source tone
to avoid magnifying palette dithering. The original facade PNG is untouched.
Keep canopy faces upward; the first rendered review caught a reversed cloth
face, a black-backed wall crop and excessive white microtexture.

`forest_kili_art.gd` caches the original 11230–11250 wall/column family using
the same surface atlas and solid round-profile helper. Kili and Sokia's nearby
native tree graphics reuse the existing Cross Gate flora masters. Sokia's
12536–12565 cliffs and undersea mouth reuse the native moss/stone crag kit from
the Venoa road pass. Source anchors, source masks, shoreline, existing physics
and native army owners remain unchanged; there is no new per-frame work.

Run `kili_recovery_test.gd -- --east-il-road` through Play Goemon for the full
57-cell coastal walk, both gate round trips, source building/scenery counts,
actual collision/plan/link preservation, native UV slots, upward canopy faces
and shared meshes. Original studies, overview comparisons, close views and
metrics belong in `build/Other Files/Asset Toolkit/Kili Village Recovery/`.
Building camera framing follows each model's bounds; it is a visual comparison,
not an image-difference test. `--coastal-kili` on the existing village fixture
also checks the original room links and NPCs. More exact sculpture, rooftop
weathering, palm silhouettes and interior prop recovery remain separate work.

## Recovered western buildings — 2026-11-20

The existing Falan exploration now uses the recovered western layouts.
`forest_original_maps.gd` places native 10604 with `forest_falan_civic_exterior.gd`
and `forest_original_map_solids.gd` reuses the 10609 house family and existing
castle parts for 10640–10654. Square generic roofs and closed market blocks
were replaced with curved hipped roofs, round porches, open stalls and stable
bays based on the native 114xx/110xx artwork. Original floors and footprints
remain authoritative. `tools/recover_western_building_surfaces.py` rectifies
the original door/window, timber, trim, roof and snow paint into
`assets/maps/original_crossgate/building-surfaces.*`; its JSON records exact
crop coordinates and original graphic hashes. Keep these source crops and
reuse the cached mesh/material builders. Do not paste complete building
sprites onto boxes. Current normal-camera captures and source comparisons
are under `build/Other Files/Asset Toolkit/Shalena Recovery/`.

## Source 10605 residential pilot — 2026-11-20

One unchanged city marker at `(-37,46)` now uses a separately cached solid
10605 study in `forest_falan_houses.gd`. Its nearest original map-1000 object
is at source cell `(60,62)`, with a center 1.5 world units from the marker;
this proximity is not proof of an exact original identity or orientation.
The pilot keeps the saved transform, collider and entrance owners. It uses the
source's narrower rectangular body, curved roof, four arched roof hoods, eight
upper slit windows on each long wall, four lower buttresses per side, ridge
crest and end door. The visible window paint is rectified from source 10605 by
`tools/recover_falan_buildings.py`; original image and crop provenance remain
in `city_building_surfaces.json`. Existing atlas slots are retained. Raised,
rotated, scaled or otherwise changed markers keep their existing appearance.
The other saved markers and the separately reused western house are unchanged.

The proportions, end walls, unseen side and geometry remain interpretations;
they are not 1:1 source geometry. The actual source image and pilot captures
are in `build/Other Files/Asset Toolkit/Falan Buildings and Props/`. Use
`falan_buildings_props_test.gd -- --east-il-road` through Play Goemon for the
pilot, bounds, saved-marker guards, city colliders and gate returns. Inspect
`10605-pilot-study.png` against `original-10605.png`
separately from technical test results. Further recovery should verify the
source identity and its door relationship before extending this model to other
markers, then finish the original facade and refine proportions.

## Residential exterior families — 2026-11-20 continuation

The earlier one-marker pilot is superseded by recovered appearances on all 57
protected markers in `city_building_surfaces.gd`. The generated family field is
authoritative; `tools/recover_falan_buildings.py::FAMILIES` owns the mapping.
Original 10605/10609 use their respective narrow window paint and original
long-roof orientation. 10003/10076/10077/10304/10306 share the entrance-facing
blue-roof family; 10006/10079 and 10007/10078 retain green/red source roof paint,
three roof fittings and the rounded gable bay. Windowed 10081–10084 retain
separate families, 10305 uses capped chimney blocks, and 10308 retains the
original flower-box paint. 10005/10080 have separate shop fittings. Existing
western-map callers of house styles 0/1 keep their old geometry.

The solid masters remain `forest_falan_houses.gd`, with immutable cached meshes,
shared prepared paint and local MultiMeshes. Roof profiles, rounded cross-ridge
caps, bay frames, turrets and source panels are prepared at setup. Existing
colliders, saved marker data, all user edit guards and original door owners stay
with their current systems. No new frame loop, scene loader or gameplay owner
is added. The shared coastal UV helper adds tile pitch only for the new red and
green roof names. The village surface preparation test reproduces its previous
atlas byte for byte.

This is still an interpretation, not a 1:1 reconstruction. Nearest references
are not exact identities for every saved marker; original footprints are fitted
to existing collider bounds. Some gable sculpture, wall details, roof paint
sampling, unseen faces and absolute proportions remain incomplete. The generated
JSON now explicitly lists 16 unresolved placeholders, including special shops,
the double-marker workshop and larger villas, so they cannot be mistaken for
finished source-matched buildings. Do not stretch a generic house onto them.

`test_falan_house_archive.py` verifies the recovered source stations are real
and unique, plus the original door direction for 21 entrance-facing examples.
The desktop fixture captures all families, verifies roof winding/bounds,
windowed roof axes, saved edits, collisions, all three gate returns and mesh
reuse. Technical passes do not certify visual fidelity. Captures and logs are
under `build/Other Files/Asset Toolkit/Falan Buildings and Props/`.

## Distinctive exterior recovery: workshop and magic shop — 2026-11-21

The user confirmed solid 3D construction with original 2D art for suitable
surface details. `forest_falan_workshop.gd` recovers source 10301 as one static
assembly, with two original room-1071 entrances. The earlier inventory called
it a tavern incorrectly; the native graphic has the SMITH sign and a second
trade sign. Preserve their actual pixels rather than substituting translated
lettering. `forest_falan_magic_shop.gd` recovers source 10075 with four corner
towers, tiered purple slate caps, spires, the curved main roof, stair and native
sign. Its original entrance leads to room 1041.

These are separate cached meshes under the existing city scenery owner, not
new gameplay controllers. They share the coastal solid/surface builder, the
existing house atlas and the existing scenery/collision lifecycle. Original
signs and window crops are recorded with source hashes and quads by
`tools/recover_falan_buildings.py`. The workshop and magic-shop markers are
listed separately in the JSON `composites` inventory; 13 distinctive
placeholders remain unresolved. Source 10301 is one building, not two houses.

The obsolete workshop blocks formerly placed a building across the original
frontage. The live exact-match replacement now uses its source-centered wall
footprint and restores the original two door positions outside the wall. The
magic shop also uses a source-centered fitted footprint instead of the small
placeholder square. This intentionally changes those three old collision
markers. Save-file data is not rewritten. Modified/raised/moved/scaled markers
retain their previous scenery assets and collision. Compound workshop recovery
requires both original signatures; editing either returns both placeholders to
their own appearances. Their chunk signatures include recovery state so that
editing the companion marker also invalidates the old compound visual.

Run `falan_magic_shop_test.gd -- --east-il-road` through Play Goemon. It includes
both workshop room routes, the magic-shop room round trip, source footprint
clearance, user-edit guards, mesh reuse and all three city gate returns. Its
inherited house fixture reconstructs only the three old marker bounds when
comparing the historical unrelated-scenery hash; the new footprints are checked
separately against their explicit source positions. Source art is checked by
`test_falan_house_archive.py` and `recover_falan_buildings.py --check`.

Visual review rejected the first oversized U-shaped workshop fit. The final
source-centered fit keeps the shop fronts together and places the native signs
on the recessed front. The magic-shop roof was turned so it could not hide the
native sign. Fine carving, some window surrounds, exact paint scale and unseen
faces are still interpretations. These are not recovered original 3D models or
a finished 1:1 city. Keep technical verification separate from that judgment.

The November 21 continuation also binds 10009 to its compatible blue-roof
family, 10049/10050 to the long three-ridge family, and 10309 to its chimney-house
family. This brings ordinary protected marker coverage to 63; source 10301 and
10075 cover three more saved markers as two distinctive assemblies. Seven
placeholders remain in `unresolved`: 10300, 10606, 10311, 10312, 10313, 10314 and
one distant/ambiguous 10077 reference. Do not add a fourth copy of native 10077
merely to force that last marker into a nearby family. Original source graphics
are preserved for reviewing each remaining building separately.

## Final seven placeholder resolution — 2026-11-21

All seven remaining cases are now resolved. The six native buildings have
separate solid exteriors in `scripts/forest/forest_falan_special_exteriors.gd`:

| Native graphic | Solid construction | Original 2D detail art |
| --- | --- | --- |
| 10300 | Curved grey roof, paired bell caps, shaped end walls, raised scroll coping | Gold/purple emblem, stained glazing, masked carving strokes |
| 10606 | Layered blue roofs, battlements, square posts and round turrets | Native gate and glazing |
| 10311 | Open roof terrace, rounded projecting bay, railings, buttress and laundry frame | Native glazing, hanging cloth and foliage |
| 10312 | Partial barrel roof, roof terrace, pale edge caps and chimney posts | Native glazing and foliage |
| 10313 | Taller villa, barrel roof, terrace, balcony and crest mounting | Native glazing, crest and foliage |
| 10314 | Four-storey house, three roof ridges, four turrets and five chimney stacks | Native glazing |

The seventh saved marker, `(-49,-16)`, has no separate building in the original
city. The native map render places grass/path there between source 10077 and
10309. Original map 1000 contains three instances of 10077, and all three already
have their own recovered markers. The unchanged extra generic house is therefore
ignored at runtime; edited/moved/raised/scaled versions remain user scenery. Its
saved record and original reusable model are preserved. Native evidence is
`extra-marker-source-gap.png` in the toolkit folder. The generated JSON records
this case in `retired`, and `unresolved` is empty.

Only exact known signatures receive these replacements. Source centers and
footprints come from original map records, and all six original room links are
kept. The existing scenery/nav owner applies the corrected footprints. Static
meshes are cached per source graphic and use one shared-atlas surface each.
No new per-frame owner, army backend, asset loading loop or save migration is
introduced. The nearest source recipe remains
`tools/recover_falan_buildings.py`; background masks preserve source colors while
making carving/emblem/foliage backgrounds transparent. Originals are untouched.

Run `falan_final_exteriors_test.gd -- --east-il-road` through Play Goemon. The
fixture visits all six rooms and returns, includes the workshop and magic-shop
routes plus all city gates, and verifies bounds, native metadata, edit guards,
source-gap retirement and mesh reuse. The extended tour has a scoped 600-second
timeout; the underlying unrelated tour keeps its existing limit. Its collision
comparison temporarily reconstructs the historical block/garden layout in the
fixture, then restores live state. This preserves the old baseline hash without
rewriting it while testing the corrected source footprints separately.

Final native/rendered comparisons, in-city views, procedural triangle counts,
logs and verification are under
`build/Other Files/Asset Toolkit/Falan Buildings and Props/`. The models are
solid reconstructions of the supplied 2D references, not recovered original 3D
geometry. Fine relief and unseen faces remain fitted interpretations; technical
passes alone do not establish pixel-identical appearance.
