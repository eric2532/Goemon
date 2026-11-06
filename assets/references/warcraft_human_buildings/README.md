# Human farm and Guard Tower source

Recovered from the user's adjacent local Warcraft project on 2026-10-28.
`provenance.json` records immutable archive paths, hashes and sizes. `original/`
contains the untouched Farm and HumanTower MDXs, their original BLP textures,
lossless PNG decoding and the existing converter's model JSON. The farm resolves
to `war3.mpq`; the tower resolves to `War3x.mpq`. No game executable was run.

The existing Warcraft `work/mpq.py`, `work/tools/package/dist/war3-model.cjs`
and Blender `export_mdl` importer were reused. No second asset compiler was added.
All native Birth, upgrade, Stand, Death and Decay data remain here. Tower forms
are states of one native model. The original team-color slot 01 is preserved;
the Goemon export composites a muted meadow blue through the same team-mask
process already used by the character exporter.

The authoritative Goemon editable masters are
`assets/blender/environments/wind_meadow/buildings/{watchtower,barracks,tower_ruins,barracks_ruins}.blend`.
The intact buildings prepare the Guard Tower's `Stand Upgrade First Ready Attack` and Farm `Stand` as static meshes. Ruins
reuse the existing Wind Meadow rubble workbench with these saved buildings and
the shared stone-block master; the first native Decay draft was rejected during
rendered review because its rough smoke/debris surfaces did not match the art. Buried foundations are clipped
at ground level, source UVs are retained, and the original gameplay footprint,
facing and named anchors remain. Runtime construction/combat timing is unchanged.

Save edits in those masters and use `tools/export_blender.py`; do not repeat the
initial import over artist edits. The old Goemon masters/exports are preserved
at Git ref `refs/codex/before-warcraft-human-buildings`. Initial preparation,
source assertions and rendered evidence are under
`build/Other Files/Asset Toolkit/Warcraft Human Buildings Review/`.
This reference directory is excluded from game exports.

The 2026-10-30 Cannon Tower addition reuses HumanTower's **Stand Upgrade Second**
form in `assets/blender/environments/wind_meadow/buildings/cannon_tower.blend`.
The original CannonTowerMissile MDX, converted JSON, BLP textures and decoded PNGs
are preserved here too. Its editable shell is
`assets/blender/effects/warcraft_cannon_shell.blend`; prepared death particles use
`assets/vfx/warcraft_cannon/impact.tscn`. Original model sound events resolve through
the recovered tables to all three launch and all three explosion samples, plus
selection and shared building cues. Exact archive/file/PCM provenance is in
`assets/audio/warcraft_cannon/source.json`.
