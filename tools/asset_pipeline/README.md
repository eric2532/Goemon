# Goemon asset toolkit

Run from the complete project selected by `Play Goemon.command`, currently
`/Users/eric/Desktop/Projects_Codex/Sonic`. Uses Python 3.9+ standard library and
Godot 4.6. No new dependencies or Blender installation are required.

Use `GOEMON_WAIT_FOR_SCRIPT_SLOT=1` before a `Play Goemon.command --script ...`
invocation when another script may be running. The launcher queues on its existing
POSIX record lock through `tools/goemon_script_lock.py`, retains that lock through
the game process, and serializes asset imports as usual. Waiting uses the kernel
rather than a polling retry loop. Normal interactive play keeps its existing path.

```sh
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py audit assets/optimized
python3 tools/goemon_assets.py optimize --asset all
python3 tools/goemon_assets.py check
python3 tools/goemon_assets.py compare --asset goldmine
python3 tools/goemon_assets.py compare --asset musashi
```

## Replace playable character or weapon sprites

Place an optional `art.json` beside the existing `motions.json`. For a
character, use the folder of the skin you are replacing. For a weapon with
its own `root` in `assets/characters/crossgate/weapons/catalog.json`, use
that weapon folder. For a weapon with a `native` index, edit the corresponding
stance in the character's file. This keeps the current character, skin and
equipment IDs and leaves the original art and motion files available.

For a replacement that keeps the original sheet layout, point the page at the
new image. For example, `{"pages":[null,"repaint.png"]}` keeps page 0, replaces
page 1, and leaves the rest alone. The loader numbers `atlas-*` first, then any
`cast-*` sheets. Page paths can be filenames relative to this folder or `res://`
paths to existing textures. Add pages after the last existing page to keep the
original sheets available while you try a few poses.

For repacked art, add `stances`. Entry 0 is the default stance and entries 1 and
up follow the `weapons` array in `motions.json`. Use `{}` to skip a stance. Each
clip key maps to a full list of replacement frame records for that clip. For
example, in Water Dragon Shin's three page folder, this puts a new guard pose
for one facing on page 3 while retaining the original pose origin:

```json
{
  "pages": [null, null, null, "new-guard.png"],
  "stances": [{"9:0": [[3, 0, 0, 63, 80, -46, -75]]}]
}
```

Each record is `[page, x, y, width, height, offset_x, offset_y]`. Keep the original
frame count and order for each clip. A replacement can have a different crop or
origin, but must put its visual contact or release at the same frame. The game
uses the original durations, hit and release cues, audio and weapon behavior.
Unknown clips, missing textures, wrong frame counts and out of bounds crops
produce a warning and leave that profile on its original art.

Restart Play Goemon after changing a file. Review all affected facings, planted
feet, grips, and attack contact. Equipment previews and counters use the patched
body frames. HUD heads, cosmetic attachments and separate guard, projectile and
effect textures still use their own assets. When the head changes or moves to a
new page/region, check the portrait and attachment placement separately. To undo
a sprite override, remove `art.json` and restart.

## Audit

For Cross Gate attack artwork, run
`python3 tools/audit_crossgate_attack_art.py '../Magic Power'`. This read-only
audit derives the current catalog from the shared audio manifest inventory,
includes Qi attack preparations, and compares native attack/throw pixels and
anchors against preserved source. It rejects added outline pixels, shifted
anchors and transparent green-key pages with alpha-border correction disabled.
The three fitted Emilia staff appearances are explicitly reported separately:
verify them with `recover_crossgate_emilia.py '../Magic Power' --check` and
`tests/forest-shrine/test_emilia_staff_outline.py`. The auditor's small tests
are `python3 -m unittest discover -s tools -p test_audit_crossgate_attack_art.py`.
Run `crossgate_attack_outline_test.gd` through Play Goemon and review its rendered
contact sheets as well; source equality alone cannot establish good-looking
motion. Reports go under `Cross Gate Attack Silhouettes/` in the toolkit folder.

Player attack audio is checked alongside optimized assets by `check`. After
adding/changing a Cross Gate character, appearance or weapon, run
`python3 tools/prepare_crossgate_player_audio.py '../Magic Power'`, then repeat
with `--check`. This prepares source cue identities against the existing attack
clocks, reuses existing WAVs after original PCM verification, and keeps explicit
silent markers. It does not rebake art or alter hit counts/timing. The generated
`assets/audio/crossgate/player-attacks.json` is exported with the game; stale
roster coverage, attack manifests or WAV data fail the ordinary asset check.
Run `tests/forest-shrine/crossgate_player_audio_test.gd` through Play Goemon for
the current Cross Gate roster/skin/weapon playback matrix; add `-- --visual` for
rendered examples and a real SFX mixer recording. Evidence belongs under
`build/Other Files/Asset Toolkit/Cross Gate Player Audio/`.

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
