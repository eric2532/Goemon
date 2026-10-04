# Edo anime refinement

The normal Edo character now uses this refinement. It follows the approved Storm Rival direction while retaining Edo's own design: tall swept near-black crest, asymmetric fringe, amber eyes, crimson jacket and trousers, orange sleeve flames, charcoal vest, ivory wraps and indigo shoes.

Edo's runtime visual is uniformly enlarged by 20% to bring his size closer to Goemon. The display scale includes his skeleton so effects continue to originate at his visible hands. His proportions, grounded origin and gameplay collider remain unchanged. `tools/preview_edo_size.gd` renders Goemon, the previous Edo size and the enlarged Edo with a shared camera.

The size adjustment passed all 25 animation/attachment integration checks and all 33 packaged-app skin checks on Metal. `build/Goemon.app` contains the enlarged Edo; `build/Goemon-before-edo-size-20261001.app` preserves the approved smaller version.

The face is broader, with clean anime features and a small confident smirk. Broad swept locks leave both eyes visible. The garment shader uses rest coordinates to draw clean lapel borders, three flame tongues on each sleeve and subtle wrap overlaps without the prior triangle-shaped color boundaries. Clothing albedo constants match the previous V05 palette exactly. Hair uses the established near-black and jade highlight values. The generated face stays within Edo's warm tan skin palette.

## Assets and rebuild

- Editable model: `assets/blender/characters/edo_anime.blend`.
- Export: `assets/models/characters/edo_anime.glb`.
- Face texture: `assets/textures/characters/edo_anime/face.png`, generated with the built-in imagegen tool and copied unchanged. [Exact prompt](art-prompt.md).
- Rebuild: Blender `--background --python tools/build_edo_anime.py`, then Godot `--headless --path . --editor --import`.
- Runtime color treatment: `assets/characters/musashi/materials/anime_palette.gd` and `anime_garment.gdshader`. The GLB includes base materials; the in-game clean garment borders and wrap lines use this shader.
- Same-camera comparison: Godot `--path . --script tools/preview_edo_anime.gd`.

The derivative starts from the currently integrated V05 playable body and skeleton. Both the V05 Blender source and canonical `Final/Musashi_Final.blend` remain byte-identical; hashes are recorded in [validation.json](validation.json). Body vertices and weights, all 16 bone rest transforms, and the existing relaxed idle adapter remain unchanged. Only the visual head/hair and material treatment are replaced. No collider, attack, movement, health, or Goemon skin behavior is changed.

Normal startup selects this model. `-- --edo-v05` loads the previous V05 appearance; `-- --edo-original` retains the older original fallback. This replaces Edo's default appearance and does not add Edo choices to Goemon's skin picker.

## Verification

`Godot --headless --path . --script tests/edo-anime/integration.gd` checks full skeleton poses and both hand attachment origins against V05 for idle, run, jump, dodge, beam, meteor, fireball, hit reaction and shield. It also checks rig bindings, unchanged collision/health, character switching and retention of Goemon's selected skin. Add `-- --visual` without headless mode for native game captures.

`Godot --headless --path . -- --firecaster-test` covers actual fireball volleys, heavy fireball splash, beam steering/damage/range, teleport effects and cleanup, pause and character switching. Generated captures and logs are in `tests/edo-anime/`.

The same-camera front, three-quarter and rear comparison uses identical lighting, camera size and pose for the previous model and the refinement. These are actual Godot model renders, not concept illustrations.

Validated with Godot 4.6.1: 25 integration checks passed in both headless and Metal visual runs; all 49 firecaster checks passed. The headless firecaster suite reported an ObjectDB leak warning during shutdown after passing; no script or rendering errors appeared in the integration or visual runs.

The signed macOS release passed all 33 skin/character regression checks using Metal, with no logged warnings or errors. The V05 fallback also passed its existing integration suite. `build/Goemon.app` is the updated release; `build/Goemon-before-edo-anime-20261001.app` preserves the previous build.
