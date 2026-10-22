# FireSiege construction FX · Blender / GLB · v1

Actual editable 3D assets, based on the approved construction concept. These are shared presentation pieces for tower and mine purchase/upgrade. They do not implement gameplay, networking, purchasing, or currency.

## Open first

- `FireSiege_ConstructionFX_v1.blend` — five organized scenes; opens on the construction demonstration
- `previews/FS_ConstructionFX_Preview.mp4` — hold → release/decay → resume → completion
- `previews/FS_ConstructionFX_ContactSheet.png` — the same four visual states
- `exports/` — four independent, self-contained GLB files
- `IMPLEMENTATION_NOTES.md` — scene names, nodes, clip contract, and integration checks
- `qa/roundtrip_report.json` — fresh Blender GLB import verification
- `qa/godot_import_report.json` — Godot 4.6.3 scene generation and hammer/completion playback checks

The pedestal in the preview and blend is deliberately labelled **placeholder only**. It is not the arrow tower or gold mine. Preview pacing is illustrative and must not be copied into gameplay balance.

## Content

| Export | What it contains | Animation |
|---|---|---|
| `FS_FX_Hammer_BuildLoop.glb` | Iron hammer, wooden handle, leather grip; grip-centered pivot | `Build_HammerLoop`, 1 second, loop |
| `FS_FX_ProgressFrame.glb` | Dark recessed track, brass edge, gold left-anchored fill | Runtime drives `ProgressFill.scale.x` |
| `FS_FX_BPrompt.glb` | Optional desktop B keycap and real 3D letter | None |
| `FS_FX_CompletionPulse.glb` | Two expanding gold rings and 10 subtle rising spark meshes | `Complete_GoldPulse`, 1 second, one-shot |

Meters; Blender +Z up and building front −Y. GLB conversion is +Y up and front +Z. The effects have independent attachment roots. No textures, external buffer files, particle systems, simulation caches, or engine shaders are needed. Gold emission enhances the effect, but its visible ring/spark movement comes from geometry.

## What has been verified

All four GLBs were imported into fresh Blender scenes. Checks cover exact scene isolation, roots and mesh counts, material/geometry presence, full 0–1 second clip ranges, the hammer loop seam, progress-fill anchor, and completion-ring morph weights. Validation covers Blender 4.3.2, the exported glTF structure, and an isolated Godot 4.6.3 headless import/playback check. Gameplay behavior, target-project lighting, and attachment placement still need checking in the game.

No game repository was modified, and nothing was published to GitHub.
