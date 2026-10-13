# Forest Shrine Definitive Combat Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. The user has explicitly approved this change and requested implementation; execute inline with a fresh final review.

**Goal:** Make Forest Shrine the normal game experience, keeping its exact grid/map/build loop while using Rogue Siege's camera, combat, and full playable roster during waves.

**Architecture:** Reuse the existing Rogue battle view, native class adapters, and fighter picker. ForestGame owns scene-local title/roster/phase transitions; a small forest title scene sets its launch flag. Default main-scene launch routes to the forest title before loading old worlds. Historical command-line regression entry points remain available.

**Tech Stack:** Godot 4.6.1, existing GDScript and Rogue assets; macOS 2.29.0 export.

**Spec:** User's approved in-chat design: exact existing forest map and building grid, overhead only between waves, Rogue Siege close combat view and all ten Rogue fighters plus Goemon; hide other mode choices from normal launch.

## Global Constraints

- Preserve forest model layout, prices, worker mechanics, fog rules, and five-wave sequence.
- Match Rogue Siege camera size 24, offset (14,28,21), smooth follow and cursor aiming. Preparation remains overhead at its existing scale.
- Reuse native fighter attacks/skills, cooldowns, health fractions and visual assets. Q offers the same fighter switching; no construction while combat or a combat menu is open.
- Default title offers Forest Shrine only. Historical modes remain source/debug fixtures, not normal player choices.
- Preserve previous app before installing the new macOS build. Leave unrelated character-design files alone.

## Review Focus

- Closing a roster opened during preparation must remain paused overhead; closing during a wave restores combat without spending resources or changing buildings.
- Held attacks/worker commands must not leak through roster, phase, defeat or restart transitions.
- Native class targeting, impacts, elemental effects, stealth and control effects must respect forest simulation and shared fog.
- Restart must preserve the selected fighter while resetting run-specific cooldowns, projectiles, health and settlement state.
- Default launch, title return and retry must never expose historical mode menus or load their world in the background.

### Task 1: Rogue camera, roster, and combat integration
**Files:** forest_game.gd, forest_view.gd, forest_ui.gd, forest_raider.gd, forest_model.gd, forest_waves.gd; rogue_roster_picker.gd, rogue_roster_combat.gd; tests/forest-shrine/rogue_test.gd.
**Interfaces:** ForestGame.show_rogue_roster(starting=false), choose_rogue_character(id), close_rogue_roster(); ForestModel.hero_targetable; scene-local UI title/phase flags.
- [x] Write camera/roster/phase/cooldown/actual class attack tests; run and observe failure.
- [x] Reuse Rogue Siege camera and native fighter picker; display class health/abilities/cooldowns in forest HUD, keep build controls preparation-only.
- [x] Adapt forest enemy control effects and untargetable player behavior; native targeting obeys fog.
- [x] Run tests and inspect rendered preparation, roster, and class combat. Commit.

### Task 2: Definitive launch and release
**Files:** scenes/forest_title.tscn, scripts/forest/forest_title_ui.gd, scripts/game.gd, forest_game.gd, lifecycle_test.gd, README.md, export_presets.cfg, project.godot.
**Interfaces:** ForestGame.launch_to_title; begin_forest(); normal main entry routes to forest title; title Play opens initial fighter choice and selection begins preparation.
- [x] Add failing lifecycle tests for default title, all 11 fighter cards, selection, wave transition, retry, and title return with no legacy choices.
- [x] Implement forest-only launch/title and preserve debug regression flags. Retain selected fighter on retry.
- [x] Run all forest suites and existing Rogue Siege regression; fresh final review, fix important findings using failing regressions.
- [x] Export/sign/launch macOS build, preserve 2.28.0 app, integrate source, update controls/validation and deliver.
