# Source-measured East-region landmarks

The editable measurements and native material samples live in
`tools/prepare_east_region_landmarks.py`, `tools/east_region_landmark_profiles.py`,
`tools/east_region_living_trees.py` and `tools/east_region_classic_landmarks.py`. Regenerate with
`PYTHONDONTWRITEBYTECODE=1 python3 tools/prepare_east_region_landmarks.py`.
`profiles.json`, the small material atlas and alpha derivatives are generated
from the preserved East native catalog. They never replace its original paint.

`forest_east_region_art.gd` reuses the existing coastal mesh, profiled round
parts, timber rods, Wind Meadow trees and source projection contracts. The
existing OriginalMaps object batch remains the rendering owner. Source map
cells, graphic origins/footprints, navigation, entrances and quest behavior
remain authoritative.

Measured parts cover Goral curved houses, towers/spires, palace domes, gate arms
and piers; Akelufa living treehouses and shrine; observatories, leaf huts,
continental temples/palaces, ruins and cave mouths; boarding stairs and native
rowboat/mast/sail. Matching classic houses, office, chief house, round towers and
writing desk reuse the existing whole source kits. The generic city/village
masters and original native atlases are unchanged.
Visible faces project the original native paint. Hidden roof faces, masonry,
wood and bark use independently sampled material tiles rather than a front
sprite wrapped around the building. Source-native weather vanes and thin
open filigree remain thin, two-sided detail. Existing Wind Meadow trees supply
compatible standalone trees. Living-house crowns retain their native leaf pixels
on crossed alpha surfaces, with actual branches buried inside opaque junctions.

Each of the seven living-house drawings has its own curved trunk axes, canopy
depth planes and cut-stump flags. The four cut rims follow the observed native
outline; their physical cavities have inner walls. The shrine's four blue ceramic
spires retain measured tips, curved tiers and pale bands. Rear root growth,
chamfered corners, bark-covered structure and bounded plaster infill are inferred
from the source-facing design, without adding rooms or doors.

The authoring/reference calibration is H=32/3 pixels, floor shear=8 pixels and
V=sqrt(2*(H*H-8*8)). Gameplay then applies the existing OriginalMaps vertical
owner frame (.045 world units per pixel) once, preserving XZ, UVs and anchors.
Reused meshes are first fitted in the reference frame; existing measured cliff
profiles already in the .045 owner frame skip that final conversion. A native
axis study and the normal gameplay camera are separate review evidence.

**Inferred details:** unseen backs and corners, roof profiles on hidden sides,
round trunk/dome depth, structural timber below stairs/platforms, sail billow,
and foliage depth. Front measurements do not establish exact hidden geometry.
The distinct crystal serial binding in maps32265/32266 is catalogued separately
as an inferred graphic namespace correspondence. The 23 individual31954
600xx-to260xxx bindings use the same explicitly inferred correspondence; there
is no verified client namespace for that unprefixed map file. Thin ropes have
real rods, plank tiles retain flat native art, and gate posts have stone/wood
volume. Native source cells and pixels remain unchanged.

Ten individually inspected leaf, flower, hedge and small-stone graphics reach
`minor_prop_mesh` through the East object's final generic `prop` fallback, after
all existing exact owners. Structural forms retain their volume owners. It keeps source
alpha on an anchored fixed card or thin floor piece instead of a textured box;
this does not establish unseen 3D geometry. These meshes share the existing map
batch and never change collision, navigation, rooms or quests.

`tests/forest-shrine/test_east_region_landmark_source.py` checks source hashes,
measurement bounds, calibration, unchanged cloth RGB, alpha-only shadow removal
and separate reverse-gate paint. `east_landmark_review.gd` captures normal and
second walkable gameplay viewpoints plus a fixed native-axis overview. Source
and parser checks do not certify visual fidelity; inspect those captures before
accepting any reconstruction.
