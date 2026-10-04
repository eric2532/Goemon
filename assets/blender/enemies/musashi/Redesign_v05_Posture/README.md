# EDO_POSTURE_SHOULDERS_V05 — focused posture and shoulder review

V04's stiff/shrugged appearance has two causes: its nearly level high shoulder surface crowds the neck, and the existing idle adapter turns both arms inward (+/-0.17 rad side angles) while flexing forearms by 0.26 rad, placing the fists close to the hips. Neutral model stance and runtime idle are therefore shown separately.

## Geometry correction

The existing connected jacket surface is reshaped directly: outer shoulders lowered by up to 0.067 units, a continuous slope toward the neck, a small backward shoulder adjustment, a narrower upper collar and local shoulder relaxation. No spherical shoulder caps are added. Lower sleeves and hands move slightly forward/outward; stance narrows by 0.016 per foot while the corrected upper pelvis remains unchanged. Head/face/hair geometry and skeleton rest transforms are unchanged. Total geometry stays at 46,790 triangles; this pass adds no subdivision or topology density.

## Optional idle correction — separate from geometry

`tools/edo_relaxed_idle_preview_v05.gd` inherits the existing motion adapter. Only stationary, grounded, non-combat IDLE/MOVING states use a relaxed arm side angle (-/+0.025 rad), small upper-arm flexion and 0.13-rad forearm bend. Movement, airborne poses and combat use the unchanged parent behavior. The preview harness verifies representative run/jump/beam/meteor bone poses remain identical. This adapter is **not wired into gameplay**.

- Neutral comparisons isolate the geometry change.
- Actual-idle comparison uses the existing adapter on both V04 and V05.
- Optional relaxed idle is a separately labeled preview, not presented as the current game's behavior.

## Review files

`Edo_Posture_Shoulders_v05.blend` is the editable native source, with hidden V04 reference, existing rig, packed source screenshot and studio setup. `assets/characters/musashi/preview/edo_posture_shoulders_v05.glb` is an opt-in export.

`Previews/00_front_neutral.png`, `01_side_neutral.png`, `02_threequarter_neutral.png`, `03_shoulders_neutral.png`: matched neutral geometry comparisons.

`Previews/04_actual_idle.png`: V04/V05 with the existing game idle. `05_optional_idle.png`: existing V05 idle versus optional relaxed idle. `06_game_camera.png`: actual game-camera comparison with the unchanged idle. `shoulder_raise_v05.png`, `pose_beam.png`, `pose_meteor.png` supply deformation review views.

Rebuild using `blender -b --python tools/build_edo_posture_v05.py`. After Godot import, run `tools/preview_edo_posture_v05.gd -- --visual` through Godot for the independent review harness.

No default model or motion-adapter replacement, gameplay-branch changes, merge or Mac operation. All earlier versions preserved. Pending: user review of the shoulder shape, neutral stance, and separately labeled relaxed idle. Passing bone checks is not final artistic/deformation approval.
