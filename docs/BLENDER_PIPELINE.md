# Blender → Godot asset workflow

The working game retains procedural four-area world assembly, player/enemy capsules and scripts, combat, camera, menus and Prototype Lab. Blender is now the editable source for the main character, enemies/guardians, weapons and migrated reusable environment modules.

## Locations

- assets/blender/{characters,enemies,environments,props,weapons,architecture}/: editable **.blend source**. The .gdignore prevents Godot from auto-converting sources.
- assets/models/: corresponding **.glb game exports**. manifest.json records mesh/triangle/surface counts.
- assets/references/: supplied blue hero, golden transformation and oval koban images. Preserve yellow/red clothing, bracers, white/blue shoes and established gameplay.
- assets/textures/: the hero uses `characters/goemon_original.png`, copied from the supplied archive and packed into its .blend and GLB. Other models use vertex colors.
- assets/materials/: palette/material conventions.
- scripts/assets.gd: cached GLB instantiation; no gameplay behavior.
- scripts/hero_model.gd: stable adapter between controller poses and imported skeleton.
- docs/ASSET_AUDIT.md: inventory, dependencies, and why terrain/bridge/water/effects remain procedural.

Names: lowercase snake_case files. Keep nodes Skin, Hair_Normal, Hair_Gold, Canopy, Trunk, and rig bone names stable. Guardian files 0–3 correspond to Arashi, Hisui, Hanami, Akagane.

## Scale, orientation and pivots

One Blender unit = **one metre**. Blender Z up, facing **+Y**; glTF Y-up export converts this to Godot Y up / **-Z forward**. Authoring helpers accept Godot coordinates and convert internally.

Character origin is ground level between the feet. Godot owns collision capsules; never export a replacement collider inside a skin. Hero rest pivots in Godot metres:

| Bone | Position |
|---|---|
| Root | 0, 0, 0 |
| Head | 0, 1.448745, 0 |
| Arm_L / Arm_R | ±0.406665, 1.304718, 0 |
| Leg_L / Leg_R | ±0.254166, 0.965830, 0 |
| Sash | 0, 0.931941, -0.338888 (unused by original mesh) |

The hero now uses the 22-bone locomotion hierarchy described in `LOCOMOTION.md`, with blended joint rings, rigid shoes, an active AnimationTree and terrain foot IK. Enemies retain their prior seven-bone rig. The controller owns translation and the double-jump body pivot; Hand_R owns the hero weapon attachment.

Pipe origin is its grip. Coin origin is its centre, face normal ±Z in Godot. Tree origin is ground contact; canopy origin is near its centre for wind/fading. Roof is a 10×10m module with 2.8m rise, scaled to existing temple tiers. Torii is 8m nominal width and 5.4m high; collision retains established post footprints.

## Updating an existing asset

1. Open its .blend in local Blender 5.2.2 LTS.
2. Edit mesh, vertex colors, weights or actions. Blue hair is the default source preview; reveal Hair_Gold to edit the transformation.
3. Preserve bone/node names and attachment origins. Apply mesh scale; keep metre scale 1. UVs exist for future painting; update after topology changes.
4. Save. **Do not rerun the initial generator to export hand edits**; it recreates geometry.
5. Export with tools/export_blender.py. It temporarily reveals both hair variants and emits each named NLA track separately.
6. Let Godot reimport the GLB. Runtime loads via GameAssets; unchanged filenames need no reference rewiring.
7. Run the game. Inspect front/back/both sides/three-quarter, movement, attacks, charge, transformation, attachments and gameplay-camera readability.
8. Fix the source and repeat. Verify roof/stair collision and tree fading after environment edits.

Local commands, from project root:

    /Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/characters/kai.blend --python tools/export_blender.py
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/export_blender.py -- --all
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
    /Applications/Godot.app/Contents/MacOS/Godot --path . -- --asset-visual

Exporter validates metre units, applied scale, UVs and Color attribute. Sources/references are excluded from builds. GLBs embed materials; no image textures are required.

## Materials and budgets

