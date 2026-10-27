# Sonic — recovered SADX master

The user's 2026-10-23 request is to retain Sonic's original model and motion,
not make a Goemon cosplay. These are the authoritative editable masters:

| Master | Normal export | Use |
| --- | --- | --- |
| `sonic.blend` | `assets/models/characters/sonic/sonic.glb` | Body, 73 original clips |
| `ball.blend` | `assets/models/characters/sonic/ball.glb` | Jump, homing and rolling ball |
| `curled.blend` | `assets/models/characters/sonic/curled.glb` | Preserved alternate curled source, currently unused |
| `effect_trail.blend` | `assets/models/characters/sonic/effect_trail.glb` | Original 12-triangle blue dash trail, SON_EFF texture 0 |
| `effect_ball.blend` | `assets/models/characters/sonic/effect_ball.glb` | Original 100-triangle blue aura, SON_EFF texture 7 |

Follow `docs/BLENDER_PIPELINE.md`. Scenes use metres, scale length 1 and 60 fps.
`Sonic_UnitAndFacing` converts one original unit to 0.2 metres, faces Godot -Z,
and raises the original centre by 1.08 m. Keep this wrapper and the bone names.
Do not normalize individual bones or replace the original textures/UVs.

The original Ninja rigid parts are prepared as one 73-bone skin. The source
game's type-2 weld table determines the seam weights; this is not a newly drawn
mesh or an approximate retarget. Keep the source vertex/UV topology, bind poses,
NLA names and all clips. The Blender files contain packed original textures.
No weapon sockets or replacement animation system are needed for Sonic.

Export saved edits with the project's normal exporter:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/characters/sonic/sonic.blend --python tools/export_blender.py
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py optimize --asset sonic
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/sonic_import.gd
python3 tools/goemon_assets.py compare --asset sonic --after 'build/Other Files/Asset Toolkit/Candidates/sonic.glb' --capture
```

Review the captured front, side, back and motion before `activate --asset sonic`.
Refresh Godot imports, run `check`, the packed motion check and the desktop
gameplay test described in `docs/recovered-sonic.md`. Never edit the optimized
GLB or change preservation hashes to force a pass.

`tools/sonic/create_blender_master.py` is the initial importer, not the exporter.
It deliberately skips existing masters. Do not delete an edited master to rerun
recovery. Raw recovered assets live in `assets/characters/recovered_sonic/`.
The body export is routed through `assets/optimized/routes.json`; the ball uses
its ordinary export. Do not point gameplay at the raw, unscaled recovery GLBs.

Animation only supplies poses. `scripts/sonic_combat.gd` owns the host game's
movement, hits and skill state. Read the fidelity limits and provenance in
`docs/recovered-sonic.md` before changing either side.

The blue effects were recovered with `tools/sonic/effects.py`. They retain their
original UVs and texture pixels. `scripts/sonic_effects.gd` uses the ordinary
exports with additive, unshaded owned material overrides and a fixed set of
instances. Their single surfaces do not need an optimized derivative. Run the
Sonic recovery unit tests after edits; they compare source/export triangle
corners, UVs and decoded pixels. Do not rerun the initial importer over edits.
