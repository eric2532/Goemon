# Ninja purple-handle blade

Reference-inspired curved satin silver blade with a real cutting bevel, compact silver guard, purple sculpted handle, graphite insets, flush fasteners and lavender accents. The source uses separate editable mesh parts. `ninja-purple-weapon.blend` is the weapon-only studio; the complete character and animation actions are in `../ninja-motion-workbench/Ninja_Animation_Workbench.blend`.

Live character source: `assets/blender/characters/goemon_cosplay/ninja.blend`. Runtime model: `assets/models/characters/goemon_cosplay/ninja.glb`. `tools/build_ninja_weapon.py` builds this design, and the roster builder retains it on future Ninja rebuilds. The hand-root transform and exact combat blade-tip axis stay fixed. All nonweapon geometry, UVs, skin weights, materials and rest bones, including the offhand, match the previous asset. Asset and GLB reimport results are in `asset-verification.json`.

Godot now imports the explicitly exported GLBs while Blender sources remain editable build inputs. Disabling automatic `.blend` import avoids a missing editor Blender-path prompt that otherwise blocked refreshing the runtime model. The new purple material and attacking grip alignment passed native gameplay verification. The standalone app remains at the previous build while poses are being authored in Blender.
