# Goemon original ROM presentation

Goemon uses the original N64 rigid body and native part matrices, without skin retargeting. These assets were recovered from the supplied US revision0 Mystical Ninja ROM (SHA2561603be37427a33548857fc3d2e8867ede71121c353fb631b79b44f1d94845d80).

- body/: thirteen original rigid body display lists, nine original decoded textures, and the separate golden head display list0900ACE8. Verified3582 geometry/pixel checks. A single uniform scale preserves the established standing height; a Y half-turn converts native+Z facing to game−Z. Eyes/mouth currently use the source neutral expression.
- motion.json:126 clips,2007 frames,232 native action mappings/playback rates. Channel decoder matched23847 original-MIPS values exactly;5498 local matrices matched within1.21e-6. Native30Hz gameplay is2 VI retraces per step. Full-stick run action0F is proven by the original analog selector.
- combat_profile.json: retail action rows/event timing. The current game's input, damage, trajectory, growth and upgrade rules remain in force. First two combo strikes flow to the next; final native recovery plays.
- weapons/: original display-list vertices, triangle/UV data and PIC-decoded textures. Body and pipe display lists share the original animation world matrices. A compatibility equipment skeleton does not deform body geometry. Coin and chain meshes are selected per instance, preserving other fighters' shared assets.
- vfx/: original hit-atlas pixels, original golden spike geometry and10 source animation frames. Hit composition/scale/fade adapt the source pixels to this engine.

Goemon-only adapters select original run, rise/fall/landing, standing/moving/air coin, combo/recovery, chain and golden transformation poses. Original body proportions/vertices are preserved. The current double-jump body turn and R gameplay values remain unchanged. Current-engine movement, projectile trajectories and hit composition are adaptations; this does not emulate the complete N64 engine.

Full extraction scripts, untouched ROM identity, executable decoder/contact proofs and native comparisons are retained in build/Other Files/Goemon ROM Recovery in the primary project. Audio has separate provenance in assets/audio/recovered_goemon/README.md.

The default pipe is the original third-tier Gold Pipe: display list09002518, dynamic material bank080+44F0, PIC801C32x64 gold texture. Its original linear normal/view texture generation is reproduced per vertex. Actions68/69/6A and recovery6B/6C/6D use native attachments; original audio is shared with the basic pipe. Gold geometry/texture/tier tables and all41 weapon matrices passed400 source checks.
