FOREST SHRINE ENEMY MODELS — ASSET PASS 01

Four editable Blender sources and self-contained textured GLB exports.
Rounded stylized shapes, painted faces fitted to curved geometry, all larger than the actual Goemon master.
No enemies or behavior in the game have been replaced. No rig or animations are included.

Each enemy has front, side, back, three-quarter and face-detail Blender renders.
exported-model-lineup.png compares actual Godot imports with Goemon at the same world scale.
model-review-contact-sheet.png shows the actual models and close facial artwork.

Blender sources: assets/blender/enemies/forest_redesign_v01/
GLBs: assets/models/enemies/forest_redesign_v01/
Textures: assets/textures/enemies/forest_redesign_v01/
Reproducible generators: tools/enemy_redesign/

Build textures first with python3 tools/enemy_redesign/paint_<enemy>.py,
then Blender --background --python tools/enemy_redesign/build_<enemy>.py.
Goemon inspection report must be present before importing common.py.
Verify the exported assets with python3 tools/enemy_redesign/verify_assets.py.

Standalone Godot preview is in godot-preview/; run godot --path <preview-folder> --script preview.gd.
Runtime art/polygon budgets and animations will need a separate integration pass.
