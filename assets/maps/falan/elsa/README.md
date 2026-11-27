# 艾爾莎島 and the original castle journey

The authoritative layout/art supplement is `assets/maps/original_crossgate/elsa/`.
This directory contains NPC/service art, source encounter/event data and scenery
derivatives used by the existing Explore and native army owners.

Read the detailed map inventory and outstanding work in
`build/Other Files/Asset Toolkit/Elsa Island/CHECKLIST.md`. `scope.json` records
connected-room ownership; map IDs alone do not identify island ownership. In
particular, shared maps 59716 and 59752 contain unrelated quest rooms.

## Reproduce

Run from the complete source used by `Play Goemon.command`:

```sh
python3 tools/recover_elsa_island.py --fetch-scope --fetch-events
python3 tools/recover_elsa_island.py --prepare --pack-creatures
python3 tools/prepare_elsa_scenery.py
python3 tools/prepare_elsa_props.py
python3 tools/prepare_elsa_gate.py
python3 tools/prepare_elsa_music.py
python3 tools/prepare_elsa_terrain.py --all
python3 tools/prepare_elsa_temple_steps.py --hall-platform-source
python3 tools/prepare_elsa_temple_steps.py --hall-platform-joins
python3 tools/prepare_elsa_hall_entry.py
python3 tools/prepare_elsa_hall_entry_props.py --publish
python3 tools/prepare_elsa_second_stair.py
python3 tools/prepare_elsa_second_stair_support.py
python3 tools/prepare_elsa_second_stair_ground.py
python3 tools/publish_elsa_second_stair.py
python3 tools/recover_elsa_island.py --check
python3 -m unittest discover -s tests/forest-shrine -p test_elsa_island_source.py
```

The client archive beside the project is read only. Do not edit original MAP,
CUT, indexed graphics, palettes, animation tables or PCM. Missing client cache
files are listed individually in the report's `blockers.json`; complete fixed
grids for those files come from the pinned corroborating server reference.

The entry-pedestal command requires the existing hall-entry source and role
preparation under the development report. It installs only the mapped BG
pedestal and its clipped parent-apron repair. See
`scenery/entry-pedestals/README.md` for source masters, generated files and
inference limits. Negative stair heights remain private. Production review
passes28 assertions/four inspected Metal views; five independent source tests
cover the staged and published paint, BG UVs, preserved stairs and source matte.

The adjacent BG staircase is also installed through the existing scenery and
shared height owners. See `scenery/temple-bg-stair/README.md` for exact source
and inference limits. Its canonical floor composes only the published pedestal
and BG-stair masks plus their scoped concealed paving: 59 original CUT crops on
one512px page. Rebuilding the
pedestals retains that union. The unfinished private portal, wall and central
FG assembly remain separate. Normal stair movement/re-entry passes133 Metal
checks, including both original door landings; this is not whole-temple art
acceptance. Negative entry-stair support remains private.

The57,712-pixel stair parent-paving repair repeats the matching native local
cobbles only in original owned/open cells beneath absent/black BG or relocated
stair photos. Its pattern is inferred. Every exposed source pixel remains exact;
no fringe repaint or extra overlay geometry is installed. Normal fixed review
passes14 checks/four inspected Metal views; the shared CUT floor importer keeps
the original per-tile UVs and closes the rejected overlay's thin seams.

`prepare_elsa_scenery.py` follows map preparation. It reuses the original map
pipeline's `solid_pages` edge-paint extension for hidden solid surfaces while
keeping the original RGBA atlas unchanged. Its local wrapper restores every
nontransparent source RGB value after edge filling, including dark shadows;
only transparent regions receive extended paint. Use `--solids-only` on both
scenery and prop preparers to refresh these RGB derivatives independently.
It prepares 96 complete scenery
animation clips and alpha silhouettes for 894 static graphics. Use
`--profiles-only` when only rebuilding silhouette data.

