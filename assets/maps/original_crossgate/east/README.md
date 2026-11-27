# Eastern fixed-map supplement

`tools/prepare_east_region_maps.py` prepares fixed source maps reached from the
East Gate, including the recovered Il harbor/ship route and its original
continents. Scope and source hashes come from the pinned reference manifests
under `build/Other Files/Asset Toolkit/East Gate Region/`. The route checklist,
script audit and generated-dungeon specifications remain separate owners.
Downloading a source map does not itself establish that every entrance or quest
predicate has been implemented.

Regenerate with `python3 tools/prepare_east_region_maps.py`; use `--check` to
compare the saved catalog and all generated native-paint pages. `--render`
also writes selected original isometric room references under the toolkit
report folder. Repeated `--manifest PATH` arguments select explicit manifests
instead of the six default eastern/harbor/continent/harbor-quest/version inventories.
Only maps owned by those inventories are activated; downloaded boundary plans
remain source evidence. Existing Falan interiors 1000–1999 keep their established
owners; the already connected house 1155 retains its explicit custom owner.

`raw` and `sha256` always retain the complete original client bytes where a
client cache exists. The flags, header and every recorded floor/object cell
remain unchanged. `restored_raw` fills only unrecorded cells from an independently
hashed LS2MAP with a compatible overlap. `reference_only` identifies layouts
whose client cache is absent. Version disagreements are recorded in
`fixed-map-preservation.json`; they are never blended into a hybrid map.

For new maps whose client version differs, a complete pinned original version
can be selected explicitly with `active_layout_variant: "pinned-reference"`.
Its separate `reference_variant_raw`, hash, size, byte length and provenance
retain that complete source version. The original client `raw` remains intact.
The catalog's `size`, `bytes` and navigation mask describe the selected active
layout; `native_size`/`native_bytes` describe the retained client. Existing room
owners keep their native layout, and the seven custom house/village/Habaru
owners carry `east_existing_owner: true` to preserve their special presentation.

Native EX/CG2/TW maps store expanded serials minus 200000. Filename prefixes are
matched without case sensitivity. Using those compressed
numbers directly can select unrelated portraits or collide with Elsa's CUT
graphics. Each map's `graphic_aliases` translates only presentation lookup to
`1000000 + expanded_source_serial`. Original map planes and navigation retain
their native serials. Alias graphics record both `source_serial` and
`source_native_serial`, their source pack/row, original origin/footprint and
lossless RGBA hash. Shared original graphics reuse the existing base, Sokia,
university and Elsa catalogs; no shared atlas is repacked or overwritten.
Later map discoveries also reuse this supplement's previous native pages when
pack/row, origin and footprint match and the atlas crop retains its RGBA hash;
only newly needed art is appended. The solid-paint byte-span fill is checked
against the established nearest-edge extension pixel for pixel.

Unprefixed maps 32265/32266 retain their low floor/wall graphics. Their only
unavailable native serial 60057 is explicitly bound to original graphic 260057,
the unique available blue teleport crystal/pedestal. `inferred_graphic_bindings`
records this visual namespace inference: the pinned map does not prove that
client correspondence. No native map values are rewritten.

Map41029 is an original storm-sea cutscene, with no native walkable terrain.
Its explicit `walk_override` opens only the center3×3 source cells x4–6/y4–6
for the original landing(5,5) and exact surrounding EventNPC ring. This is a
technical interaction adaptation, not original terrain; source planes and sea
art remain unchanged. The preservation report records the same nine cells.

New graphic `page` and `surfaces[0]` indices are local. The lazy runtime loader
appends `pages`, `solid_pages` and `surface_pages` to its current arrays and adds
the current corresponding offsets to these new records. Page paths are relative
to `assets/maps/original_crossgate/`. `reused_graphics`, `requires` and
`shared_catalogs` record shared-art ownership and input catalog hashes.

The preparer does not invent rooms, routes, encounters, NPC placement or 3D
geometry. Rendering the original planes is source evidence, not approval of
their 3D reconstruction. Verify source preservation with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/forest-shrine -p test_east_region_maps_source.py
```
