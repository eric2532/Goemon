# Southern Lakes southwest source extension

`tools/prepare_venoa_field.py` prepares this derivative from original client map
`BlueCrossgate/map/0/100.dat` (840×610) and the preserved existing
`assets/maps/falan/south_lakes_surface.png` (321×321).

The existing `south_lakes` source frame stays at source (387,463). The derivative
adds 26 columns on its left: source bounds `(201,303,347,321)`, local origin
`(-558,-480)`. Every existing RGBA pixel remains byte-identical at offset (26,0).
The original mask is not rewritten. `provenance.json` records source hashes,
672 newly included decoder-open cells and 80 original object anchors.

Regenerate with `python3 tools/prepare_venoa_field.py`; verify with the same command
plus `--check`. The existing 1.5 field expansion convention accommodates this
asymmetric native mask. Fresh layouts publish 1.5 and Model preserves compatible
older saved layouts that lack that property. Existing source coordinates, native
collision and navigation owners are retained.

World reuses the existing native-mask player-bounds convention for Southern
Lakes, preventing normal input from walking into the larger field's invisible
padding. This is an intentional clamp change; it retains existing water support
inside the rectangle and does not alter the protected old terrain samples.

`visibility.png` clips unused expanded background through the existing Freyja
land-visibility shader. It is not an original walkability mask. The native mask's
wet/road/paving channels remain responsible for terrain interpretation.

`water.png` is a separate 840×610 full-source water derivative, using the same
classification as Sokia: red marks original `is_water` tiles; green marks known
non-water ground. All 512,400 pixels are checked against original map100. Ground0
remains unclassified and is not silently filled as confirmed ocean. The full
water plane supplies visuals only; local ground visibility, player bounds and
water-walking support remain under their existing native owners. The preserved
local mask includes 14 rows beyond original source height; they are inherited
bytes, not source-confirmed ground or water.

`ocean-backdrop.png` is the separately authorized unseen-surface judgment: a
visual-only 840×624 mask. It fills source0 with inferred ocean, pads rows610–623
for those inherited wet rows, and preserves every known source pixel exactly.
It adds no terrain, routes, navigation, support or encounter coverage. The
authoritative WATER mask remains unchanged.

`ocean-index.png` reuses the original graphic5000 water art through the existing
Freyja atlas. It preserves all 173,625 nonzero source cells' original canonical
index RGBA bytes and fills only source0 plus rows610–623 with the existing
graphic5000 encoding `(5,1,255,255)`. This prevents the inferred backdrop from
falling back to a different water texture/color. `OCEAN_INDEX_PATH` is a string;
only Southern Lakes water setup loads this derivative, after the normal archive
surface binding. Native terrain keeps `freyja_ground_index.png` unchanged. These
filled cells remain inferred background using original art, not newly recovered
source layout or playable coverage.

The index import is lossless, has no mipmaps or alpha-border repair, and does
not premultiply or remap color. `--check` enforces its data-import contract.
Canonical index import settings remain untouched. The runtime review compares
all imported index RGBA bytes against the prepared PNG, including 37,596
transparent nonzero source placeholders.

The terrain package lists its 80 original object anchors separately from scenery
verification. `scenery.json` now restores those exact stations through
`forest_venoa_southwest_scenery.gd`: 22 trees, 49 shore forms, eight flower patches
and one stump. The preparer is `tools/prepare_venoa_southwest_scenery.py`; use
`--check` for source/asset preservation and `--review` for original composites.
See the canonical evidence directory
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/` for
map100 union counts, preserved old field samples, native navigation checks and
fixed gameplay-camera views. Metadata/envelope coverage does not establish
complete source art fidelity or that every original decoder-open cell supports
the adapted native combat clearance. Encounter rules are not changed here.

Trees reuse the approved Cross Gate flora GLBs and Ruby source fits. Only owned
canopy materials get the crown-only linear native/base tint; original bark,
meshes and old Ruby material tints are preserved. Shore forms reuse
`forest_tina_ground.gd::bank_mesh` and full original base/east atlas art. Their
height/depth fits the preserved terrain/water visually and adds no support.
The nine low plants/stumps remain source-open. Only the 22 source-blocked tree
cells receive the existing 2.5 m trunk obstacle, with established player-passable
tree behavior. Full appearance, geometry and native-clearance qualifications
are in `SCENERY_REPORT.md` beside the evidence.

`scenery.json.offshore_placements` separately preserves five original water-flower
anchors at map100 `(20..24,7)`, graphics12175–12179. These ground/object cells
agree in the client cache and pinned server `00100_field1`. The existing scenery
owner reuses whole Meadow flower meshes with each source graphic's measured fit
and leaf/petal colors, rooted at the existing full-source water height. They add
no land, support, collision or navigation; the original80-anchor strip stays
unchanged. The normal63° camera studies are explicitly camera-only views beyond
playable land. Their source/rendered evidence and geometry/lighting qualifications
are in `Freyja union audit/Art gaps/offshore-verification.json` under the canonical
Sokia Venoa Coverage directory. The broader union/art inventory remains a client
variant baseline until validated server-only stations are reconciled.

The bounded source southwest recovery is published. Its132 land stations
retain the original80-prefix and add52 exact source anchors:35 in the added
x193–200 columns, plus17 adjacent stations in the same headland. The active package
keeps the five existing offshore flowers; the inactive full stage adds the remaining35
source-water props (27trees,4stumps,4flowers) at their original coordinates.
Their source-ground remains water. They add no land, support or collision, and
their original placement intent is not inferred from the arrangement.

Use `--source-extension` for the bounded headland or `--complete-source` for
the full offshore set, with `--out` pointing into the canonical Asset Toolkit
staging directory. Set `CROSSGATE_FREYJA_SOURCE_DIR` to the matching prepared
source folder; `--check` verifies that output. Use `--source-extension --check`
for the current132+5 package. The old80+5 output is retained as historical
preservation evidence, rather than the current canonical data.
Both stages preserve every previous graphic record and reuse the same whole
tree/flower models, original-painted stump forms and shore owner. Only the27
land-tree trunks own obstacles; the terrain preparer delegates those cells
rather than adding duplicate generic stone colliders. A35-check headless owner
fixture verifies unchanged old mesh/material/tint/transforms, exact prefixes,
bounded caches and protected source hashes before publication. A concurrent
shared-catalog metadata edit required fresh source preparation: all60 graphics
and all source placement/palette records stayed exact, and all30 used runtime
atlas crops/origins/sizes were rechecked against original art. The old guard and
failed check remain retained; no authored preservation baseline was rewritten.

The current rendered scene passes30 checks with three nonblank63° views. All132
actual MultiMesh anchor positions match the original cells (maximum measured
error0), all27 trunks retain native obstacles and player-passable behavior, and
no previously verified old native point is lost. Actual forward input reaches
source198.4647 from204,420. The204,420 view uses the exact protected before eye,
rotation and FOV. Close foliage occludes parts of the west/north views; shore
depth and unseen faces remain3D fits. There are zero script errors and seven
Metal fence diagnostics; this is not a smoothness measurement.

Source-open shore centers195,420 and210,407 remain rejected by the inherited
four-corner finite-radius terrain rule because an adjacent corner is original
water. They have no obstacle overlap. This native/source-fidelity gap stays
required work; the water mask/support was not expanded to make the query pass.
The earlier headless transform readback returned identity matrices and cannot
certify scenery positions. Current rendered buffers provide that proof.
Evidence is in `Freyja full-source scenery/headland-rendered.json` under the
canonical Sokia Venoa Coverage directory. Whole-map100, its35additional offshore
props and original encounter boundaries remain required work.
