# Knight energy lion

`energy_lion.blend` is the editable master. The runtime export is
`assets/vfx/knight_lion/energy_lion.glb`; the spectral material is
`assets/vfx/knight_lion/energy.gdshader`. Godot forward is -Z, origin at the feet.
The projectile scales the prepared lion by 1.65, independently of travel speed.

The body, skin, hierarchy and five original motion clips come from the saved
`assets/blender/dogs/iwa.blend` master, which remains unchanged. Companion
equipment was removed only in this separate variant. A shorter, broader muzzle,
swept mane, curved horns, fangs and tail tuft use the attached Gazelle reference
as silhouette inspiration. The shield effect's navy `19498c` and cyan `77cfff`
are the energy palette. The existing shield-bracing player pose supplies the
charge gesture without granting a block. No animation is retargeted in combat.

The new mesh has 12,890 triangles, one skinned mesh, one material surface,
24 deform joints and no textures. Its asset-audit prop budget warning is retained;
the runtime uses two cached player projectiles, not a lion per army soldier.
Preserve the rig/bone names, vertex colors and existing motion when editing.

Export saved edits, then import and verify:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/knight_lion_asset.py
python3 tools/goemon_assets.py audit assets/vfx/knight_lion --out 'build/Other Files/Asset Toolkit/Knight Lion/Audit'
python3 tools/goemon_assets.py check
python3 tests/asset-toolkit/test_knight_lion.py
'/Users/eric/Desktop/Play Goemon.command' --resolution 1280x800 --script res://tests/forest-shrine/knight_lion_test.gd
```

The initial `--create` option refuses to overwrite this master. Do not use it
to replace hand edits. The exporter checks the original donor hash and authored
motion-curve hash. The GLB comparison tolerates only 0.000002 float32 export
rounding; timings, track names and joint order must remain equal. Gameplay checks
cover charge, lifetime, swept native damage, knockback, cover, cancellation,
loadouts, repeated reuse and a short rendered cost comparison. These are not a
full-army or long-session performance certification.

Damage (360), speed (60 m/s), lifetime (5 s), knockback (22), charge (.8 s) and
cooldown (14 s) live in `scripts/knight_lion*.gd`. T is the Knight's default;
saved custom T assignments take precedence. A released lion keeps its straight
horizontal heading, follows terrain/bridge surfaces and stops at solid cover.
Native enemies retain their existing boss resistance and lifecycle rules.
