# Wind Meadow modular expansion

Authored and checked 2026-10-31. Open `Preview Modular Kit.command` in this
folder for the separate development scene. It runs the complete current source
through the normal desktop launcher. The bundled standard/large valleys, saved
maps, editable Blender masters and exported app are untouched by this expansion.

## What the existing kit supports

Inspection of the current masters' guides, imported meshes, map document,
scenery catalog, terrain sampler and runtime renderer established these contracts:

- Metres; Godot Y-up; Blender Z-up. Existing scenery/building origins are at
  ground level. Map cells are 6 m; baked terrain samples are 3 m apart.
- Organic, clustered vertex-coloured meadow foliage, natural greens/bark,
  cool mossy stone and warm painted architecture. Foliage is rough and uses
  the existing GPU wind/canopy cutaway shader. Meadow ground uses world-space
  green variation and worn paths; cliffs reuse the 512px cliff painting.
  Architecture uses the existing 1024px atlas; current farm/tower textures are
  256px. The project remains the visual authority; the user-selected
  [Game Art Style atlas](https://gameartstyle.loopyhop.com/) was consulted only
  as background reference.
- Current scenery includes broadleaf/cedar/pine/sakura/bamboo, shrubs, short/tall
  grass, three flower colours, moss/river rocks, mountains, modular walls,
  corners, caps, blocks, ruins and timber fences. Walls/blocks use 6 m joins;
  the existing fence uses 1.875 scale to meet the grid.
- Imported broadleaf and related trees have 6,396 triangles/two parts; rocks
  and flowers are much smaller. Repeated scenery shares meshes/materials in
  spatial MultiMeshes. Trees retain separate Body/Canopy. No new tree is needed.
- Valley ground is a continuous height field, with the same triangle heights
  used by physics and native navigation. A mesh placed on top does not by itself
  update native army support. The existing rampart system supports solid decks
  and slopes, widths 18/30/42 m, half-cell endpoints (3 m), heights 0–256 m and a
  maximum 1:3 rise. It supports one surface height per X/Z position.
- Runtime terrain lives under `AuthoredMapFeatures`; `ValleyTerrainCollision`
  owns the base field, and `RaisedWallRoutes` owns rampart hulls/guardrails.
  Scenery rendering is separate from its fitted collision/native obstacle box.
  Functional walls, gates, towers and forts retain their existing combat owners.

The missing useful pieces were ready-to-reuse, explicitly sized ramp/deck
recipes and small obstacle compositions, rather than another terrain engine or
another tree/rock master. A coplanar ground slab was discarded because it would
duplicate the valley floor and collision. Existing roads and ground shading
already provide ground/path variation.

## New assets

Scenes are under `assets/models/environments/wind_meadow/modular/`.

| Scene | Dimensions / use | Existing pieces complemented |
| --- | --- | --- |
| `platform_18.tscn` | 18 × 18 m deck, 6 m high | Rampart ramps and stone wall kit |
| `causeway_36.tscn` | 36 × 18 m solid deck, 6 m high | Longer elevated connections |
| `ramp_6.tscn` | 18 × 18 m run/width, 0→6 m | Ground-to-deck transition |
| `ramp_12.tscn` | 36 × 18 m run/width, 0→12 m | Higher terraces; stack the deck recipe at +6 m |
| `platform_30.tscn` | 30 × 30 m deck, 6 m high | Wider landing and narrow-to-wide connections |
| `corner_18.tscn` | 18 m wide L turn, 6 m high; two non-overlapping deck prisms | Existing ramps and straight causeways |
| `t_junction_18.tscn` | 18 m wide three-way join, 6 m high; two non-overlapping deck prisms | Two straight connections and a side branch |
| `boulder_pair.tscn` | About 4.76 × 3.25 m footprint, 1.32 m high; 1,340 triangles | Two references to the approved meadow boulder |
| `river_cluster.tscn` | About 4.14 × 2.23 m footprint, 1.30 m high; 104 triangles | Two references to Cedar Pass river stones |
| `fence_corner.tscn` | 6 × 6 m footprint, 3 m high; 312 triangles | Two references to the existing timber fence |

The three scenery assemblies are available on the existing editor's numbered
palette. Placement, resizing, rotation, undo/redo, saving, picking, impact
material and both native teams' blockers all use the existing scenery system.
Assembly scenes reference their authoritative GLBs, sharing their geometry;
the Cedar Pass compositions retain its existing shared matte material.
No new textures, Blender masters, per-frame script, simulation or pool was added.

## Terrain placement

The seven terrain scenes are generated authoring prefabs with open longitudinal
connectors, layer-1 hull/guardrail collision and a `ramparts` metadata recipe.
Their pivot is the existing rampart **start-edge centre at ground Y=0**;
local +X runs toward the far connector. Width extends equally along ±Z.
The low/high connector surface is defined by `h0`/`h1`, not by moving the pivot.
Keep scale at 1 and use quarter turns. Ordinary pivots use the 6 m grid;
side connectors may use its 3 m half cells. This matches the existing baked
terrain spacing, without changing native interpolation or army movement.

The map editor now exposes all seven terrain modules on palette pages 3–4.
Use **] / Page Down / Next** to reach them, select with **1–9** or a button,
and click the map to place. Compact grid names are **Plat18**, **Span36**,
**Ramp+6**, **Ramp12**, **Plat30**, **Corner** and **T Join**; tooltips and the
status line show the full names. **R** or the Rotation field turns a module
90 degrees. Terrain snaps to 3 m, allowing side branches to meet their connectors.

