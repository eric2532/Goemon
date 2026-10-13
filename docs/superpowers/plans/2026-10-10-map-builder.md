# Map Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan inline. Steps use checkbox syntax for tracking.

**Goal:** Build and install a complete in-game map builder with new scenery assets.
**Architecture:** MapDocument owns serialization/validation/history; MapPieces owns visuals/collision catalog; BuilderWorld converts document to existing defense world contract; MapEditor owns isolated preview and user controls. Small game hooks choose authored map and return to editor.
**Tech Stack:** Existing Godot 4.6.1 GDScript, native procedural mesh assets, JSON local files.
**Spec:** docs/superpowers/specs/2026-10-10-map-builder-design.md

## Global Constraints
Latest worktree only; preserve all v2.42 Ranger behavior; no commits/push/publish; only Fire Siege export updated. Flat 160×310m field; one route with up to64 waypoints; up to512 pieces; local JSON files at most256KiB.

## Review Focus
Malformed maps must leave draft intact; solids must not block route/spawn; reversed/horizontal route segments must advance; saving/loading must survive restart; editor clicks must not attack or change underlying paused game.

### Task1: document and assets
Files: scripts/map_document.gd, scripts/map_pieces.gd, scripts/map_document_tests.gd.
Interfaces: reset_template/reset_blank; place(kind,point,rotation)->uid; move_item/rotate_item/remove_item; undo/redo; validate()->Array[String]; encode/decode; save/read_file. Catalog build(parent,kind,collisions)->Node3D and collision_rects(kind).
- [x] Write runnable tests for absent feature; observe RED.
- [x] Implement catalog and strict document/history/persistence; tests GREEN.

### Task2: editor and game
Files: scripts/map_builder_world.gd, scripts/map_editor.gd, scripts/game.gd, scripts/tower_defense.gd, scripts/fire_siege_hud.gd, scripts/map_builder_tests.gd.
Interfaces: game.open_map_editor(), play_custom_map(data), map_editor_draft, custom_map_data; world uses existing spawn_point/base_position/lanes/cannon_sites/mine_sites contract. Editor keeps own SubViewport and draft.
- [x] Write integration tests for missing main-menu entry/runtime choice.
- [x] Build world conversion, custom route following/recovery, editor UI/controls/history/save/load/confirmation/play/return. Existing standard modes clear custom state.
- [x] Test real route turning, gameplay construction and editor input.

### Task3: verify and deliver
Files: scripts/map_builder_tour.gd, docs/fire-siege-mvp/map-builder-v243.md, README.md, export_presets.cfg.
- [x] Render native editor tour, inspect assets/layout and gameplay screenshots.
- [x] Run map suites plus MVP, controls, equipment and Ranger air suites; review changes with fresh reviewer.
- [x] Export v2.43; run packaged map tour/test; strict signature verify; back up2.42 and install tested app.
- [x] Record manifest and user instructions.

## Completion record

Task1:30 document checks pass. Task2:25 integration checks pass. Task3:19 native tour checks, full Ranger93/equipment63/controls136/MVP72/legacy59 source checks; source total497, package total233. Fresh review findings fixed with regression tests and re-reviewed clean. v2.43 installed after signature/hash checks;2.42 retained. Prior uncommitted changes outside feature byte-for-byte unchanged in captured binary diffs. Legacy desktop checkout remains clean. No commits, pushes or publication.
