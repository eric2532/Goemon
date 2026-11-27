# Komatei native ruin sections

`tools/prepare_east_ruin_sections.py` copies the ten exact native records and
prepares a small owned surface atlas and measured construction data. `--check`
verifies the derivatives against the preserved source library. Every record's
original pack/row, RGBA hash, origin and footprint is retained in `data.json`.

`forest_east_ruin_sections.gd::owns(serial)` / `mesh(serial,graphic)` owns only
`1233270..1233275` and `1233279..1233282`. The cached immutable mesh is already
in OriginalMaps' `.045` height-per-pixel frame. Apply no additional owner Y
conversion. OriginalMaps retains instance transforms, source cells, collision,
walk masks, doors, actors, quests and routes. The raised decks and window
recesses are render geometry; they add no walkable upper floor or route.

The existing WindMeadow wall/tower/gate ruin masters were inspected first.
Their complete authored silhouettes do not match these square CG2 turrets,
thin lower wall shafts with wide broken upper caps, or raised polygonal decks.
They remain unchanged. The new sections reuse Tina's native source-foot/contour
contract and `forest_falan_building_shapes.gd::extrude` for closed modular stone.
Observed faces keep native projection; hidden faces use independently tiled
native stone/cap/floor samples, with a private material for shaded recess backs.

Source-view evidence and explicit inferred geometry are documented in
`build/Other Files/Asset Toolkit/East Gate Region/Komatei Ruins/`.
`tests/forest-shrine/east_ruin_sections_review.gd` captures all ten source/reverse
models and representative actual map camera pairs. Technical checks do not
replace the separate visual judgment.
