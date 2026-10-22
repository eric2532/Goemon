# Goemon asset toolkit

Run from the complete project selected by `Play Goemon.command`, currently
`/Users/eric/Desktop/Projects_Codex/Sonic`. Uses Python 3.9+ standard library and
Godot 4.6. No new dependencies or Blender installation are required.

```sh
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py audit assets/optimized
python3 tools/goemon_assets.py optimize --asset all
python3 tools/goemon_assets.py check
python3 tools/goemon_assets.py compare --asset goldmine
python3 tools/goemon_assets.py compare --asset musashi
```

## Audit

Read-only for assets. Reports go to `build/Other Files/Asset Toolkit/audit.json`
and `audit.html`; the HTML table supports sorting and filtering. `--out` selects
another directory, and `--budgets` selects a JSON budget file. Input paths may be
individual GLBs or directories. Read errors fail the command but do not hide
other assets. Hash groups identify exact duplicate image payloads.

`budgets.json` contains category warning thresholds, not automatic reduction
targets. Surfaces count exported primitives, not measured frame draw calls.
Texture memory estimates assume RGBA8 with mips, not engine compression or actual
GPU residency. Direct references cannot resolve every script-built asset path:
unresolved usage never authorizes deletion.

## Optimization

Supports `--asset goldmine`, `musashi` or `all`. Originals remain unchanged.
Derivatives and provenance live in `assets/optimized/`; the gameplay loaders use
these candidates. The target is the recovered playable Musashi, not the locked
Blender master or historical Edo/Musashi designs.

The lossless pass batches compatible triangle primitives sharing a parent. It
preserves original named nodes, hierarchy edges, sockets, joints, bind poses,
animation samples, UVs, vertex colors and texture bytes. Directly animated mesh
nodes, morph targets and unsupported extensions are excluded or rejected. Skinned
merging requires identical skins and identity mesh transforms. Material merging
includes texture content, sampler settings and CLUT ids used by equipment swaps.
Rigid geometry is baked into parent coordinates; float32 errors are measured by
the preservation checker. No decimation, retopology, UV repacking or texture
resizing is performed.

`check` rejects stale source hashes or modified/missing candidates, then reruns
preservation checks. After ANY source export or Musashi recovery operation,
regenerate the affected derivative. Never edit generated candidates or change
manifest hashes to suppress failure.

## Comparison

The Godot viewer provides matching cameras/lighting, synchronized clip selection,
play/pause, timeline scrubbing, camera angle and wireframe. Musashi uses the real
game palette shader and gear masks (0 original, 31 full equipment). Materials stay
independent between model instances.

```sh
python3 tools/goemon_assets.py compare --asset goldmine --capture
python3 tools/goemon_assets.py compare --asset musashi --capture
# Optional slower rendered sweep of every source animation:
python3 tools/goemon_assets.py compare --asset musashi --capture --all-clips
```

Captures require a graphical display; headless Godot cannot validate rendered
appearance. Representative clips are sampled at start/middle/end from four
angles. PNG pairs, pixel metrics, per-viewport draw counts and `comparison.json`
are saved in each asset's report subdirectory. `--before` and `--after` accept
custom GLBs. `--godot` or `GODOT_BIN` selects the engine. Pixel metrics support
visual review, not a universal acceptance threshold or FPS claim.

## Required post-export pipeline

1. Complete the normal editable-source/export or recovery operation.
2. Audit changed assets and review their usage and budgets.
3. Regenerate supported candidates with `optimize --asset NAME`.
4. Refresh Godot imports, run `check` and the tests below.
5. Review synchronized motion, gear and construction states in the comparison
   viewer and captured images.
6. Verify the live game through `/Users/eric/Desktop/Play Goemon.command`.
7. Integrate only validated candidates. Keep original sources and user edits.
   Export an app only when explicitly requested.

```sh
python3 -m unittest discover -s tests/asset-toolkit -p 'test_*.py'
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/integration.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/musashi_outfit_model_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/fire_siege_structure_tests.gd
```

The imported test samples every clip at five times, comparing every Musashi bone
pose and mine geometry bounds/socket transforms. Python also compares every
source animation sample exactly. Equipment tests cover all 32 combinations and
instance isolation. Run motion/combat tests relevant to further changes.

## Initial results

| Asset | Mesh instances | Surfaces | Materials | Triangles |
| --- | ---: | ---: | ---: | ---: |
| Gold mine | 248 → 14 | 421 → 49 | 18 → 18 | 9,404 unchanged |
| Recovered Musashi | 31 → 1 | 43 → 9 | 43 → 6 | 724 unchanged |

Remaining surfaces preserve animated parents, material behavior and attribute
formats. Original names remain as empty nodes, so node-count reduction is not
claimed. Exact file sizes, hashes and numerical errors are in the manifest.
Measure actual game frame times before claiming an FPS improvement.
