# Edo Ember v01 — preview only

Asset ID: **EDO_EMBER_V01**. Branch: `feat/edo-redesign-preview-v1`, based on PR2 commit `65fa8b1` after fetching current origin/main and the unmerged PR2 branch. No playable default, enemy/town/effect file, push, merge, or running Mac instance was changed.

Original Blender geometry redesign retaining Ed's recognizable black angular hair, wine-red cropped jacket, charcoal frog-button vest, orange flame sleeves, cropped balloon trousers, wrapped shins and indigo shoes. Reference: [Ed, Brave Fencer Musashi artwork](https://www.creativeuncut.com/gallery-02/bfm-ed.html), compared with the repository's packed `Final/Reference/Musashi_Original_Reference.png`. The game name remains Edo. This is an original interpretation, not an imported reference-game model.

The old surface has an oversized rounded hair mass, uneven pointed trouser legs and compressed lower-body separation. The new design uses a smaller, faceted face, directional hair locks, tapered jacket, distinct hands, balanced knee volumes and exposed wrapped shins. Standing visual height remains approximately 2.198 units; character transforms and gameplay collision remain unchanged. The new face without hair is approximately one fifth of standing height; the full hair/head silhouette is deliberately exaggerated.

## Deliverables

- `Edo_Ember_v01.blend`: complete editable studio scene, rigged new surface, materials, UV map, cameras and lights. The shipped original surface is retained as hidden `BEFORE_Edo_Refined` for comparisons. No external library dependencies; original comparison texture is packed.
- `assets/characters/musashi/preview/edo_ember_v01.glb`: preview-only skinned GLB. Actual repository path: `assets/characters/musashi/preview/edo_ember_v01.glb`.
- `Previews/`: same-camera front/three-quarter/side/rear before and after; actual Godot gameplay captures and action pose captures; labeled comparison sheets.
- `asset_report.json`, `validation.json`, `compatibility.json`: build and compatibility evidence.

## Compatibility

All 16 bone names, hierarchy and rest matrices are retained. GLB roundtrip tests compare global rests and all bone poses/hand origins for idle, run, jump, beam and meteor against the original using the existing `MusashiMotion`. All vertices have normalized weights. There are no new root-motion or attack animation tracks: animation timing remains owned by the unchanged gameplay scripts.

This validates the adapter contract and representative poses, not an exhaustive animation/clipping certification. Studio images use Cycles CPU; actual game captures use Godot 4.6.3 OpenGL Compatibility/llvmpipe in cloud. The gameplay comparison uses the normal 63-degree vertical FOV, 14-unit distance, 0.36-radian pitch and 1.4-unit follow height. Close action captures intentionally use a nearer inspection camera. No Mac rendering was used. Software renderer shutdown reported two texture cleanup leaks after successful captures; no pose/check failures were reported.

## Reproduce

From repository root:

```sh
blender -b --python tools/build_edo_redesign_v01.py
blender -b --python tools/validate_edo_v01.py
godot --headless --editor --path . --import --quit
godot --path . --rendering-method gl_compatibility --script tools/preview_edo_v01.gd -- --visual
```

Use a writable XDG config/cache/data directory in a restricted cloud environment. Omit `--visual` and add `--headless` for compatibility checks without captures. The preview harness temporarily swaps only its own scene instance; normal startup keeps `edo_refined.glb`.

The generic repository exporter deliberately skips alternative files under the locked Musashi directory. This version therefore has an explicit scoped builder/export path using the same GLB/Y-up/skinning conventions; it never invokes a generic master overwrite.

## Preserved masters and limitation

SHA-256 comparison against `65fa8b1` proves the approved master, both existing playable .blend sources, shipped GLB, animation adapter, combat script and player script are unchanged. The original .blend sources use Blender 5.2 and cannot be opened by this cloud's Blender 4.3.2. Inspection used the shipped GLB, source builder scripts, approved reports and packed reference image. The new .blend is native Blender 4.3.2 and reopens successfully. No claim is made that the original 5.2 files were natively audited here.

Pending: user visual review before any playable replacement. No technical blocker to reviewing these source/export files.
