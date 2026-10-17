# Ninja authored poses implementation plan

**Goal:** Bring the user's edited idle and RMB start/finish into the real game and rebuild Goemon.app.
**Architecture:** Sample the untouched authored workbench into compact skeleton-local pose data. Use a Ninja-only runtime adapter for idle and the .42s dash cut, with an interruptible .16s recovery. Carry over the mesh's authored local transform and synchronize the combat tip. Keep physics and combat clocks unchanged.
**Tech stack:** Blender Python, Godot 4.6.1 GDScript, signed macOS export.

- [x] Preserve saved and live unsaved workbook data; identify authored frames against the original action copies.
- [x] Add a meaningful runtime test; observe failure before wiring authored clips.
- [x] Export idle frame 0 and slash frames 0/1. Preserve subtle existing breathing around the new idle; interpolate the two slash anchors in local bone space. Preserve user sources, meshes, rest rig, UVs, and all other characters.
- [x] Apply authored idle when grounded and unoccupied, blend to existing run, sample slash by the actual dash timer and recover smoothly. Interrupt recovery for attacks/shots/jumps/dodges. Preserve hand-relative weapon transforms and reach scaling.
- [x] Test actual pose agreement, loops, transitions, interruptions, primary contacts, dash hits/travel, melee reach, drift and packaged resources. Inspect native gameplay captures.
- [x] Fresh focused code review, resolve significant issues, export and verify package, back up current app, install and launch test.

Ruling: work in the current dirty checkout because the live Blender workbook, preceding features, and runtime art are here. Snapshot every touched existing file first; no resets or unrelated edits.
Ruling: workbook comparison shows idle only edited on 0, slash only on 0/1, run untouched. Treat slash 0/1 as start/finish; user clarification requested while independent preservation/export proceeds. Do not play old generated frames after the authored finishing pose.
