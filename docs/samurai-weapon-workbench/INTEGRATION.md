# Samurai runtime integration

The approved maroon katana is 20% larger than the animation draft, with a sharper
point and no scabbard. The original body, hair, painted UVs, skin weights and rest
bones remain unchanged. The runtime exporter consolidates the 20 weapon parts into a blade and a fixed hilt.

Run Blender in background with `--python tools/export_samurai_animations.py` to
sample the saved workbench and rebuild the runtime GLB and pose JSON. The original
character source and editable workbench are read-only during export.

Idle loops at frames 1–61, run at 1–25. The five-strike action uses contact frames
12, 30, 48, 66 and 87, mapped to native damage contacts. Jumping can retain a
strike; dodging and bow actions release the authored pose. Native damage,
cooldowns, overdrive and input queuing rules remain owned by combat.

Verification: Samurai pose 108/108, real gameplay 29/29 (native capture 35/35),
melee response 140/140, input cancellation 106/106, no backlog 38/38,
selection idle 283/283, Ninja poses 29/29, Dragoon poses 1872/1872.
The existing reach suite has six failures for hero IDs 5,7,8,9,11,12; the same
six fail in the pre-Samurai source. Samurai's reach cases pass. Reports and native
screenshots are in the main checkout under build/Other Files/Samurai integration.
