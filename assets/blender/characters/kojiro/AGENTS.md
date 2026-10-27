# Kojiro editable master

`kojiro.blend` is the authoritative editable character. Do not regenerate it over
artist edits. `tools/prepare_kojiro_blender.py` creates it only when absent.

Keep all fifteen `Part_00` through `Part_14` meshes, their UVs, vertex colors,
materials and original numeric actions. Part 14 is the sword; its local endpoints
are `(0,0,0)` and `(0,0,64)` in glTF source coordinates. The source root is 0.01
units per ROM unit. All motion is prepared at **30 FPS**; changing FPS retimes it.
Flat part transforms are original actor-space animation, not a missing rig.

Export the saved master with:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b assets/blender/characters/kojiro/kojiro.blend --python tools/export_recovered_monster.py
```

This shared rigid-character exporter reads artist edits and keeps exact recovered
geometry/material data when only poses changed. It writes
`assets/models/characters/kojiro/kojiro.glb` and its motion manifest. Immutable ROM
recovery is in `assets/characters/recovered_kojiro/`. Never edit that recovery or
optimized derivatives to apply artist changes. Refresh Godot imports, audit,
run the Kojiro preservation/gameplay tests and inspect the desktop capture.

Source attacks, damage events and effect release ticks are in `combat.json`.
Changing animation does not automatically change combat. Runtime model fitting
uses the shared Goemon standing height; model and spell size remain separate.

Locomotion mapping: `Source__801e21f8` is walk, `Source__801e22a0` is forward run,
and `Source__801e2478` / `Source__801e2500` are lateral runs. Do not restore the
old incorrect forward-run label on `801e2478`.

Ground LMB uses three separate clicks: `Source__801e2b50` (first 24 ticks),
`Ground__turning_cut` (24 ticks) and `Ground__somersault_cut` (30 ticks).
The two editable `Ground__` actions adapt `Source__801e2660` and
`Source__801e2708`; all 21 original actions remain untouched. The prepared
variants keep original part orientations and hand/sword relationships during
their cuts, with whole-pose floor clearance, four-tick entries and a six-tick
final recovery. The somersault's lift is visual; the shared player controller
still owns movement and collisions. Contact tick 15, click buffering and 2×
playback belong to the combat adapter. Do not substitute a reverse of the first
cut or a recovery-only section for these distinct attacks.

Keep authored actions linked in each part's muted NLA tracks so the shared
ACTIONS exporter includes them. Their `source_action` and `player_adaptation`
properties supply manifest provenance. Preserve the terminal hold key at 24/30.
The export contains 23 actions. Test original preservation, prepared floor/grip,
optimized motion and rendered grounded input after edits. Kojiro is player-only;
no army pose bake is required.
