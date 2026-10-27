# Recovered rigid enemy workbenches

These are editable originals made from the user's preserved Musashi disc data.
Preserve saved/unsaved artist changes, `Part_XX` names, the flat part hierarchy,
native pivots, UVs, vertex colors, texture pixels and all `Source__...` actions.
Each part is rigid. Do not add per-enemy runtime retargeting or a second AI owner.
The scene uses 30 FPS; changing FPS after import changes the animation speed.

Use the SAME workflow for additional compatible enemies:

1. Recover source geometry/motion with provenance into
   `assets/characters/recovered_monsters/`. Leave these disc recoveries immutable.
2. `tools/prepare_recovered_monsters_blender.py` creates only missing masters;
   it refuses to regenerate an existing `.blend` implicitly.
3. Edit the saved master in Blender. Export the OPEN master with
   `tools/export_recovered_monster.py`. This writes the separate authored GLB and
   motion manifest under `assets/models/enemies/recovered_monsters/`.
4. Refresh Godot imports, run `tools/bake_recovered_monsters.gd`, then asset
   audit/check, motion/contact tests and desktop gameplay review. Runtime pose
   data is generated; never edit the `.res` directly. An export alone does not
   update the GPU pose bake.

The registry is `scripts/forest/forest_enemy_roles.gd`; compatible new types add
stats, source bounds, clips and attack data there. All ordinary types share the
native Unit, movement, damage, status, targeting and event code. Native attack
profiles define phase lengths, contact markers, melee segments, travel and an
optional next form. The boss shares that lifecycle and uses its existing native
encounter pattern. Keep special behavior inside that owner, not a parallel node
controller. Reuse the existing rigid GPU atlas/MultiMesh renderer and bounded
effect/audio pools.

See `docs/recovered-monsters.md` and the root asset/performance policy.

Dark Lumina 2 uses `dark_lumina_2.blend` for its 19-part body and 21 original
motions, plus `dark_lumina_2_effects.blend` for the shock dome, shock ring and
fragment. Export the body with the common exporter above; export the existing
effects master with `tools/dark_lumina_effects_blender.py`. Its effect meshes
retain raw disc dimensions and use `.018` scale in the shared presentation.
Original sprite frames and sound provenance stay alongside the recovered body.
See `docs/dark-lumina-2-recovery.md` for controls, source identities and checks.

The jump stomp now uses `dark_lumina_2_stomp.blend` and its `stomp_wave` mesh.
It preserves actor 0x352's nineteen textured ground sectors; export that open
master with `tools/dark_lumina_effects_blender.py --stomp`. Its rise/travel/UV
animation runs in one shared effect shader. The older dome/ring remain editable
and preserved, but were incorrectly identified as this attack's ground wave.

DL2's `Source__801f1898` / `Source__801f1978` actions are directional spins;
the shared kit supplies their ROM-driven actor rotation. Preserve those local
poses without baking that world turn into the master a second time. `801F1FD8`
is the reduced-part walk, not death breakup. The newly recovered flying floor
patches are authoritative lossless PNGs in `dark_lumina_2_effects/spin_debris.png`
with `spin_sources.json`; their source primitive is a runtime quad, not another
editable body mesh. Reuse these prepared resources for repeated spin effects.

Identity correction (2026-10-23): `karate_wolf.blend` is the verified 13-part
Haya Wolf from SC04 / FILE_004. The historical `haya_wolf.blend` is the preserved
12-part Slow Guy/gorilla from SC04 / FILE_002; keep its existing edits intact.
Runtime wolf role 9 selects `karate_wolf`, never the historical misnamed master.
Slow Guy is now live as separate native role 16, selecting the preserved
`haya_wolf` master/export and its original arm swing, reactions, walk and death.

Dark Lumina 3 uses three masters: `dark_lumina_3.blend` (17-part body),
`dark_lumina_3_sky_copy.blend` (10-part copies), and `dark_lumina_3_effects.blend`.
Keep all 50 original effect morph endpoints, including sword and core keys.
The common exporter detects morph edits independently of rigid geometry.
Wind/core GPU morph textures come from the authored effect GLB at initialization;
body and copy motion still require the ordinary rigid pose bake after export.
See `docs/dark-lumina-3.md` for the verified identities and source commands.
Dark Lumina 3's requested 3× gameplay size is applied once by the shared kit
and body shader. Keep these masters at recovered scale; scaling them as well
would multiply the enlargement again and move the authored contact contract.
