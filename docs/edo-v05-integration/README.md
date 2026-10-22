# Edo V05 local integration

Historical integration record. Normal Edo selection now uses the [anime refinement](../edo-anime/README.md). Launch with `-- --edo-v05` to use this preserved V05 appearance and run its historical integration checks below.

Integrated into the combined gameplay review at base commit `32c02225e8ec9924d770de53c3df6237cb426cc2`, using the V05 source and export from `9299c3532e5a6f6d341defb0ea0f92277a975e16`.

The runtime material mapper reuses V01's existing crimson jacket, charcoal vest, black hair, warm skin, ivory wraps and indigo footwear resources on V05. Connected garment surfaces are partitioned by rest-space region without changing vertex positions, skin weights or triangles.

Normal Edo selection loads `assets/characters/musashi/preview/edo_posture_shoulders_v05.glb`. Its relaxed idle changes only the arms while stationary, grounded, and outside combat. Running, jumping, dodging, fireballs, beam and meteor poses retain the existing adapter. The original model and original idle remain available by launching Godot with `-- --edo-original`.

The V05 native source and historical review reports are in `assets/blender/enemies/musashi/Redesign_v05_Posture/`. The combined enemy cap, town assets, smaller elemental effects, colliders and combat mechanics are preserved. The canceled Goemon hero prototypes are not used.

Validation commands with installed Godot 4.6.1:

```sh
Godot --headless --path . --editor --import
Godot --headless --path . --script res://tests/edo-redesign-v05/integration.gd -- --edo-v05
Godot --headless --path . --script res://tests/edo-redesign-v01/combined_review.gd
Godot --headless --path . --script res://tests/edo-redesign-v01/combined_review.gd -- --edo-original
Godot --headless --path . -- --firecaster-test
Godot --path . --script res://tests/edo-redesign-v05/integration.gd -- --visual --edo-v05
```

The visual check renders the final integrated model with the game's native renderer and saves the idle and gameplay views under `/tmp/goemon-edo-v05-*.png` before exiting.
