# Fire Siege MVP Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for integration and superpowers:dispatching-parallel-agents for isolated subsystem implementation. Steps use checkbox tracking.

**Goal:** Implement v0.2 on the pinned Fire Siege build and publish verified runnable release packages.
**Architecture:** A FireSiege subclass isolates redesigned runtime behavior from legacy TowerDefense. Construction visuals expose a stable API, while game/player/enemy/HUD adapters route only Fire Siege to new behavior. Pure state tests and scene integration tests cover independent transitions and actual actors.
**Tech Stack:** Godot 4.6, GDScript, native GLB/procedural assets, GitHub CLI.
**Spec:** ../../fire-siege-mvp/source-handoff.md and ../../fire-siege-mvp/decisions.md.

## Global Constraints
- Start gold 10, arrow price 5, damage 50, interval 0.5; mine price 10 and 2 gold/sec.
- Unlimited setup, hold Y 3 seconds, 10 waves at 5/sec for 60 seconds, then clearance; reward 10 x wave once.
- 12 empty sites, no enemy gold or pickups, 5-second revival, no old cards/upgrades in Fire Siege.
- Preserve heroes, movement, camera, personal progression, healing, and unrelated modes.

## Review Focus
- Held inputs crossing pause/switch/death/wave boundaries must never buy or launch unintentionally.
- Floating ledger frame partitions must preserve income, upkeep and paid firing time.
- Queued actors/projectiles from an outgoing run must not resolve into a replacement run.
- Dead hero and same-tick last kill/base breach must resolve consistently.
- Actual scene layout, exported package resources and UI usability must match tests.

### Task 1: Runtime state and director
Files: scripts/fire_siege.gd, scripts/fire_siege_state.gd, scripts/fire_siege_state_tests.gd.
Interfaces: FireSiege extends TowerDefense; redesign_mode=true; tick(delta), update_build_input(delta,held), update_start_input(delta,held), hero_died(), revive_now(), interrupt_inputs(), nearest_site(), interaction_prompt(); exposes mine_built, build_progress, start_progress, revive_left, wave_elapsed, powered, generation, money, sites/cannons compatibility.
- [x] Write failing deterministic tests for fixed opening, ledger, hold/decay, exact spawn boundaries, all ten rewards, generation/terminal/revival guards.
- [x] Implement state and scene director; FireSiegeStructure API below is supplied by Task 2.
- [x] Run headless tests through Godot and record exact results.

### Task 2: World, construction and arrows
Files: scripts/fire_siege_structure.gd, scripts/tower_defense_world.gd, scripts/fire_siege_structure_tests.gd, optional supplied economy assets.
Interfaces: TowerDefenseWorld.redesign_mode controls 12 sites and mine_position/mine_build_position. FireSiegeStructure has game/director/kind, set_build_progress(p,working), complete_build(), tick(delta,powered_delta), retire_wave_effects(); position supplied by director; kind arrow/mine. Exposes target, shells, blasts for compatibility. director provides generation, wave, active, phase, owns(enemy).
- [x] Test site geometry and structure/projectile contracts against real nodes.
- [x] Implement partial assembly, progress/hammer/light and visible fixed-cadence arrows; use supplied assets if found, explicit fallback otherwise.
- [x] Verify import/seek/axes where packages exist and headless structure checks.

### Task 3: Game integration, death, targeting and HUD
Files: scripts/game.gd, player.gd, enemy.gd, defense_enemy_traits.gd, hud.gd, fire_siege_mvp_tests.gd.
- [x] Add integration test entry point and failing tests for new opening, controls, death and enemy restrictions.
- [x] Select new director only for Fire Siege; bind B/Y; remove F/card flow there; route both native and original death paths; preserve other modes.
- [x] Replace stale setup/result/HUD copy; show current hero portrait/health/LMB/RMB and Beta revive action.
- [x] Test real game scenes, retry, victory while dead and legacy controls/regressions.

### Task 4: Verification and release
Files: export_presets.cfg, docs/fire-siege-mvp/verification.md, release artifacts.
- [x] Run relevant regression suites, scene launch and visual checks; fix actual failures.
- [x] Fresh code review, resolve important findings with regression tests.
- [x] Export macOS and Linux release packages, verify ZIP and exported resource/runtime startup, compute checksums.
- [x] Commit, push new branch and tag, publish GitHub prerelease with honest test and asset limitations; verify uploaded assets.

Published `fire-siege-v2.32.0-mvp` at implementation commit `b93dc378aaf92e1db3e15c102f6efdc6343e0eaf`.
GitHub reports all five release assets uploaded; every size and SHA-256 digest matches
the local package. Release: https://github.com/eric2532/Goemon/releases/tag/fire-siege-v2.32.0-mvp.
