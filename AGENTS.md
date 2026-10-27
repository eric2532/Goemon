# Goemon build and delivery policy

The user wants exactly one playable app in the build folder: `build/Goemon.app`.

## Iteration workflow

- For development changes, run the latest source with `/Users/eric/Desktop/Play Goemon.command`; use `/Users/eric/Desktop/Edit Goemon.command` to open the same project in the Godot editor.
- Do not export or replace the app on every iteration. Export an app only when the user explicitly asks for an app build or distribution.
- The launchers use the current complete source on `main` and enable painterly scenery. Keep them pointed at the complete source if it moves.
- The app delivery rules below apply when an app export is requested.

## Playable map

- Wind Meadow Valley is the only bundled playable map; keep its standard and large sizes.
- Retired layouts belong only in excluded regression fixtures under `tests/forest-shrine/reference/maps/`. Do not restore their preset buttons or export them. Preserve user-saved maps and reusable scenery.

## Army simulation

- Normal Goemon gameplay uses the native army runtime exclusively. Do not add a legacy backend selector or fallback.
- Original army controllers and renderers are test references under `tests/forest-shrine/reference/`; keep them excluded from game exports.
- Preserve player controls, wave counts, hills, bridges and portals while improving the native simulation.

## Performance memory and teaching

- On 2026-10-23 the user reported that general gameplay feels really smooth and asked us to remember the work and teach them how to maintain it.
- Read `docs/goemon-performance-guide.md` before future performance work or character/skill changes. Preserve the current feel and explain the measured bottleneck, the smallest fix, and how the user can verify it in plain language.
- Update that guide when new evidence changes the advice. Distinguish the user's gameplay experience, historical measurements, and freshly verified results; do not imply that old stress tests passed on current source.

## Character and skill performance

- Enemies and bosses must reuse the native army lifecycle, queries, combat and
  pooled presentation. Add type/attack data instead of another simulation or
  renderer per enemy. Reuse the editable rigid-enemy Blender export/bake workflow
  in `docs/recovered-monsters.md` for compatible recovered assets; preserve the
  existing specialized boss patterns inside the same native owner.
- Apply these rules whenever changing a character, weapon, animation or skill. Reuse existing character, combat, effect, projectile and pooling systems before adding new machinery.
- Reuse existing animations, combos and attack patterns where compatible with the requested design before authoring replacements. Inspect source/destination rigs and weapon contracts; reuse compatible motion directly or retarget and correct grips, feet and proportions during asset preparation. Do not assume copying animation also copies gameplay behavior.
- Follow `docs/BLENDER_PIPELINE.md`, `assets/blender/AGENTS.md` and the nearest asset/workbench guide before animation transfers. Preserve editable originals and user edits; use the matching exporter for GLB/authored pose data, rebuild affected army pose bakes and optimized derivatives, then run preservation, motion/contact and rendered gameplay checks. Avoid adding per-unit runtime retargeting when prepared animation data works. Reuse combat logic while keeping hit timing, damage, reach, cooldowns and travel under the existing controller unless the user requests changes.
- Load/setup models and resources when selected or initialized; play animations and adjust existing shader parameters during combat. Avoid repeated asset loading, scene reconstruction and material creation in frame, attack and hit loops. Occasional setup on character selection is fine; do not add pools without a repeated workload that needs them.
- Reuse or pool frequently repeated effects/projectiles. Reset position, target, damage, timers, visibility and other per-use state, and clear obsolete callbacks/references so reuse cannot cause stale hits or leaks.
- Share immutable meshes/materials and batch army visuals where supported. Keep per-character visual changes isolated through existing instance parameters or owned overrides; never mutate a shared material in a way that changes other characters accidentally.
- Keep target searches local and reuse current snapshots; do not scan or copy the whole army for each character's skill. Preserve exact hit checks, damage, cooldowns, animation timing and event delivery.
- Verify repeated use and, when the skill is used by allies/enemies, simultaneous army use. Check correctness, appearance, frame-time spikes and resource growth through the desktop launcher, with focused tests and before/after profiling appropriate to the change. Do not claim smoothness from headless tests alone or silently reduce army counts, art quality or skill behavior to pass.

