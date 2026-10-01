# Cedar Pass — enterable interiors, revision 2

22 original environment assets for Goemon, including six revised architectural designs. The shop, inn, tea house and warehouse now have open entrances, furnished interiors and continuous entry ramps. The shrine provides an accessible worship hall; the gatehouse provides a through passage and two guard bays. Nature and town props retain their original geometry.

## Start here

The independent **asset viewer** is `project.godot` in this directory. Run `godot --path .`; drag to orbit, wheel to zoom, WASD to pan, 1/2 for shop/tea house, 3 for overview. Press **I** to cycle exterior, ground-floor cutaway and upstairs cutaway. This viewer has no player avatar.

The **actual Goemon traversal lab** uses the existing repository player, model, tuning and camera base. Place this directory at `Goemon/asset_packs/cedar_pass/`, then run from the Goemon repository root:

```sh
godot --headless --path . --editor --import
godot --path . --rendering-method gl_compatibility --script asset_packs/cedar_pass/interior_lab/launch.gd
```

Alternatively open `interior_lab/lab.tscn` through that repository project. WASD moves, Ctrl walks, Shift sprints, right mouse looks, wheel zooms, and F5–F10 visits the six buildings. Combat/character switching/jumping are disabled in this traversal-only harness. Movement, acceleration, gravity, step handling, collision capsule and animation come from the unmodified `scripts/player.gd` and existing Goemon visual. The lab supplies inert audio/combat services and a flat test ground; it never instantiates or edits the live game world.

The asset-only ZIP is self-contained for Blender, GLBs and the orbit viewer. **The actual-player lab additionally requires the Goemon repository dependencies**; it intentionally does not distribute a duplicate or altered character/controller. Run the root import command before first use on a fresh checkout. No Mac-only Edo V05 or enlarged Tidefall work is included.

## Rooms and accessible routes

| Building | Interior design | Entry opening* | Usable levels |
|---|---|---:|---|
| `machiya_open` | Merchant counter, stock shelves, parcels, clear central shopping aisle | 3.2 m | Ground floor |
| `inn` | Reception, waiting bench, ground futon, stairs, upstairs guest futons and clear corridor | 3.6 m | Ground + mezzanine |
| `tea_house_open` | Two dining groups with low tables, cups, benches, mats and rear service counter | 3.4 m | Ground floor |
| `warehouse` | Inward-facing goods racks, stacked rear cargo, wide loading aisle | 4.0 m | Ground floor |
| `shrine` | Offering altar, vessels, prayer mats and lateral worship benches | 3.2 m | Worship hall |
| `gatehouse` | Open central passage, guard benches and cubbies in accessible side bays | 6.0 m | Passage + guard bays |

*Nominal structural openings; frames and facade trim slightly reduce visual width. All are validated with the repository's actual **0.76 m diameter × 1.85 m height** player capsule. Lowest doorway decoration leaves approximately 2.5 m above the finished floor. Routes keep furniture to the sides and retain space to turn and back away.

