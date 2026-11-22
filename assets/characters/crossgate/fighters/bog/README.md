# Bog

Stable playable ID 40 / save key `bog`. Only the two approved old-model looks
are selectable: gray hair / black #100625 and dark hair / black #100942.
Both use the axe exclusively, with source records `joy:620` and `v3:578`.
The picker and HUD use the matching unarmed portraits, `joy:622` and `v3:429`.
Source archives remain read-only in the adjacent Magic Power project.

Bog uses the existing Cross Gate model, native combat adapter, local target
queries, pooled effects, damage labels, audio voices and jump presentation.
His fixed shortcuts are 1 **乾坤**, 2 **連擊**, and 4 **明鏡止水**. Their damage,
reach, cooldowns, target replacement, protection and healing rules are the
existing Shin sword skills, played with Bog's own axe art and contact marker.
There is no weapon switch, separate simulation, or per-frame resource loading.

The basic axe animation preserves its 50 drawings over 1.6 seconds and both
source contacts: frame 19 plays impact 136, and frame 35 plays impact 138.
Frames 18 and 34 play swing 106. The existing multi-contact attack loop handles
both contacts; charge skills still use their existing single contact contract.
Only the missing swing and first impact WAVs are copied into
`assets/audio/crossgate/bog/`. The second impact reuses Shin's prepared polearm
sample. Original source paths and hashes are in that audio folder's provenance.
Custom recordings, gain and mute stay under Bog's own sound profile.
Footsteps and landings use the prepared Goemon defaults.

The 94-pixel standing body measurement excludes the axe and ground shadow.
It feeds the existing Goemon-height normalization and Character Select framing.
Each skin has one 2048 × 1033 body atlas and one 2048 × 124 cast atlas:
9.04 MiB of RGBA texels, excluding engine overhead. Only selected skins load.
All eight facings retain stand, walk, run, attack, hurt, guard, fall and cast.
The shared meditation preparer preserves the original cast release marker.

Rebuild with the existing preparers:

```sh
python3 tools/recover_crossgate_bog.py '../Magic Power'
```

The preparer checks source IDs and event markers, preserves packed frame pixels,
and verifies the copied audio bytes. It also reuses inventory serial 20200 for
the axe HUD icon. Do not edit generated atlases directly.
Gallery, combat, timing, repeated-use and rendered evidence are in
`build/Other Files/Asset Toolkit/Cross Gate Bog/Gameplay/`.
Run the focused replay through the desktop launcher:

```sh
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/crossgate_bog_test.gd
```

The 2026-11-11 desktop replay passed 120 checks with no script/resource errors.
After warmup, repeated skills retained the same resource count and presentation
nodes. The separate Shin desktop replay passed 364 checks, Saizo's regression
passed 91, and the shared sound tests passed 40. The asset toolkit's 76 unit
tests, 12,973 imported-model checks, 98 outfit checks and 86 structure checks
also passed. These focused tests do not claim a long-session army stress result.
