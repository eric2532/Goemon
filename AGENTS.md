# Cross Gate build and delivery policy

The game is named **Cross Gate**. On the next requested app export, the single canonical app becomes `build/Cross Gate.app`; move the superseded `Goemon.app` to Trash then. Do not export solely for the rename. Keep existing launcher paths and the save-data directory compatible.

## Randomness

- User direction (2026-11-17): use marble-bag / shuffle-bag RNG for future gameplay outcome systems: draw without replacement from the intended outcome distribution, then refill and reshuffle when empty. Reference: https://www.youtube.com/watch?v=gUYkIlp8HAo . This is a future implementation rule, not a request to replace current random calls or native target variation now.

## Iteration workflow

- For development changes, run the latest source with `/Users/eric/Desktop/Play Goemon.command`; use `/Users/eric/Desktop/Edit Goemon.command` to open the same project in the Godot editor.
- Do not export or replace the app on every iteration. Export an app only when the user explicitly asks for an app build or distribution.
- The launchers use the current complete source on `main` and enable painterly scenery. Keep them pointed at the complete source if it moves.
- The app delivery rules below apply when an app export is requested.

## Playable map

- Falan Arena (the Cross Gate city arena adapted for four-sided survival) is the only bundled playable map; keep its standard and large sizes. The existing Wind Meadow preset resource paths are compatibility aliases.
- Retired layouts belong only in excluded regression fixtures under `tests/forest-shrine/reference/maps/`. Do not restore their preset buttons or export them. Preserve user-saved maps and reusable scenery.

## Army simulation

- Normal Goemon gameplay uses the native army runtime exclusively. Do not add a legacy backend selector or fallback.
- Original army controllers and renderers are test references under `tests/forest-shrine/reference/`; keep them excluded from game exports.
- Preserve player controls, wave counts, hills, bridges and portals while improving the native simulation.
- User direction (2026-11-13): all current and future pets, including summoned
  bears and selectable companions, share the native scattered-target preference.
  Prefer nearby enemies with fewer companion pursuers and a little random
  variation; keep valid pursuits stable. Preserve player-threat priority,
  reachability, exact combat, local cleanup and right-click/F/Z commands. A lone
  enemy may still be shared. Extend the existing owner for new pets rather than
  adding species-specific targeting loops.
- World enemies share the native preference for less-crowded nearby combat
  targets and small random variation. Keep valid nearby pursuits stable; preserve
  taunts, retaliation, castle/gate priorities, patrol limits, cover and committed
  strike timing. Reuse bounded queries and once-per-tick claim counts; do not
  scan the whole army for each enemy or add a targeting owner per species.

## Performance memory and teaching

- On 2026-10-23 the user reported that general gameplay feels really smooth and asked us to remember the work and teach them how to maintain it.
- Read `docs/goemon-performance-guide.md` before future performance work or character/skill changes. Preserve the current feel and explain the measured bottleneck, the smallest fix, and how the user can verify it in plain language.
- Update that guide when new evidence changes the advice. Distinguish the user's gameplay experience, historical measurements, and freshly verified results; do not imply that old stress tests passed on current source.

## Character and skill performance

- User approval (2026-11-17, Water Dragon Shin): the bottom rows in `build/Other Files/Asset Toolkit/Shin Water Dragon/Edge Review/exact-named-edge-flips.png` and `adjacent-edge-review.png` are correct. Apply those exact blade-face flips to S0-05/06/07, S2-02/03, S1-01, S3-02/03, S6-08 and S7-08. Preserve each pictured original body, hand anchor, blade axis and scale. S6/S7 use their original recovery drawings, not a substituted idle pose. Permanent approved images are under `assets/references/shin_water_dragon/`; use them as the visual reference rather than a blanket swing-phase mirror rule.

- User direction (2026-11-17, sprite weapon orientation): iterate with images first. For visual-only blade-edge/grip corrections, skip automated tests, gameplay test runs and full audit/rebuild cycles; show the named original frames with the proposed visual change so the user can judge it. Keep the same body, hand anchor and blade axis when the request is to flip the cutting-edge side; do not rotate the whole sword or replace a recovery drawing with idle. Follow the user's image feedback before extending a visual change. Once the user asks to implement an approved preview, prepare the affected runtime art and its required cached dependencies, without running tests. This overrides the heavier verification workflow below for these visual-only iterations; retain appropriate checks for runtime, combat, lifecycle or performance changes, or when the user requests them. Preserve original assets.
- User direction (2026-11-17, 水龍shin): appearance 900050 is named 水龍shin. Shorten 水龍劍 by 10% along its blade from the approved larger fit; retain width, grip and approved edge flips. Counter attacks reuse the equipped normal attack's frames and atlas. The user then approved the seven recovered weapon previews and requested all routes, curved boomerang flight, ice hit audio and the blue shockwave. Keep counter frames identical to each equipped normal attack.

