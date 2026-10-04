# Castle humanoid allies

These are optimized, rigged adaptations of the existing authored meshes from `feat/hero-concept-models` at `1064214f1f6497a854edd42f11060c40a0bb3ae6`. Originals remain unchanged under `asset_packs/hero_concepts`. No character was redesigned or replaced with a new generated model. Subdivision and microscopic detail were reduced; original material colors were consolidated into up to four vertex-color material surfaces.

Each adapted source contains the actual Goemon armature/rest and its copied animation actions from `assets/blender/characters/kai.blend`. The game reuses `HeroLocomotion` and `PipeCombo` for live attack poses and weapon contacts. Static held staff/tonfa geometry is omitted from the runtime copies; identity clothing, hair and carried accessories remain. The game attaches the existing golden pipe to the animated right hand.

Portraits are Blender renders of the delivered optimized and rigged geometry. Rebuild using `tools/build_defense_heroes.py`; all original sources remain separately editable and preserved.