**Height** sets the absolute base elevation. It follows the underlying meadow
ground until you edit the field; a deck's surface is another 6 m above that
base, and the long ramp rises 12 m. Set matching base heights when connecting
modules. Terrain size stays fixed so the collision and native support agree.
Select a placed deck or its side branch to edit its height/rotation or delete
the whole module; corners and Ts stay grouped. Undo/redo, Save/Load, Play map
and Restart preserve the grouping and prepared geometry.

Palette placement writes existing `ramparts` segments plus a small `kit`
descriptor on the first segment of each module. It is checked against the
allowlisted recipe on load. No new simulation, navigation backend or playable
map preset is introduced. Existing ungrouped terrain records remain unchanged;
the regenerated separate kit test map includes editable module descriptors.
The actual map domain now governs terrain bounds for both meadow sizes, rather
than the old 36-cell limit. The current 24-segment limit remains (a junction
uses two); maximum surface height is 256 m.

For scripted authoring, use `Kit.placement` for editor-selectable modules, or
the original `segment` / `segments` helpers for raw prepared terrain. The
existing owner builds collision/rendering and supplies the same surface to
native armies. Do not additionally instance physical prefabs into that map,
which would duplicate collision. The cursor ghost has collision disabled and
reuses cached scenes; moving it does not rebuild the map. Committed terrain edits
retain the meadow mesh/base collision and update local navigation, nearby foliage,
fitted scenery and the small raised-route batch. Discard restores the prior routes
the same way. Changes to base terrain, roads or portals still use complete setup.
See the [placement measurements](../goemon-performance-guide.md#terrain-placement-stalls--2026-10-31-follow-up).

```gdscript
const Kit = preload("res://scripts/forest/forest_environment_kit.gd")
# 0,1,2,3 turn +X toward +X,+Z,-X,-Z. Positions below are map cells.
layout.ramparts.append(Kit.segment("ramp_6", Vector2i(10, 0)))
layout.ramparts.append(Kit.segment("causeway_36", Vector2i(13, 0)))
layout.ramparts.append(Kit.segment("ramp_6", Vector2i(22, 0), 2))
layout.ramparts.append_array(Kit.segments("corner_18", Vector2(-24, -7)))
layout.ramparts.append_array(Kit.segments("t_junction_18", Vector2(-24, 7)))
layout.ramparts.append_array(Kit.placement("platform_18", Vector2(20, 12), 1, 0))
# Use the existing ForestMapDocument.validate(layout) before applying/saving.
```

These connectors are at X=60→78→114→132 m, with heights 0→6→6→0 m.
Use the optional base height only where underlying ground/decks support both
approaches. Inspect the full footprint: the valley owner takes the higher of
the baked ground and recipe, while a prefab hull retains its authored shape.
Use level ground or a fully supported terrain transition; do not hide a gap by
raising scenery. Adjacent ground/raised structures must keep existing clearance.

The renderer's old fixed half-metre end-cap test blocked valid 1:3 joins.
It now uses the existing terrain step-clearance rule. Standalone authoring
prefabs omit longitudinal end walls; runtime maps still cap exposed high ends.
Side rails retain the existing geometry and collision contract.

For the unrotated L turn, connector centres relative to its pivot are (0,0)
and (18,27) metres. The T adds an exit at (36,0). Both stand at Y=6 m.
Their horizontal and side-branch prisms meet along an exact shared plane, with
no overlapping interiors. Joined pieces use 3 m guardrail sections so rails
stop at the turn openings. Existing straight/retired-layout rails remain exact.

## Planting and stacking

Scenery no longer requires clear grass/level terrain. Trees, shrubs, stones and
modular wall pieces can be placed on roads, stone decks and supported structure
tops. In the editor, select **Stone Block**, **Wall Piece** or **Wall Cap** from
the scenery pages, then click an existing piece to stack the next one on its
fitted top. Clicking a stone surface with a tree selected plants it there.
The gameplay Wall tool keeps its existing functional building owner; use the
scenery pieces for freely composed stacked walls.

Select a placed layer to adjust **Height** above terrain, Size or Rotation.
Ray picking identifies that exact layer, including top pieces sharing a grid
cell with their supports. Each layer has independent collision, undo/redo,
save/reload and restart data. Deleting a support does not delete the other
layers; their saved heights stay fixed until edited. Touching stacked faces
are allowed; intersecting solid interiors, invalid dimensions, map bounds and
protected base/portal/gate exits are still checked.

Saved scenery entries optionally carry `height` in metres, defaulting to zero.
Old map data and zero-height identities remain unchanged. Elevated layers use
distinct internal anchors while rendering and native obstacles still share the
existing scenery owner, spatial batches and fitted boxes. Blocks/wall pieces
remain solid scenery cover for native armies, rather than a new walkable
terrain or destructible building simulation. Native armies route around them;
use ramp/deck recipes for elevated enemy walking routes.

## Edit and verify

Edit terrain dimensions in `scripts/forest/forest_environment_kit.gd` and obstacle
transforms in `tools/build_environment_kit.gd`. These are the editable composition
sources. The `.tscn` outputs are generated; rebuilding replaces these outputs
and the dedicated test fixture, never the original GLBs/Blender masters or
bundled maps. Keep changes to individual rock/fence geometry in their existing
masters and use their normal exporter. After source edits, rebuild this kit so
fitted bounds can be reviewed against `forest_scenery.gd`.

```sh
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tools/build_environment_kit.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/modular_environment_test.gd -- --capture
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/map_catalog_test.gd -- --visual
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/map_stacking_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/map_terrain_palette_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tests/forest-shrine/terrain_placement_performance_test.gd -- --large
godot --headless --path . --script res://tests/forest-shrine/terrain_edit_reuse_test.gd
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

The separate `tests/forest-shrine/modular_environment_demo.tscn` loads a valley
fixture under excluded `tests/forest-shrine/reference/maps/`. It demonstrates
three ramp/deck/descent configurations, the joined corner and T, low/high elevations,
narrow/wide joins and a stacked stone wall with a tree on its coping. It uses an isolated settings
file, retains four enemy castles and uses the current player and native armies.
It adds no playable preset and is excluded from app exports by existing rules.

Rendered evidence, inventory, source audit and validation logs are under
`build/Other Files/Asset Toolkit/Modular Environment/`. The focused desktop test
passes 3,579 checks: physics/support parity across the straight and joined arrangements,
exact seams, non-overlapping deck interiors, fourteen native unit traversals
across both teams, actual player walking/turning, source mesh sharing, bounded repeated
scenery instancing and document/history checks. Native corner/T traversal uses
only final destinations, without supplying turn waypoints. The new stacking
fixture passes 46 desktop checks including automatic click-to-stack, planting
on stone, per-layer picking/height editing, collision, save/reload/restart,
delete/undo, bounded repeated edits and both teams navigating around the wall.
Captures include `junctions.png`, `stacked-wall.png` and `stacking-editor.png`.
The palette fixture additionally covers every module and quarter turn, malformed
group records, whole-junction selection/deletion, native collision, elevation
editing, cursor resource stability, page/number/R shortcuts, Save/Load and
Play/Restart. Screenshots are `terrain-palette-page-3.png` and
`terrain-palette-page-4.png`. Its document-only run passes 454 checks and the
desktop run passes 525, including a native soldier crossing a height-edited T
at about 48 m elevation and palette fit at 960×600 / 1280×800. The sampled
cursor callback measured 0.121 ms median / 0.284 ms p95 on this Apple M3 run;
these are callback CPU times, not rendered frame times or an army stress pass.
Additional checks: 69 toolkit unit tests, 12,973 import/preservation assertions,
98 Musashi outfit assertions, 86 structure assertions, 223 catalog document
assertions and 310 desktop catalog checks (placement, transforms, save/reload,
restart and native play) pass. The preserved rampart geometry regression passes
14 checks headlessly, with per-instance transform readback skipped by that
renderer, and the clearance regression passes five. Its historical baseline
keys still use `assets/maps/`; the test now resolves the retired fixture paths
to those keys without altering the captured geometry. These results are
correctness checks, not a frame-time benchmark.
Earlier graphical fixture runs emitted shutdown resource/RID warnings. The fresh
palette and terrain-navigation runs exited without those warnings; whole-game
teardown has not been audited. Repeated scenery/ghost reuse passes its bounded
resource check, which is not proof of leak-free whole-game teardown.

## Compatibility limits and sensible next modules

- These are solid causeways, not open-underpass bridges. The current one-height
  terrain owner cannot route actors both above and below the same X/Z.
- The fence corner is solid cover across its entire 6 m square. Its empty-looking
  inside corner is not a walk-through enclosure. This preserves one fitted box
  for editor validation, physics and both teams; it is not a functional gate.
- Width changes join on their common 18 m centre. Side guardrails remain, but
  exposed end shoulders are cliff edges rather than an extra entrance.
  Approaches must remain clear of scenery and existing forts.
- Terrain recipes retain the current 24-segment map limit, height and slope
  limits. Arbitrary rotation/non-uniform scaling would break native support.
- A wider 42 m landing is a useful next extension. Natural cliff corners should be prepared with
  the current continuous height-field bake, not dropped in as visual-only cliffs.
- Dense-map frame times were not profiled. Reuse the existing shared batches;
  measure before increasing placement density or adding a new pooling system.
