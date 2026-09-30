# Environment reskin validation

Baseline: `0da35bc7eaa93c68bf6939b5238989af16920919` (`origin/main` before this branch).
Tools: Blender 4.3.2; Godot 4.6.3 (README currently names 4.6.1).

## Passed

- Clean Godot editor import and game startup; no parse/import/shader errors.
- Thirteen saved Blender sources verified: metre scale, applied mesh scales, UV layers, materials, matching GLB exports. Asset counts and triangle/surface counts are in `assets/models/manifest.json`.
- Deterministic baseline comparison at seed 90824 across every region:

| Area | Exact collision shapes compared | Result |
| --- | ---: | --- |
| Tidefall Sanctuary | 712 | Identical |
| Jade Grotto | 242 | Identical |
| Sakura Highlands | 429 | Identical |
| Sunforge Citadel | 490 | Identical |

For every collision shape, world transform, triangle faces and disabled state are identical. All 8,343 sampled terrain heights per region, playable bounds, outpost positions and final RNG state are also identical. See the compact [audit summary](../../docs/environment-reskin/audit-summary.json). Physics owners and navigation/gameplay code are unchanged.

- `--survival-test`: **27 passed, 0 failures** (timer, waves, pursuit, pause, restart, loss/win and disabled travel).
- `--direct-attacks-test`: **28 passed, 0 failures** (combat/queue/interruptions/character separation).
- `--elemental-orbs-test`: **27 passed, 0 failures** (drops, pickup, line of sight, effects, magnets, pursuit and resets).
- Fourteen rendered views using the actual gameplay camera: sanctuary spawn/temple/bridge/grotto/outpost; spawn/court/outpost in each dormant region. Selected native-resolution captures are [included in the visual review](../../docs/environment-reskin/README.md).
- `git diff --check`; no modifications to existing character/enemy/weapon/animation sources, UI, collision/navigation implementation, gameplay configuration or project renderer configuration.

## Reproduce

From the repository root, after the usual Godot import:

```sh
python tests/environment-reskin/prepare_baseline.py
godot --headless --path . --audio-driver Dummy --script res://tests/environment-reskin/audit.gd -- --label=baseline-fixed --baseline --audit-only
godot --headless --path . --audio-driver Dummy --script res://tests/environment-reskin/audit.gd -- --label=final --audit-only
python tests/environment-reskin/compare_audits.py

godot --headless --path . --audio-driver Dummy -- --survival-test
godot --headless --path . --audio-driver Dummy -- --direct-attacks-test
godot --headless --path . --audio-driver Dummy -- --elemental-orbs-test
```

For screenshots, omit `--audit-only`, use a working display, and run `--rendering-method gl_compatibility` if required by the host. Generated baseline copies and test reports/captures are ignored; the selected review images and compact audit summary are committed.

## Limits

This Linux environment rendered with OpenGL Compatibility and Mesa llvmpipe through an Xorg dummy display. It has no Vulkan/Metal GPU, so Forward+/Metal appearance, hardware frame rate and the macOS application build were **not** validated or rebuilt. Project renderer settings remain unchanged. No performance claim is made from software rendering.

Both the unmodified baseline and reskin capture runs print two existing OpenGL texture-leak warnings during shutdown; no runtime rendering errors occurred. Legacy expedition combat suites assume the pre-survival game mode and were not used; dormant worlds were inspected directly without changing which areas the game exposes.
