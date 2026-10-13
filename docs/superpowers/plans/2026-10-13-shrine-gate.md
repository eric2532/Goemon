# Buildable Shrine Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved 10-gold / 5,000-HP wall-and-gate defense position while preserving exploration and shrine battles.

**Architecture:** A dedicated structure owns presentation/collision, a bounded objective controller owns slots/clocks, and an enemy adapter presents gate combat. Fire Siege owns construction payment, health, and lifecycle.

**Tech Stack:** Godot 4.6.3, GDScript, procedural Japanese geometry, existing physics/weak-reference and construction patterns.

**Spec:** `../specs/2026-10-13-ink-roster-gate-design.md`, approved.

## Global Constraints

All constraints in `2026-10-13-ink-roster-gate.md` apply. No roster-effect dependency:
the gate must work with current character kits. Enemy-only panel layer is bit 16;
normal terrain stays bit 1. Confirm no competing bit-16 use before implementing.
Doorway occupancy uses enemy layer 4; player/friendly passage remains unchanged.

## Review Focus

- Repeated completion/deferred payment: Task 1 charges once and never charges an occupied opening.
- Static wall access: Task 1 physically validates mine/tower pads and door passage.
- Death/knockback and long updates: Task 2 prevents ghost contacts, slot reuse bugs and catch-up bursts.
- Optimized enemy motion and local hero interception: Task 3 must not bypass gate blocking or priority.
- Mid-wave rebuild and custom maps: Task 3 preserves inside enemies, shrine assignment, and custom-map contracts.

### Task 1: Gate structure, transaction and physical passage

**Files:** create `scripts/fire_siege_gate_structure.gd`, `scripts/shrine_gate_tests.gd`; modify `scripts/fire_siege.gd`, `scripts/fire_siege_layout.gd`, `scripts/fire_siege_hud.gd`, `scripts/game.gd` and gate-related expectations in existing structure tests only where the approved route changes.

**Interfaces:** gate structure fields `game: Node`, `director: Node`, `kind: String="gate"`, `_generation: int`, `completed: bool`, `walls_built: bool`; methods `set_build_progress(progress: float,working: bool) -> void`, `set_proximity(selected: bool,affordable: bool) -> void`, `can_complete_build() -> bool`, `complete_build() -> void`, `break_gate() -> void`, `tick(delta: float,powered_delta: float=0.0) -> void`, `retire_wave_effects() -> void`. Director fields `gate_state: Dictionary`, `gate_hp: float`, `gate_max_hp: float=5000.0`, `gate_position: Vector3` from the map's named gate anchor; helpers `_build_states() -> Array`, `_build_sites() -> Array`, `gate_alive() -> bool`. Add `--shrine-gate-test` / `SHRINE_GATE_RESULT` game hook. Layout exposes named gate anchor `(0,0,180)` only on expanded standard maps; gate build footprint `Vector2(6,.6)` around the opening.

- [ ] **Step 1:** Write real-game construction/collision tests: empty start, insufficient gold, three seconds eligible work, interruption/decay, exactly one 10-gold charge, HP 5000, repeat completion no charge, setup/combat/pause/death, nearest-site selection, and damage persisting across waves. Physically probe player/enemy masks and preserved mine/tower work pads. Add occupied-enemy volume and friendly-only occupancy cases:

  ```gdscript
  check(is_equal_approx(run.money,before-10) and run.gate_hp==5000, "one purchase")
  check(not gate.can_complete_build() and run.money==before, "occupied opening defers payment")
  check(hero_crosses and not enemy_crosses, "selective door collision")
  check(side_wall_blocks and mines_accessible and towers_accessible, "solid accessible layout")
  ```

- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . -- --shrine-gate-test`; require expected missing-barrier assertions rather than parser errors.
- [ ] **Step 3:** Build the Japanese frame, opaque side walls to x=±20, 12-metre opening, ~four-metre height, ~30%-opacity no-opaque-shadow panel, empty foundation, progress/price/HP prompts. Side walls are layer 1; panel layer 16. Extend construction via shared build-state/site helpers and explicit gate price/duration; preserve tower/mine indices and ice upgrades. Gate is never added to upkeep cannons. Defer the completion transaction when live enemy bodies occupy the panel volume. Reset only on a new run; retain side walls on destruction and reuse them on rebuild. Invalidate existing obstacle caches on wall creation/removal through their configure entry point, not every frame. Add compact gate HUD state without covering shrine/crosshair.
- [ ] **Step 4:** Run gate construction tests plus structure/economy/ice/exploration/custom-map suites; require zero failures. Render before/after building and inspect mine access and enemy visibility through the panel.
- [ ] **Step 5:** Commit `Add buildable transparent shrine gate and side walls`.

### Task 2: Gate-only strike clock and bounded objective allocation

**Files:** create `scripts/gate_attack_clock.gd`, `scripts/fire_siege_gate.gd`, `scripts/shrine_gate_unit_tests.gd`; modify `scripts/game.gd` for `--shrine-gate-unit-test` / `SHRINE_GATE_UNIT_RESULT` native hook.

**Interfaces:** clock `reset() -> void`, `advance(delta: float,eligible: bool,paused: bool=false) -> bool`, `pose() -> StringName`; interval 1.25, final .65 windup and .30 strike within the cycle. Controller `configure(owner: Node) -> void`, `intercepts(enemy: Ninja) -> bool`, `admit(enemy: Ninja) -> bool`, `handles(enemy: Ninja) -> bool`, `assignment(enemy: Ninja) -> Dictionary`, `tick(delta: float) -> void`, `release(enemy: Ninja) -> void`, `clear() -> void`, `attackers() -> int`, `waiting_count() -> int`. Assignment is `{position: Vector3, attacking: bool, pose: StringName}`. Owner supplies `_running() -> bool`, `owns(enemy: Ninja) -> bool`, `gate_alive() -> bool`, existing generation/wave/phase/game, `gate_position: Vector3` from Task 1, and `apply_gate_contact(enemy: Ninja) -> bool`, implemented in Task 3.

- [ ] **Step 1:** Write clock unit checks and fixture-owner allocation tests for nine and 300 living owned actors. Eight contact points span x=±4.9 ahead of the panel at z=178.4; reserve distinct legal waiting points ahead of those slots, using terrain clearance/bounds checks. Check idempotent admission, weak identities, FIFO turnover, zero legal points, and no teleports. Pin:

  ```gdscript
  check(not clock.advance(1.24,true), "first hit waits")
  check(clock.advance(.01,true), "first hit at 1.25 seconds")
  check(clock.advance(100,true) and not clock.advance(0,true), "one hit, no replay")
  check(controller.attackers()<=8, "bounded contact positions")
  ```

  Cover paused time, ineligible reset, enemy death/displacement during windup, actor/slot reuse, retired generation/wave, broken/rebuilt gate, enemies already inside, and shrine-owned actors.
- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . -- --shrine-gate-unit-test`; observe missing clock/controller assertions.
- [ ] **Step 3:** Implement independent clocks and bounded slot/waiting allocation following the shrine pattern, refreshing at .2 seconds and keeping at most eight active clocks. `intercepts` accepts only live wave-owned entrance-side raiders during combat while the gate is alive, excluding current shrine assignments. Validate proximity within 1.25 metres of the assigned point, status and obstruction before proposing a hit. Keep zero-clearance fallback safe, release promptly on death/displacement, and clear pending contacts on ownership changes. Do not apply health changes in this controller.
- [ ] **Step 4:** Run gate unit and existing shrine-clock tests; require zero failures, including a long update, new-generation actor reuse, and 300 bounded waiting identities.
- [ ] **Step 5:** Commit `Add bounded gate attack slots and independent strike clocks`.

### Task 3: Gate-first enemies, destruction, rebuilding and shrine continuation

**Files:** create `scripts/gate_enemy_motion.gd`; modify `scripts/enemy.gd`, `scripts/fire_siege.gd`, gate structure/controller, `scripts/shrine_gate_tests.gd`, and existing shrine/exploration expectations that assume an unobstructed completed route.

**Interfaces:** `GateEnemyMotion.tick(enemy: Ninja,delta: float) -> bool`; true means gate motion consumed this frame. Director `apply_gate_contact(enemy: Ninja) -> bool` revalidates all eligibility then subtracts `20.0*enemy.defense_damage_multiplier*game.tuning.enemy_damage` once; `gate_blocking(enemy: Ninja) -> bool` delegates to controller interception. Director owns health and the once-only zero-HP transition. Preserve existing shrine interfaces unchanged.

- [ ] **Step 1:** Add actual enemy/input tests: nearby hero behind/in front of gate cannot lure eligible raiders past it; optimized far/cached-ground movement cannot tunnel through panel; attacks lower gate HP but never hero/shrine HP; stun/freeze/knockback reset strike timing; ice only slows approach; hero death does not stop gate hits. With 300 real raiders require ≤8 attackers, distinct waiting assignments, stable living count and no arrival rewards. At destruction check:

  ```gdscript
  check(run.gate_hp==0 and panel_layer==0, "one opening transition")
  check(raiders_resume_route and shrine_hp_falls_after_arrival, "defense continues")
  check(run.alive_count==alive_before_break, "breaking door is not a kill")
  ```

  Cover 10-gold rebuild/HP restore, occupied doorway deferral, inside/shrine actors retaining positions/assignments, both shrine-arrival entry points, melee/projectile/J passage with real terrain obstruction, pause/restart/switch/wave retirement/termination, and custom maps with no automatic gate.
- [ ] **Step 2:** Run the gate integration suite; observe missing priority/contacts/continuation failures, while construction and clock tests stay green.
- [ ] **Step 3:** Configure/clear the gate controller with wave ownership, release on defeat/recovery, and run the gate adapter before normal local hero interception and shrine motion. Preserve frozen/stun/impact-pause handling. Walk toward assigned positions with clamped approach steps and face the gate during clock poses; waiting actors cannot deal gate damage. Apply bit-16 masks only to this map’s owned raiders and restore prior masks on retirement. Guard both breach paths while gate priority applies. Destroy panel collision/visual once at zero HP, clear clocks, retain walls and normal wave accounting; reacquire only entrance-side enemies after a successful rebuild. Preserve shrine state when clearing only gate effects.
- [ ] **Step 4:** Run gate unit/integration, existing shrine, Fire Siege economy/structure/campaign, exploration/ice/custom-map, J/crosshair, and real ranged/melee obstruction suites; require zero failures. Render the attacking crowd, player shooting through the panel, destruction, and continued shrine combat. Do not collect or label FPS from these functional fixtures.
- [ ] **Step 5:** Commit `Integrate gate-first raiders and resume shrine battles after breach`.
