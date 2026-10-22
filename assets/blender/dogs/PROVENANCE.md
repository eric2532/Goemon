# Castle ally dog models

These models are new Blender game-ready rebuilds of the ten approved dog identities on `feat/ninja-dog-models` at `f511c48`. Their original PNG references and dense static sculptures remain preserved under `asset_packs/ninja_dogs`. All references were visually reviewed before the rebuild.

Each dog has newly authored unified canine anatomy, vertex-painted breed markings, distinct ears/tail/equipment, an editable armature with planted-foot IK, and authored idle/run/bite/hurt/death clips. Mesh surfaces are merged by material; no dense static sculpture is used at runtime. Portraits are transparent Blender renders of the delivered dog meshes.

The animation contact for `attack` is 0.38 seconds into a 1-second clip. The run reference speed is 2.4 m/s; the runtime should advance the run animation proportionally to actual horizontal speed. Idle/run use Blender `_loop` naming hints; normal Godot imports expose `idle` and `run`.

Rebuild with `tools/build_defense_dogs.py`; per-dog JSON and `manifest.json` record geometry/rig budgets, clip timings, reference hashes and output hashes. Fine illustrated fur and embroidery are interpreted as deliberate, inexpensive stylized forms.
