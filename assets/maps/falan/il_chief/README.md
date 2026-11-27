# Il chief house, source graphic11268

`forest_il_chief.gd` is a bounded replacement for this building only. The existing
Il village placement,6×7 source footprint, collider and source door at(47,83)
remain owned by `forest_il_laruka_art.gd` and its travel systems.

The original344×522 artwork is preserved under
`build/Other Files/Asset Toolkit/Il and Laruka/Source/11268.png` and in the existing
Il/Laruka paint atlas. The isolated `front.png` is an exact lossless transparent copy;
the shared atlas is opaque outside the silhouette, so it cannot supply that mask.
Its decoded RGBA SHA256 is checked by
`python3 tools/prepare_il_chief.py --check`. That preparer extracts separate native
plaster, stone, timber, thatch, door, window and sign patches into this directory;
it does not edit the master or shared village art. The inferred roof backs reuse
the exact existing Il11272 straw tile, also verified against its native master;
source11268 paint stays on the observed surfaces.

Observed faces retain native paint at the city source-camera projection. Solid
stone courses, the octagonal plaster body, two flared thatch tiers, the upper
window drum, framed openings, bracketed sign and lossless rooster cutout provide
the silhouette and relief. Hidden faces carry the matching source part paint at
fixed world scale instead of wrapping the front building image around the back.
Hidden roof contours, block depth, cap bevels, rafters, rear window rhythm and
thin vane/sign depth are inferred from the visible design. There are no extra
doors, rooms or routes.

The isolated source-fit camera uses the city Euclidean projection. The actual
building uses the existing village height frame of.045 world units per source
pixel, retaining its XZ footprint. Its roof is near14.8 and its rooster near17.1
local units before the existing village owner's scale. The reference-only source
capture and the actual village capture are labeled separately; city height units
are not applied to the playable village.
`tests/forest-shrine/il_chief_review.gd` captures that native axis and the actual
village from normal gameplay cameras at two walkable source cells. Passing a
parse or a source hash check does not establish visual approval. The review
artifacts live under `build/Other Files/Asset Toolkit/East Gate Region/Il Chief/`
and `Verification/IlChief/`.
