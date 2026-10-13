# Fire Siege • Gold Mine v1

An editable, stylized 3D gold mine built from the approved concept sheet: faceted rock mound with surface gold veins, a timber-framed tunnel, short metal rails, an open ore cart, iron joinery, ropes, a lantern, and an animated interior pick. All visible elements are mesh geometry. No concept image is used as a flat substitute for the model.

## Files

- `goldmine_v1.blend` — compressed Blender 4.3 source, individual named meshes, collections, material palette, animation actions, and presentation scene
- `goldmine_v1.glb` — portable binary glTF with the complete mesh asset, material colors, three attachment sockets, and four named animation clips
- `goldmine_preview.mp4` — rendered build, working, optional upgrade, and reverse-build preview
- `goldmine_overview.png` — six-view/state contact sheet made from actual Blender renders
- `renders/` — three camera views plus unbuilt, construction, and reinforcement proposal renders
- `goldmine_metrics.json` — dimensions, mesh counts, sockets, and gameplay metadata
- `verification/` — GLB re-import report and a render of the re-imported GLB
- `build_goldmine.py` — deterministic model-generation source

## Gameplay agreement, separate from the asset

The mine starts unpurchased near the left side of the base. Completing the initial build costs **10 gold** and level 1 produces **2 gold per second during combat only**, with zero income during setup or pause. Unlimited setup includes the first wave and ends only when the player holds Y for 3 seconds. Whether a post-60-second cleanup interval counts as combat remains undecided. It uses the same hold-B interaction as the tower, including reversible progress. Those numbers are stored as metadata only; this pack does not implement income, purchasing, proximity, collision, UI, input, or saving.

Upgrade use also follows hold-B. Upgrade count, prices, and outputs are still undecided. `upgrade_preview` is a visual proposal only: extra timber braces, a small slate canopy, and a slightly enlarged cart. Do not interpret it as an approved tier or economy value.

## Scale and placement

- Units: meters; 1 Blender unit = 1 meter
- Root: `GoldMine_Root`, ground-center pivot at `(0, 0, 0)`
- Blender up/front: `+Z` / `-Y`
- glTF and Godot up/front: `+Y` / `+Z` after standard Blender glTF conversion
- If the game convention faces `-Z`, rotate the imported root 180° around Y; do not rotate individual children
- Footprint approximately 4.55 m wide × 4.73 m deep, including track and terrain skirt
- Visible height approximately 2.89 m
- Rock undersides intentionally extend about 0.42 m below the ground plane to avoid exposed seams when placed on terrain
- 248 mesh objects; 9,404 authored triangles; 18 used exported materials

The source opens in a completed working pose for easy inspection. The game must initialize the unbuilt state explicitly by seeking the `build` animation to time 0. Do not use the editor-open pose as purchase state.

## Animation contract

All four clips survive GLB export and re-import. At 24 fps, authored build clips cover frames 1–49 (2 seconds) and the working loop covers frames 1–97 (4 seconds). A Godot animation player should use the exported seconds, not Blender frame numbers.

| Clip | Duration | Use |
|---|---:|---|
| `build` | 2 s | Survey stakes → temporary scaffold → foundations/rails → posts/lintel → completed mine |
| `reverse_build` | 2 s | Full completed-to-unbuilt visual reversal |
| `work_loop` | 4 s | Seamless cart travel, wheel rotation, and interior pick swing |
| `upgrade_preview` | 2 s | Optional, unpriced reinforcement appearance |

For hold-B construction, store normalized progress `p` from 0 to 1 and seek `build` at `p × 2.0` seconds. Release decreases `p` and seeks the same clip backward, so partial construction reverses from exactly its current state. Clamp at 0 and 1. Charge gold and enter the working state only when the game’s own build logic completes. The separate `reverse_build` clip is useful for a full reversal demonstration; starting it at time 0 after a partial build would jump to the fully built state.

At completion, stop build seeking. The game’s visual controller may start/loop `work_loop` during the active working phase and must gate income to combat only; playing this clip never awards gold by itself. Each clip keys stage-root transforms to restore a coherent state. The upgrade clip is a preview that returns to the base arrangement when another base-state clip is applied. A future persistent upgraded working state should be implemented after its gameplay design is decided.

