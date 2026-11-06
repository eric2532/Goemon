# Wind Meadow — original landscape kit

The compatible modular expansion (2026-10-31) is documented in
[`docs/wind-meadow/modular-kit.md`](../../../../docs/wind-meadow/modular-kit.md).
It adds seven existing-owner ramp/deck/junction recipes and three rock/fence compositions.
Its scenes reference the existing exports; no master here was duplicated or
regenerated. Use that guide for pivots, native support and the separate test map.

Created 2026-10-23 from the user's supplied open-air fantasy landscape reference.
The art uses new geometry and colors; no game assets or screenshot pixels were extracted.
The chosen [Game Art Style atlas](https://gameartstyle.loopyhop.com/) was consulted for visual direction.

Open any `.blend` here in Blender. These are the editable masters. One Blender
unit is one metre; origins sit at ground level; Blender Z-up exports to Godot
Y-up. Meshes use linear `Color` vertex colors, a UV layer, and rough materials.
The mountain's original 512px painted stone texture is packed into its master
and GLB, with an editable PNG in `assets/textures/wind_meadow/`. `Body` and `Canopy` stay separate so
the existing forest renderer can eventually retain its canopy cutaway behavior.
Grass/flower stems remain anchored at local Y=0 in Godot; the preview bends tips
with a shader. Blender masters contain static rest geometry.

| Asset | Triangles | Meshes / materials |
| --- | ---: | ---: |
| Short grass | 135 | 1 / 1 |
| Tall grass | 180 | 1 / 1 |
| Blue, ivory, coral flowers | 95 each | 1 / 1 each |
| Broadleaf tree | 6,396 | 2 / 2 |
| Leafy shrub | 1,920 | 1 / 1 |
| Terraced mountain | 4,078 | 1 / 1 |
| Mossy boulder | 670 | 1 / 1 |

After editing a saved master, export it using the existing exporter:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/environments/wind_meadow/broadleaf_tree.blend \
  --python tools/export_blender.py
```

Runtime GLBs live in `assets/models/environments/wind_meadow/`. Run the asset
audit and `check`, refresh Godot imports, then inspect the rendered preview.
`tools/build_wind_meadow.py` is initial generation only; it refuses to overwrite
these masters. Saved tree/mountain refinements and the painted cliff texture
supersede the initial generator. The user's grass revision makes blades 45%
shorter and about half as wide, with rounded caps and smaller placement scales.

## View the meadow

Close the currently running game, then open `docs/wind-meadow/Preview Meadow.command`.
It uses the normal desktop Play launcher, refreshes imports, and runs the asset
study from the same complete project. Drag to orbit, wheel to zoom, Escape to
close. It never loads or writes gameplay maps. Normal Play still opens Goemon.

The scene and shaders are `tests/forest-shrine/wind_meadow_*`. Native Metal
captures and audit/test logs live in `build/Other Files/Asset Toolkit/Wind Meadow/`.

## Why the floor looks better

Use broad green color variation on the ground, with thin painted strokes that
stay subtle at distance. Match the blade roots to that ground. Scatter small
shared grass meshes in uneven patches, add taller grass at edges, and cluster
flowers instead of spacing every plant evenly. Keep warm worn earth along paths.
Large tree crowns, cool stone, warm sunlight and blue distance haze complete
the palette; changing a grass model alone cannot provide the whole look.

## Playable valley integration

Normal `Play Goemon.command` now opens Wind Meadow Valley. The independent art
study remains available. Runtime materials live under `scripts/forest/`, with
shared source loading/batching in `forest_wind_meadow_assets.gd`. Reuse these
masters and GLBs; no approved mesh was regenerated for map integration.

`forest_wind_meadow_layout.gd` authors terrain/routes/landmarks;
`tools/build_wind_meadow_map.gd` bakes the same height triangles for physics,
native armies and corridors into `assets/maps/wind_meadow/`, and writes the
bundled `forest_wind_meadow.json`. Terrain, roads and decorative placements are
deterministic. Grass/flowers use spatial batches, GPU wind and 28–46 m fade;
canopies support the existing hero cutaway. Large rocks and mountains are scenery.
Existing tree obstacles and building/gameplay collision remain owner-controlled.

The default castle uses the original perimeter, with four destroyable cardinal
barracks beyond it. The map editor retains earlier maps and adds Wind Meadow.
Custom saved maps retain their terrain identity; gameplay objective HP is reset
on a new run. See `docs/goemon-performance-guide.md` for fresh measured frame
times, actual controller travel times, verification commands and limitations.
No app export is required for source iteration.

## Map-grid foliage variants — 2026-10-30

The user's direction is Breath of the Wild inspired scenery, with natural colors,
organic silhouettes and soft painted shading. The earlier flat Cedar Pass crowns
were rejected beside this meadow. The grid's `cedar`, `pine`, `sakura` and `bamboo`
IDs now use `cedar_tree`, `pine_tree`, `sakura_tree` and `bamboo_cluster` here and
under `assets/models/environments/wind_meadow/`. Saved map IDs, placement origins,
size/rotation and native collision ownership remain unchanged.

Cedar, pine and sakura reuse the approved broadleaf bark and every original leaf
card (6,396 triangles and two parts each). They reshape that existing geometry
into a tapered cedar, layered pine and broad blossom crown. Sakura's painted
colors use muted rose shadows and warm cream-pink light. Bamboo reuses the Cedar
Pass export's 1,236 triangles with softened stem normals and meadow greens.
All four use the existing foliage shader; tree canopies retain wind/cutaway.
No changes were made to the broadleaf/shrub masters or original Cedar Pass GLBs.

`tools/prepare_meadow_tree_variants.py` performed initial preparation, checks
protected hashes and refuses to overwrite these editable masters. Do not rerun
it over artist edits. Edit the saved variants and export with the existing tool:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/environments/wind_meadow/sakura_tree.blend \
  --python tools/export_blender.py
```

Run audit, the named `meadow-cedar-tree`, `meadow-pine-tree`, `meadow-sakura-tree`
or `meadow-bamboo-cluster` optimization recipe, import and preservation checks.
The initial lossless pass retains the source meshes/surfaces unchanged, so no
candidate was activated. Keep `Body` and `Canopy` separate and preserve UVs and
vertex colors. Review the actual game camera beside the original broadleaf.
Evidence and protected hashes are in `build/Other Files/Asset Toolkit/Map Catalog/`.

The same grid reuses `leafy_shrub`, Cedar Pass `river_rock`, `moss_boulder`, `fence`,
and this kit's `buildings/stone_block`, `wall_cap`, `wall_corner`, `wall_section`
and `wall_ruins`. The fence uses 1.875 base scale to meet the six-metre grid.
Modular pieces are ground-level static scenery/cover; functional structures keep
existing construction/combat owners. Torii/door openings and elevated assemblies
need their actual clearance/support contracts before adding them as map pieces.
