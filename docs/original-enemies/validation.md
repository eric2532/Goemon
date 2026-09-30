# Validation and review evidence

Built in cloud Blender 4.3.2 from current origin/main `82b4e8307af1158dbec566cb67632eb5cdbbb6d2`, on isolated branch `feat/original-enemies-town-cap`. No user's Mac execution, push, merge or deployment.

## Asset checks

Four enemy GLBs each contain one embedded atlas material, UV0 on every primitive, and no skins. Measured exported triangles match source catalog: 430 soldier, 478 bandit, 604 lantern, 312 daruma. The exported named rigid parts merge to one runtime surface per species; source mesh count is not the runtime draw count. All 13 new editable Blender masters are separate from previously approved masters. The original working checkout remains clean.

Cloud Godot 4.6.3 headless and software OpenGL imported and rendered the assets. `game-lineup.png` is an actual Godot scene capture; the contact sheets are Blender renders. Renderer invariant checks pass: one surface per species, UV preservation, no per-actor skeleton/mesh hierarchy, frozen/windup/strike data, survival lantern cosmetic mapping without changing melee stats, and all four batches cleared on menu return. Software OpenGL emitted two texture-leak messages during shutdown; no shader or script errors were reported by the renderer suite.

## Environment checks

All nine town props are integrated in Tidefall only, 23 static placements. New checks passed including 366 player-capsule route samples and gate clearance. Existing Tidefall suite passed: 712 original collision shapes, 8,343 terrain height samples, seeded RNG, 24 building hulls/roofs, routes/courts, six navigation destinations and five camera views preserved.

## Population and gameplay

See `tests/enemy-cap-validation.md` for the configurable 200-active default, saturation policy, shared spawn-path checks, cleanup and representative cloud load limits. Survival and current firecaster suites passed with zero failures. A real-clock 35.017-second run observed 2,102 physics frames across four scheduled waves: maximum 200 living enemies, ten controlled deaths, exactly ten next-wave replacements, and no intervening backlog refill. Directional recoil remains per-instance in the batch renderer; game-feel regression passed with zero failures. The maintained combat suite passed 25 checks; its separately identified input-expectation repair is documented in `validation-renderer.md` with the exact baseline comparison.

## Delivery

Sources, GLBs, textures, catalogs, previews and authoring tools are local deliverables. Library preview saving was attempted but the Library helper could not reach its hosted service (`network`); no Library IDs were returned. Local preview files remain available.