## Named collections / stage roots

Each collection has a corresponding root ending in `_Root`:

- `00_SHARED_ROCK_SITE`: permanent boulders, gold seams, gravel, terrain skirt, tunnel recess
- `01_UNBUILT_MARKERS`: four survey stakes and gold caps
- `02_BUILD_FOUNDATION`: post footings, sleepers, rails
- `03_BUILD_POSTS`: upright timber posts
- `04_BUILD_LINTEL`: lintel, turned ends, diagonal interior braces
- `05_BUILD_DETAILS`: straps, rivets, rope, lantern
- `06_TEMP_CONSTRUCTION`: scaffold and stored timber; disappears at completion
- `07_WORKING_CART`: cart body, ore, four independent wheel pivots
- `08_WORKING_PICK`: the interior mining tool
- `09_OPTIONAL_REINFORCEMENT`: future visual proposal, normally hidden by a visually negligible 0.00001 root scale
- `99_SOCKETS`: attachment nodes

Mesh parts remain separate for editing. The GLB is a reusable v1 exchange asset, not a draw-call-optimized production bake; static groups can be joined or batched in a later optimization pass without remodeling the visible forms.

## Attachment sockets

Blender coordinates (the exporter converts these to glTF axes):

- `socket_build_fx`: `(0, 0, 3.2)`
- `socket_income_fx`: `(0, -1.3, 2.4)`
- `socket_entrance`: `(0, -1.25, 0)`

The shared construction/effects pack can attach its progress bar and hammer to `socket_build_fx`. Socket transforms carry no gameplay behavior.

## Materials and rendering

Warm cedar/honey timber, faceted cool-gray stone, dark iron, warm gold, and an optional dark slate canopy coordinate with the arrow tower. No external texture files are required. Gold has metallic roughness values and the lantern has emissive material; any actual light source should be added by the game if desired.

`PRESENTATION_ONLY` contains the camera, three soft area lights, and floor used for previews. It is excluded from the GLB. Previews are Cycles renders; this Blender build has no OpenImageDenoise, so lightweight animation frames are intentionally lower-sample than the still images.

## Validation

A fresh Blender scene imported `goldmine_v1.glb` successfully. The checks verify mesh and triangle counts, finite vertices, material assignments, all four clips, and all three sockets. A separate render was made from that imported GLB, then inspected against the source render. An isolated Godot 4.6.3 import/playback test also checks build seek at 0/1/2 seconds, repeated partial seeking, full reverse endpoints, cart travel and pick swing, material assignments, socket positions, and loop configuration. The final run reports no errors or warnings. This does not replace a Godot gameplay integration test; no game repository has been modified.

## Godot 4.6 import settings

Preserve exported clip names: disable **Nodes → Use Name Suffixes** (`nodes/use_name_suffixes=false`). Otherwise Godot’s suffix processor renames `work_loop` to `work`.

Preserve constant transform tracks: disable **Animation → Remove Immutable Tracks** (`animation/remove_immutable_tracks=false`) in the Godot scene importer. When loading with `GLTFDocument`, use `generate_scene(state, 30.0, false, false)`; the final false preserves immutable tracks. The default runtime optimization removes constant translation keys, which caused the cart to jump to the origin during a scale-only build animation in the isolated test. Preserving those tracks retains the intended cart position at build completion.

Hidden stage endpoints use scale 0.00001 rather than exact zero to avoid Godot basis-decomposition errors. They are visually negligible; a game controller may additionally manage node visibility if desired. Do not replace these endpoints with exact-zero transforms.

Set the imported `work_loop` animation’s loop mode to `Animation.LOOP_LINEAR` explicitly in the importer or controller. glTF does not standardize looping behavior.

Both the runtime GLTFDocument route and standard Godot editor PackedScene route passed with this import setting.

The reusable test harness is `verification/godot_import/check_mine.gd`, with its own minimal `project.godot`. It loads only this asset and never edits the game project. Its reports are `verification/godot_import_report.json` and `verification/godot_editor_playback_report.json`.
