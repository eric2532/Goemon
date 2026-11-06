# Wind Meadow — walls, blocks, tower and barracks

## Raised fort stone — 2026-10-30

The raised central fort's sides and four stairways reuse the old castle wall's
`assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png`.
`scripts/forest/castle_stone.gdshaderinc` samples the original padded stone and
coping cells at world scale; the ground and existing batched stairs share this
texture. `forest_wind_meadow_art.gd` binds it during setup. The courtyard, natural
valley cliffs, other stone materials, geometry and collision retain their current
owners. No Blender master or exported GLB changes are needed for this material edit.
Run `tests/forest-shrine/fort_stone_texture_test.gd` through the desktop launcher
for both map sizes and rendered before/after captures in
`build/Other Files/Asset Toolkit/Fort Stone/`.

## Skullpion castle objective — 2026-10-30

Current standard/large enemy castles replace their central farm/keep with a
destructible stone Skullpion statue. The existing per-castle HP and saved
`enemy_castle_health` setting now belong to that statue. Walls remain separate:
a breach opens access; destroying the statue stops that castle's reinforcements,
retires its remaining defenses and contributes to the existing victory rule.
Older unexpanded saved layouts retain their farm objectives.

`forest_enemy_castle.gd` assembles the existing stone shrine pedestal at 1.8×
horizontal scale, the static `assets/models/forest/skullpion_stone_statue.res`,
and the unchanged wall/gate/tower kit. Repeated statues share one mesh/material.
The statue derives from the existing Skullpion master; its exact bake command
and preservation contract are in `assets/blender/enemies/skullpion/START_HERE.md`.
Do not create a second editable Skullpion master. Statue debris reuses this
folder's `stone_block.blend` / exported `stone_block.glb` in one prepared batch.
Combat, physics and native navigation use the same pedestal and 22 part bounds.
Placement ghosts and the baked build-card portrait use the same assembly.

Run `tests/forest-shrine/enemy_statue_model_test.gd` and the castle damage and
placement fixtures after edits. `enemy_castle_damage_test.gd -- --large` checks
the larger valley. Rendered evidence belongs under `build/Other Files/Asset Toolkit/`.

## Building portraits and source kit

Build-grid portraits are baked from these current GLBs and the gameplay painterly
materials with `tools/render_building_icons.gd`. Rebuild through the desktop launcher:

```sh
"/Users/eric/Desktop/Play Goemon.command" --audio-driver Dummy --script res://tools/render_building_icons.gd
```

The tool reuses the weapon-icon renderer and the normal enemy-castle assembly;
no editable master is changed. Rebuild after visual
building edits, refresh imports, and review the grid in game. The 256px transparent
PNGs live in `assets/ui/forest/buildings/`; the tower frames its roof and lookout
for readability. Source hashes and audit evidence are in
`build/Other Files/Asset Toolkit/Building Icons/`. Runtime UI uses these cached PNGs.

Original Blender art created 2026-10-23 to match the meadow kit. The user's
correction is authoritative: preserve the existing castle layout and provide
modular wall/block art, rather than a new standalone castle building.

Current user direction — 2026-10-28: blend the Human Warcraft silhouettes with
Wind Meadow's painted scenery, replace barracks with farms and use the roofed
Guard Tower. The farm retains the existing barracks save key, cost, housing,
repairs and shelter behavior. No saved map migration or new simulation is needed.

Open the `.blend` files here to edit the masters. Their GLBs live under
`assets/models/environments/wind_meadow/buildings/`. Walls and gates retain the
packed 1024px architecture atlas. The farm and Guard Tower reuse the recovered
native geometry/UVs and original painted textures, with muted meadow-blue team
accents and the existing `forest_painterly_surface.gdshader` applied through the
shared `forest_wind_meadow_assets.gd` material cache. No texture or material is
created during combat. One static mesh/two surfaces replaces each former
three-mesh building. Geometry counts are asset evidence, not an FPS measurement.
Native sources, original animations and provenance are preserved in
`assets/references/warcraft_human_buildings/`; the existing Warcraft importer and
normal saved-master exporter were reused. Initial preparation is not a tool to
run over later artist edits.