Animation descriptors retain the native header flags. `--animation-flags-only`
refreshes those96 descriptors without rebuilding art;48 clips carry bit8.
The two59530 flame masters113651/113652 use it. CGTool independently names
[bit8 LIGHT_THROUGH](https://github.com/HonorLee-cn/CGTool/blob/master/CrossgateToolkit/Anime.cs#L241).
Their shared scenery material now uses additive blending instead of an opaque
dark fringe. Original pixels, frames, sizes, placement and timing stay unchanged.
The additive material is the3D interpretation; live original-client blend parity
remains unverified. Two source tests check all96 headers and private stair-floor
RGB/alpha preservation. The first updated fixed Vulkan views pass13 checks and
show the floor through the flame. These views do not establish full-room quality.

`prepare_elsa_props.py` assembles native fragments that share their original
graphic and canvas origin. It prepares 626 native objects plus two assembled
spire variants in 14 atlas pages, fits 29 clear column silhouettes to octagonal
geometry, and identifies original
walkable portions of architectural sheets for floor batching. Use `--fit-only`
to rebuild those fits without repacking unchanged source art. Use `--edges-only`
to refresh silhouette side-color samples; each sample must land on an original
nontransparent pixel, rather than the edge fill outside its silhouette. Graphic 300786 is
a fence, despite sitting between the tower's graphic IDs; keep its placements
separate. The tower's base fit stays within its connected blocked footprint.
The five smaller spires join their matching body, tip and base fragments; the
original separate placements remain available as preservation evidence. A trial of row-locked spire UVs passed source checks and eight Vulkan placement
checks, but its broad gold bands on reachable sides were visually rejected.
`Temple Bays/Row UV Rejected/` retains all four inspected frames. Both flags and
the preparer rule were removed. Original projected UVs remain; the spires still
need physical horizontal tiers and clean reverse material continuation before
whole-landmark acceptance. `Temple Bays/Spire Source/` retains the three full
original masters and both assembled variants. Master300791 is a packed scenery
sheet; only its recorded lower-right body continuation belongs to these spires.
Do not attach its unrelated horse/statue art. Occupied bottom image boundaries
leave the hidden underside and exact ground contact unproven. The current
silhouette-derived foot is inferred. The pointed roof tiers, faceted crystal
and flared pedestal need separate physical sections and material regions.

Static CUT entries with zero width and height are nonvisual. There are 70 such
placements in this scope (11 distinct graphic payloads), including the return
stone's map marker. Their complete master images remain diagnostic payloads;
they are not instructions to draw the entire sheet. This interpretation follows
the recorded rectangle dimensions and the [documented CUT fields](https://crossgatedata.github.io/cgsword.com/filesystem_graphicmap.htm).
Original-client rendering of these empty entries remains unverified. See
`zero-crop-audit.json` and `zero-crop-interpretation.json` in the report.

Rock sheets are split into 288 source parts, including the forest moss families. Above-ground
rocks reuse the Wind Meadow boulder; hanging caps and undersides (300401, 300942,
300944 and 300945) reuse the closed Cedar Pass river rock below the walking plane.
The Meadow model has an open underside and is unsuitable when inverted. Each
part retains its native bounds and paint; tiny stones and original GLBs remain
unchanged. The shapes still require further gameplay-view refinement.

Perimeter walls and fences recover their ground line from their original alpha
footer. Their paint retains the original camera projection while their slabs
follow that line in world space. Plants and pond patches use grounded relief or
floor art as appropriate. The twelve stands in packed graphic 300938 are fitted
separately in the diagnostic master; its zero-area placements remain nonvisual.
Ordinary cropped stands use the same column fitter. Fountain basins use round
geometry with separate figure/bronze relief. Animated torch flames share their
original stand's recovered ground anchor; source frame order and pixels remain
unchanged. The parent placements and native matching distances are retained in
`props/data.json` under `effect_sources`.
These inferred fits do not alter navigation or interaction coordinates.

City tree masters 300795–300804 are assembled before model fitting, with 17
source forms and 51 visible island instances. Fit each whole object once using
the existing Woodland/Evergreen/Palm models; never create a whole tree for each
native canopy fragment. The separate forest banyan families still use source
relief and remain part of the unfinished depth pass.

`prepare_elsa_gate.py` assembles the arrival, ferry, forest and east gates' foreground and original
background paint. The round towers, conical roofs and curved arch share
the existing source-paint builder. The original grille remains a separate alpha
surface. Original pole fragments remain separate. The side gates join pieces
from families 300814/300815 and the background layer; native roof/eave/pole rows
guide their fit. Cylinder ground centers and unseen surfaces are inferred.
Their attached wallwalks remain present. Lower background wall bodies and their
cliffs still require the remaining depth pass; fixed views exposed stretched
upper wall paint, so these fits are not final art approval.

`prepare_elsa_terrain.py` covers the 56 scoped maps using the original blue-cliff
floor family. They share two prepared geometry templates; each map keeps its
own original floor and walking-mask hashes. `coverage.json` records the full
list. Use `--map ID` for a focused rebuild. Original
top paint and cliff paint use separate surfaces. Connected cliff sections share
continuous ledges and retain vertical pixel spacing. Joining their vertices to
zero-height floor or transparent padding would stretch narrow image strips
across an entire cliff. Brown walking paint and Explore navigation stay at zero;
the original walking mask is unchanged. A projected cliff image pixel is not a
navigation coordinate. Runtime displacement preserves the native camera projection.
This is inferred depth, not archived height data. Fixed views cover the shared
forms; they do not establish visual acceptance of every room's other scenery.

The two long decorative spans in masters 300814/300815 use the bright blue deck
edge and lower gray footer to recover their raised height. Original side paint,
an inferred inner face and alpha-edge thickness form the volume. Twelve sampled
support positions on both faces match original blocked cells. Their native
placements and walking mask remain unchanged. The inferred inner walls and
end caps use original background masonry from `props/wall-inner.png`, recorded
in `props/data.json`. Original outer foreground paint remains in place; CUT
fragment gaps are backed by masonry rather than extruded as internal walls. This fit adds no crossing or
walkable exterior bridge cells.

The island shoreline fit lowers original navy sea pixels to Goemon's existing
water depth. It preserves the original walkable island and its rim. Exterior
water belongs to a separate unreachable component in the source grid. Run
`prepare_elsa_scenery.py --shore-only` to regenerate this fit independently;
depth is an adaptation, not an archived 3D measurement.

## Geometry and ownership

`forest_elsa_scenery.gd` reuses the existing Cross Gate broadleaf/conifer masters
and palm model. The tower separates its original shaft, four gold buttresses,
two masonry bands and flower terraces. The shaft's curved front retains native
pixel projection; hidden depth is inferred. The terraces use source surface
crops on a smooth ellipse inside the blocked footprint. Use
`prepare_elsa_scenery.py --tower-materials-only` to rebuild these derivatives;
the full preparer and `--solids-only` also refresh them. The earlier width-profile
fit remains diagnostic metadata. The temple uses the original floor-layer facade
on three entrance volumes and two connecting wings; see the temple fit below.
Other foreground pieces retain
their original silhouette and anchors on relief meshes, including open arch
holes. Animation uses source frame order, duration, palette and opacity.
Support silhouettes are traced from the original tower image; their common
physical tip height is inferred from those projected tips. Original blue paint
extends behind support occlusion only, recorded by `tower-body-occluded.png`.
The visible source colors and original tower master are preserved. Alpha gaps
left by those supports do not create long closing panels through the shaft.
The two garden terraces also retain the original gold filigree fence motif on
curved bands; unseen rear repeats are inferred. No new collision is added.
The return stone uses actor 110500's four original idle frames over 500 ms;
`--return-stone-only` rebuilds its atlas without changing interaction ownership.

The original client contains rendered scenery, not original 3D models. Hidden
depth and rear surfaces are inferred. These fits require fixed gameplay-view
review; source preservation tests do not establish visual accuracy.

## Travel and encounters

`forest_elsa_route.gd` supplies the castle/return stone and event choices to normal
Explore interaction/travel. It does not change home, login or saved location.
Original quest item/job/story prerequisites are omitted for Explore access and
kept in the source evidence. Boss exits require the source encounter's native
death callbacks. Do not turn a victory transfer into an unconditional warp.

Random encounter zones and event groups reuse `forest_waves.gd`, the native army,
existing companion rendering, bounded placement and shuffle bags. There is no
Elsa simulation or targeting owner. NPCs without implemented conversations use a
short greeting. Original safe areas have no added random encounters.

Area music uses every container's pinned native sound ID and the client's
`bgm.cf`, through the existing single music player. The route uses original
castle music, silent time passage, PUK2 ruins, field and town tracks. Temple
halls use `puk2_sinden`; trial rooms retain their distinct dungeon IDs and
silence. `prepare_elsa_music.py` preserves original audio frame counts and gain.
Mute, volume and recording behavior remain in the shared music owner.

## Interior furniture and hidden floor paint

Three source forms in 59530 now use the shared furniture fitter: master 301043
at native crop origin (192,96), size 128×144, and master 301045 at (-320,96),
128×144, and (-320,0), 128×96. These are the table and two benches. Their native
feet, seat heights and backrest paint regions are recorded in `props/data.json`.
All twelve fitted feet occupy original blocked cells. Occluded feet/rear paint
are inferred. Their original RGBA masters and placement records remain intact.

`forest_elsa_scenery.gd` reuses its source mesh and column builders and
`forest_falan_lamps.gd` rods for the gold frames. The same setup cache and static
batches own them; there is no new runtime renderer. Do not substitute the
upholstered Falan bench or solid wood bed headboard for these source metal forms.
Wood and gold use separate native-color derivatives. A nearest-pixel flood
extends only each material's selected original colors onto unseen faces; it
does not reuse the row filler, which creates stripes on these small forms.
Original selected pixels stay intact. Bench backrest samples use inset native
board regions; their hidden faces and metal thickness remain inferred.

The original background contains cutouts for flat foreground artwork. One
shared `floor-infill-59530.png` fills the modeled furniture masks at ground
height. It copies existing background colors and matches nearby native paving
patches through transparent/dark matte occlusion. Visible pixels outside those
masks remain untouched. Hidden paving is inferred, not recovered original
pixels. `prepare_elsa_props.py --fit-only` rebuilds the fits and records source
background hashes, mask members, copied-patch offsets and output hashes.
Original navigation is unchanged. Other furniture and architecture roles remain
part of the unfinished interior pass.

## Interior ground and upright roles

`props/data.json` records twelve confirmed ground forms by original master,
crop origin and size: temple stairs/landing, three spiral-stair pieces, three
blue floor panels, two metal stair openings and two metal stairs. Only these
forms receive `ground_cells`; floor panels and openings have `floor_only` so
they are not also drawn upright. Walls, headers, columns, counters and machinery
do not belong in this floor pass. This replaces the former broad master-ID
rule (174,387 candidate cells) with 1,273 original open cells before clipping.
It is a role correction, not a change to the original walking mask.

The fifteen separate torn-space wall/machinery forms now use their native alpha
foot envelopes. The two faces of the corner wall use separate fitted planes.
These preserve the native surface projection and source paint; plane depth is
inferred. They reuse the existing mesh cache and static batches. The original
background still contains some lower architectural artwork which needs its own
role/depth pass; neither these fits nor passing source tests approve that art.

## Banyan crown fits

Twenty-four recovered tree forms now use 26 fitted crowns, including two
original double-tree assemblies: 147 crown placements in 59500 and 129 in
59501. Masters 300842–300861 are selected by actual tree forms; the stump and
standalone crystals remain separate source objects. Each doubled image splits
at its measured native crown gap, with separate root-plane fits.

`prepare_elsa_props.py` follows the existing native foliage preparation method.
It samples original green/yellow crown pixels, retains each row's original width
and repositions the 2,990 reusable leaf quads from `cg_woodland.glb`. Points lie
in the source camera plane; inferred elliptical depth preserves their native
projection. The existing foliage shader owns wind and lighting. Source paint
already contains dapple, so prepared copies use white vertex color rather than
multiplying in another tree graphic's shading. The original GLB, editable tree
master and its vertex colors remain untouched.

Leaf material colors come only from the corresponding native crown. Hidden
paint extends those colors using the nearest native pixel; opaque leaf quads
avoid losing fine foliage to alpha mipmaps at gameplay distance. The body
removes only selected leaf pixels. Original branches, lower trunks, hanging
roots, fruit, crystals and ground art remain intact. Body surfaces retain thin
inferred depth; broad trunk/root geometry still needs refinement.

All fits and derivative hashes are under each `banyan` record in `props/data.json`.
The same setup cache and static batches own them. There is no new simulation or
navigation owner. Fixed forest/plain views establish crown volume and variant
coverage; they do not approve every trunk, pond or forest prop.

The common plain banyan (master 300843, crop origin -320,-240, 320×432)
also has a first solid root/shaft fit at its 32 original placements. It reuses
266 triangles from the existing woodland body, the original nine-cell blocked
footprint and four measured native root tips. Bark and moss use original RGB;
the retained image carries branches and hanging roots. This is one body form,
not completion of the remaining trunk family. Preparation is in
`prepare_elsa_props.fit_banyan_trunk`; optional `banyan.trunks` records its fit.

## Inner hall enclosure

`python3 tools/prepare_elsa_inner_hall.py` recovers the 59535 enclosure jointly
from its six foreground placements and background. The front portal and three
front walls belong to the background; flattening that layer duplicated them
on the floor. Six visible wall faces, two inferred edge-on faces and eight
columns now use the existing source-painted mesh and column builders. Their
ground centers follow the native base ellipses, with the repeated red caps
276 pixels above them. Original blocked/open cells and NPC/travel ownership are retained.

`scenery/inner-hall/` retains both recovered layers, their composite, the object
mask, fitted profiles and hashes. The replacement floor preserves every pixel
outside that mask. Hidden paving repeats an original surface sample; hidden
blue floor extends native blue pixels. Depth, obscured feet and hidden surfaces
remain inferred. Three original curved nosings now have source-painted treads.
Their half-metre risers and hidden support are inferred from the native edge
thickness. The same local support grid feeds player height, physical collision
and the existing native movement owner; it does not open any original blocked cell.
Four background wall spans and seven octagonal posts also have fitted geometry,
with obscured contacts and hidden side faces explicitly inferred. The portal's
18-pixel panel setback lies inside its measured column radius; the inferred blue
floor boundary follows that same plane. Other interior families still require
their own art pass.
Source checks and targeted fixed views are recorded separately from visual acceptance.

The source foreground itself includes clipped front-portal fragments. Dedicated
wall and column paint roles prevent those fragments from appearing on rear
surfaces. Hidden rear shafts continue a small native dark-stone sample at its
original pixel scale and reuse a matching native gilt base. Original caps,
collars and portal colors remain separately recoverable. The portal's existing
colored frame also has shallow source-painted relief, with its white center
recessed. These are inferred continuations of the documented structure.

Original-facing surfaces stay on their measured planes. The unseen outer faces
reuse the enclosure's confirmed gray masonry and gilt arch rhythm; inward faces
continue its native blue treatment. Both edge-on sides repeat the measured
neighboring arch profile. The portal's frame includes its upper foreground
ornament as well as background art. Continuous alpha contours, simplified within
one native pixel, replace coarse grid caps; fine engraving remains surface art.
Fixed approach and rear captures cover the enclosure and surrounding room walls.

The current hall pass has three focused source checks and 122 runtime assertions
covering 53 original open samples, physical/native height agreement, real player
landings, normal forward/back walking and outward-facing risers. Ten fixed images
establish wall/material coverage; the final two step images recheck the last
floor-mask and solid-face corrections. Current runs have no script or GPU fence
errors. The fitted visible assembly has 12 surfaces and 10,165 triangles, measured
headlessly. This component review is separate from the full-island art pass.

The temple source search inventories all 133 static masters and ten animation
sources linked by the original 59520 CUT. Contact sheets cover the complete
associated BG sequence and foreground masters. No matching upper-temple image
was found there. Primary facade masters 300069–300075 already reference every
opaque pixel of their stored 640×480 images; the stored art itself starts across
the building. Hidden upper architecture must therefore be labelled inferred,
rather than described as recovered or verified 1:1. Evidence is under
`build/Other Files/Asset Toolkit/Elsa Island/Temple Source Search/`.

`Native Temple/` in the same report directory retains a 7040×1440 native BG
reference, 30 master placements and eight original entrance-link records.
Independent master/CUT assembly matches the existing native-layer pipeline on
every covered RGB channel. It includes lower entrance art omitted from the old
runtime facade crop. Temple massing, inferred upper roofs and shoreline fitting
remain under construction.

## Island temple volume fit

`python3 tools/prepare_elsa_temple.py` prepares `scenery/temple/` from the original
59520 background. The runtime `forest_elsa_temple.gd` replaces the former single
wavy shell with three entrance bodies and two closed connecting wings. Facade
contacts follow the visible doorway thresholds and plinths. Rear depth stays
inside the source blocked-band edge; zero-valued unowned padding beyond it is
not a reachable rear aisle. No walking bits, triggers or door records change.
The lower tower taper follows the visible clipped silhouette; blue plinths
and gold trim continue around hidden sides. A uniform original white patch
avoids repeated gradient seams, and privately owned hidden materials use local
lighting. Original-facing paint keeps its native color treatment.
Upper taper, roof termination and hidden depth remain inferred because the
original stored facade images are clipped. The current body/material pass has
eight fixed gameplay images and twelve placement checks without script or
Metal fence errors. The separate entrance-stair height and rail-mesh pass
remains unfinished; the whole temple is not yet accepted.

Original front paint stays on the original-facing walls. Hidden white masonry,
brick, blue roof and gold trim use private source crops with repeating UVs;
window/door photographs are not repeated on reverse walls. The barrel roofs
close against each sampled rear wall edge. All meshes/materials are cached at
map setup; there are no frame-loop loads or additional simulation owners.

The original floor tiles are clipped around the replacement rectangle. The
new floor keeps visible native paving and the entrance terraces, with inferred
native grass only beneath lifted architecture. `occluded-floor-mask.png` records
small palette-key gaps and source stair-rail occlusion filled from neighboring
original colors; lifting the rails into 3D otherwise reveals green streaks.
Larger dark doorway openings use a black matte instead of copying gold edge
pixels across the opening. Every opaque source pixel is retained. Source preservation and geometry checks are separate from art approval. The
current headless test has 20 assertions and measures 1,978 body triangles plus
two floor triangles. Door fixtures pass 90 assertions across 18 representative
crossings. These are component checks, not a final full-island round trip.

## Island entrance stairs (in progress)

`prepare_elsa_temple_steps.py` separates the three source stair flights into
seven, nine and eight curved levels. It reuses `forest_elsa_hall_steps.gd` for
cached support shared by physical collision, model height and native movement.
The source XZ grid and door cells stay fixed; half-metre rises and occluded
continuations are inferred. Pylon foundations meet the raised landings.

All six original rail placements are retained, including group 294 / master
300786 on the west side. Native foreground pixels stay exact. Their baked
background copies and gold base beams are separated from the floor; original
rail art and those beams use thin mesh surfaces. The original blue riser bands
move to actual vertical faces, with narrow gold nosings and source paving on
top. Masks record every inferred floor/paving repair. The shared helper retains
its existing 59535 default API and resources.

The corrected movement fixture passes 40 samples and 107 assertions, including
normal controls up and down all three flights. Its first eight screenshots
exposed overly wide rear slabs and oversized gold risers. Those fits have been
corrected; the current geometry fixture passes 21 checks before the following
floor repair. The inner-hall regression passes 122 assertions after the optional
material split. Fresh floor geometry, door and art checks remain pending. These
results do not accept the whole temple or complete the island goal.

The west-side blue/white floor strip is a baked copy of the **existing 3D tower**.
Direct BG/FG pixel comparisons are retained under `Native Tower Floor/` in the
report directory. `tools/prepare_elsa_landmark_floor.py` prepares private BG tile
derivatives in `scenery/landmark-floor/`. They separate that tower photograph
and the relocated temple, stair and rail roles from the ground. Original grass
and paving continue occluded surfaces; those continuations are inferred. The
2,109 affected placements retain their native origins/extents, including 320
shoreline profiles. The runtime geometry fixture passes 985 checks, comparing
every affected shoreline profile's positions and normals exactly. Original alpha stays exact except explicitly masked removal
of duplicated tower pixels outside the land. No grass sheet replaces the sea.
`forest_elsa_landmark_floor.gd` supplies private atlas UVs to the existing floor
geometry; the former flat garden replacement is removed. Source preservation
passes. A separate alpha patch fills only original BG holes in the recorded
floor domain. The tower-removal mask also retains inferred blocked ground inside
the outer walking outline, confined to the original tower silhouette. A fixed
camera probe at source (164.417,57.510) changed from no rendered hit to the
private native-grass atlas. This outline is an inferred occluded continuation,
not a verified coastline or a new walking route.

Stair side faces now close to ground. All six original rails remain; rail 294's
tower-occluded gap continues the original ascending motif from rail 288 at the
measured image offset (17,19), with every original visible pixel retained. This
continuation is inferred. Tread repairs use a consistently scaled original stone
pattern toned from each actual horizontal tread, keeping photographed vertical
faces off the tops. The tower grass crop mirror-wraps its original colors to
avoid repeating bright/dark cut seams. Facade infill samples only architecture;
`python3 tools/prepare_elsa_temple_steps.py --front-only` refreshes that repair
without rebuilding the unchanged stair support. Obsolete separate
`landmark-floor/tread-paint.png` derivatives are removed; `temple-steps/paint.png`
owns the tread paint.

The raised entrances pass 90 targeted door assertions and the shared inner hall
passes 122 regression assertions. Eight current fixed images pass twelve placement
checks; the repaired stairs/ground have been visually reviewed. The central
pylon now has a candidate pair of rounded facade volumes.
`python3 tools/prepare_elsa_temple.py --bays-only` updates their metadata without
rewriting the unchanged source paint, floor repair or stair support. The original
pale lobes guide native spans (9085–9440) and (9470–9930). Their six metres of
depth and lower transition are inferred. The facade is segmented every 24 native
pixels and 16 vertical bands, displaced along the original view direction so its
source-facing UV projection stays fixed. Original ground contacts remain on the
same lines; the roof/reverse enclosure joins the same segmented top boundary.
The revised source/material test passes (one test, 14.350s). Actual mesh checks
pass 29 assertions: 38 facade contacts stay on the original lines (maximum error
0.000245 native pixels), zero ground shift, maximum paint projection error
0.501 pixels including the half-pixel atlas clamp, and a segmented, height-bounded
upper cap. The body has 4,820 triangles and five surfaces; body, stairs and six
rails total 44,282 triangles and 20 surfaces, plus the separate floor patch.
Headless shutdown resource warnings remain; these checks do not measure growth.

The first four bay captures were rejected for occlusion and camera compression;
`Temple Bays/Rejected Views/` retains them. A bounded scout tested 32 original
walkable stands with the normal camera's legal upward pitch: 30 framed the two
measured bay targets, and four captures passed 67 technical checks. The selected
plaza (153,127) and east (198,151) stands keep 24.3 units of camera distance. Four
subsequent Vulkan views pass six placement checks and have been inspected from
both approach and alternate angles. They exposed oversized inferred white
pyramids, now replaced by short white continuations and curved blue caps using
existing temple materials. The original client upper search region has only 40
cached cells out of 5,390; no mapped roof art was recovered there or in the
corroborating layers. This is a partial-cache limitation, not proof the original
roof did not exist. All three upper forms remain explicitly inferred. Spires,
ornaments, surrounding scenery and whole-temple acceptance remain open.

A source-fidelity guard excludes generic optional Explore entry chests on the 95
journey/island maps; explicit reward owners remain unchanged. Its all-map repeat
check is queued; the four-view Vulkan repeat passes eight checks with no generic
entry chests. No original treasure or NPC
record is removed.

`tools/report_elsa_geometry_coverage.py` inventories current FG ownership across
all 95 maps: 626 used original groups and 41,077 placements, including 251
generic-relief placements to review. Its JSON retains each group's original
master, bounds, hash and placements. These labels do not certify visual fidelity;
BG-only architecture and terrain remain separate checklist items.

## Trial top-surface fragments

`python3 tools/prepare_elsa_props.py --trial-caps-only` repairs four reviewed
brown cap crops (300374, 300375 and two 300943 fragments), shared by 168
placements across 56 trial maps. The 59609 original BG/FG composites and walking
mask distinguish these ground surfaces from adjacent blue cliff/arch crops.
They reuse the existing flat surface builder, original pixels, UV scale and
anchors; no navigation or crossing changes. The blue arches remain separate.
The mixed 300943 cap retains two source-matched 300938 pillars using the existing
column mesh at translations (65,-8) and (2,88). Private floor paint uses original
BG beneath their silhouettes; 306 missing BG pixels use inferred nearby native
brown paint. Original cap alpha and paint outside that mask remain exact.
Source preservation and the mixed-layer source check pass; geometry passes 19
checks, including the primary shared arch surface below. The later five-point
Vulkan review passes 25 checks with ten captures and no runtime script/fence
errors. All images have been inspected: the brown cap floors are intact and the
generic entry chests are absent. Earlier large Metal checkerboard holes were
resident-texture corruption, not evidence of missing source terrain. The first
503 pair looks too similar despite different recorded camera positions; the
fixture now resets rig interpolation and waits a physics tick before capture.
That pair does not establish two independent visual angles. The owned 59603
arch entrance exposes a separate real fit defect: its opening is below the
zero-height walkway. Whole trial architecture remains unapproved. Evidence is
retained under `Trial Depth Vulkan/`.

`python3 tools/prepare_elsa_trial_surfaces.py --publish-reviewed` attaches the
original 300943 arch crop (group 562, 56 placements) to each map's existing BG
geometry. Two shared depth variants cover 28 maps each. Reusing 59609 on the other
28 maps displaced 137 quads, affecting 6,605 opaque source pixels by up to 328 native
depth pixels. The all-map source check now compares every variant quad and role
against its own BG template. Original RGBA, UV scale, anchors and navigation
remain exact. Both meshes retain 1,152 triangles, one surface and a 3 cm offset.
The earlier primary-fit source-camera error was at most 0.424 px; current runtime
geometry passes 23 assertions, retaining 0.424 px primary source projection
error. The five-point Vulkan review is recorded above. The arch room is outside linked ownership
on 59609 but lies by the documented (45,95) entrance on 59603; no access is added.
Prepared surface metadata survives full/fit-only prop preparation and rejects
changed BG template dependencies. Coverage for all 27,001 blue pixels refers to
the primary 59609 wall roles; the alternate variant follows its own wall/floor roles.
Groups 549 and 563 remain unactivated candidates under `Trial Wall Candidate/`:
their unmatched sections still need review. Neither candidate establishes new
walking ground or a verified original link.

The later entrance recovery is now enabled by
`python3 tools/prepare_elsa_trial_surfaces.py --publish-entrance`.
`forest_elsa_trial_entrance.gd` fits matched BG/FG vertices during their normal
CPU construction, retaining both28-map background variants. Original floor
vertices, UVs, source art, links, collisions and navigation are unchanged. The
opening now meets its documented walking-height crossing. One shared source-
painted recess has separate dark inner edges; its0.75m depth,64px transition
and0.5m underside thickness are inferred. The underside stays below the floor
and closes the ray that previously revealed a distant prop. The old test-only
GPU deformation is replaced by a production-only fixed-view review.

Four independent trial source tests pass, including a fresh native BG+FG decode,
exact recess paint and both source depth variants. The geometry check passes27
assertions. Its first updated check incorrectly required the FG crop to retain
its old35m depth; the fitted crop spans the original960–1248 native rows around
the1200 walking foot (about24.1m above and4.8m below), and the corrected source-
span check passes. The default-Metal production capture passes33 checks and
four inspected views with no runtime ScriptErrors/fence timeouts. It also
verifies native trial pages40–43 through the existing prepared-Image owner;
minimap/sign sampling shares those unmodified Images. This proves the scoped
views and source binding, not FPS, long-session stability or completion of the
surrounding trial architecture. Reports remain under Elsa Island/.

## Known source gaps

- Castle WatchEx 806084 uses `EV_tane_GATE_10000.txt`: actor at (28,87), activation
  at (28,88), landing 59511 (19,19). The client has no visible prop at that castle
  position. User direction explicitly requires no level requirement or travel
  fee. Corroborating trial/level/gold conditions are provenance only; normal
  Explore stone travel has no such gate and never changes home or login state.
- `EV_tane_mein5_104.txt` lands in 59716 (166,173), disconnected from bishop
  806499 at (67,171). The downstream 59737 room is prepared, but that transfer is
  closed until an original onward link is verified. Do not substitute (66,173).
- GuildWarp at 59530 (98,52) lacks the original guild allocation/template state.
- Off-island destinations are recorded without recursively rebuilding their
  cities/fields. Existing supported crossings remain available.

No app export is part of this work.


## Temple interior source inventory

`Temple Interior/inventory.json` in the Elsa report now records all 69 foreground
groups/placements for59530, with original anchors, source cells, RGBA hashes,
observed roles and ownership review distance. Four contact sheets and the central
768×1472 BG+FG composite retain the source reference. The current geometry owners
are23 column forms, three fitted furniture pieces,42 generic reliefs and one
separate body/globe pedestal; these counts do not accept the whole room. The
initial six-image Vulkan review passed12 placement checks, but central stairs/
landing/arches remained flat or disconnected. The automatic pointed-pedestal
attempt was rejected and remains removed.

`python3 tools/prepare_elsa_props.py --publish-pedestal` now publishes the reviewed
component under `props/pedestal-406/`; full/fit-only preparation also regenerates
it. The authoritative source remains the original301044 crop and its preparer.
The existing column builder reconstructs a level octagonal cap, thin gray molding
and native faces; a separate round globe rests on the cap. Both surfaces use
retained CPU arrays through fitting, without GPU readback. Horizontal molding
samples its own gray material. Only paint outside the original globe mask uses
softened inferred continuation; every photographed globe RGBA and unmasked body
RGB is preserved exactly. Hidden depths/material continuation remain inferred.

An independent source test passes. The actual production default-Metal review
passes14 checks/two inspected normal views, with exact original anchor, shared
mesh/material bindings, full globe/cap contact and no new collision/interaction
owner; no runtime ScriptErrors/error lines/fence timeouts. Shared trial geometry
still passes27 checks after the column change. Source hashes of all69 inventory
entries are unchanged. The59530 platform contact, five curved treads, BG pedestal
and other BG architecture, central stairs/landing/arches, curved writing counter
and clinic furniture remain unfinished. The component is installed; the full
temple interior is not accepted.

`prepare_elsa_temple_steps.py --hall-platform-joins` now recovers the four
visible right return faces of the entry stairs through529 distinct original
dark-pixel samples. The first end is hidden by FG406. `prepare_elsa_hall_entry.py`
stages five actual tread polygons and source-painted material roles under
`Temple Interior/Hall Entry Candidate/` in the report. Fourteen headless topology/
footprint checks pass; original world XZ is exact and uses the existing ground-
sampled stair contract. The common11px/1.10245m height, closures,648-sample local
support and paving below relocated riser photos remain inferred/preliminary.
Unmasked native color/alpha is exact. Nearby native paving replaces the rejected
striped fill. The candidate is not installed or visually accepted in gameplay.

The central island door200,95 lands at59530(59,93), also the return event's tile
(graphic103010). Preserve it;60,92 is merely an adjacent approach. The draft
support currently leaves the landing at0 beside a-4.4098m approach, so support,
actor/native heights, collision and actual interaction must agree before
publication.59530's client payload is present; its observed2487 BG/82 FG entries
match the reference. Empty checkerboard BG entries do not establish missing map
data. The static composite has no visible paving at the landing; preserve the
original void and avoid inventing scenery to hide that contact uncertainty.

## Temple return events and staged entry support

The three corroborated temple return stones are explicit exceptions to the
later-ID exclusion: Event1930008/9/10 on59530 at79,55 /59,93 /81,133,
graphic103010. Their scripts return to59520 at175,62 /200,96 /228,128.
They use the existing yes/no travel dialogue; cancellation stays in the room.
The previous paired-return inference activated them automatically and used the
inbound landing for the central return. That behavior is corrected. Other later
records remain excluded. The public scripts carry Level>49 and LeaveGroup;
those version conditions are provenance, while current free Explore travel
stays available. Original-client behavior remains unverified. No home/login
change is introduced. Effective AnimeInfo records use the last row for each
appearance within its selected pack. The old103010 tiny icon was an obsolete
record; original:3171 supplies the full blue crystal and eight idle directions.
The three temple stones reuse the existing city travel-stone solid model and
retain their exact original NPC interaction points. 荷特普 likewise uses the
effective original:2911 instead of obsolete original:1326. All76 NPC art tokens
are checked against raw AnimeInfo tables and original frame pixels.

Source checks validate both the three scripts and all repacked NPC paint.
The18 targeted branch cases pass99 assertions, including cancel/retry on all
three stones. Population is now263 records; encounters remain195 zones.

The59530 descending stair candidate stays under the development report, not
canonical scenery assets. The existing HallSteps owner provides its shared
actor/native/physical support only when the review fixture registers the data.
Its inferred ramp grid, local ground cutout and extended existing boundaries
preserve source walking cells and exact XZ. The actual entry, held-input
ascent/descent and return to200,96 pass37 assertions. Candidate-only fixed
Metal views now pass19 assertions/four captures, plus14 on a corrected lower
viewpoint. Inspected views still expose source photo occlusion and unresolved
black landing contact, so the candidate remains unpublished. The generic fall-recovery guard
now uses the local floor below zero instead of resetting a valid descent to0.


The four return NPCs now route their normal F interaction through the same
yes/no travel used by E. Actual input verification passes29 checks, including
cancel/retry and exact free level1 landings with unchanged saved bytes.
Encounter species use the same effective-record selection;101913 changes from
obsolete original:1386 to original:2971. Rebuild with `--pack-creatures`. The
independent source test checks all29 species selections and504 affected native
bank frames, origins and clocks. Updated rendered native lifecycle passes54
checks; this is not a combat-balance or full-island visual acceptance result.
