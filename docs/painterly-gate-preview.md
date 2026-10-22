# Painterly environment preview

## Current iteration — 2026-10-21

Run the current complete source with `/Users/eric/Desktop/Play Goemon.command`. App delivery follows `AGENTS.md`: export only on request, to the single `build/Goemon.app`. The older release notes below describe historical deliveries, not the current workflow.

Towers and roofless barracks now use a small [Tiny Glade / miniature-diorama](https://gameartstyle.loopyhop.com/styles/miniature-diorama/) inspired treatment: beveled limestone courses, arched entrance surrounds, paved open decks, restrained ivy, corner shrubs, stepping stones and a soft meadow apron. The planted area extends at most four world units from the foundation and is fitted to terrain at construction. The apron fades on steep slopes. Existing map-wide lighting and native terrain stay in control.

`forest_glade_structures.gd` caches one masonry mesh per building kind and shares materials. Each instance renders through three geometry nodes; planting and the apron cast no shadows, and the old tower lantern light is removed. There are no animation, physics or per-frame scenery updates. The original render meshes are hidden while the painterly treatment is enabled and restored exactly when disabled. Existing colliders, platform heights, health bars, population rules, workers and bunker combat remain owned by the original systems.

`glade_structures_test.gd` covers the rendering budget, physics preservation, visibility restoration, construction, demolition and map reload. `glade_army_benchmark.gd` exercises sustained native combat with extra structures, supports an original-pilot fixture for A/B comparison, and uses the main benchmark's `--map=blood_gulch` option for the current map. Captures, measured runs and baseline regression diagnostics are retained in the primary project's `build/Other Files/Glade Structures 2026-10-21/`.

## Historical environment preview — 2026-10-18

Open **Goemon Painterly Preview.app** from the original project's `build` folder. It is a separate signed app, beside the unchanged **Goemon.app**. The experiment's source is isolated on `codex/painterly-gate-preview`, based on `d5a4746`; the regular checkout and GitHub build remain available.

The building view opens near the main gate and western watchtower. Click **Painterly: On / Off** beside Map Editor to compare the same view. Scroll to zoom; middle-drag or WASD to pan. The art choice lasts for this app session, including restarts, and does not write maps or settings. **Map Editor → Original Map** and **Twin Ramparts** remain available.

The environment uses painted moss/earth, weathered timber and bark, layered olive foliage, slate roof strokes, mossy stone blocks, stone footings and warm lantern light. The shrine, mines, palisades, gates, every tower, raised ramparts, portal stone and resource deposits now share the same painted finish. Grass/earth covers the entire terrain and all authored road tiles; roads keep a warmer worn-earth tint. Cooler ambient light, longer shadows and contact shading tie the surfaces together. Existing building geometry, physics bodies, navigation, map data, characters, enemy fidelity, attack timing, damage, stats and combat camera are unchanged. Extra trim is visual only. Lighting is an app-wide preview profile, so surrounding objects also receive its lighting.

Disabling the pilot restores the original material/shader/environment references and sun properties. Reloading/previewing maps reapplies the ground treatment and local structure details without saving it into map files. Maps without a gate still receive the painted ground and lighting. Fog continues to control scouting and grid visibility; hidden terrain has muted painted texture without revealing actors. Unrelated building revisions do not rebuild art.

The normal `macOS` export defaults to original presentation. `Painterly Preview macOS` uses the `painterly_preview` feature and separate bundle identity. Source command: `godot --path . -- --painterly-preview`. This flag routes into Forest Shrine directly; ordinary no-argument app launch uses the title screen.

Generated asset: [painted ground and generation prompt](../assets/textures/forest_painterly/README.md). Built-in image generator, generate mode; no external service/runtime dependency.

## Verification

Evidence is in the original project's `build/Other Files/painterly-gate-20261017/`.

- 14 presentation invariants: unchanged authored maps/building stats, collision identities/transforms/shapes, exact material/shader restoration, repeat toggles, map reload, western tower selection, safe missing structures, no art rebuild on unrelated revisions.
- 14 native Metal gameplay/visual checks: comparison button and label, unchanged fighter/position/health/camera, real A/B overhead and eye-level captures, both map presets, normal waves and automatic gate opening.
- Launcher regression observed red before routing change and green afterward.
- Combat/map regressions pass: Ninja pierce/finish 19, Knight held shield 22, melee reach 146, Twin Ramparts gameplay 19, bow audio 9, Ninja three-hit refresh 24.
- **Existing failure:** `ddii_combat_view_test.gd`, “Ranged aim-facing preserves movement”, fails identically on the unchanged `d5a4746` original checkout and this pilot (58/59 pass). No movement/combat implementation was changed for the art pilot. Some older headless combat harnesses report retained resources at exit; their checks pass. Native pilot cleanup is clean.
- Independent review: launch flag routing issue corrected and regression tested; no other important findings.

New package signing/boot and old-package preservation are recorded in `verification.json` alongside these logs.

## Whole-map grass expansion

The original request limited the first experiment to a gate and tower. The subsequent request extends the same grass/earth texture across the entire map, including custom layouts without those structures. The original gate/tower trim was kept local in that grass-only stage; the later environment extension applies it to every gate and tower. Original-look toggle and Goemon.app remain available; no characters, gameplay, map documents or collision geometry changed. `tests/forest-shrine/painterly_whole_ground_test.gd` verifies three distant terrain locations through actual native rendering, a map with no gate/tower, reload and exact original-shader restoration. Evidence: `build/Other Files/painterly-whole-ground-20261017/`. The new test first reproduced the old limited coverage (four failures). Texture mipmaps are enabled to avoid distant grass shimmer when zoomed out; the same single ground mesh and texture sampler are reused.

## Trees, walls and buildings — 2026-10-18

The expanded environment uses per-instance material overrides for procedural buildings, palisade MultiMeshes and deposits; per-surface overrides for the imported shrine; and reversible shader bindings for the instanced forest, ramparts and portal stone. Original albedo textures, vertex colors, culling, alpha cutouts and emissions are retained. The animated portal shader, health indicators and all characters are excluded. Materials share the existing painted ground image as a brush-variation mask, with no new texture or foliage mesh allocations. Tree/log meshes and instancing buffers are unchanged.

Forest materials retain the original visibility-map inputs, distance haze and near-player canopy cutaway. Newly placed/destroyed structures trigger rebinding; unrelated run revisions do not. Disabling the toggle restores exact original material references, embedded surface bindings, shaders, lighting and scenery. No map, geometry, navigation, collision, character, attack, balance or audio files changed. The previous painterly app is retained as **Goemon Painterly Preview Before Painted Environment.app**; regular **Goemon.app** is untouched.

Validation: `painterly_environment_test.gd` first reproduced nine missing-coverage failures, then passed 17 headless/native checks. `painterly_characters_test.gd` passes 13 checks covering every fighter's materials, geometry, health, position and shared balance settings. Source/native overview, settlement, forest and raised-wall images were inspected. Existing environment/toggle/map and Ninja, Dragoon, Knight and melee-range behavior checks pass. Some older headless combat harnesses report retained resources at exit; their behavioral assertions pass. Independent review found no important issues. Package signature, native release boot, backup hashes and exported-pack validation are recorded in the original project's `build/Other Files/painterly-environment-20261018/verification.json`.
