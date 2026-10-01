# Cedar Pass — original environment pack

22 original, editable stylized feudal-Japanese environment assets for Goemon. Cedar framing, warm plaster, turquoise ceramic roofs, vermilion shrine accents and faceted nature. Created procedurally in Blender, with saved part-level mesh sources. No copied game meshes, paid packs, downloaded art or character changes.

## Scope and provenance

Additive directory only: `asset_packs/cedar_pass/`. Based on `32c02225e8ec9924d770de53c3df6237cb426cc2` fetched from `feat/original-enemies-town-cap`, on local branch `feat/cedar-pass-environment-pack`. No world layout, gameplay, character, or existing asset replacements. No GitHub push. Cloud workspace only. The Mac-only Edo V05 integration and 48-building, 4× Tidefall work are **not included or inspected**.

## Scale and placement

1 Blender unit = 1 metre = 1 Godot unit. **No 4× scaling is baked in.** Inspection of original `noren_shop`, `two_story_inn`, and `plaster_storehouse` sources confirms 8 × 6 m bodies; their full bounds include eaves and foundations. Original measurements are in `verification/original_scale.json`.

New body footprints: machiya 8 × 6, inn 10 × 7, tea house 9 × 6, warehouse 8 × 7, shrine 7 × 6, gatehouse 12 × 5 m. New foundation bottoms rest at ground instead of copying the older buried foundations. A 1.8 m reference capsule stands beside the shop in the showcase.

For the enlarged Mac town, inspect actual instance transforms first. Use scale 1 under an existing scale-4 parent, or scale 4 under a scale-1 parent only if the same enlarged architectural treatment is desired. Do not multiply both. A 4× shop body becomes 32 × 24 m and its doorway becomes oversized; keeping these assets at scale 1 can instead support human-scale side streets. Placement is intentionally left to that later integration.

Export origin is the ground placement anchor `(0,0,0)`, with identity scale and rotation. It is not necessarily the geometric centroid of asymmetric trees/ridges. Blender Z-up, frontage toward -Y; GLB/Godot Y-up, frontage toward +Z. Below, dimensions include roof overhangs, finials and props attached to the asset, shown as Godot X × Y × Z (width × height × depth).

| Asset | Category | Full bounds, m (W × H × D) | Triangles | Interior/use |
|---|---|---:|---:|---|
| `machiya_open` | building | 9.80 × 6.66 × 8.21 | 4,838 | Open furnished room |
| `inn` | building | 11.80 × 9.66 × 9.11 | 5,762 | Exterior shell only |
| `tea_house_open` | building | 10.80 × 5.66 × 8.21 | 5,126 | Open furnished room |
| `warehouse` | building | 9.80 × 7.66 × 8.41 | 2,690 | Exterior shell only |
| `shrine` | building | 8.80 × 6.86 × 8.31 | 3,582 | Exterior shell only |
| `gatehouse` | building | 13.60 × 7.61 × 6.21 | 3,576 | Open passage |
| `cedar` | tree | 4.60 × 7.67 × 4.60 | 84 | Static environment |
| `sakura` | tree | 5.89 × 6.26 × 5.09 | 364 | Static environment |
| `cloud_pine` | tree | 5.89 × 6.36 × 5.09 | 384 | Static environment |
| `bamboo_cluster` | tree | 5.40 × 6.31 × 1.45 | 1,236 | Static environment |
| `river_rock` | rock | 2.66 × 1.30 × 1.80 | 52 | Static environment |
| `moss_boulder` | rock | 2.88 × 2.40 × 2.30 | 52 | Static environment |
| `split_crag` | rock | 3.11 × 4.00 × 2.32 | 80 | Static environment |
| `cliff_step` | rock | 5.86 × 4.00 × 3.39 | 52 | Static environment |
| `twin_summit` | mountain | 26.84 × 15.00 × 13.44 | 136 | Static environment |
| `long_ridge` | mountain | 29.68 × 11.00 × 9.96 | 272 | Static environment |
| `sacred_peak` | mountain | 29.77 × 20.00 × 17.92 | 68 | Static environment |
| `lantern` | prop | 1.60 × 3.21 × 1.21 | 512 | Static environment |
| `well` | prop | 3.80 × 4.01 × 2.91 | 1,060 | Static environment |
| `cart` | prop | 2.07 × 1.58 × 3.70 | 508 | Static environment |
| `fence` | prop | 3.20 × 1.60 × 0.18 | 156 | Static environment |
| `torii` | prop | 6.40 × 4.80 × 0.86 | 1,412 | Static environment |

