# Ninja pose workbench

The updated curved silver blade with a purple handle is attached to the full Ninja rig. Open `Ninja_Animation_Workbench.blend` and select a clip in the Action Editor. `Ninja_Idle.blend`, `Ninja_Run.blend`, and `Ninja_Cross_Slash_RMB.blend` are convenient copies opening on each clip; every file contains all three actions.

| Action | Frames | Use |
| --- | --- | --- |
| 01_Idle | 1–217 | Breathing idle loop |
| 02_Run | 1–41 | One running stride cycle |
| 03_Cross_Slash_RMB | 1–37 | Current Ninja right-click strike, plus editable recovery |

The blue `Blade_Control` follows `Hand_R`, and `Offhand_Control` follows `Hand_L`. Pose the arms and hands normally; use the controls to refine weapon angles. Existing body/face/hair geometry, UVs and bone lengths are preserved. Start in Pose Mode; R rotates, G moves, I records keys, Space plays, and Command-S saves. Auto Key is off. More guidance and suggested pose frames are in `START_HERE.txt` and the matching Blender Text block.

These are editable work copies. Saving poses here prepares them for a later game animation export. The builder refuses to overwrite an existing workbench, protecting user edits.

Verification sampled the actual game skeleton and both weapon transforms, compared all keyed poses after the Godot-to-Blender coordinate conversion, and checked geometry/UV/bone preservation. `verification.json` records the results. Native Blender UI was opened on the full Ninja in the Animation workspace with Idle selected.