- User direction (2026-11-16): character HUD portraits use heads cropped from the original selected model/skin, with consistent facing and alignment. Reuse `tools/prepare_crossgate_heads.py` and the existing portrait cache. Preserve painted masters and the separately approved conversation portraits.

- User direction (2026-11-13): future character and skill testing covers Cross Gate characters only. Use the Cross Gate roster as the test matrix; do not run the old 42-character sweep or legacy-character regressions by default. Legacy characters need testing only when the user explicitly requests it.
- Keep shared gameplay, native army, pooling, save-data and asset-preservation checks when relevant to Cross Gate gameplay. Scope mixed-roster fixtures to Cross Gate cases when reusing them. Legacy-only checks, including Musashi outfit/motion checks, are not required for routine Cross Gate work.
- For changes to Mirror Image, copied loadouts, Cross Gate model setup or shared charge skills, run `Play Goemon.command --headless --script res://tests/forest-shrine/mirror_movement_test.gd`. Require charge progression, resumed following, interrupted-charge cleanup and pooled reuse across the Cross Gate roster, including nine Kaz copies; script errors fail verification even if assertions pass. Preserve setup-time charge visuals for borrowed skills regardless of the copy's weapon family. See the Kaz Mirror Image entry in `docs/goemon-performance-guide.md`.
- User direction (2026-11-15): show only Cross Gate characters in character selection, Character Balance and Sound Studio. Keep old characters hidden in user-facing character lists. Preserve their stable IDs, source, assets, saved balance/loadouts, recordings and test references; do not delete them. Future character balancing and routine testing use the Cross Gate roster only.

- Goemon's walking/footstep sound is the default for all new characters and every shared footstep fallback. Never use the early prototype `audio/step.wav` in gameplay or previews. Reuse SoundLibrary's prepared sample and voice pool; preserve distinct recovered character audio and user recordings/gain/mute overrides.
- Goemon's landing sound (prepared ROM event 21E) is also the default for all new characters and every shared landing fallback. Preserve distinct recovered boss/character impacts and user recordings/gain/mute overrides; do not give a new character the heavy boss landing by default.

- Enemies and bosses must reuse the native army lifecycle, queries, combat and
  pooled presentation. Add type/attack data instead of another simulation or
  renderer per enemy. Reuse the editable rigid-enemy Blender export/bake workflow
  in `docs/recovered-monsters.md` for compatible recovered assets; preserve the
  existing specialized boss patterns inside the same native owner.
- Apply these rules whenever changing a character, weapon, animation or skill. Reuse existing character, combat, effect, projectile and pooling systems before adding new machinery.
- Reuse existing animations, combos and attack patterns where compatible with the requested design before authoring replacements. Inspect source/destination rigs and weapon contracts; reuse compatible motion directly or retarget and correct grips, feet and proportions during asset preparation. Do not assume copying animation also copies gameplay behavior.
- User approval (2026-11-17, Red Lightning Shin): use the successful sword-run repair as the preferred method for future compatible character animation fixes. Reuse a complete matching pose, keeping torso, shoulder, elbow, wrist, hand and weapon coherent; avoid replacing only the legs while leaving a walking grip. Use a readable weapon/color variant and matching unarmed frames to measure the actual grip, blade axis, projected width and occlusion instead of guessing angles. Adapt the selected character's original weapon/effect art offline, preserving originals, source origins, portraits and native body/hand overlap; do not invent a visible blade when the source body hides it. Review one short sequence frame by frame and in motion before extending it to every facing, then verify rendered gameplay through Play Goemon using the actual controls (including Shift press/release), plus preservation, native-copy and repeated-use checks. Report visual judgment separately from technical results. Reuse existing runtime players, combat clocks and pools. The worked example and reproduction commands are in `docs/goemon-performance-guide.md` under “Red Lightning's running sword grip” and `assets/characters/crossgate/shin/README.md`; the preparer is `tools/prepare_shin_red_lightning_run.py`. Apply the method where the source is compatible; author new motion when reuse cannot satisfy the requested behavior.
- User correction (2026-11-12, rejected Kaz dual-wield attempt): study the actual animation closely, frame by frame and in motion, before changing or attaching weapons. Establish the grip, wrist/arm motion, blade direction, swing path and camera perspective from the source; do not fill gaps with guessed angles. Validate one short sequence visually before extending it to other frames or directions. Passing technical tests, preserved pixels or correct damage timing do not establish correct-looking animation. Report technical results and visual judgment separately, state unresolved visual problems plainly, and never say it works on technical tests alone. The dual-wield attempt was rejected and stopped; do not resume it without a new user request.
- Follow `docs/BLENDER_PIPELINE.md`, `assets/blender/AGENTS.md` and the nearest asset/workbench guide before animation transfers. Preserve editable originals and user edits; use the matching exporter for GLB/authored pose data, rebuild affected army pose bakes and optimized derivatives, then run preservation, motion/contact and rendered gameplay checks. Avoid adding per-unit runtime retargeting when prepared animation data works. Reuse combat logic while keeping hit timing, damage, reach, cooldowns and travel under the existing controller unless the user requests changes.
- Load/setup models and resources when selected or initialized; play animations and adjust existing shader parameters during combat. Avoid repeated asset loading, scene reconstruction and material creation in frame, attack and hit loops. Occasional setup on character selection is fine; do not add pools without a repeated workload that needs them.
- Reuse or pool frequently repeated effects/projectiles. Reset position, target, damage, timers, visibility and other per-use state, and clear obsolete callbacks/references so reuse cannot cause stale hits or leaks.
- Share immutable meshes/materials and batch army visuals where supported. Keep per-character visual changes isolated through existing instance parameters or owned overrides; never mutate a shared material in a way that changes other characters accidentally.
- Keep target searches local and reuse current snapshots; do not scan or copy the whole army for each character's skill. Preserve exact hit checks, damage, cooldowns, animation timing and event delivery.
- Verify repeated use and, when the skill is used by allies/enemies, simultaneous army use. Check correctness, appearance, frame-time spikes and resource growth through the desktop launcher, with focused tests and before/after profiling appropriate to the change. Do not claim smoothness from headless tests alone or silently reduce army counts, art quality or skill behavior to pass.

