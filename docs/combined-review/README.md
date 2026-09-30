# Combined review build

This PR2 branch enables **EDO_EMBER_V01** as the model used when selecting Edo with **Q**. It also includes the original enemy/town asset set, hard enemy cap (default 200, configurable 32–400), and smaller fire/ice effects. This is a playable review build; main is not merged.

The original `assets/characters/musashi/model/edo_refined.glb` and approved Blender masters remain unchanged. Launch with `-- --edo-original` to compare the previous model. Only the model load path changes: the existing 16-bone animation adapter, combat component, hand origins, player collider, movement and ability timings are preserved.

## Launch

1. Check out the verified head of `feat/original-enemies-town-cap`.
2. Import with Godot 4.6.3: `godot --headless --editor --path . --import --quit`.
3. Launch `godot --path .`, start a run, and press **Q** to select the redesigned Edo. Do not add `--edo-original` for the new design.
4. Comparison fallback: `godot --path . -- --edo-original`, then select Edo with Q.

This branch contains the actual playable binding; the separate preview branch alone retains the old startup binding. No Mac launch was performed by the cloud worker.

## Verification on the combined build

- Clean headless editor import; no script errors.
- Original-versus-new rig check, explicitly run with `--edo-original` to retain a genuine old-model baseline: 12 checks passed, covering 16 bones, global rests and full poses/hand origins for idle, run, jump, beam and meteor.
- Normal model selection and explicit original fallback: seven checks each, including correct scene path, collider/health preservation, finite hand origins, four enemy batches, default cap and town dressing.
- Firecaster, meteor, survival/cap and maintained combat regression suites: zero failures.
- Actual cloud OpenGL screenshots: `edo-gameplay.png` and `edo-elemental-overlap.png`. The latter shows the redesigned Edo with three fire/ice pairs and the blue surge shield. No Mac FPS claim.
- Renderer shutdown retains the previously documented texture cleanup warnings; no script or shader failure occurred.

Logs are local `tests/combined-*.log`; structured results are in `validation.json`. Existing full-session cap checks remain in `tests/enemy-cap-validation.md`. The character source and initial preview evidence are under `assets/blender/enemies/musashi/Redesign_v01`.
