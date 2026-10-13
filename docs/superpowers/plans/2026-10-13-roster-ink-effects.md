# Roster Ink Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the ten remaining heroes’ attack/hit appearance while preserving all twelve kits, and hide the lock marker while J/crosshair work.

**Architecture:** Generalize the existing brush material and bounded weapon sampling, reuse projectile/area geometry, and add a small original-hero feedback adapter. Combat still owns damage, movement, status, and timing.

**Tech Stack:** Godot 4.6.3, GDScript, ShaderMaterial, cached ArrayMesh, existing batched particles.

**Spec:** `../specs/2026-10-13-ink-roster-gate-design.md`, approved.

## Global Constraints

All constraints in `2026-10-13-ink-roster-gate.md` apply. No gate dependency:
these three tasks must produce a working effects preview on their own. Preserve
Samurai/Magic’s existing red/purple defaults, model hashes, damage and abilities.
Use the specification’s per-hero treatments and current class palettes.

## Review Focus

- Fast skipped emission windows: Task 1 samples a displayed authored pose, including 4.5× tempo plus ultimate.
- Explorer’s left-hand trail: Task 1 must follow its real left weapon, not duplicate the right pose.
- UV-free cached geometry: Task 2 must not become invisible under the pigment shader.
- High-count coins/projectiles: Task 3 preserves batched geometry and finite admission, rather than one trail node per coin every frame.
- Hidden markers: Task 3 preserves target reacquisition, the center crosshair, and ordinary obstruction.

### Task 1: Palette materials and real weapon brush sampling

**Files:** create `assets/rogue/scripts/ink_brush_style.gd`, `scripts/roster_ink_brush_tests.gd`; modify `assets/rogue/shaders/magic_ink_brush.gdshader`, `assets/rogue/scripts/magic_sword_brush.gd`, `assets/rogue/scripts/effects.gd`, `scripts/rogue_roster_combat.gd`, and `scripts/game.gd`.

**Interfaces:** `InkBrushStyle.material(tint: Color, energy: float=1.0, fade: float=1.0) -> ShaderMaterial`; `fx.weapon_brush_sample(attack: Variant, blades: Array, tint: Color, accelerated: bool=false, tempo: float=1.0) -> void`, where each blade is `{node: Node3D, axis: Vector3}`; retain `sword_brush_sample(...)` compatibility. Ribbon `sample_blades(poses: Array) -> void` accepts world-space `[base,tip]` pairs and keeps `sample_blade(base,tip)` for existing callers. Add `--roster-ink-brush-test` hook and `ROSTER_INK_BRUSH_RESULT` summary.

- [ ] **Step 1:** Add actual-input tests for Pirate/Ninja/Knight/Explorer/Master Thief normal and boosted cuts. Check pigment material, nonzero triangle area, leading tip within .015 metres of each real blade, distinct left/right Explorer surfaces, and no idle emission. Pin bounded geometry:

  ```gdscript
  check(total_vertices <= (208 if dual else 104), "finite blade geometry")
  check(tip_error < .015 and triangle_area > .01, "visible real blade path")
  check(live_ribbons <= [2,3,4][quality], "shared attack admission")
  ```

  Cover Low/reduced flashes, 2×/3× pickups, 4.5× pickup/chain tempo, cancellation/death/switch/pause/restart, and the existing Samurai/Magic expectations.
- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . -- --roster-ink-brush-test`; observe intentional missing-treatment failures. Existing Samurai/Magic suites must remain green.
- [ ] **Step 3:** Add optional tint uniforms without changing existing red/purple defaults. Generalize pose histories by blade identity; cache actor blade bindings and sample only after authored poses. Use one admitted ribbon per attack: one surface per blade, at most two, 18 poses / 104 vertices per surface. Preserve first-crossing and wholly skipped-cut presentation, proportional fast tail lifetime, and no resurrection of cancelled handles. Keep directional thrusts separate; retain generic slashes only for actions not replaced by a sampled brush.
- [ ] **Step 4:** Run the roster suite, Samurai/Magic VFX and crimson combat suites; require exit zero and no gameplay errors. Inspect actual rendered sword angles and both Explorer blades.
- [ ] **Step 5:** Commit this deliverable as `Generalize bounded ink brush materials and real blade trails`.

### Task 2: Rogue projectiles, thrusts, area attacks, and hit feedback

**Files:** modify `assets/rogue/scripts/effects.gd`, `assets/rogue/scripts/class_actions.gd`, `assets/rogue/scripts/ink_brush_style.gd`, `scripts/roster_ink_brush_tests.gd`; extend `scripts/combat_vfx_tests.gd` only with meaningful geometry/budget assertions.

**Interfaces:** preserve `create_projectile(kind: String, color: Color) -> Node3D`, `weapon_impact(pos,angle,style,color,heavy)`, `thrust(...)`, existing area-effect methods, and `Actions.update_projectile(g,pr,dt)`. Add `InkBrushStyle.animate(node: Node3D, delta: float) -> void` for materials registered in node metadata; it changes shader clocks only, never projectile state.

- [ ] **Step 1:** Extend roster tests to every Rogue secondary/utility/ultimate and primary projectile. Assert each appropriate attack uses a pigment wake/body/ring and confirmed hits have a bright core plus colored fragments. Misses must produce zero confirmed-hit bursts. For any cached geometry receiving a brush material, require UV count equal to vertex count and rendered visibility. Use existing combat tests to pin original flight, width, damage, piercing, contact/cooldown, status and ultimate outcomes; retain Ranger curve/spread and Dragoon actual-floor rules. Add dense 300-actor feedback fixtures at all qualities:

  ```gdscript
  check(impacts_this_frame <= [3,8,12][quality], "cosmetic frame cap")
  check(all_expected_damage_landed, "admission does not drop damage")
  check(live_effects_after_expiry == 0, "finite crowd feedback")
  ```

- [ ] **Step 2:** Run the roster and effect-budget suites; observe only newly requested appearance failures.
- [ ] **Step 3:** Apply pigment to existing cached blade/spear/ring geometry with valid UVs and preserve projectile silhouettes. Keep Pirate rounds, Ninja stars, Mage fire/frost, Knight counter, Dragoon thrust/leap, Ranger arrows/rain, Explorer hook/dash and Thief ember/smoke identifiable. Register existing material layers for clock updates; add no per-frame meshes, per-victim lights, or alternate combat collisions. Generalize the current brush impact branch to appropriate styles/colors while retaining heavy strength and existing admission. Do not add a sword stroke to Ranger’s bow or Mage’s ranged release.
- [ ] **Step 4:** Run roster, full-roster controls/upgrades/equipment, Ranger flight/storm, wave, VFX and projectile-query suites; require zero failures. Render representative projectiles, thrusts, area rings and confirmed hits for each class.
- [ ] **Step 5:** Commit `Apply ink textures and bounded impacts across Rogue abilities`.

### Task 3: Goemon/Edo effects and invisible lock marker

**Files:** create `scripts/native_ink_feedback.gd`; modify `scripts/game.gd`, `scripts/gold_coin.gd`, `scripts/coin_volley.gd`, `scripts/combo_energy.gd`, `scripts/edo_fire_explosion.gd`, `scripts/edo_meteor_rain.gd`, `assets/vfx/fireball/fire_energy.gd`, `assets/vfx/fireball/fireball.gd`, `assets/vfx/fire_shield/fire_shield.gd`, `assets/vfx/fire_beam/fire_beam.gd`, `scripts/hud.gd`, roster tests and `scripts/auto_lock_tests.gd`. Do not modify character models or Musashi balance.

**Interfaces:** `NativeInkFeedback.configure(game: Node) -> void`, `slash(point: Vector3, direction: Vector3, heavy: bool, combo: int, tint: Color, size: float, plane: float) -> void`, `impact(point: Vector3,direction: Vector3,strength: int,tint: Color) -> void`, `tick(delta: float) -> void`, `clear() -> void`. Preserve the existing public game slash/impact signatures; delegate cosmetics in Fire Siege. Add HUD `lock_marker_visible() -> bool` returning false, consumed by drawing, with no change to targeting.

- [ ] **Step 1:** Add real-input Goemon/Edo tests covering pipe/heavy/charge/chain/coins/bonus actions, normal/large fireballs, beam, shield, dodge, meteors and surge. Pin existing contact/flight/cooldown/status results with the existing Goemon/firecaster suites. Check finite gold/fire/blue brush feedback, Low/reduced-flash presence, batched coin wakes, and repeated switching among originals and Rogue heroes. Add:

  ```gdscript
  check(not game.hud.lock_marker_visible(), "no target ring or LOCK label")
  check(p.auto_aim_target() == visible_enemy, "J acquisition retained")
  check(game.hud.crosshair_visible(), "center crosshair retained")
  ```

  Also prove ordinary cover prevents acquisition and leaving sight/death reacquires correctly.
- [ ] **Step 2:** Run roster/auto-lock tests; observe requested native-appearance/marker failures, without changing kit expectations.
- [ ] **Step 3:** Implement the adapter using the shared style helper and bounded cosmetics. Keep Goemon’s existing weapon geometry and coin MultiMeshes, replacing material/wake appearance without de-batching or changing flight/hit loops. Brush Edo’s existing fire/beam/shield/meteor visuals, preserving flame shapes and combat handlers. Game owns `native_ink_feedback: Node`, calls `configure(self)` once on creation, `tick(delta)` once per unpaused displayed frame, and `clear()` on lifecycle changes; projectile nodes own their own material clocks. Use displayed-frame admission for native impacts too. Route quality/reduced-flash updates to both paths. Remove HUD’s projected arc/text; never call target selection solely to draw a hidden marker.
- [ ] **Step 4:** Run roster, Goemon attack-chain/power/coin, Edo firecaster, J and crosshair suites; require zero failures. Render both originals and the HUD. Verify cosmetics stop during pause and switching cannot leave or double-tick effects.
- [ ] **Step 5:** Commit `Upgrade original hero brush feedback and hide lock markers`.
