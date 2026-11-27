# East native fallback families

Prepared by `python3 tools/prepare_east_fallback_families.py`; verify with `--check`.
The 32 native PNGs are exact decoded original RGBA records. `data.json` records their
native pack/row, hashes, origins, alpha bounds and footprints. Originals remain
under the source library. `surfaces.png` contains padded, seam-blended native
stone, gold and cap samples for independently painted closed hidden faces.

`forest_east_fallback_families.gd::mesh(serial,graphic)` returns one cached,
immutable mesh in the existing OriginalMaps `.045` world-height-per-pixel frame.
It owns only `10474/10475`, `11150/11151`, `11188..11208` and `1235161..1235167`,
only when the caller selects
the East object-layer final-prop fallback. Other owners and regions retain their
previous meshes. Placement, source grid, collision, navigation, doors and quest
ownership stay with the existing map runtime.

`11150/11151` reuse every Body/Canopy triangle of the existing WindMeadow
`cg_woodland.glb` master, the Kili source-bounds fit and the existing native
dry-leaf palette ratios. All 21 palms reuse their exact existing Sokia profiles'
original trunk/fronds, including the multiple-stem profiles. Ruby's existing
separate native-crown correction applies to the single-stem forms.
Each receives one source-bounds fit
and one East owner-height conversion. No GLB, Blender master or shared material
is edited.

The palace's native 64×48 cap measures a 3×3 section and 8.1 world-height; the
shorter `1235163` measures 6.525. The two 128×96 caps measure 9×3/3×9 beams over a
single source post. Their source walk footprint remains 1×1. Native paint is
projected only onto the two observed faces. Stepped bases/capitals, beam braces,
hidden flutes and the closed native-tiled rear are inferred solid reconstruction.
They are not additional source routes or collision volumes.

The fixture is `tests/forest-shrine/east_fallback_families_review.gd`; development
launcher captures and separate visual judgment belong under
`build/Other Files/Asset Toolkit/East Gate Region/Fallback Families/`.

`10474/10475` reuse `forest_falan_courtyard.gd::ironwork`: five bars, five caps and two rails.
Native structural bounds exclude the baked ground shadow. Each panel retains
its original axis, native iron palette and thin closed bar/cap geometry.
The East cache variant is distinct from every other region's fence/grille owner.
