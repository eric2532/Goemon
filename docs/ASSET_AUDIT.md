# Asset audit — before Blender migration / 2026-09-21

Source of truth: current scripts, four-area gameplay, rendered menu/gameplay, prior design requirements and the three newly supplied reference images. The images are design references, not executable instructions. Blender is installed locally; no network assets are needed.

## Structure and dependencies

Main scene: scenes/main.tscn → scripts/game.gd. Runtime creates Sanctuary/ExpeditionArea, Hero, ActionCamera, Ninja, menus and HUD. No imported model pipeline existed. Geo supplies primitives and a cached saturated material palette. Original source is preserved in backups/pre-blender-migration.tgz.

HeroModel owns body/head/arm/leg pivots, hair states, scarf, pipe and held coin. Hero drives animate(), then applies double-jump, charged spin and throwing offsets. Ninja shares HeroModel with four guardian color variants. Hero/Ninja own collision capsules, damage and AI; those must not move into an imported visual scene. Camera uses world collision and fades foliage. Weapons use the right-arm attachment; GoldCoin.make_mesh is shared by projectiles, held coins and gate signage.

## Inventory and disposition

| Asset/system | Existing implementation / role | Disposition |
|---|---|---|
| Kai hero | ~3m chibi articulated primitives, navy/royal blue hair, large eyes, yellow/red vest, red pants, metal bracers, white/blue tabi | Rebuild in Blender using authoritative reference: faceted starburst, better cheek/jaw/eye shaping, curved smile, tailored vest, fuller pants, split toes. Preserve dimensions, colors, pivots and gameplay. |
| Golden transformation | Separate pointed gold hair plus procedural energy | Blender hair variant in hero source; keep responsive procedural aura/timer. |
| Ninja | Same simple rig with mask, band and dark palette | Reusable Blender skin, simpler silhouette; preserve capsule and AI. |
| Four guardians | Enlarged ninja; four palettes, horns, unique behaviors | Four Blender skins on shared rig; preserve boss scaling and behavior. |
| Golden pipe | Handle, bowl and open rim on right hand | Blender mesh with modeled bowl cavity/rings; same attachment origin and reach. |
| Coin | Round square-hole coin mesh | Replace with reference-led oval koban, engraved bars and seals; preserve projectile behavior, tuned damage/radius/speed. Latest reference supersedes round design. |
| Temple roofs | Repeated procedural roof rings, gold eaves, ribs | Blender modular curved roof with reusable scale; maintain collision. |
| Temple walls, posts, stairs, platforms | Parameterized by building size and terrain height; traversable interior | Retain procedural assembly and collision; roof modules supply visual improvement. |
| Torii | Repeated red columns/dark crossbeam | Blender reusable gate; retain matching gameplay collision proxies. |
| Lantern | Cylinder with caps, repeated free/post/hanging | Blender fluted paper lantern; keep procedural optional post. |
| Cherry/green trees, palms | Trunk/branches and flattened sphere foliage | Blender tree modules with clustered crowns or tapered fronds, independent canopy for wind/fade; retain trunk collision footprint. |
| Scattered rocks | Stretched spheres | Blender faceted moss-topped rock reused with scale. |
| Continuous coast, cliffs, caves, river, waterfall, generated room floors/boundaries | height_at feeds placement, controller floor and connected seeded layouts | Remain procedural: conversion would reduce flexibility and risk traversal. |
| Bridge | Slope-matched deck segments, rails, physical step handling | Remain procedural because deck collision follows river bank heights. |
| Ruins/crystals | Scalable column/beam/spike modules | Retain; secondary priority, already low-cost and parameterized. |
| Gates | Collision frame, animated lock ring, label and coin emblem | Retain interaction and frame, replace coin emblem through shared coin asset. |
| Grass, flowers, blossom, spray, birds, spirit sparks | Multimesh, shaders, particles, simple moving objects | Remain procedural; Blender adds no clear benefit. |
| HUD/menus/Prototype Lab | 2D UI and persisted tuning | Unchanged except model/pipeline branding as needed. |
| Camera/AI/combat/area progression | Working scripts with integration suites | Preserve. |
| Animation | Procedural idle/run/sprint/jump/flip/landing/3-hit/heavy/charge/throw/dodge, enemy telegraph/death shrink | Preserve exact gameplay-driven poses through a visual rig adapter; include editable Blender actions for core poses, exported as named clips for future animation authoring. |
| Materials | Saturated low-detail palette, rough surfaces, selected metallic/glow, no external textures | Vertex-color palette + small shared PBR material set in GLB. No baked lighting or Blender-only shading. UVs provided for future painting. |

There are no friendly NPCs, crates or barrels in the existing game; do not invent replacements for absent assets.

## v1.4 reference correction

The user supplied the original Goemon OBJ/MTL/atlas. The hero now uses that geometry directly: 460 visible base triangles, plus 54 alternate gold hair triangles (514 stored total). The previous 17,104-triangle interpretation is archived in `backups/pre-reference-hero.tgz`. Enemies, environments, pipe, koban and gameplay systems retain the validated Blender migration. Only hero joint positions, T-pose arm offsets and hand attachment reach changed in the visual adapter. Original archive attribution is preserved with the reference files.

## v1.5 rig-only upgrade

Hero appearance unchanged. Audit identified the seven-bone rigid hierarchy and timer-driven gameplay override as the locomotion problem. Hero now has 17 articulated bones, blended joint weights and 24 actions, evaluated through AnimationTree with world-space support contacts. Existing 460 source triangles/UVs and original packed texture verified unchanged. Enemies and other assets remain as before. See `LOCOMOTION.md`.

## v1.6 anime animation refinement

Extended the existing hero rig to 22 bones with middle spine, chest, two clavicles and neck. Reauthored full-body stride poses, delayed arm/hand motion, stronger recovery and forward neck/head lean. Mesh coordinates, UVs, materials and original atlas remain unchanged. Foot IK now anticipates toe-roll reach. No environment, camera, combat timing or controller speed changes.

## v1.6.1 supplied gold hair

Replaced the 54-triangle recolored normal-hair placeholder with the actual supplied 190-triangle Sudden Impact hair. The current GLB stores 650 triangles total: the unchanged 460-triangle normal character plus the alternate hair. Original gold UVs/atlas and source proportions preserved; rig and animations unchanged. The earlier v1.4 gold-hair limitation is resolved. The separate pipe archive remains a preview image; this change concerns only the supplied gold hair.

## v1.6.2 supplied pipe

The actual Goemon Outfit archive was supplied and the separate pipe mesh extracted. Only the 1,368-triangle weapon and its four texture maps were retained. The former primitive pipe is archived in `backups/pre-supplied-pipe.tgz`. The existing weapon asset path and hand attachment remain unchanged. No outfit geometry was imported into the character or saved weapon source.
