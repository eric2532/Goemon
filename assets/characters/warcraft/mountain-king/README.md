# Mountain King runtime assets

Generated from the authoritative editable `Warcraft/assets/MountainKing/` package
in the adjacent project. Preserve all 27 clips, eight geosets and both skin layers.
The main GLB is `assets/models/characters/warcraft/mountain-king/mountain-king.glb`.
`motion.json` stores source opacity and Avatar-layer samples; `avatar_*.png` are
original alternate skin composites. WAVs are copied without resampling.

`effects/*.res` are generated immutable mesh/particle samples. Do not edit these
or optimized GLB derivatives. Rebuild using the commands in
`docs/recovered-warcraft.md`, then audit, verify preservation/imported motion and
review rendered gameplay. Blue energy is intentional user direction and is baked in the editable
master/exported texture; the model loader does not recolor it. Body/armor
textures retain their original colors. Original portrait animations, spell tables
and archives remain in the editable Warcraft package.

Armor and clothing are authored blue in the saved body/portrait masters and
exported textures, including Avatar armor; no runtime outfit tint is needed.
