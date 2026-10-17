# Forest Enemy Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace Forest Shrine enemies with the approved four models and distinct combat roles, including the massive slow Daruma.

**Architecture:** The Forest model owns enemy roles, targets, navigation, attacks and health. Forest actors adapt that state to the existing hero combat interfaces; a dedicated batched renderer preserves the approved textured models and animates their rigid parts. Other game modes keep their existing enemies.

**Tech Stack:** Godot 4.6, GDScript, GLB, spatial shaders, headless and native game tests.

**Spec:** `docs/superpowers/specs/2026-10-14-forest-enemy-redesign-design.md`; implementation authorized by Eric on 14 October 2026.

## Global Constraints

- Raider prioritizes the main character; Archer prioritizes workers; Daruma prioritizes towers and walls; Lantern prioritizes the shrine.
- Use Raider, Archer and Lantern v01 assets and the massive Daruma v02 asset at their exported dimensions.
- Daruma: 0.75 m/s, 3,000 HP, 120 building damage, 1.5 s windup, 3.5 s recovery, 90% knockback resistance, no routine flinch or healing. Freeze pauses attack timers.
- Preserve testing gold, doubled walls, worker commands, fog, hero kits and the five-wave run. Preserve existing uncommitted work and original asset masters.
- Keep changes uncommitted for the user to review. Work in the existing feature checkout because it contains the approved uncommitted assets and ongoing work.

## Review Focus

- Removed or moving targets during windup: cancel invalid contact; never damage a stale target.
- Giant against trees, narrow gates and map edges: fitted clearance and reachable staging, no tunneling or stuck wave.
- Giant visible feet: melee and projectile contact must damage the fitted lower geometry.
- Freeze and pause: stop locomotion and attack progress without losing model pose.
- Fog and wave cleanup: no hidden labels, projectiles or giant spawn footprint; all five waves finish and retry resets.

### Task 1: Roles, navigation and attacks

**Files:** Create `scripts/forest/forest_enemy_roles.gd`, optional focused navigation/projectile helpers, and `tests/forest-shrine/enemy_roles_test.gd`; modify `scripts/forest/forest_waves.gd` and old fixtures whose expected shared priorities are superseded.

**Interfaces:** `forest_enemy_roles.gd` exposes static `stats(variant: int) -> Dictionary`, `asset_path(variant: int) -> String`, `height(variant: int) -> float`, `footprint_radius(variant: int) -> float`, `hurt_point(enemy: Dictionary, from: Vector3) -> Vector3`. Enemy dictionary retains all old fields and adds `action` (walk/windup/recover), `action_left`, `target_kind` (hero/worker/building), `target_id`, `facing` (yaw, model forward -Z), `walk_phase` (radians, advances only when moving), `attack_progress` (0..1 windup, negative recovery), `attack_point` (world visible contact). Director exposes `spawn_enemy(variant: int, point: Vector3) -> Dictionary` for production spawning and deterministic tests. `projectiles: Dictionary` is director-owned; enemy arrows emit `enemy_arrow` with id/from/to and `enemy_arrow_impact` with id/point.

- [x] Write and run failing tests for target categories, giant 12m/16s, wave-independent speed/HP, stable structure preference, canceled strikes, freeze, impulse sweep, full footprint staging and completion.
- [x] Implement role defaults (Raider 300 HP/6 m/s, Archer 65 HP/5 m/s/24m range, Lantern 55 HP/10 m/s); balanced damage with readable windups. Archer shoots traveling arrows at healthy workers, including tower crews when unobstructed; if no workers, shrine. Raider pursues targetable hero, otherwise shrine. Lantern always shrine. Route blockers can be breached without changing primary role.
- [x] Implement giant route clearance derived from the 17m core, fitted obstacle contact and slow turning. Validate staging in wide reachable unseen approaches; introduce one giant in waves 3–5.
- [x] Run role, simulation, worker and fog regression tests; record commands and results.

### Task 2: Batched approved models and rigid animation

**Files:** Create `scripts/forest/forest_enemy_crowd.gd`, `assets/materials/forest_enemy_crowd.gdshader`, and `tests/forest-shrine/enemy_visual_test.gd`.

**Interfaces:** Node3D with `game`, `batches: Array[MultiMeshInstance3D]`, `materials`, `clear()` and `_process(delta)`. Consumes Task 1 role paths and actor `forest_id`/variant/global_transform/model/HP/dead plus the authoritative enemy fields. Keeps `batches` diagnostic compatibility, including `visible_instance_count`.

- [x] Test imports, exact world heights, facial materials/UVs, bounded draw batches and no duplicate full model per actor.
- [x] Merge shared meshes by material, retaining face textures and smooth normals. Animate identifiable arms/legs/body with encoded vertex groups; heavy alternating feet with stance compensation for Daruma, slow body rock and visible fist contact. Respect simulation phase/facing, freeze, pause and death; never rescale approved assets to old proxy scale.
- [x] Run a native render review at front/side/back plus movement/attack, report performance and any integration assumptions.

### Task 3: Actor and fitted combat contact

**Files:** Modify `scripts/forest/forest_raider.gd`, focused existing combat query helpers, `scripts/forest/forest_workforce.gd`, `scripts/forest/forest_tower_arrows.gd`; create `tests/forest-shrine/enemy_contact_test.gd`.

**Interfaces:** Retain Ninja compatibility. Forest actor exposes `combat_aim_point(from: Vector3) -> Vector3`, `combat_contact_point(point: Vector3) -> Vector3`, `combat_segment_hit(from: Vector3, to: Vector3, radius: float) -> bool` or equivalent shared queries; old actors retain current behavior. Actor synchronizes Task 1 state, enforces Daruma resistance without suppressing damage/freeze, and provides fitted compound collision and readable low health display. Tower arrows use role `hurt_point` for visible contact instead of giant root + UP.

- [x] Write failing tests for melee feet, airborne/body and missed projectile segments, tower arrow contact, normal damage and giant resistance/freeze.
- [x] Fit humanoid and lantern shapes to exported bodies, and Daruma compound body/feet/fists at v02 scale. Adapt shared query callers behind capability checks; keep other modes behavior.
- [x] Run hero/combat and tower-arrow regressions and record results.

### Task 4: Integration, review and playable export

**Files:** Modify `scripts/forest/forest_game.gd`; create enemy projectile presenter and `tests/forest-shrine/enemy_integration_test.gd`/native tour as needed; update saved design status and test README.

**Interfaces:** Swap only Forest crowd. Dispatch director arrow events to fog-aware arrow visuals; cleanup arrows with phase transitions/retry. Forest visibility tests fitted giant footprint; actor labels/effects follow shared fog.

- [x] Connect roles, actors, models, projectiles and full-footprint visibility.
- [x] Verify all four roles, damage, pause/freeze, five waves, retry, preserved setup and real native gameplay frames. Review each scoped task and the combined diff with independent reviewer; fix material findings.
- [x] Export macOS, verify package startup/signature, preserve previous build, then replace `build/Goemon.app` and deliver the playable build.

Delivery: Goemon2.55.0 at `build/Goemon.app`. Previous app preserved at `build/enemy-redesign/previous/Goemon.app`. Independent task/final reviews approved; source and packaged native verification completed. Code changes remain uncommitted.