Vertex palette uses the active **Color** corner attribute. Three transferable Principled/PBR treatments: matte, metallic and subtle emissive. Color painting is the primary color-editing workflow. Do not rely on Blender-only procedural shaders.

Meshes are joined into useful visible/animated groups. Hero skin and two hair variants are independently skinned; only one hair variant is visible at a time. Environment modules use one/two meshes and a small material set. See the manifest for measured triangle counts. Avoid dense details invisible at gameplay distance.

## Animation

Sources contain editable NLA actions: Idle, Run, Sprint, Attack_Left, Attack_Right, Attack_Finish, Heavy, Charge_Spin, Throw, Jump, Front_Flip, Hit, Death. Tracks are muted in saved sources so neutral models open cleanly. Select one action or unmute one track to preview/edit; do not preview every track simultaneously. Exporter temporarily enables tracks and exports distinct clips.

**Live gameplay preserves procedural timing and drives the imported skeleton through HeroModel.** GLB AnimationPlayer clips are an editable authoring/future-integration library; editing one does not silently override combat timing or double-jump/spin poses. To adopt a clip for gameplay, blend it in the visual adapter while retaining strike events in Hero. Damage and collision rules stay outside animation assets.

## Tools and checks

- tools/build_blender_assets.py: original initial-authoring/rebuild recipe. Recreates all 15 assets and overwrites sources; use deliberately after backing up artist changes.
- tools/export_blender.py: normal exporter for edited sources, updates manifest.
- scripts/asset_validation.gd: Godot rendered inspection and imported rig/clip checks; screenshots in tests/blender-*.png.
- --combat-test, --expansion-test, --smoke-test: preserve combat, traversal, camera collision and progression.
- Original sources remain recoverable in backups/pre-blender-migration.tgz. Obsolete primitive construction was removed from active code after replacements were inspected.

Use the existing Godot macOS preset to build the runnable app. Do not ship .blend, references, backups or authoring tools.

## Reference-accurate hero (v1.4)

The user-supplied archive is the authoritative geometry source: `assets/references/goemon_original/Goe/goe.obj`, its MTL and 128×128 atlas. Original archive attribution is retained in `infoz.txt`. The active game file remains `characters/kai` for reference compatibility; it now contains the supplied Goemon model rather than the former procedural interpretation.

All **460 original triangles and UV corners** are preserved. Only a uniform conversion to 3.3 metres tall and a facing/up-axis conversion were applied. No smoothing, remeshing, face replacement, clothing redesign or additional hair spikes were added. Hair triangles are separated into a named mesh solely for transformation visibility. The texture uses nearest filtering, original UVs, matte material, and no added surface detail.

`tools/import_reference_hero.py` is the one-time importer. It assigns rigid weights by existing connected mesh islands, retains the seven driver names and 13 editable NLA clips, and creates a `Reference_Camera` plus an export-excluded studio. The saved source opens in the original T pose. The Godot adapter lowers each arm by 90° in the visual transform, uses source-specific shoulder/hip pivots, and moves the weapon grip to the original hand reach. Enemies retain their existing rig dimensions. Gameplay controls, hit timing, movement, collision, camera and area generation are unchanged.

The archive contains only the normal blue version. R remains functional via a gold material variant of the **same original hair geometry**; this is not a claim to reproduce the different golden hairstyle/angry-face reference. The original face atlas stays unchanged during R.

The source's perspective reference camera uses 70 mm, position (3.5, 7.4, 2.15), target (0, 0, 1.65). Inspect `tests/reference-comparison.png`, source front/back/side renders and `tests/blender-reference-import-tpose.png` for comparisons. Normal runtime poses remain independent of the T-pose source.

Run `tools/verify_reference_hero.py` inside Blender with kai.blend open to verify all original triangles and UV corners against the OBJ at a 0.00001 tolerance, complete skin weights, seven bones and thirteen clips. `tools/export_blender.py` accepts textured materials as well as vertex palettes, and excludes marked studio objects. The old batch generator deliberately preserves this hero when the original reference is present.

