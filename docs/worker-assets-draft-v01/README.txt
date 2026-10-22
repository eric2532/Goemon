WORKER — ASSET DRAFT v01

Approved teal/straw-hat worker design, with an angry painted expression.
This folder is excluded from Godot import. No worker gameplay, scene,
active model, animation code or current app has been replaced.

Editable model: source/worker-angry-draft.blend
Standalone model: export/worker-angry-draft.glb
Optional separate tool: export/worker-pickaxe.glb
Textures: textures/ (also packed in the Blender source and GLB)
Reviews: renders/worker-front.png, worker-side.png, worker-back.png,
worker-three-quarter.png and worker-angry-face-detail.png

The face has painted brows, eyes, creases and a downturned mouth on a
closed volumetric skull. The nose is part of that same skull geometry.
Teal layered work clothes, rolled cuffs, linen leg wraps, rope belt,
straw sandals, woven basket and removable gold cargo follow the concept.
The model is 3.0 authoring metres tall, about 91% of Goemon's source height.
The Body, Head, Hat, Arms, Legs, Basket and Gold Cargo have named pivots.
This is a static review asset: skeletal rigging, animations, attachment
logic, collision, behavior and game integration have not been supplied.

REBUILD (from project root)
python3 docs/worker-assets-draft-v01/paint_worker.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python docs/worker-assets-draft-v01/build_worker.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python docs/worker-assets-draft-v01/verify_worker.py
