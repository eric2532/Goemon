# Kili and Ghana native street fixtures

The original map-3200 and map-3000 object planes supply every placement in
`data.json`: 139 Kili and 103 Ghana placements omitted by the preceding scenery
ranges. Source crops, origins, footprints, bounds, pack/record identities and
RGBA hashes are recorded. Original client maps and assets remain read-only.

`tools/prepare_kili_ghana_props.py` prepares the atlas and inventory;
`--check` reproduces them in a temporary directory. The established outdoor
setup calls `forest_kili_ghana_props.gd` once. It reuses the shared native solid
builders, original-paint projector, woodland masters, material caches and 48 m
batches. Ten Ghana tree variants fit the original bounds/colors using those
masters. Fine cloth, notices and bones use native cutouts; ground bones lie on
the ground plane. Carts use reusable deck/handle/wheel primitives. New geometry
adds no collider, actor, encounter, targeting loop or per-frame asset work.
Hidden depth, reverse faces and the fine source tree crowns remain inferred.

`forest_kili_building_details.gd` supplies individual low terrace cap contours
and shallow raised native door/sign paint to the existing eight-piece building
kit. Existing footprints, door ownership, chief-house tiers, hospital belfries,
shop wings and arcade remain authoritative. `forest_ruby_region_art.gd` keeps
projected native paint on the two recorded wall faces; caps/backs retain the
complete kit's tiled stone, avoiding stretched dark edge pixels from the one
original view. Geometry and collision dimensions are unchanged.

Ghana's 13 interiors now use the complete coastal room preparation, including
all source walls/furnishings. The three missing cache houses use pinned distinct
classic layouts under `assets/references/crossgate_ghana_houses/`; these are not
independently captured BlueCG versions. `tools/prepare_kili_ghana_rooms.py`
updates only their masks and housing thresholds, preserving every other room
and link. Full future generation uses the same `load_map` source path.

Before/after evidence and separate village checklists are in
`build/Other Files/Asset Toolkit/Kili Ghana Villages/`. Fixed source-aligned
isometric views are the visual handoff; raw close gameplay captures include
obstructed cameras and are retained as diagnostics. All 27 interiors and four
gate round trips were checked; the user retains the full street walkthrough.
