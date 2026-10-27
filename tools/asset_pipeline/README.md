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

Supports named entries in `gameplay.json`, `goldmine`, `musashi`, `gameplay` or `all`. Originals remain unchanged.
Active derivatives and provenance live in `assets/optimized/`. Gameplay candidates
are staged under `build/Other Files/Asset Toolkit/Candidates/` until reviewed; the
full staging inventory is `gameplay-candidates.json` in the same report folder. The target is the recovered playable Musashi, not the locked
Blender master or historical Edo/Musashi designs.

The lossless pass batches compatible triangle primitives sharing a parent. It
preserves original named nodes, hierarchy edges, sockets, joints, bind poses,
animation samples, UVs, vertex colors and texture bytes. Directly animated mesh
nodes, morph targets and unsupported extensions are excluded or rejected. Skinned
merging requires identical skins and identity mesh transforms. Material merging
includes texture content, sampler settings and CLUT ids used by equipment swaps.
Only vertices with identical positions, normals, UVs, colors, joints and weights
are welded. Named mesh controls, directly animated meshes and sparse morph data
remain addressable. Ed retains separate coplanar clothing meshes to preserve draw
ordering. Rigid geometry is baked into parent coordinates; float32 errors are measured by
the preservation checker. No decimation, retopology, UV repacking or texture
resizing is performed. Models without a useful lossless improvement retain their
authored source in gameplay; staging copies are excluded from app exports.

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

## Remaining gameplay models

`gameplay.json` registers the reviewed gameplay catalogs and per-model protected
mesh names. It covers roster/equipment, recovered leaders, Chief/weapons, enemies,
towers/feedback, allies/dogs, scenery/buildings and gameplay props across modes.
Recovered Goemon/Sasuke/Yae/soldier renderers already batch their native JSON
geometry; their independently animated source parts are not blindly merged.

```sh
python3 tools/goemon_assets.py optimize --asset gameplay
python3 tools/goemon_assets.py check --staged
python3 tools/goemon_assets.py compare --asset arrow-tower --capture
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/gameplay.gd -- --staged
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/procedural.gd -- --staged
# After source-preservation, imported motion and visual review:
python3 tools/goemon_assets.py activate --asset gameplay
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/goemon_assets.py check
```

Activation publishes only useful candidates. GameAssets resolves explicit source
paths through `assets/optimized/routes.json`, preserving fallback to unmodified
sources and reverse source identity for roofs/building damage. The routes JSON is
included in export presets; this workflow does not export an app. Army pose-cache
fingerprints include the routes and resolved GLBs so source/geometry changes
invalidate old bakes. Standalone `check` verifies active derivatives and does not
require development staging files to survive cleanup.

The static comparison viewer also accepts models with no AnimationPlayer.
Gameplay validation samples every imported clip at five times, checks protected
mesh types/morph channels, and compares the actual procedural roster drivers,
bones and cape controls. Rendered captures include file hashes for provenance.

Use `compare --asset NAME --capture --imported` after activation/import to compare
the actual PackedScenes used by gameplay (including their import settings and
LODs). Run `tests/asset-toolkit/gameplay.gd -- --packed` to validate active imported
scenes, and `tests/asset-toolkit/routing.gd` to check real loading, reverse asset
identity and retired-enemy route removal. Leader comparison uses the same
native palette shader as the playable models.


The first gameplay-wide pass reviewed 132 additional profiles and promoted 30:
425 → 291 mesh instances, 551 → 429 surfaces and 172 → 111 materials.
Triangles and texture pixels remain unchanged. The other 102 profiles retain
their original assets. Detailed results, per-model CSV, comparison captures and
known baseline Ben flight test failures are recorded in
`build/Other Files/Asset Toolkit/GAMEPLAY_VALIDATION.md`. GLB bytes increased
slightly overall; measure game frame times before claiming a speed improvement.

## Recovered rigid enemies

Vambee and Haya Wolf use the existing native enemy owner and rigid GPU batching.
Their generic saved-Blender-master exporter and offline pose bake are documented
in `docs/recovered-monsters.md` and
`assets/blender/enemies/recovered_monsters/AGENTS.md`. Compatible new enemies
extend that registry/workbench instead of adding another controller or renderer.
Audit the immutable recovery and authored export, run the dedicated source and
imported motion/contact checks, then verify through the desktop launcher.
