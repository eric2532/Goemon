# Warcraft III Human Peasant worker

Goemon's normal workforce now uses the original classic Human **Peasant**, unit
`hpea`, recovered from the user's adjacent Warcraft project. This is the original
model/skin and motion, fitted uniformly to Goemon's existing worker height. It is
not a recreation or cosplay. `motion.json`, `extraction-manifest.json`, original
`sound-events.json` / `sound-tables.json` and `source.json` retain provenance.

Editable masters, packed textures, original archives/MDX and four portrait
motions remain in `/Users/eric/Desktop/Projects_Codex/Warcraft/assets/Peasant/`.
See that package's README for recovery and Blender editing. The Goemon exporter
opens the saved master read-only and verifies its SHA-256 after export.

## Runtime contract

The exported GLB preserves all **22 actions**, six independently visible geosets,
42 exported joints and **452 triangles**. The lossless toolkit derivative keeps
geometry/UVs/weights/motion and reduces six material resources to three; it does
not reduce triangles or resize textures. The six-surface warning is retained
because source visibility is independent. Staging captures are in
`build/Other Files/Asset Toolkit/warcraft-peasant/`. Static GLB comparison does
not apply the separate native visibility tracks; runtime captures and atlas
checks additionally verify those tracks.

`forest_worker_warcraft.gd` replaces only the presentation used by `forest_art`.
It shares one immutable six-surface mesh, materials and a 60 Hz pose atlas across
workers, using the existing army shader/pose format and interpolated rows. There
is one single-instance MultiMesh per existing worker node and no per-worker
skeleton, AnimationPlayer, loading, material creation or retargeting during jobs.
`worker.res` bakes eight selected job clips into 570 rows with 28 skin transforms;
all other original actions remain in the editable master and GLB.

Idle/walk use Stand/Walk. Delivering uses native Stand Gold / Walk Gold and the
original sack. Mining uses Attack; repair uses Stand Work at its native 0.6 s
cycle. Garrison freezes Stand Ready, stows the axe by its AxHandle01 binding and
retains Goemon's tower bow. The bow and targeting share the Peasant's original
right-hand grip through `forest_structure_profile.gd`; no arm is stretched or
retargeted. Wounding retains the existing fallen-worker behavior. Workforce
jobs, health, movement, costs, repair pulses, tower firing cadence and damage
still belong to the existing controller. Placing buildings remains immediate.

The original `SNDXAREP` event occurs **234 ms** into Stand Work. AnimLookups maps
AREP to **Repair**, whose AnimSounds row selects `PeonRepair1–3.wav`. Despite the
filenames, these are the Peasant's actual native work cues. All three are copied
byte-for-byte from war3.mpq and imported as uncompressed mono PCM16 at 22,050 Hz;
file and decoded PCM hashes are checked. The full recovered audio catalog is
preserved, but extra selection/voice behavior was not added.

Actual repair animation events and successful placements reuse the existing
four construction voices. Repair cues are limited to visible work within 65 m,
with a shared 75 ms overlap limit. Explicit pause, menus, transitions, recording
and mute suppress playback and stop tails. Preparation's normal simulation
pause still permits its live construction feedback. Voice gain uses SFX/master
volume once. The previous Goemon worker and placement assets remain preserved;
there is no runtime backend selector or fallback.

## Re-export and verify

Run from the complete Sonic project, after saving authored edits in the master:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/export_warcraft_characters.py -- Peasant
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py optimize --asset warcraft-peasant
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/warcraft.gd
python3 tools/goemon_assets.py compare --asset warcraft-peasant --capture
# Inspect source/candidate motion and native visibility before activation.
python3 tools/goemon_assets.py activate --asset warcraft-peasant
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/bake_warcraft_worker.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/warcraft_worker.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tools/capture_worker_portrait.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/goemon_assets.py check
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/warcraft_worker_test.gd
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/building_placement_audio_test.gd
```

Also run the shared toolkit unit/import, Musashi outfit/motion and structure
checks in `tools/asset_pipeline/README.md`. Atlas fingerprints must match actual
resolved GLB/imported textures and sidecars; rebuild instead of editing hashes.
Runtime captures, repeated-use results and logs belong under canonical
`build/Other Files/`. No app export is part of this development procedure.
