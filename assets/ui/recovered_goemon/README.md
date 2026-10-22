# Recovered Goemon weapon HUD images

These transparent 256×256 icons are native Godot renders of the gameplay meshes and materials in `scripts/recovered_goemon_weapons.gd` and `assets/characters/recovered_goemon/weapons/weapons.json`:

- `gold_pipe.png`: the original third-tier `gold_pipe` mesh and its generated gold texture coordinates.
- `ryo.png`: `create_coin()`, including the original ryo projectile texture and UVs.
- `chain_pipe.png`: the recovered grip, projectile head, and alternating links, assembled with the gameplay chain spacing, thickness, and resting sag.

Rebuild from the repository root with `godot --path . --audio-driver Dummy --script tools/render_goemon_weapon_icons.gd`. The native renderer uses 4× MSAA, renders at 512×512, and downsamples to 256×256. Exact vertex bounds keep every part inside a centered frame with 12% padding. The audio override lets this offline image bake run without initializing microphone input.