## v1.6 locomotion update

The v1.4 seven-bone/13-clip notes above describe the import milestone. The current hero source has **22 bones and 24 clips**; see `LOCOMOTION.md` for the authoritative hierarchy, runtime blend/IK pipeline, controls and tests. Original reference geometry and packed texture remain unchanged. Use the saved source plus the normal exporter, not the original seven-bone importer.

## Supplied Sudden Impact hair — v1.6.1

`Hair_Gold` in `assets/blender/characters/kai.blend` now contains the actual supplied `SI_Goe/SI_goe.obj` hair: three connected islands, 110 vertices, 190 triangles. It uses the original UVs and packed `goemon_sudden_impact.png` atlas. The existing character scale is used for both hair variants, so the taller gold silhouette is not normalized away. The original body, face, normal hair, 22-bone rig and 24 animation actions are preserved. All new hair vertices bind rigidly to Head.

The user-supplied archive is extracted under `assets/references/goemon_sudden_impact/`, including original attribution. `tools/import_surge_hair.py` replaces only Hair_Gold; it does not recreate the character or animations. Run it only to deliberately reimport the supplied hair. Use the normal exporter for subsequent edits. `tools/verify_surge_hair.py` checks source triangle/UV fidelity, original packed atlas and head weights; `tools/verify_reference_hero.py` still checks the unchanged normal character.

R continues using the existing visibility switch, 30-second timer, aura and combat effects. No gameplay script changes are required for the replacement asset.

## Supplied pipe — v1.6.2

`assets/blender/weapons/golden_pipe.blend` contains only the weapon mesh extracted from the supplied Goemon Outfit archive (`b_goemon_m.fbx`, `MiiS_Sword_VIS_O_OBJShape`). No outfit, head, body, armature or unused outfit textures are retained. Original topology and UVs are preserved: 910 vertices, 1,368 triangles, one material. The four original 512×512 color/metallic/roughness/normal maps live in `assets/textures/weapons/goemon_pipe/` and are packed into Blender.

The mesh is uniformly scaled and reoriented to the established weapon convention: origin at the thin shaft grip, Blender +Y toward the bowl and +Z through the bowl opening (Godot -Z / +Y). The whole pipe is about 1.61 m long, with the bowl extending about 1.23 m forward from the grip. Existing Hand_R attachment, attacks and hit timing remain unchanged.

`tools/import_supplied_pipe.py` deliberately extracts only the weapon from the original user-supplied archive; temporary outfit geometry is discarded before saving. `tools/verify_supplied_pipe.py` compares the saved geometry/UVs and packed texture bytes to that archive. Normal future edits use the saved Blender source plus `tools/export_blender.py`. Batch environment regeneration now protects this supplied weapon from the old primitive generator.

## Reference koban — v1.9.2

`assets/blender/weapons/koban.blend` is the editable coin source; `assets/models/weapons/koban.glb` is the game export. The supplied style reference is retained in `assets/references/koban/shape-reference.png`. The coin is 0.46 × 0.90 × 0.07 m, centered at the existing origin with the face in Godot XY, preserving all held/projectile integration. Rounded ends, nearly straight sides, a modeled bevel/rim and inset double-sided faces replace the previous wider oval. One mesh, 1,024 triangles, two PBR materials.

Local original color/normal maps are in `assets/textures/weapons/koban/` and packed in the source/GLB. `python3 tools/draw_koban_texture.py` recreates the striped gold atlas and dark stamps using Pillow and the locally installed Hiragino Sans GB font. No remote assets are used. `Blender --background --python tools/build_koban.py` rebuilds only this coin and exports it. The batch generator's `coin()` delegates to this source generator. For hand edits in Blender, save the source and run `tools/export_blender.py` instead of rebuilding. `tools/render_koban.py` produces front/back/three-quarter source inspection renders without altering the source.

Projectile damage, collision radius, charge/surge scaling, spin and hand attachment are unchanged. Both normal and giant coins share the new GLB.