## Interiors and collision

`machiya_open` and `tea_house_open` have separate side/back/front-wing walls, floor, tatami and low table; their entry gaps are 2.4 m and 3.2 m respectively. Lowest curtain clearance is about 2.19 m above the finished floor. Doors are fixed open, not animated. The gatehouse has a 6 m central passage. Inn upper floor/balcony, shrine and warehouse are exterior silhouettes, not authored playable interiors.

The standalone Godot showcase builds static triangle collision for buildings, rock/mountain pieces and props. This is an exact inspection/demo setup. Production guidance per asset is also in `manifest.json`:

- Open buildings: use separate floor, side/rear wall and front-wing box shapes; never one convex hull spanning the room. Keep the doorway and approach free. Optional roof collision for rooftop play. Furniture can use separate boxes.
- Gatehouse: two tower boxes plus overhead passage; leave the arch clear.
- Closed buildings: one body box plus optional roof mesh collision is sufficient.
- Trees: trunk capsule(s) only; no canopy collision. Bamboo can be decorative or use a few slim capsules. Tree collision is intentionally absent from the showcase.
- Rocks/cliffs: convex hulls for small rocks, static trimesh or a few convex pieces for larger cliffs. Mountains are distant scenery by default; disable collision for backdrop use.
- Fence: thin box; cart: bed box and simple wheel cylinders if needed; torii: two pillar capsules plus beams; well: separate wall pieces to preserve opening; lantern: post capsule.

`verify_godot.gd` verifies all imported meshes, dimensions and triangle counts; clear rays and 0.6 × 1.8 m capsule samples through both entrances and the gate; floor presence; and a blocked warehouse facade. These are focused geometry tests, not validation against the unavailable Mac player controller or navmesh.

## Materials and budgets

Every exported asset is one mesh with one material surface. Colours are embedded vertex colours; no external textures. `shared_matte.tres` is the single reusable Godot material used by every showcase asset. Independent GLBs embed equivalent materials; override them with this shared resource after integration to avoid per-file material duplicates. Blender sources retain named palette materials and individual parts for convenient editing. No LOD meshes, lightmap UVs or baked navigation are supplied. Lighting is dynamic; mountains suit distant silhouettes rather than close terrain traversal.

## Files and usage

- `sources/<id>.blend`: 22 editable part-level sources, metric units.
- `exports/<id>.glb`: 22 game exports, ground pivots, one vertex-colour surface each.
- `sources/contact_sheet.blend`: normalized, labeled display; relative scale intentionally not preserved.
- `sources/showcase.blend` and `showcase.glb`: full-scale assembled asset field.
- `project.godot`, `showcase.tscn`, `showcase.gd`: standalone interactive Godot showcase. Open this project separately; it does not replace the Goemon main scene.
- `previews/`: Blender checkpoint, labeled contact sheet, close views, doorway view, and Godot captures.
- `manifest.json`: machine-readable exact bounds, triangle counts, pivots and collision guidance.
- `verification/`: Blender reopen/GLB import audit, original-scale evidence and Godot results.

Launch from this directory with `godot --path .`. Drag left mouse to orbit, wheel to zoom, WASD to pan, 1/2 for shop/tea house, 3 for overview. Asset models can also be copied into the main game's asset directory independently.

Edit `.blend` parts normally, then run `blender -b --python export_saved.py` to re-export saved sources and refresh the manifest. `build_pack.py` is the complete procedural authoring recipe and overwrites the pack's generated sources/exports/previews; use it only for an intentional rebuild, not to preserve hand edits. `-- --checkpoint` builds the initial three-asset checkpoint. `render_contact_sheet.py` rebuilds the labeled catalog from current exports; `render_details.py` refreshes the corrected shop, tea-house and doorway views. `verify_blender.py` reopens sources and reimports GLBs; `godot --headless --path . --script verify_godot.gd` runs the import/collision checks after `godot --headless --path . --editor --import`.

The original checkpoint remains as the first visual milestone; final close views reflect the corrected threshold rails and tea-house gable. Blender renders use Cycles CPU without denoising because this cloud build lacks OpenImageDenoise; some fine sampling grain remains. All work and application launches were in the cloud environment.
