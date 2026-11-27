# Il and Alyut source buildings

`tools/prepare_east_village_buildings.py` and `--check` preserve five exact native
RGBA copies (11269,11271,11272,11273,11275), two original rooster cutouts, and the
source hashes, footprints, centers and house warps for all13 major buildings in
maps2000/2400. The approved chief11268 and shared civic10607 retain their existing
appearance owners. All eight Il placements were already at the original centers.
The five Alyut author hints were replaced with verified original cell centers.

`forest_east_village_buildings.gd` reuses the approved chief's source projection,
octagonal construction and layered thatch method; the Il/Laruka timber/window
parts; existing native surface tiles; and the existing roof/dormer studies.
`round-surfaces.png` keeps that atlas layout and replaces only the straw tile
with a rectified11269 patch, preserving the round houses' original green tone.
Observed faces retain native paint on solid walls, roof slopes, dormers and
shallow ridge ornaments. Their alpha silhouette preserves the native thatch
fringe. Hidden walls/slopes have independent part paint at fixed world scale.
The roundhouse retains its octagonal body, upper drum, two thatch tiers, original
rooster and observed lantern. The winged building has closed timber wings.

Hidden wall and roof contours, wing backs, eave thickness, rear window rhythm,
ridge ornament depth and roof supports are inferred3D reconstruction. They are
not recovered original meshes. No new doorway or route is inferred. Source map
files, native masters, interiors, NPCs and quest ownership remain intact.
Laruka/West do not use this helper. Models/materials are cached at setup; no new
frame update or gameplay simulation is added.

The isolated source camera uses the Euclidean city frame. Actual villages keep
the established.045 world units per original height pixel; the Y adaptation is
applied exactly once. Source-axis images and real gameplay images are labeled
separately. A source hash or successful parse does not establish visual approval.

For further repair, keep the complete tiled solid underneath observed paint;
native alpha cannot replace the backing on a roof visible from another angle.
Round roof backs use the round houses' own straw part paint, keeping photographed
front details off the hidden slopes. Ridge ornaments attach by their measured source-pixel position
along the real ridge, rather than an evenly spaced guessed station. Check both
the source camera and a reachable gameplay corner after changing those fits.

Run the review through the existing desktop launcher and shared fair queue:

```sh
python3 tools/prepare_east_village_buildings.py --check
zsh 'build/Other Files/Asset Toolkit/East Gate Region/Verification/queue_one.command' --script res://tests/forest-shrine/east_village_buildings_review.gd
```

Evidence lives under `build/Other Files/Asset Toolkit/East Gate Region/Village
Buildings/` and `Verification/VillageBuildings/`. The review checks the actual
13 scene owners and footprint colliders, all11 original house doors through
player-control micro-approaches and returns, and normal/second cameras above
connected walk-grid cells for each changed building type. It is a focused visual
and source-layout review, not a whole-region playthrough or performance claim.
