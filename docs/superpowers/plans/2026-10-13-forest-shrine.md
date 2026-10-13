# Forest Shrine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver a playable forest shrine siege with overhead construction, live worker commands, shared fog, and five waves.

**Architecture:** A separate scene inherits the existing game services and reuses Goemon, cursor combat, sounds, and enemy rendering. A scene-independent model owns grid navigation, construction, economy, workers, visibility, and waves. Small world, presentation, and UI components adapt that model to the actual 3D battlefield.

**Tech Stack:** Godot 4.6, GDScript, existing GLB assets, spatial shaders, native macOS export.

**Spec:** docs/superpowers/specs/2026-10-13-forest-shrine-design.md

## Global Constraints

- User now authorizes implementation; the original discussion-only restriction is superseded.
- Latest steering: a spacious map with starter mines next to the shrine. Use 80 × 80 cells at 6 metres per cell (480 metres square), a central clearing 30 cells across, and two deposits within initial shrine vision.
- Preparation before every wave, overhead actual battlefield, illustrated build bar. Combat has no construction or tactical command pause.
- Hold to gather workers, release for nearest available local job; wounded workers recover during preparation.
- Explored terrain persists while enemies require current shared vision.
- Keep existing modes working. No new dependencies or external services.

## Review Focus

- Phase/input changes must not let a placement click become a hero attack or preserve a held command across pause/restart.
- Wall placement and gate replacement must preserve usable allied routes and refund nothing on rejected transactions.
- Full/depleted/unreachable workplaces must not trap reservations or teleport workers.
- Hidden enemy geometry, labels, targeting, and effects must not leak through fog.
- A fully enclosed shrine must remain attackable through destructible barriers, including after navigation changes.

---

### Task 1: Grid, construction, and fog model

**Files:** Create scripts/forest/forest_model.gd; tests/forest-shrine/model_test.gd.
**Interfaces:** Model.new(); reset(seed: int); cell_of(point: Vector3) -> Vector2i; point(cell: Vector2i) -> Vector3; placement_error(kind: String, cell: Vector2i, rotation: int) -> String; build(kind: String, cell: Vector2i, rotation: int) -> Dictionary; route(from: Vector2i, to: Vector2i, enemy: bool=false) -> Array; update_vision(hero: Vector3); visible_at(point: Vector3) -> bool.
- [x] Write tests rejecting occupied/unexplored/unaffordable and combat placements without spending; valid mine adjacent to shrine; gates allow allies; discovered terrain survives source movement.
- [x] Run `godot --headless --path . --script tests/forest-shrine/model_test.gd`; observe feature failure.
- [x] Implement terrain, footprints, transactions, allied/enemy grids, persistent exploration and shared current vision.
- [x] Run the same test until clean PASS and commit.

### Task 2: Worker jobs and finite wave simulation

**Files:** Extend scripts/forest/forest_model.gd; create scripts/forest/forest_workforce.gd and scripts/forest/forest_waves.gd; extend model_test.gd.
**Interfaces:** model.start_wave() -> bool; model.tick(delta: float, hero: Vector3); model.rally(held: bool, hero: Vector3); model.damage_worker(id: int, amount: float); model.damage_building(id: int, amount: float); model.damage_enemy(id: int, amount: float); model.workers/buildings/enemies dictionaries; model.events array.
- [x] Add failing tests for local nearest assignment, capacity, cargo delivery, no income while preparing, wounds/recovery, finite waves, and enemy wall breach.
- [x] Implement live jobs, paths, retreat, recovery, delivered income, tower attacks, and seeded perimeter waves.
- [x] Verify tests, including an enclosed-shrine fixture and depleted workplace, and commit.

### Task 3: World, structures, workers, and fog presentation

**Files:** Create scripts/forest/forest_world.gd, forest_art.gd, forest_fog.gdshader, forest_raider.gd; create tests/forest-shrine/world_test.gd.
**Interfaces:** ForestWorld.model; rebuild(); sync(delta: float); creation of real StaticBody3D construction colliders and visible worker models; raider.setup(game, id).
- [x] Add failing scene checks for world bounds, deposits near shrine, gate collision policy, and actor visibility.
- [x] Build spacious clearing, reused cedar/shrine assets, custom timber towers/mines/palisades, animated workers, construction ghosts, and visibility-aware forest rendering.
- [x] Verify scene tests plus rendered inspection and commit.

### Task 4: Preparation UI and game integration

**Files:** Create scripts/forest/forest_game.gd, forest_ui.gd, scenes/forest_shrine.tscn, tests/forest-shrine/integration_test.gd; modify scripts/game.gd and scripts/enemy_crowd.gd minimally.
**Interfaces:** ForestGame extends existing game; set_phase_view(); place_at(screen: Vector2); return_to_menu(); UI callbacks for build, recruitment, start wave, pause/restart; main-menu ForestShrineButton and --forest-shrine launch flag.
- [x] Add failing integration checks for menu entry, actual build-button/click flow, camera transition, no combat construction, rally input, defeat/retry/menu.
- [x] Implement parchment build cards with previews, wall dragging, rotation, pan/zoom, selection repair/removal, worker assignment, and combat HUD. Reuse Goemon and enemy models.
- [x] Exercise integration checks and inspect preparation/combat screenshots. Commit.

### Task 5: Regression, review, and playable delivery

**Files:** Update README.md, tests/forest-shrine/README.md, project.godot/export_presets.cfg only if required for release metadata.
- [x] Run model, world, integration, and existing tower-defense/Rogue Siege regression checks; inspect runtime logs.
- [x] Request fresh whole-branch review; resolve important findings with regression tests.
- [x] Export and verify a native macOS playable build; preserve existing app in build/Other Files before replacing the main app.
- [x] Update documentation with controls, validation, and any concrete limitations; commit and deliver the build and source changes.
