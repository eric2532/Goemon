# Goemon playable skins

Settings → Playable skins offers **Goemon · Original** and **Ren · Storm Rival**. Original remains the default. Ren is an optional chibi-anime rival; the two earlier experiments are retained as source files but are no longer used by the picker. Both entries have live 3D previews, an isolated Golden Surge preview and a saved equipped state. Selection survives launch, character switching and retry. Choosing a Goemon skin while Edo is active does not select Goemon.

## Current direction: Storm Rival

The user rejected the first exact-measurement redesign and the subsequent slender anime version, then approved a compact chibi-anime rival using the original as a quality benchmark.

This revision retains the original body/head vertices and weights, compact limbs, large hands, outfit silhouette and 22-bone / 24-animation rig. It changes the front-face texture to a large-eyed cocky grin, models 13 broad curved cobalt hair locks, and adds an ivory headband with ties and an indigo/gold shoulder sash. The original rear/temple hair texture remains as a dark undercut. The sash follows the source jacket surface and inherits barycentrically interpolated skin weights so it follows the torso through animation. Golden Surge uses a lifted gold version of the new hair.

Both skins use the same standard in-game lighting, display scale, comparison camera and original cloak fit. The prior custom anime shaders and 1.3× scale are not used. Collision, movement, damage, weapon assets, health and abilities are unchanged. The live rig, animation controller, weapons and cloth nodes are preserved when switching skins.

The original `kai.blend`, `kai.glb` and atlas are not overwritten. The source SHA-256 remains `9f7088ff693b982f79e25874f67f46f9fd65d0fc906ca255d85cc6b6f8cef54c`.

## Current sources

- `assets/blender/characters/ren_rival.blend`: editable model with both hair variants and packed face texture.
- `assets/models/characters/ren_rival.glb`: current runtime asset.
- `assets/textures/characters/ren_rival/face.png`: generated face texture, used unchanged. UV placement is authored on the model.
- `tools/build_ren_rival.py`: reproducible Blender generator and preservation/weight validation.
- `rival/validation.json`: original hash, geometry/weight preservation, bone/animation counts.
- `scripts/hero_skins.gd`: skin catalog and shared mesh cache.
- `scripts/skin_picker.gd`: Settings picker and live previews.
- `tools/preview_rival_skin.gd`: same-camera front, three-quarter, back and gold comparisons.

The face was generated with the built-in image-generation tool; [the exact prompt is saved here](rival/art-prompt.md). No concept illustration is substituted for the playable-model preview.

`ren.blend` and `ren_anime.blend`, their exports, generators and accompanying art remain as prior experiments. They are not selected by the current `ren` catalog entry.

## Checks

From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ren_rival.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview_rival_skin.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --skins-visual
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --direct-attacks-test --test-ren-skin
```

The skin suite covers defaults, legacy settings, invalid IDs, UI selection and saved choice, model startup, rig/attachment identity, repeated switching, original scale/resource restoration, pause timers, health/position, cloak/Surge continuity, Edo switching, restart, movement, double jump, number attacks and dash. It uses a temporary settings file and restores user preferences. The combat suite runs with the rival equipped and checks actual damage, projectiles, range, queues, cloak bonuses, Surge and cancellation.

Comparison renders and logs are under `tests/goemon-skins/rival/`. Picker and in-world captures are under `tests/goemon-skins/`. The playable release is `build/Goemon.app`.

Final results: all 33 skin checks and 28 combat checks pass with Storm Rival. The signed universal macOS release passes the 33 skin checks under the Metal renderer with no logged script/render errors. The verified app is `build/Goemon.app`; the previous version is preserved as `build/Goemon-before-rival-20261001.app`.
