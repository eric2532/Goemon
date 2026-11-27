# East Gate and overseas population

`tools/prepare_east_region_population.py` compiles the five source inventories
under `build/Other Files/Asset Toolkit/East Gate Region/`. It preserves original
map IDs, actor IDs, source cells, facing, graphic identity and the original
25-field NPC records. Runtime aliases belong to the existing map owner.

`population.json` contains every selected actor, including invisible warp/watch
markers and native enemy encounter triggers. `npcs` contains the source-visible
residents/signs; native bosses retain a separate flag and the existing army
owner. All IDs are strings and scripted interactions use `east_event:<id>`.
The original source scripts are inert line/condition/window data, SHA-pinned
and stored with source line numbers. Unknown conditions must remain gated.
Placeholder dialogue is explicitly authored, not recovered wording.

The atlas keeps exact native pixels and source offsets. Expansion NPC graphic
IDs such as 231097 resolve directly through the source graphics database;
the map-only serial lookup intentionally omits some of those records. Original
single-view facing remains unchanged; reverse images are unavailable.

The fifth inventory follows every active reached source row, including the
additional Babel Tower, spirit valley and supply-ship branches. Numeric NPC IDs
do not determine whether a branch is included. Exact historical release parity
of the pinned community server is uncorroborated and remains a source limit.

`routes.json` retains fixed doors, time masks and actor-attached quest/battle
relocations. `field-entries.json` supplies recorded reachable source100 cells
inside the three original random-entry rectangles. The derived field masks
select the complete pinned Freyja layout inside the East-owned windows, including
native walkable shoreline caps. All82179recorded East client cells agree with
that layout; originals and other region owners remain intact. This also restores
the previously unrecorded source return638,161 without moving its landing.

The storm sea41029 keeps its original water-only art. A documented invisible
3×3interaction stage and the eight original invisible event anchors let the
source cutscene return function in3D; no visible island or new route is added.

Encounter data retains original weighted memberships, levels, source groups,
quest conditions and follow-on encounter pools. Species first reuse the shared
native companion bank and existing dedicated banks. `--pack` passes compatible
unprepared appearances through `recover_habaru_encounter.recover`, producing
one additional shared native bank under
`assets/characters/crossgate/east_region/`. There is no separate simulation.
Original source body pixels relative to Kazi's standing drawing provide the
initial height fit; this is a 3D interpretation, not original world dimensions.
Source contacts/audio cues are preserved. Unsupported importer contracts stay
in `native-preparation-blockers.json`; timing or encounters are not invented.

```sh
python3 tools/prepare_east_region_population.py --pack
python3 tools/prepare_east_region_population.py --check
```

Regenerate ordinary population data without `--pack` after a source inventory
changes. Keep any existing East bank variants in their original order when
adding more; preparation appends newly compatible variants before rebuilding
that single bank. The check verifies source graph/script identity, native atlas
pixels, stable actor actions, member indices and matching native variant IDs.
It does not establish rendered appearance, gameplay gate behavior, combat,
frame time, resource growth or a complete route walkthrough. Those checks
belong to the route integration and fixed-camera review.