## App delivery rules

- Publish the latest complete game with its current painterly scenery and gameplay. Do not keep separate original/preview apps or version-named app copies.
- The complete painterly source now lives in this project on `main`. Use its `Painterly Preview macOS` export preset; it publishes the app as **Goemon**. Do not substitute a stale original-look branch build for the latest game.
- Export and unpack into a temporary directory outside `build/`. Verify the staged app, then replace the single canonical app atomically.
- Move superseded app bundles and app-only export ZIPs to macOS Trash; do not empty Trash. Do not create `Before ...` copies, parallel apps, or retained release ZIPs unless the user explicitly asks.
- Keep logs, screenshots, reports, and other development artifacts in `build/Other Files/`. Leave only `Goemon.app` and `Other Files` as visible entries at the build folder root.
- Preserve source files, editable assets, saved maps, preferences, and user data during cleanup. Use Git for source history.

## Asset reuse

- User direction (2026-10-23): whenever buildings, scenery or other assets are similar, reuse existing assets instead of creating everything anew. Inspect the current library, editable masters and runtime contracts before authoring new geometry.
- Reuse compatible whole models first, then existing modular walls, blocks, doors, arches, roof pieces, timber, foliage, textures and materials. Build variations by assembling those parts or using existing instance parameters; create only the pieces the requested design actually lacks.
- Keep one authoritative editable source per reusable asset and reference its exported mesh/resource for repeated placements. Preserve origins, dimensions, sockets, collision/navigation and gameplay ownership; isolate variations so editing a shared material cannot change unrelated assets. Record useful pieces and their source/export paths in the nearest asset guide.

## Game art inspiration

- The user selected [Game Art Style](https://gameartstyle.loopyhop.com/) as a reference for game art inspiration. Consult it when exploring visual styles, environments, characters, or interface art for this project.

## Asset audit and optimization pipeline

- Run toolkit commands from the complete source selected by `Play Goemon.command`
  (currently `/Users/eric/Desktop/Projects_Codex/Sonic`).
  See `tools/asset_pipeline/README.md` there for commands and preservation rules.
- After exporting/recovering an asset, run `python3 tools/goemon_assets.py audit`
  and review triangles, mesh parts, surfaces, materials, textures and gameplay use.
  Budget warnings do not authorize redesign, deletion or automatic decimation.
- Gold mine and recovered playable Musashi use derivatives generated by
  `python3 tools/goemon_assets.py optimize --asset goldmine` or `--asset musashi`.
  Preserve the authored GLBs, Blender files, approved art, joints, sockets, texture
  pages/CLUT ids, UVs and animation samples. Never edit generated derivatives.
- Run `python3 tools/goemon_assets.py check` after source changes. Stale hashes or
  preservation failures require rebuilding from source; never rewrite baseline
  hashes to bypass a failure. Refresh Godot imports before imported-model tests.
- Run toolkit unit/import tests, Musashi outfit/motion checks and structure tests
  documented in the toolkit README. Use `compare --asset NAME` for synchronized
  animation/gear review and `compare --asset NAME --capture` for rendered evidence.
  The live loaders may use only candidates that pass preservation and review.
- Keep reports, logs, screenshots and comparison captures under canonical
  `build/Other Files/Asset Toolkit/`. Keep only app delivery entries at build root.
  Verify gameplay through the existing desktop launcher; do not export an app
  unless the user asks for a build or distribution.

- For the rest of the gameplay catalog, use `optimize --asset gameplay`; recipes
  and protected mesh names are in `tools/asset_pipeline/gameplay.json`. Candidates
  stay in `build/Other Files/Asset Toolkit/Candidates/` until preservation, imported
  motion, procedural-pose and rendered comparison checks pass. Then use
  `activate --asset gameplay`, refresh imports and run `check` plus gameplay tests.
  Activation publishes only useful results through `assets/optimized/routes.json`.
  Preserve named hit regions, equipment/cloth mesh types, sparse cape morphs and
  independently visible Ben accessories. Keep Ed's coplanar clothing meshes
  separate. Do not bypass visual failures simply because geometry checks pass.
