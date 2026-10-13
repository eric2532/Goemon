# Forest Crosshair Definitive Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans, inline with one fresh final review. The user has authorized implementation and replacement of the current definitive local build.

**Goal:** Make Forest Shrine the definitive game using the complete Fire Siege Crosshair v2.53.1 camera, characters, animations, combat, and effects, replacing in-world construction with the existing overhead forest preparation and fog system.

**Architecture:** Merge `aa7f1d2` into the Forest implementation, retaining the latest shared combat code. ForestGame owns its independent wave/economy model and overrides combat capabilities; ActionCamera provides the original perspective shoulder camera. The same battlefield switches to orthographic placement only during preparation.

**Tech Stack:** Godot 4, GDScript, macOS export v2.54.0.

**Spec:** The user's approved conversation, corrected after the rejected v2.29 release: current Fire Siege Crosshair with updated attacks and all twelve heroes; forest grid construction only between waves, central shrine, mines, workers, walls/gates, fog memory and current enemy visibility.

## Global Constraints

- Preserve latest shared combat and assets from `aa7f1d2`; do not substitute the old orthographic Rogue Siege camera.
- Keep Forest map dimensions, placement, economy, worker commands, wounds, and five waves.
- Live combat uses captured mouse, perspective camera, centered reticle, camera-relative movement and true crosshair aim. Menus/preparation release the mouse and hide the reticle.
- Normal launch exposes Forest Shrine only; old debug entry points remain usable for regressions.
- Preserve the previous native app and unrelated Edo design work. Integrate locally; do not publish remotely.

## Review Focus

- Latest attacks, auto-lock, projectile collisions and ink effects must not reveal enemies through fog.
- Phase/roster/pause transitions must restore the right camera and mouse state, and cancel held attacks/rally commands.
- Original Goemon and Edo must retain their updated effects without requiring the old Fire Siege construction director.
- Start Wave must preserve the exact prepared settlement and prevent all legacy construction inputs.
- The exported app must have the same default Forest entry and combat capabilities as the source checkout.

### Task 1: Modern combat baseline and Forest integration
**Files:** shared combat/assets from `aa7f1d2`; scripts/forest/forest_game.gd, forest_ui.gd; game.gd, rogue_roster_picker.gd, rogue_roster_combat.gd; tests/forest-shrine/crosshair_test.gd and existing Forest suites.
**Interfaces:** ForestGame.camera_combat(), crosshair_aim_enabled(), auto_attack_enabled capability; inherited ActionCamera and projectile_direction(); Forest UI crosshair_visible(); latest twelve-character picker configuration.
- [x] Add a regression that fails on old orthographic wave view, absent reticle and missing Edo card. Observe the failures.
- [x] Merge latest Fire Siege combat; resolve conflicts retaining modern implementations and Forest adapters.
- [x] Switch only wave camera to existing ActionCamera perspective, initialize its defaults, capture/release mouse by phase/menu, and draw centered reticle.
- [x] Preserve updated class mechanics and fog-sensitive targeting/effects; test twelve heroes, projectile aiming/cover, and full transition cycle.
- [x] Run Forest suites and relevant modern combat suites. Commit integrated baseline and evidence.

### Task 2: Definitive native release
**Files:** README.md, project.godot, export_presets.cfg, native build artifacts.
**Interfaces:** normal main entry -> Forest title -> roster -> overhead preparation -> crosshair battle; macOS app v2.54.0.
- [x] Verify normal launch/return/retry exposes only Forest and latest twelve-character roster.
- [x] Inspect rendered battle, preparation and picker, confirming crosshair perspective visually.
- [x] Fresh review against latest combat baseline and Forest behavior; fix important findings with regressions.
- [x] Export and verify app, back up v2.29, install definitive app, integrate source safely, and record final test/release evidence.
