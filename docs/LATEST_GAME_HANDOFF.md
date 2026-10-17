# Latest playable game handoff — 2026-10-17

Repository: https://github.com/eric2532/Goemon
Branch: `feat/original-enemies-town-cap`

This branch contains the current game, including all prior local commits and the latest source/assets. Use this branch explicitly; `main` may be older.

```sh
git clone --depth 1 --branch feat/original-enemies-town-cap https://github.com/eric2532/Goemon.git
cd Goemon
godot --headless --editor --path . --import
godot --path .
```

Use Godot 4.6.1. The title menu's **PLAY FOREST SHRINE** opens the current building/combat game. To open that title directly, run `godot --path . res://scenes/forest_title.tscn`. Blender import is disabled in project.godot: all runtime GLBs and animation JSON are supplied, so Blender is only needed to edit/re-export art.

## Current behavior

- Default map: Twin Ramparts, two raised wall routes joining at the gate, with visible portals. The map editor also offers **Original Map**; its protected source is `assets/maps/forest_shrine_original.json`.
- Building view: map placement/rotation/deletion/save/load, balance button and instant restart. Core balance controls starting gold, tower stats and wave composition.
- Compact upper-left character HUD with five empty responsive loadout slots. Settings control HUD/camera size, character screen position, optional gold crosshair and per-character melee reach.
- Enemies use low-fidelity visuals with hidden HP bars. Melee attacks and arrows damage players on flat ground and walls. Invincibility is off by default; existing user settings can override it.
- Ninja: editable purple-handled blade and authored idle/slash poses, Explorer run/jump/landing motion, tucked double jump, cooldown refresh every three landed basic swings. RMB pierces along the unchanged dash route and deals a separate final hit. A purple crescent and .5-second capsule outline mark the finishing area. See `docs/ninja-piercing-dash.md`.
- Knight: indefinitely held RMB/3 frontal guard; a block emits three forward damaging shield faces while guard remains held. See `docs/knight-held-guard/README.md`.
- Five bow effects from the supplied video are mapped to Ranger regular shots (2/3), power shots (1), and tower releases (4/5). Sound Studio recordings still override player defaults. Provenance/cuts: `assets/rogue/audio/bow_source.source.json`.

## Editable assets

Runtime art: `assets/models/`, `assets/animations/`, and `assets/rogue/audio/`.
Blender source: `assets/blender/`; read its `AGENTS.md` before editing art.
The user's motion projects are under `docs/ninja-motion-workbench/`, `docs/explorer-motion-workbench/`, `docs/dragoon-motion-workbench/` and `docs/ranger-motion-workbench/`. Preserve their authored workbench files; exporter scripts are in `tools/`.

Generated renders, video frames, caches, local settings/recordings, export ZIPs and backup app bundles are intentionally not versioned. `.blend` source files and readable verification notes are included.

## Verification and export

These standalone scripts cover the current mechanics:

```sh
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ninja_pierce_finish_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/ninja_three_hit_refresh_test.gd -- --test --original-map
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/bow_source_audio_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/knight_held_guard_test.gd -- --test
godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/twin_ramparts_test.gd -- --test
```

Headless renderer shutdown can report retained resources in some harnesses; check their explicit `*_RESULT checks=... failures=0` lines and script-error output. Native packaged-game and installed-app checks are the final runtime validation. Older prototype tests may still encode superseded behavior such as Knight's timed guard.

For macOS export, install Godot 4.6.1 export templates, then:

```sh
mkdir -p build
godot --headless --path . --export-release macOS build/Goemon.zip
```

The `macOS` preset builds the current game. Other presets retain earlier Fire Siege/experimental modes.

## Clean source handoff verification

The staged Git source was extracted into a separate folder with no `.godot` cache and reimported with Godot 4.6.1: zero import/script errors. The native Metal title launch exited successfully. Real-game regressions passed: Ninja path/finish/movement19 checks, Knight held guard22, bow audio9 and Twin Ramparts42. The existing exported Mac app also passed native packaged gameplay and visual checks before this handoff.