Ground floors sit at 0.36 m. Entry ramps rise continuously over 2.2 m (about 9.3°), eliminating the previous raised threshold. The gate has a ramp at each end. The inn has 22 visible stair risers and a continuous collision incline, 1.6 m stair width, 3.3 m rise over 4 m run (about 39.5°, below the player's 48° floor limit), generous turning space at both ends and a widened guest corridor. The stair ramp smooths the 0.15 m visual risers; no jumping is needed. Low futons and floor mats are deliberately low-profile.

## Player, collision and camera evidence

`interior_lab/test_walk.gd` instantiates the actual repository `Hero`, its real capsule and animation, and the actual `ActionCamera` base. It drives the player's existing `smoke_move` input hook while its native physics loop runs. It does not move the avatar directly along tested routes. Teleports only initialize independent cases, as normal test setup.

The checks include three repeated room circuits per building; diagonal entry/exit from both sides; slow walking at 2.2 m/s; normal movement at 10.2 m/s; sprint entry/exit at 18 m/s; pushing against furniture and backing away; recovery from four diagonal wall/furniture corners; and camera checks at four yaw angles in every room. Inn checks also cover stair ascent, both landing turns, the route to both upstairs futons, and descent. No jump inputs are sent. See `verification/interior_walk.json` for the full six-room result and `verification/interior_walk_inn.json` for supplemental floor-height and fall-reset assertions.

Run the same tests from the Goemon root:

```sh
godot --headless --path . --script asset_packs/cedar_pass/interior_lab/test_walk.gd
godot --headless --path . --script asset_packs/cedar_pass/interior_lab/test_walk.gd -- --inn-only
```

`interior_lab/capture.gd` records the real avatar walking exterior → threshold → interior → exit, plus the other rooms and upstairs. The screenshots are in `previews/interiors/goemon_*.png`. They complement the physics checks; they are not a video or proof against the unavailable Mac-specific world/player state.

### Collision contract

Building collision is authored in `interiors.json` and mirrored by hidden editable meshes in each source's `CP_COLLISION_PROXIES` collection. Use those boxes and convex entry/stair wedges, not a single whole-building convex hull. Floors, walls, counters, shelves, benches, cargo and guardrails retain physical collision when cut away. Minor cups, cloth, lantern frames and plank seams are decorative. Furniture boxes intentionally simplify small openings between legs; mats/futon heights remain low. Roofs are visual cutaway geometry and are not authored for rooftop traversal.

The player uses world collision layer 1 and its existing layer 2. The lab also places visible camera blockers on layer 8. Reserve or remap that camera layer when integrating elsewhere. Convert Blender points `(x,y,z)` to Godot `(x,z,-y)`; box sizes use absolute axis dimensions. Collider editing is explicit: update `interiors.json` when changing the matching hidden source proxies. `export_saved.py` refreshes render meshes and manifest statistics, not hand-edited collision metadata.

### Cutaway contract

Building exports retain named meshes `CP_Floor`, `CP_Interior`, `CP_Roof`, and four wall groups. The inn additionally has `CP_UpperFloor` and `CP_UpperFurniture`. All share `shared_matte.tres` in Godot. The lab reveals the room on the approach ramp, hides the roof and camera-facing walls, and uses hysteresis near the boundary. On the inn ground floor, it hides the mezzanine and upstairs furniture together; upstairs they are restored. Player collision stays active.

The isolated `camera_adapter.gd` extends the real `ActionCamera`: outside it uses the original camera behavior; inside it reuses yaw, input, follow target and FOV with an elevated, eight-metre, collision-aware boom using the visible-geometry layer. This keeps architecture from covering the avatar without changing `scripts/camera.gd`. Neither visibility nor collision integration is installed into the live world.

## Scale, pivots and budgets

1 Blender unit = 1 metre = 1 Godot unit. **No 4× enlargement is baked in.** Original town source inspection established 8 × 6 m bodies (`verification/original_scale.json`). New body footprints remain 8 × 6 m shop, 10 × 7 m inn, 9 × 6 m tea house, 8 × 7 m warehouse, 7 × 6 m shrine, and 12 × 4 m gate passage. Full bounds below include ramps, eaves and finials.

For the unpublished enlarged Mac town, inspect actual parent and instance transforms before integrating. Never apply 4× to both a parent and an asset. These authored clearances are validated at scale 1 with the repository player, not with unknown local modifications.

Every exported group's pivot is the ground placement origin `(0,0,0)`, with identity scale/rotation. Asymmetric scenery uses a placement anchor, not necessarily its bounding-box centroid. Blender is Z-up, front -Y; Godot is Y-up, front +Z. Dimensions below are **width × height × depth** in Godot metres.

| Asset | Bounds, m (W × H × D) | Triangles | Mesh/material surfaces |
|---|---:|---:|---:|
| `machiya_open` | 9.80 × 6.66 × 9.11 | 5,514 | 7 |
| `inn` | 11.80 × 9.66 × 10.11 | 7,090 | 9 |
| `tea_house_open` | 10.80 × 5.66 × 9.11 | 6,118 | 7 |
| `warehouse` | 9.80 × 7.66 × 10.11 | 3,834 | 7 |
| `shrine` | 8.80 × 6.86 × 9.11 | 3,986 | 7 |
| `gatehouse` | 13.60 × 7.61 × 8.40 | 4,236 | 7 |
| `cedar` | 4.60 × 7.67 × 4.60 | 84 | 1 |
| `sakura` | 5.89 × 6.26 × 5.09 | 364 | 1 |
| `cloud_pine` | 5.89 × 6.36 × 5.09 | 384 | 1 |
| `bamboo_cluster` | 5.40 × 6.31 × 1.45 | 1,236 | 1 |
| `river_rock` | 2.66 × 1.30 × 1.80 | 52 | 1 |
| `moss_boulder` | 2.88 × 2.40 × 2.30 | 52 | 1 |
| `split_crag` | 3.11 × 4.00 × 2.32 | 80 | 1 |
| `cliff_step` | 5.86 × 4.00 × 3.39 | 52 | 1 |
| `twin_summit` | 26.84 × 15.00 × 13.44 | 136 | 1 |
| `long_ridge` | 29.68 × 11.00 × 9.96 | 272 | 1 |
| `sacred_peak` | 29.77 × 20.00 × 17.92 | 68 | 1 |
| `lantern` | 1.60 × 3.21 × 1.21 | 512 | 1 |
| `well` | 3.80 × 4.01 × 2.91 | 1,060 | 1 |
| `cart` | 2.07 × 1.58 × 3.70 | 508 | 1 |
| `fence` | 3.20 × 1.60 × 0.18 | 156 | 1 |
| `torii` | 6.40 × 4.80 × 0.86 | 1,412 | 1 |

Total render geometry: **37,206 triangles**. Buildings use seven visibility groups, or nine for the inn; nature and props remain one mesh each. Each group has one vertex-colour surface, and the viewer/lab reuse one shared matte material. There are no texture dependencies, LODs, baked lightmaps or navmeshes. Two short-range, shadow-free warm lights per room are supplied by the lab metadata. Physics uses simple boxes/convex ramps instead of detailed render triangles.

## Files and editing

- `sources/<id>.blend`: 22 editable asset sources; the six buildings include named source parts and hidden collider proxies.
- `exports/<id>.glb`: 22 refreshed game exports, including separated building visibility groups.
- `sources/showcase.blend`, `showcase.glb`: full-scale asset field.
- `sources/contact_sheet.blend`: normalized, labeled full-pack display.
- `sources/interior_contact_sheet.blend`: six-room cutaway catalog.
- `manifest.json`: bounds, pivots, polygon budgets and group names.
- `interiors.json`: room dimensions, ramps, collision primitives, light positions and test route points.
- `previews/`: refreshed exterior/context views, the full contact sheet, and the original v1 three-asset checkpoint retained as a historical milestone.
- `previews/interiors/`: furnished cutaways, inn mezzanine, interior catalog and actual-Goemon views.
- `verification/`: source reopen/import audits, original-scale evidence and actual-player traversal reports.

Edit the saved `.blend` files, then run `blender -b --python export_saved.py`. Revision-2 building exports retain their cutaway groups. Use `render_interiors.py`, `render_interior_catalog.py`, `render_contact_sheet.py`, `refresh_exterior_previews.py` and `refresh_showcase.py` to refresh displays. The original `build_pack.py` refuses to overwrite a revised pack; `build_interiors.py` is the one-time v1-to-v2 authoring recipe and skips buildings already recorded in `interiors.json`.

`verify_blender.py` reopens all sources and reimports exports, checking triangles, pivots, group counts and collision proxy counts. From this asset-only project, run `godot --headless --path . --editor --import`, then `godot --headless --path . --script verify_godot.gd` for the viewer/import audit.

## Provenance and limits

Only `asset_packs/cedar_pass/` is changed. The completed v1 pack remains at commit `034d81a125bcbf3cf8e4a25b2f98202c67e6b789`, originally based on `32c02225e8ec9924d770de53c3df6237cb426cc2`. Revision 2 continues the local `feat/cedar-pass-environment-pack` branch. No push, merge, world layout, gameplay controller, character source or Mac changes were made. All geometry and furnishings are original; no game rip or paid asset pack was used.

The original player and camera base scripts are unchanged; their SHA-256 hashes are recorded by the traversal tests. The Mac-only Edo V05 and enlarged Tidefall integration remain separate. Live-world navigation, combat inside buildings, multiplayer, rooftop movement and target-device frame-rate profiling are not claimed. Cycles CPU previews retain some sampling grain because the cloud Blender build lacks a denoiser.