| Master | Geometry / anchors | Triangles | Mesh groups |
| --- | --- | ---: | ---: |
| `wall_section.blend` | 6m long; 5.6m body depth; 6m footing/cap; top 16m | 924 | 1 |
| `wall_corner.blend` | 6m square corner; top 16m; four join anchors | 1,012 | 1 |
| `stone_block.blend` | Stackable 6m cube | 44 | 1 |
| `wall_cap.blend` | 6m square coping, 0.7m thick | 44 | 1 |
| `gate_frame.blend` | Existing 12m frame, 22m height; 9.6m × 11m opening | 452 | 3 |
| `watchtower.blend` | Human Guard Tower; 12m grid footprint; deck anchor 20m, lookout anchor 25m; pennant 31.4m | 156 | 1 |
| `barracks.blend` | Human farm; 18m grid footprint; original 6m shelter deck anchor; chimney 8.2m | 171 | 1 |

Units are metres. Blender +Z is up; front is -Y, exported as Godot +Z.
Origins are at ground centre. Named empty anchors survive export. The two Human buildings are static prepared Stand poses with one editable
Architecture mesh and two material surfaces. Other architecture, banners and
lantern glass retain their original mesh groups. Edit mesh faces or select
connected pieces in Blender; there are no hidden procedural dependencies.
Existing collision, worker deck and native shelter/attack contracts remain.
The enclosed Guard Tower conceals the pooled garrison body/bow presentation;
shots, targeting and recall retain their original owner and 20m origin. Recalling
the worker restores its same body. Other worker states/maps are unchanged.
The source Birth/upgrade animations are preserved for future use; this visual
replacement does not add construction delays or change combat timings.

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

Refresh Godot imports before reviewing the preview. The historical initial authoring tool
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
| `tower_ruins` | Current Human Guard Tower and shared stone block | 523 | 3 |
| `barracks_ruins` | Current Human Farm and shared stone block | 639 | 3 |

Wall and gate rubble retain the cropped/capped original kit and its packed
1024px architecture atlas. The farm/tower rubble reuses that workbench with fragments of the new
Human buildings and the existing stone-block master. It retains three shared
material surfaces, low capped stumps and fallen roof/wood/stone pieces, with
the same ground-centre origins. Prior masters/exports are retained in Git. The existing one-time authoring workbench is
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

## Angled preparation camera — 2026-10-28

The user approved the gentle quarter view for building mode: offset
`(55,150,118)` (about 25° around the map and 49° downward). The existing
orthographic camera, cursor-ground picking and anchored zoom remain. Mouse and
keyboard panning use the same screen-aligned ground directions in preparation
and the map editor. Combat camera settings and framing remain unchanged.
`tests/forest-shrine/preparation_zoom_test.gd` checks both input owners and
phase transitions; `human_buildings_test.gd` reviews the actual valley art.

## Human Cannon Tower — 2026-10-30

`cannon_tower.blend` is a separate editable master, prepared from the same original
HumanTower MDX's **Stand Upgrade Second** form. It preserves the original stone,
UVs and muted meadow-blue team layer: 215 triangles, one mesh, two surfaces,
23.66 m height, the existing 12 m grid footprint and entrance/deck/lookout anchors.
Runtime export: `assets/models/environments/wind_meadow/buildings/cannon_tower.glb`.
Edit the saved master and use `tools/export_blender.py`; the original MDX/complete
animations remain under `assets/references/warcraft_human_buildings/original/`.
Do not regenerate over artist edits. The Guard Tower and old saved map IDs remain.

The cannonball has a separate editable source at
`assets/blender/effects/warcraft_cannon_shell.blend`, exported to
`assets/models/effects/warcraft_cannon_shell.glb`. Its ten original triangles and
UVs come from CannonTowerMissile; .06 scale maps native +X forward to Godot +Z.
The tower and shell use their authored exports: lossless candidates preserve them
but offer no mesh/surface reduction. Reports and initial preparation scripts are
under `build/Other Files/Asset Toolkit/Human Cannon Tower/`.

Cannon placement uses Build → 5 (200 ryo), automatic worker staffing/repairs and
existing tower cards. Native average damage is 100.5 at default balance, with
2.5 seconds per worker, 48 m targeting and 42 m/s fixed-destination arcing shells.
Splash is 100% / 50% / 10% at 3 / 6 / 7.5 m from fitted enemy bodies, respecting
world cover. The existing native army owns damage and death; the original target
can die without cancelling a shell already in flight. Shared Guard Tower damage
and speed settings scale both types proportionally. Audio is documented in
`assets/audio/warcraft_cannon/README.md`.
