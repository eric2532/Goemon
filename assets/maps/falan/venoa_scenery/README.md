# 海洞 to 熊洞 scenery

The expanded [索奇亞 + 維諾亞村 goal](../sokia/README.md#required-索奇亞--維諾亞村-goal-scope--2026-11-26)
requires the entire surrounding outdoor area, every source-confirmed entrance
and each map/zone/floor's complete original encounter roster, including rare
variants, mixed groups and bosses. Historical road-only exclusions and completed
visual reviews below do not complete that goal. Missing maps, missing enemy art
and unverified encounter rules must stay separate and open; verify scenery from
fixed gameplay cameras and representative fights through direct triggers.

The original reference is the adjacent Magic Power archive: Freyja `100.dat`,
熊洞 `11000/11001/11002/11022.dat`, cliff graphic 12543 and the original
13324–13359 cave rock family. Original art, maps, navigation, stairs and bear
slots remain with their existing owners. No Blender master or GLB was replaced.

`cliff_stone.png` and `cliff_moss.png` are native opaque crops of graphic 12543,
mirrored at their edges without resampling or repainting. Exact record, crop
bounds and source RGBA hash are in `provenance.json`. Keep mipmaps enabled in
their import settings. `cave_rock_atlas.png` derives two stone-face samples from
13355. Baked dark crevices are replaced by the nearest solid stone pixel from
the same crop, retaining only original colors; the new geometry supplies the
actual crevices and shading. The original cave atlas stays intact. Rebuild or
check from the complete source:

```sh
python3 tools/recover_venoa_scenery.py
python3 tools/recover_venoa_scenery.py --check
```

Editable procedural geometry remains in
`scripts/forest/forest_freyja_destination_art.gd`: `crag_cluster` assembles nine
of the existing ridge pieces inside each southern cliff footprint; `cave_crags`
fits three narrower stones behind each original cave boundary segment. The
original backing wall is recessed and capped, then shaded as a dark crevice.
Shallow ridge pieces soften pool edges. These are visual surfaces; the existing
collision, native navigation, ceiling headroom, doors and stairs remain intact.

`forest_falan_frontier.gd` changes southern tree presentation to the existing
Wind Meadow cedar/pine/broadleaf family at original anchors. Its native scenery
plan and obstacle bounds remain unchanged. Do not move the collision owner into
these visual recipes. `forest_stone.gdshader` reuses its existing rock/face
texture slots for the new stone/moss blend on owned southern materials only.
`habaru_ceiling.gdshader` applies the darker backing/roof and denser stone paint
only to the Venoa cave family. Other caves retain their existing materials.

All geometry is built at area setup and indexed without changing its shape.
Keep the single extra cave stone surface rather than a node per stone. Preserve
the unmodified source pixels, original wall-face atlas and reusable model masters.
The added crags and unseen rock faces are source-informed 3D interpretations.

Run `tests/forest-shrine/venoa_scenery_review.gd -- --venoa-undersea` through
Play Goemon for matched road, entrance and cave views, complete road clearance,
geometry clearance, all cave floors, native bears, boss and shortcut returns.
Evidence and source references are in
`build/Other Files/Asset Toolkit/Venoa Scenery Recovery/`.

Kili continuation (2026-11-17) reuses the unchanged stone/moss crops and
`crag_cluster` geometry for the same cliff graphics on Sokia's coastal approach,
including its undersea recess. Kili's existing source banks remain separate.
This changes visual surfaces only; the original coast collision, source cells
and mouth profile stay with their current owners. Review evidence is under
`build/Other Files/Asset Toolkit/Kili Village Recovery/`.

## Source-based village forms — 2026-11-23

The current user workflow is source-supported changes by connected area, with
short in-game review notes. Do not generate further walkthroughs or verification
screenshots for this pass; the user will review on a later source launch.

The editable form records are `FORMS` in `tools/recover_venoa_buildings.py`.
They record native foundation stations, visible gable curves, opposite ridge
stations and roof-furniture positions for graphics 11276/11279/11280/11283/11284/
11286. `venoa_buildings.*` contains the generated paint, provenance and runtime
records. The original archive and `coastal_building_art.png` remain unchanged.
Changing form records does not change the maps, door markers or physical plans.

`forest_venoa_buildings.gd` reuses the coastal source mesh/round-part builder and
Tina's source-painted roof clipping. It prepares one immutable mesh per graphic.
The existing coastal loader supplies all seven placements and keeps their old
collision boxes. Other atlases/custom data retain their existing building path.
The old uniform roof/chimney recipe is excluded for these canonical Venoa forms.

Review locations:

- Chimney houses: native flared roofs, paired hollow pots and open stone flues.
- Pink-roofed residence: two raised dormers, with the wider rear eave curve.
- Long equipment shop: raised facade, support posts, cross-gable and both entry
  stair surfaces. Its existing door links and collision remain authoritative.
- Bell building: corrected roof axis, pitched timber belfry, bell and yard wall.

Native pixels establish the visible forms. Hidden depth, obscured foundations,
rear faces, concealed structural details and the single-view-to-3D conversion
remain inferred. These edits have not been accepted as a 1:1 appearance match.

Native wall graphics 11252–11265 now share `solid_native_paint` with the building
preparer. It removes boundary-connected gray-71 checkerboard ground shadow,
then reuses the existing opaque edge extension. It preserves all other opaque
RGB, including black/green flue interiors and dark wood carving. The earlier
brightness filter was incorrect and has been replaced. Source RGBA hashes and
removed shadow counts are stored in both provenance files.

```sh
python3 tools/recover_venoa_walls.py
python3 tools/recover_venoa_buildings.py
python3 tools/recover_venoa_walls.py --check
python3 tools/recover_venoa_buildings.py --check
python3 tests/forest-shrine/test_venoa_paint.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/explore_venoa_buildings_test.gd
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/explore_southern_walls_test.gd
python3 tools/goemon_assets.py check
```

The focused checks cover source-station projection, mesh reuse, usable normals,
all seven building placements and their seven old physical shapes; the wall
fixture covers 164 placements/physical shapes. They produce no captures. Asset
checks do not establish visual acceptance, frame time or long-session behavior.
Current logs are under `build/Other Files/Asset Toolkit/Explore Visual Match/`.


The final source-camera correction converts the internal .045 m/pixel geometry
once to physical height 1/sqrt(2*((32/3)²-8²)). UV stations and native paint remain
unchanged, and inverse-transpose normals preserve shading. Both the six building
forms and fourteen wall forms receive this correction; no collision changes.
The fixed area list and reference-gap handoff are in the parent Falan README.


## Ruby-region visual reconstruction — 2026-11-25

The current request explicitly requires fixed-view review. Its scoped visual
owner is `scripts/forest/forest_ruby_region_art.gd`, prepared by
`tools/prepare_ruby_region_art.py`. Source trees/palms/fences retain native cells,
fit measured visible bounds and reuse the existing flora, palm and fence masters
with owned palette materials. Existing seven Venoa house placements/forms and
Kili’s native flat-roof kit remain authoritative. Kili/coastal wall ornament
paint is an owned derivative over the existing meshes.

The 12536–12565 cliff family now uses each actual native graphic’s contour and
whole visible paint instead of repeated generic clusters within Venoa and the
reviewed Southern Lakes/Sokia Coast bounds. Only visual duplicates are omitted;
the original physical plans and obstacle owner remain. Source black void is
excluded from rock geometry, and hidden surface depth/color remain a recorded
3D adaptation. Other routes retain their existing visual path.

The complete recipe, fixed-camera metadata, per-map findings and limitations are
under `build/Other Files/Asset Toolkit/Ruby Region Reconstruction/`. Do not
interpret a matched source bound as proof of exact foliage volume or terrain
height; native maps contain no authoritative walkable heightfield.


Single palm crowns additionally fit the original leaf width/height already
measured in `sokia/details.gd`, independently of whole-tree bounds, retaining
the original trunk attachment. Their owned derivative is not stored in the
shared palm cache. Traced and compound crowns keep their existing geometry.
Owned two-sided frond materials apply only to batches fully within this region.
The existing Sokia source/master preservation check still verifies the reused
recipe, source paint, curves and original palm model. Crown depth is a fitted
adaptation from one view; it is not recovered original depth.

The named cave approaches at Southern Lakes (341,496) and Sokia Coast
(237,265) still expose a source-depth blocker: the fitted cliff volumes can
overhang/obscure the recessed mouth from the low gameplay camera. Native open
cells and original isometric bounds are known; their true solid depth/elevation
is not. These views remain explicit unresolved visual mismatches in the handoff,
despite passing transition checks. Do not certify those entrances as 1:1.
