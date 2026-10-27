# Wind Meadow — walls, blocks, tower and barracks

Original Blender art created 2026-10-23 to match the meadow kit. The user's
correction is authoritative: preserve the existing castle layout and provide
modular wall/block art, rather than a new standalone castle building.

Open the `.blend` files here to edit the masters. Their GLBs live under
`assets/models/environments/wind_meadow/buildings/`. All use one packed 1024px
painted atlas; the editable image is `assets/textures/wind_meadow/architecture_paint.png`.
The latest user references show a round crenellated stone tower and a pale
stone/timber lookout with blue shingles. The revised tower uses a round shaft,
individual weathered blocks, a battered base, chunky battlements, an oak gallery,
arched openings, blue shingles and a blue pennant. Its 20m deck and 25m rear
landing remain open. A small blue-roof shelter covers the rear landing, with
2.2m headroom; the decorative pennant reaches 31.4m. The palette uses cool pale masonry, cream plaster, warm
timber, blue trim and banners, moss and warm lantern glass. The project's chosen
[Game Art Style atlas](https://gameartstyle.loopyhop.com/) was consulted alongside
the user's supplied landscape reference. No artwork was extracted from either.

| Master | Geometry / anchors | Triangles | Mesh groups |
| --- | --- | ---: | ---: |
| `wall_section.blend` | 6m long; 5.6m body depth; 6m footing/cap; top 16m | 924 | 1 |
| `wall_corner.blend` | 6m square corner; top 16m; four join anchors | 1,012 | 1 |
| `stone_block.blend` | Stackable 6m cube | 44 | 1 |
| `wall_cap.blend` | 6m square coping, 0.7m thick | 44 | 1 |
| `gate_frame.blend` | Existing 12m frame, 22m height; 9.6m × 11m opening | 452 | 3 |
| `watchtower.blend` | Round shaft in 12m grid footprint; deck 20m; rear lookout 25m | 7,695 | 3 |
| `barracks.blend` | 18m grid footprint; open deck 6m; oak diagonal braces | 4,773 | 3 |

Units are metres. Blender +Z is up; front is -Y, exported as Godot +Z.
Origins are at ground centre. Named empty anchors survive export. Architecture,
banners and lantern glass are separate editable mesh groups, with one material
surface each. Edit mesh faces or select connected pieces in Blender; there are
no hidden procedural dependencies. The tower and barracks retain open landings.

The gate's `GateDoor` mesh contains the closed leaf at 0–11m height. Move that
child up 11m to tuck it behind the header; `GateOpenCenter` marks the raised
centre. This is a prepared visual, not a replacement for the current gate
controller, collision body or wall-damage ownership.

## Preview

Close the running game and open `docs/wind-meadow/Preview Buildings.command`.
This uses the normal Play launcher. Drag to orbit, wheel to zoom, Escape to exit.
The initial view now shows Goemon, Ed and Ben in front of the gate, left to right.
It directly reuses their existing gameplay model scripts and proportions,
including Ben's larger size. They are stationary visual instances with their
original palettes; no character source, material, combat or saved map is edited.
The nearby grass, flowers, trees and shrubs reuse the existing meadow assets.
The viewer reads **the existing Twin Ramparts map** to place all 54 occupied
wall cells, the gate and both towers, and retains the existing Goemon statue
for context. It also displays the new barracks and loose modular samples.
It never saves the map. Flat preview ground makes the module joins visible;
the playable terrain, hills, bridges and portals are unchanged.

Renders and audit/test evidence are under
`build/Other Files/Asset Toolkit/Wind Meadow/Buildings/`. The unused initial
keep draft is archived there as development evidence and is not part of this kit.

## Edit and export

Save edits in Blender, then run from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/environments/wind_meadow/buildings/wall_section.blend \
  --python tools/export_blender.py
python3 tools/goemon_assets.py audit assets/models/environments/wind_meadow/buildings \
  --out 'build/Other Files/Asset Toolkit/Wind Meadow/Buildings'
python3 tools/goemon_assets.py check
```

Refresh Godot imports before reviewing the preview. The initial authoring tool
`tools/build_wind_meadow_buildings.py` refuses to overwrite any requested master;
saved masters are authoritative. Do not regenerate them to export hand edits.
The supplied-reference redesign supersedes the initial square-tower generator.

## Reuse this kit

The user's standing rule is to reuse similar assets. Reference these existing
masters and GLBs before creating more buildings. All 54 perimeter wall cells
in the preview share the same imported wall mesh. Reuse the wall section and
corner for new layouts, the block and cap for masonry extensions, and the tower
and barracks when their existing footprint/deck contracts fit. Keep this shared
atlas for compatible additions. The source arch, timber, roof and lantern
authoring helpers live in `tools/build_wind_meadow_buildings.py`; reuse them for
missing parts while exporting edited masters through the normal exporter.

## Playable valley integration

The default Wind Meadow Valley now uses these models through the existing
forest art owner. Variable wall spans/extensions use shared wall meshes;
tower/barracks colliders and worker decks retain their original contracts.
The painted gate leaf follows the original GateDoor moving collider and damage
owner. New construction and placement ghosts reuse the same imported sources.
Four enemy barracks reuse the existing static combat-target and destruction path.
The earlier asset study remains a separate view and never saves maps.

Fresh gameplay, gate rotation, native routing, terrain, editor round-trip,
map-switching and asset-preservation checks passed. Matched 30-second foreground
army evidence is documented in `docs/goemon-performance-guide.md` and stored in
`build/Other Files/Asset Toolkit/Wind Meadow/Valley/`. No app was exported.

## Four enemy castles — 2026-10-23

The enlarged default valley reuses the complete starter perimeter via
`scripts/forest/forest_enemy_castle.gd` and `forest_model.gd::_make_starter_fort`.
Each enemy fort is the same 102 × 78 metres as the central castle, with the same
wall heights, two towers and a raised gate, plus the existing barracks inside.
The four rotations face inward. Meshes and materials still come from the GLBs
above; no Blender masters or exported building geometry were changed.

Castle physics and native obstacles borrow the existing building colliders.
One existing objective owns each castle's health and reinforcement lifecycle;
all its masonry is hittable, and destruction removes its collision. Spawn exits
are 72 metres in front of each centre, outside both walls and large boss radii.
The map editor reserves the fort footprint and exit.

`tools/build_wind_meadow_map.gd` bakes the 960 × 960 metre terrain into
`assets/maps/wind_meadow/castles/`, retaining the original 3-metre sample spacing.
The bundled map uses `terrain_scale: 2`; old saved valleys without that scale
keep their original terrain resources and barracks. Do not overwrite the old
resources when rebaking the enlarged map. Evidence is in
`build/Other Files/Asset Toolkit/Wind Meadow/Castles/`.

## Castle damage and reusable ruins — 2026-10-25

Each enemy wall panel, gate and watchtower has its own 6,000 HP by default.
The keep inside has a separate 6,000 HP pool. Core Game Balance exposes both
fortification and keep health; saved edits apply to the next run. Panels reuse
the original perimeter, split into modules no wider than six metres. Destroying
one opens a local breach while the keep and reinforcements remain active.
Destroying the keep retires all remaining sections; all four keeps must fall to win.

The existing static combat-target script handles exact per-panel contacts;
`forest_model.gd` owns the health and navigation revision. Each section updates
its own four-stage `forest_wall_damage.gd` fractures. The last struck panel owns
the single nearby HP label, preventing overlapping text during broad sweeps.
Area attacks can still damage multiple panels they actually reach. Player walls
retain their existing settings. Panel HP is runtime state, excluded from saved
map layouts. Normal restarts restore intact walls with the selected balance.

Four new editable masters and their matching GLBs live beside the original kit:

| Master / export stem | Reused sources | Triangles | Surfaces |
| --- | --- | ---: | ---: |
| `wall_ruins` | Wall section and stone block | 1,094 | 1 |
| `gate_ruins` | Gate frame and stone block | 994 | 1 |
| `tower_ruins` | Current round watchtower and stone block | 2,818 | 1 |
| `barracks_ruins` | Barracks and stone block | 3,831 | 1 |

These are cropped, capped and fallen pieces of the saved masters, retaining the
existing packed 1024px architecture atlas and ground-centre origin. Original
masters were hash-checked unchanged. The one-time authoring tool is
`tools/build_wind_meadow_ruins.py`; it refuses to overwrite saved ruins. Edit
the `.blend` files and use `tools/export_blender.py` for future changes.

`forest_enemy_castle.gd::build_ruins` batches each type across the original fort
layout. Intact wall panels also share one batch. Each castle prepares four ruin
batches and two bounded emitters during setup. A breach hides one intact instance,
reveals that panel's low rubble, and removes only its collision and navigation
obstacles. Wall debris uses 18% vertical scale to keep the route visually open.
The same emitters reset between ordinary impacts and local/full collapse.
Ruins are cosmetic, traversable
remnants, without rigid bodies or navigation obstacles. Stone-chip meshes reuse
`stone_block.glb`; dust uses the existing soft radial-particle technique.

Wall breaches now play a 1.35-second split, tumble and fade before leaving that
low rubble. `scripts/forest/forest_wall_collapse.gd` reuses six scaled instances of
`assets/models/environments/wind_meadow/buildings/stone_block.glb` per wall panel;
its editable source remains this folder's `stone_block.blend`. One additional
MultiMesh per castle and an owned fade material are prepared at setup. No new
asset master, physics debris or per-hit resource loading is needed. Upper courses
release first, intact neighbors remain unchanged, and collision opens immediately.
Ordinary pause freezes the fall; victory allows it to finish. Local breach dust
is smaller than the whole-keep plume so the moving masonry stays visible.

The original shared-health desktop and headless fixture each passed 45 assertions,
including actual pipe/bullet contacts, repeated hits, rotations, collision
removal and victory. See `tests/forest-shrine/enemy_castle_damage_test.gd` and
`build/Other Files/Asset Toolkit/Wind Meadow/Castle Damage/` for six rendered
views, audit and preservation evidence. All four ruin exports have one material,
one surface and one atlas; no optimizer derivative is needed for these already
combined static meshes. Existing imported asset/motion and valley regressions
also passed; those results predate independent panels. Updated breach, balance,
render and regression evidence is in
`build/Other Files/Asset Toolkit/Wind Meadow/Castle Breaches/` and the current
performance guide. Keep using `tests/forest-shrine/enemy_castle_damage_test.gd`
for the panel lifecycle, actual player traversal and saved health settings.