## App delivery rules

- Publish the latest complete game with its current painterly scenery and gameplay. Do not keep separate original/preview apps or version-named app copies.
- The complete painterly source now lives in this project on `main`. Use its `Painterly Preview macOS` export preset; it publishes the app as **Cross Gate**. Do not substitute a stale original-look branch build for the latest game.
- Export and unpack into a temporary directory outside `build/`. Verify the staged app, then replace the single canonical app atomically.
- Move superseded app bundles and app-only export ZIPs to macOS Trash; do not empty Trash. Do not create `Before ...` copies, parallel apps, or retained release ZIPs unless the user explicitly asks.
- Keep logs, screenshots, reports, and other development artifacts in `build/Other Files/`. After the next requested export, leave only `Cross Gate.app` and `Other Files` as visible entries at the build folder root.
- Preserve source files, editable assets, saved maps, preferences, and user data during cleanup. Use Git for source history.

## Asset reuse

- User direction (2026-10-23): whenever buildings, scenery or other assets are similar, reuse existing assets instead of creating everything anew. Inspect the current library, editable masters and runtime contracts before authoring new geometry.
- Reuse compatible whole models first, then existing modular walls, blocks, doors, arches, roof pieces, timber, foliage, textures and materials. Build variations by assembling those parts or using existing instance parameters; create only the pieces the requested design actually lacks.
- Keep one authoritative editable source per reusable asset and reference its exported mesh/resource for repeated placements. Preserve origins, dimensions, sockets, collision/navigation and gameplay ownership; isolate variations so editing a shared material cannot change unrelated assets. Record useful pieces and their source/export paths in the nearest asset guide.

## Game art inspiration

- User approval (2026-11-12): use the approved 熊弟 conversation presentation as
  the default for all conversations: large painted character portrait, speaker
  nameplate, ivory-framed dark dialogue box, gradual text reveal and Space to
  continue. Reuse `scripts/forest/forest_dialogue.gd`; shared style and portrait
  preservation rules are in `assets/ui/dialogue/README.md`.

- 熊弟's approved dialogue portrait and future-expression rules are in
  `assets/ui/dialogue/README.md`. His grey flat-top is hair, not a cap; reuse the
  approved PNG as the reference and preserve it when making new expressions.

- User correction (2026-10-30): scenery should follow a Breath of the Wild inspired
  direction: organic silhouettes, clustered foliage, natural greens/bark and soft
  painted shading. Avoid the visibly faceted Cedar Pass tree crowns in the map
  grid. Reuse the Wind Meadow tree masters and shared foliage shader; keep the
  original Cedar Pass assets intact for their existing uses. Editable grid tree
  variants and their export instructions are in the Wind Meadow asset guide.

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
- Run relevant toolkit unit/import and structure tests for affected Cross Gate
  or shared gameplay assets, following the testing scope above; do not add
  legacy-only character checks by default. Use `compare --asset NAME` for synchronized
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
