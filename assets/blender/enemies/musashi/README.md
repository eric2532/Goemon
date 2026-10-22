# MUSASHI_FINAL_APPROVED

The visual-development stage is complete. The single source of truth is [Final/Musashi_Final.blend](Final/Musashi_Final.blend).

- [Final report](Final/FINAL_REPORT.md)
- [Final reference comparison](Final/Validation/00_final_comparison.png)
- [Rigging readiness](Final/RIGGING_READINESS.md)
- [Development backup](Archive/Musashi_Development_Backup.blend)

`Final/` contains the organized production master, packed/external reference, validation images, technical reports and verification tools. `Archive/` contains the pre-cleanup backup and verified archive of obsolete development stages.

All approved design geometry, stance and reference camera remain locked. Final materials use deliberate painted tonal regions. The only technical geometry cleanup removed 12 isolated microscopic zero-volume duplicate hair face pairs with no visible change. No rigging, animation or game import has been performed. Do not continue visual revisions automatically.

## Playable derivative · explicitly authorized next phase

The approved visual master remains immutable. `Musashi_Playable.blend` is the separate rigged game derivative, exported to `res://assets/characters/musashi/model/musashi.glb`. See the [project README](../../../../README.md) for the current game entry point; runtime behavior lives in the current scripts and tests. Do not use the derivative to overwrite `Final/Musashi_Final.blend`.
