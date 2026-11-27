# Native East tree fits

Private candidate; no live runtime hook yet. `tools/prepare_east_native_trees.py`
records27 original drawings, alpha-visible bounds, source anchors/footprints and
linear-light foliage/bark tint measurements. The three whole originals remain
under `assets/models/environments/wind_meadow/crossgate_flora/`; all source GLB,
leaf/bark images, mesh topology and UVs are unchanged.

The first27 whole-master trial is rejected: the16 conifer crowns were too round
and a green-only color sampler lost blue-gray needles. Its code/data/images are
preserved in `Typed27/Rejected Whole Master Trial`. The current16 conifers reuse
the existing39-tree source-traced timber/native-tier-crown recipe; original
needle colors/alpha and visible tiers are preserved. Crossed thin crown depth
and hidden round trunk sections are explicitly inferred.

The11 broadleaf variants keep compatible whole masters with cached CPU points
and per-ID source-bound fits/private linear-light tints. Palette sampling now
includes blue/neutral foliage. Both paths apply the existing OriginalMaps `.045`
owner-height frame once. No original front picture is stretched around a box.

Native source rectangle and colors guide the fit. Hidden volume and tint are
inferred, and the individual leaves/branches do not become a pixel-for-pixel
copy of the original sprite. Rendered silhouette/tint review is separate from
source/geometry tests. The old whole-master trial passed224 technical checks and
still failed visual review. The revised two source tests and144 geometry checks
pass after importing the32 private crown/branch images. The new angle review
remains pending; no live hook is enabled.

Keep any eventual hook eastern and object-layer only, after existing contextual
owners. The eight non-tree pictures in the historical numeric tree range
remain assigned to furniture/architecture owners. No map raw cells, navigation,
colliders, actors or other regional owners are changed by this candidate.
