# Exploration, Shrine Combat, and Ice Towers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a larger exploration map with defended shrine health, persistent shrine attackers, zero-damage level 2 ice towers, and verified crowded-combat performance.

**Architecture:** Extend the existing world contract through an opt-in expanded layout and a static district builder. Separate shrine allocation and clocks from Ninja's ordinary combat, while FireSiege retains health, economy, and wave ownership. Keep tower progression in the director and implement ice impacts through the existing movement-slow interface.

**Tech Stack:** Godot 4.6.3, GDScript, existing procedural meshes and asset catalog, spatial MultiMesh batches, Metal Forward+, universal macOS export.

**Spec:** `docs/superpowers/specs/2026-10-12-exploration-shrine-ice-design.md` (approved for planning on 2026-10-12).

## Global Constraints

- Use the existing `/Users/eric/.codex/worktrees/fire-siege-spirit-effects/Sonic` checkout on `codex/fire-siege-spirit-effects`; leave `/Users/eric/Desktop/Projects_Codex/Sonic` intact.
- Deliver a separate playable macOS version using Godot 4.6.3, preserving the v2.49.1 app and ZIP.
- Expanded bounds: x=-160 to 160, z=50 to 530; 320 by 480 metres; flat height contract.
- Enemy route: (0,110), (0,155), (0,195), (0,220). Shrine objective: (0,220). Player start near (0,185).
- Twelve tower sites, four mines, three districts and three once-per-run caches worth three gold each.
- Unlimited preparation; existing hold-Y-for-three-seconds confirmation; no preparation spawning, automatic wave countdown, or shrine damage.
- Keep the existing 300-enemy active limit, five spawns per second, 300 enemies per wave, ten waves, and existing enemy roles.
- Shrine health: 100 normal, 50 hard; no between-wave healing; twelve attack positions at 5.5 metres radius, 1.25 metre contact tolerance, outer waiting ring at 10.5 metres.
- Shrine strikes: one HP every 2.5 seconds, including the first hit; final 0.65-second windup; at most one contact per update; separate player combat timing.
- Level 1: five gold, three-second construction, 50 damage, 48-metre range, 0.5-second shots. Level 2: ten additional gold, zero damage, 48-metre range, one-second shots, 0.6 movement multiplier for two seconds.
- Both levels use 0.10 gold/second upkeep. Ice cannot call `take_hit(0)`, cause stun, kill, or award damage/kill credit.
- Keep no more than 160 decorative trees, 24 buildings/pavilions, and 32 rocks; preserve existing directional shadow distance and quality presets; no new shadow-casting local lights.
- Spatial scenery batches: approximately 64–80 metres. Shrine reassignment: up to five checks per second. Ice pool: up to four visuals per tower, three-second shot lifetime.
- Preserve character models/VFX, crowd sweep staggering, cached projectile queries, crosshair framing, Ranger spread, curved shots, and airborne aiming.
- Preserve authored custom map bounds/schema/routes and other modes' layouts and arrival rules.
- Investigate a reproducible matched warmed mean frame-time regression above 5% or p95 regression above 2 milliseconds. Report measured limitations; do not promise constant 60 FPS.
- No push, merge, or release publication. Export only the new crosshair macOS version.

## Review Focus

1. A custom shrine near a boundary or wall must use only legal positions, including zero legal positions; no off-map assignment or hit through cover. Test in Task 3.
2. A held/echoed F press, an upper-floor tower, or two adjacent towers must not spend gold twice or upgrade an inaccessible tower. Test in Task 6.
3. A cache approached through a wall, during pause/death, or after run restart must respect access and once-per-run rewards. Test in Task 2.
4. Knockback or death during shrine windup, followed by actor/slot reuse, must not create a ghost contact. Test in Tasks 3 and 4.
5. Focus loss, different enemy health, or cold shader compilation must not masquerade as an FPS improvement. Test benchmark validity in Task 7.

## Execution setup and commands

Reuse the attached managed worktree; inspect it before edits with the using-git-worktrees skill. Do not create another checkout or reset local changes. Starting planning commit is `75357c5`; this plan/spec-status commit will become the execution base.

For the commands below, set a task-specific engine variable in each shell that needs it:

```sh
goemon_engine='/Users/eric/Downloads/Goemon-marc-prototypes-2026-10-10.JqoVC3/runtime/Godot.app/Contents/MacOS/Godot'
"$goemon_engine" --version
```

Expected: `4.6.3.stable.official.7d41c59c4`. Run from the worktree. Standalone suites use SceneTree scripts and finish with `failures=0` and exit 0; game-attached suites use the existing CLI hooks. Keep complete logs under ignored `build/exploration-shrine-ice/`. A parser error or nonzero test exit is a failure. Known headless renderer shutdown diagnostics are recorded separately, not used to excuse assertion failures.

## File responsibilities

- Create `scripts/fire_siege_layout.gd`: expanded coordinates and named art anchors.
- Create `scripts/fire_siege_districts.gd`: static district art, paths, spatial batches, and cache markers.
- Create `scripts/fire_siege_exploration.gd`: preparation-only cache collection and run reset.
- Create `scripts/shrine_attack_clock.gd`: independent deterministic strike clock.
- Create `scripts/fire_siege_shrine.gd`: validated slots, FIFO waiting identities, contact eligibility, clocks, and cleanup.
- Create `scripts/shrine_enemy_motion.gd`: shrine-specific movement and poses for Ninja.
- Create `scripts/ice_tower_effects.gd`: shared crystal/bolt resources, four-shot visual pool, and bounded impacts.
- Modify `scripts/tower_defense_world.gd`, `scripts/neon_shrine.gd`, `scripts/spirit_fortress_effects.gd`: opt-in layout, aligned art, culling and effect budgets.
- Modify `scripts/fire_siege.gd`, `scripts/enemy.gd`, `scripts/fire_siege_structure.gd`, `scripts/fire_siege_hud.gd`, `scripts/game.gd`: small orchestration/input/visual hooks; no broad refactoring.
- Add three standalone suites: `scripts/fire_siege_exploration_tests.gd`, `scripts/shrine_combat_tests.gd`, `scripts/ice_tower_tests.gd`; update existing expectations only where the approved behavior changes.
- Create ignored diagnostics `build/exploration-shrine-ice/foreground_battles.gd`, `foreground_traversal.gd`, `assemble_version.py`, result JSON and logs. Add release notes in `docs/fire-siege-mvp/exploration-v2500.md`.

### Task 1: Expanded world and aligned shrine anchors

**Files:** Create `scripts/fire_siege_layout.gd`, `scripts/fire_siege_exploration_tests.gd`; modify world, game, NeonShrine, SpiritFortressEffects, and `scripts/fire_siege_structure_tests.gd`.

**Interfaces:**
- Produce `FireSiegeLayout.configure(world: TowerDefenseWorld) -> void` and `FireSiegeLayout.anchors(world: TowerDefenseWorld) -> Dictionary`.
- Add world `expanded_mode: bool = false`, `layout_anchors: Dictionary`, and `exploration_caches: Array[Dictionary]`. Standard FireSiege enables expanded_mode before entering the scene tree; custom maps and direct legacy fixtures do not.
- Anchors have Vector3 values for entrance, shrine, pagoda, forward_station, rear_station, hero_summon, dog_summon, grove, village, watchpost; pagoda is shrine + (0,0,31), hero_summon is (-8,0.15,208), and dog_summon is (8,0.15,208). Keep approach towers at x=±12/z=116,130,144,158; move four parapet towers to z=155. Start mines at (-18,0,175), (18,0,175), (-30,0,180), and (-18,0,280), adjusting only if real footprint checks find a collision.
- Keep existing world properties as consumers' public interface; helper supplies coordinates before ground/routes/defenses/art are built.

- [x] **Step 1:** Write `expanded_layout_contract` and `legacy_layout_unchanged` assertions: bounds equal `Rect2(-160,50,320,480)`, lane 1 ends at `(0,0,220)`, route length is 110, twelve towers/four mines, height zero; direct compact world still has its existing bounds/sites. Assert collider rays at x=-5.5,0,5.5 from z=110 to 218 are clear and all build pads fit inside bounds.

  ```gdscript
  check(world.playable_bounds == Rect2(-160,50,320,480), "expanded bounds")
  check(world.lanes[1][-1] == Vector3(0,0,220), "shrine route endpoint")
  check(world.cannon_sites.size() == 12 and world.mine_sites.size() == 4, "sites retained")
  check(legacy.playable_bounds == Rect2(-80,50,160,310), "compact fixture unchanged")
  ```

- [x] **Step 2:** Run `"$goemon_engine" --headless --path . --script res://scripts/fire_siege_exploration_tests.gd`; expect the new expanded contract to fail before implementation, with a clear missing-feature assertion rather than a parser failure.
- [x] **Step 3:** Implement the interfaces and flag hook. Shift wall stations, mines, player/allied markers, shrine pagoda/lanterns/banners/windows, road trim, horizon and floating stones through anchors. Keep legacy world construction unchanged when expanded_mode is false. Keep small impact/fog/quality budgets at their existing values.
- [x] **Step 4:** Run the new suite and existing standalone `fire_siege_structure_tests.gd` and `spirit_fortress_tests.gd`; require zero failures. Verify actual tower access and route collision rather than coordinates alone.
- [x] **Step 5:** Commit only this deliverable with message `Add expanded Fire Siege layout and aligned shrine anchors`.

### Task 2: Three explorable districts and preparation rewards

**Files:** Create `scripts/fire_siege_districts.gd`, `scripts/fire_siege_exploration.gd`; modify world, FireSiege, HUD, and exploration tests. Reuse `scripts/map_pieces.gd` as a catalog without changing its saved schema.

**Interfaces:**
- Consume Task 1 anchors and world properties.
- Produce `FireSiegeDistricts.build(world: TowerDefenseWorld) -> void`, filling `world.exploration_caches` with `{id: StringName, position: Vector3, visual: Node3D}`.
- Produce exploration `configure(owner: FireSiege) -> void`, `tick(delta: float) -> void`, `reset() -> void`, `collected_count() -> int`; owner retains gold authority.
- Produce `FireSiege.shrine_guidance() -> Dictionary` with `distance: float`, `direction: Vector2`, and `under_attack: bool` (false until shrine integration).

- [x] **Step 1:** Add tests `district_paths_reach_shrine`, `cache_once_per_run`, `cache_access_and_lifecycle`, and `preparation_stays_unlimited`. Assert each cache adds exactly 3 gold once, all three add 9, pause/death/combat and blocked access add 0, new run rearms them, and a later preparation does not. Assert setup after 600 seconds has no scheduled actors or HP loss. Physically traverse representative path segments with the hero radius, not just centre rays.

  ```gdscript
  var before = director.money
  game.player.position = game.world.exploration_caches[0].position
  exploration.tick(.2)
  check(is_equal_approx(director.money, before + 3), "first cache grants three gold")
  exploration.tick(.2)
  check(is_equal_approx(director.money, before + 3), "same cache cannot grant twice")
  check(director.phase == "setup" and director.total_spawned == 0, "preparation stays safe")
  ```

- [x] **Step 2:** Run the exploration suite; observe missing districts/rewards failures while Task 1 checks stay green.
- [x] **Step 3:** Build the grove, village and watchpost loops and direct return paths. Route side paths behind the castle ramp toes (z>230), and take the watchpost's two returns around the pagoda at x=±30 rather than through its foundation. Use existing procedural kit meshes, shared night palettes, simple authored solids and spatial MultiMesh batches. Expose cache visuals at clear walkable points; check three markers at 5 Hz only when owner is running, setup and hero alive, within 2.5 metres and clear layer-1 access. Reflect collection once and display the reward. Update HUD preparation copy and shrine direction/distance without covering the crosshair.
- [x] **Step 4:** Run the exploration suite and `"$goemon_engine" --headless --path . -- --map-builder-test`; require zero failures and verify custom maps have no standard districts/caches. This task must not alter saved documents.
- [x] **Step 5:** Commit `Add exploration districts and preparation supply caches`.

### Task 3: Independent shrine strike clocks and legal slots

**Files:** Create `scripts/shrine_attack_clock.gd`, `scripts/fire_siege_shrine.gd`, `scripts/shrine_combat_tests.gd`.

**Interfaces:**
- Clock: `reset() -> void`, `advance(delta: float, eligible: bool, paused: bool) -> bool`, `pose() -> StringName`; true means one proposed contact, not applied damage. Poses are `chase`, `windup`, `strike`, `recover`.
- Controller: `configure(owner: Node) -> void`, `admit(enemy: Ninja) -> bool`, `tick(delta: float) -> void`, `release(enemy: Ninja) -> void`, `clear() -> void`, `handles(enemy: Ninja) -> bool`, `assignment(enemy: Ninja) -> Dictionary`, `attackers() -> int`, `waiting_count() -> int`. The owner contract is current `generation`, `wave`, `game.world`, `_running() -> bool`, `owns(enemy: Ninja) -> bool`, and `apply_shrine_contact(enemy: Ninja) -> bool`; use dynamic Node calls for the latter hook until integration.
- Assignment: `{position: Vector3, attacking: bool, pose: StringName}`; store weak references and current generation/wave identity, not raw queued Node references. At most twelve clock-bearing slots; waiting assignments do not deal damage.
- Controller calls the Task 4 interface `owner.apply_shrine_contact(enemy: Ninja) -> bool` only after eligibility and obstruction checks. Tests provide a fixture owner implementing this contract before real director integration.

- [ ] **Step 1:** Write clock tests with assertions: `advance(2.49,true,false)==false`, next `0.01` emits exactly one event, next 2.5 emits one, `advance(100,true,false)` emits one rather than forty, paused time emits none, and ineligible time cancels a pending hit and requires a fresh 2.5 seconds. Write slot tests for thirteen living owned actors: twelve legal assignments, one waiter, release transfers one seat, repeat admit is idempotent. Test near-boundary and blocked custom shrine positions, zero legal slots, stale/dead actors, contact cover, and slot reuse after cancellation.

  ```gdscript
  clock.reset()
  check(not clock.advance(2.49,true,false), "first contact waits")
  check(clock.advance(.01,true,false), "first contact at 2.5 seconds")
  check(not clock.advance(100,true,true), "pause cannot accumulate contacts")
  check(clock.advance(100,true,false), "large update emits one contact")
  check(not clock.advance(0,true,false), "large update leaves no replay backlog")
  ```

- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . --script res://scripts/shrine_combat_tests.gd`; require intentional missing-feature failure before adding the controller.
- [ ] **Step 3:** Implement clocks and controller. Sample up to 48 candidates at 5.5 metre radius to obtain at most twelve legal contact positions using bounded clearance/bounds checks; retain existing floor height. Assign waiting positions on the 10.5 metre ring with bounded legal fallbacks and no teleports. Refresh queue at 0.2-second intervals. Validate ownership, slot proximity within 1.25 metres, status, and a clear altar contact ray before proposing a hit. Clear all clocks/references on lifecycle invalidation.
- [ ] **Step 4:** Run the shrine suite; require zero failures, including partitioned delta timing, FIFO seat turnover, and zero-contact results when all candidates are blocked.
- [ ] **Step 5:** Commit `Add independent shrine attack clocks and bounded siege slots`.

### Task 4: Persistent attackers, wave accounting, and shrine feedback

**Files:** Create `scripts/shrine_enemy_motion.gd`; modify FireSiege, Ninja, HUD, shrine tests, `scripts/map_builder_tests.gd`, and relevant FireSiege tests that expect immediate arrival death.

**Interfaces:**
- Consume Task 3 controller and assignment contract.
- Produce `ShrineEnemyMotion.tick(enemy: Ninja, delta: float) -> bool`; true means this adapter performed shrine movement/poses for the tick. Preserve existing walk_motion and immediate knockback paths.
- Produce `FireSiege.apply_shrine_contact(enemy: Ninja) -> bool` and `shrine_attacker_count() -> int`; HP mutation and terminal state remain director-owned.
- Override FireSiege `can_breach(enemy: Ninja) -> bool` so already admitted actors are handled by the adapter, and enforce final-route-segment eligibility. Override `lane_direction(enemy: Ninja) -> Vector3` to use the controller's assigned/waiting position for admitted actors and the inherited route otherwise. Existing `breach(enemy)` becomes idempotent admission. No change to legacy TowerDefense breach.

- [ ] **Step 1:** Add real-scene tests for both arrival entry points, alive_count unchanged on arrival, shrine 100/50 starting HP, first contact only at 2.5 seconds, one HP per interval, and no player HP loss from shrine strikes. Assert waiting/attacking actors block settlement; each actual death resolves once; zero HP defeats before victory. Test death/stun/freeze/knockback during windup, hero switching, hero death/revival, pause, restart, blocked contact, and earlier custom waypoint passing near the altar.

  ```gdscript
  var population = director.alive_count
  var integrity = director.base_hp
  director.breach(enemy)
  director.breach(enemy)
  check(not enemy.dead and director.alive_count == population, "arrival preserves actor once")
  check(director.base_hp == integrity, "arrival itself causes no damage")
  ```

- [ ] **Step 2:** Run shrine tests and the custom-map integration test; expect old auto-breach behavior to fail the new assertions.
- [ ] **Step 3:** Integrate controller setup, tick, cleanup, release-on-death and arrival admission. Call motion adapter before ordinary player/dog combat for assigned attackers, while waiting enemies retain nearby player combat. Protect admitted actors from recovery resets. Use existing model poses without invoking player-damage strikes. Change HUD breach copy to active shrine attackers; cap warning banners to one per three seconds and reuse bounded hit flashes.
- [ ] **Step 4:** Run standalone shrine/state/crowd suites and game hooks `--map-builder-test`, `--fire-siege-mvp-test`, `--fire-siege-motion-test`, `--auto-build-test`; require zero failures. Update old arrival assertions to persistent siege contacts, retaining their original ownership and earlier-waypoint protections. Keep legacy arrival tests unchanged.
- [ ] **Step 5:** Commit `Keep Fire Siege enemies alive to attack the shrine`.

### Task 5: Zero-damage ice projectile branch and shared effects

**Files:** Create `scripts/ice_tower_effects.gd`, `scripts/ice_tower_tests.gd`; modify FireSiegeStructure and optionally share slow-ring material in DefenseEnemyTraits without changing slow rules.

**Interfaces:**
- Produce structure `level: int = 1`, `upgrade_to_ice() -> bool`, `attack_type() -> StringName` (`arrow` or `ice`). kind remains `arrow` for imported model binding; level determines the attack.
- Ice visual helper: `configure(tower: Node3D) -> void`, `acquire() -> MeshInstance3D`, `release(visual: MeshInstance3D) -> void`, `impact(point: Vector3) -> void`, `tick(delta: float) -> void`, `clear() -> void`. Return null when the four-shot pool is exhausted; never grow it beyond four.
- Consume existing `Ninja.apply_defense_slow(factor: float, seconds: float)` and projectile generation/ownership checks. Arrow impacts and ice impacts are distinct paths.

- [ ] **Step 1:** Test actual Ninja HP and movement: ice arrival preserves HP=100 and stun/kill/damage-credit state, applies factor 0.6 for 2 seconds, refreshes without multiplying, expires to 1, and preserves boss resistance. Obstructed, dead, expired and retired-generation shots apply no slow. Assert conversion removes pending arrow damage; level 1 still deals 50. Exercise pool reuse for 1,000 shots and assert no more than four live visual slots and no added per-target lights/particles.

  ```gdscript
  # After a real level-2 projectile reaches this 100-HP actor:
  check(enemy.hp == 100 and enemy.stun == 0 and not enemy.dead, "ice is slow only")
  check(is_equal_approx(enemy.defense_slow_multiplier(), .6), "ice reduces movement by forty percent")
  enemy.defense_traits.tick_status(2)
  check(is_equal_approx(enemy.defense_slow_multiplier(), 1), "slow expires after two seconds")
  ```

- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . --script res://scripts/ice_tower_tests.gd`; expect failure because the tower has no ice upgrade yet.
- [ ] **Step 3:** Implement the ice branch: range 48, interval 1, three-second TTL, shared crystal/bolt material, bounded impact visuals, no shadows, and target obstruction validation. Conversion clears old shells, resets firing state, and shows the crystal adapter while preserving GLB build/aim/recoil bindings. Leave imported/protected assets unchanged.
- [ ] **Step 4:** Run ice and structure suites plus `projectile_query_tests.gd`; require zero failures and validate observed movement rather than only a stored slow value.
- [ ] **Step 5:** Commit `Add zero-damage ice tower shots and pooled visuals`.

### Task 6: Deliberate level 2 purchase and tower HUD

**Files:** Modify FireSiege, game input, FireSiege HUD, ice tests, auto-build tests, and FireSiege controls tests.

**Interfaces:**
- Produce `FireSiege.nearest_upgrade_site() -> int`, `upgrade_site(index: int) -> bool`, `tower_counts() -> Dictionary` with `arrow: int`, `ice: int`; preserve `try_purchase() -> bool` as the F action entry point.
- Unfinished-site nearest_site stays dedicated to level 1 building. Upgrade purchase requires current running run, living grounded hero, existing 3.5-metre footprint-edge access and clear LOS, level 1, and at least 10 gold.
- Site dictionaries keep level state 0/1/2; structure level synchronizes after the atomic purchase. cannons retains each built tower exactly once.

- [ ] **Step 1:** Add assertions for exact 10-gold charge, repeated same-tower calls charging 0, insufficient funds, inaccessible/upper-floor towers, nearest of two candidates, grounded hero requirement, dead/paused/terminal/stale run, and F key echo/held-event rejection. Assert no level 2 auto-upgrade while standing idle; level 1 still auto-builds for 5 gold in 3 seconds; mixed tower counts and 0.10 upkeep per tower remain correct. Conversion during an in-flight arrow cannot damage later.

  ```gdscript
  director.money = 20
  var powered_count = director.cannons.size()
  check(director.upgrade_site(site_index) and director.money == 10, "conversion costs ten")
  check(not director.upgrade_site(site_index) and director.money == 10, "conversion cannot repeat")
  check(director.cannons.size() == powered_count, "conversion retains one upkeep entry")
  ```

- [ ] **Step 2:** Run ice/auto-build/control suites; expect new upgrade behavior tests to fail before purchase integration.
- [ ] **Step 3:** Implement exact-once eligibility/purchase and synchronize level, structure, and prompts. Filter `event.is_echo()` for F in game input while preserving legacy F behavior. Show `F: ICE UPGRADE · 10 gold · Slow only`, insufficient gold, and final level status. Display separate arrow/ice totals, shrine HP, and existing economy without crowding the reticle.
- [ ] **Step 4:** Run ice and state scripts plus `--auto-build-test` and `--fire-siege-controls-test`; require zero failures. Confirm actual InputEventKey handling, not only direct method calls.
- [ ] **Step 5:** Commit `Add explicit arrow-to-ice upgrades and defense HUD`.

### Task 7: Visual checks, full regressions, performance, and independent review

**Files:** Create ignored diagnostics `build/exploration-shrine-ice/foreground_battles.gd` and `foreground_traversal.gd`; modify production only to fix demonstrated regressions. Update new/affected tests alongside fixes.

**Interfaces:**
- Diagnostics produce JSON rows with hero/scenario, enemy health mode, alive counts, shrine attackers, tower mix, frame mean/p95, physics/process times, draw calls/nodes/effects, viewport/render size, quality, and unfocused-frame count.
- Reuse `build/crosshair-60/foreground_roster.gd` focus tracking and sampling interface; do not inherit its old far-away base relocation for live shrine cases. Diagnostic-only scene controls can neutralize shrine damage in durable tests, never shipped gameplay.

- [ ] **Step 1:** Import with `"$goemon_engine" --headless --path . --editor --import`; then run the three new standalone suites and existing state, structure, crowd_motion, projectile_query, spirit_fortress, neon_shrine, map_document and combat_vfx scripts. Also run `--map-builder-test`, `--fire-siege-mvp-test`, `--auto-build-test`, `--fire-siege-controls-test`, `--fire-siege-motion-test`, `--ranger-flight-test`, and `--ranger-storm-test` after `--`. Run crimson with `--script res://scripts/crimson_combat_runner.gd` and crosshair with `--script res://build/aim-lag/crosshair_runner.gd` (existing SceneTree wrapper). Record exit/status/count per suite; no crimson/crosshair game CLI hooks exist.
- [ ] **Step 2:** Run a rendered tour at Low/Medium/High. Inspect grove/village/watchpost paths and rewards, tower work areas, moved walls/shrine trim, ranged sightlines, slot/strike poses, mixed tower visuals, warnings, and the crosshair while Ranger aims in air. Add a regression for any gameplay bug found. Only use native CUA for UI; do not run foreground automation during timed FPS samples.
- [ ] **Step 3:** Export a staging release PCK with `--export-pack 'Fire Siege Crosshair macOS' build/exploration-shrine-ice/staging.pck`. Write the two diagnostic harnesses; assert validity rejects any unfocused sample, mismatched viewport/quality, or durable case ending below 300 living actors. Record cold and warmed passes separately.
- [ ] **Step 4:** Sequentially benchmark v2.49.1 and staging PCK with the matching official Godot 4.6.3 engine identity: Medium, 1280x800 window / 1138x712 render, VSync enabled, Engine.max_fps=0. Use seed 241, actual AI/HUD/VFX/attacks. Run Mage/Ranger primary/ultimate and Ranger air durable cases; then all twelve heroes with normal-health 300-actor starts and live shrine simulation. Exercise twelve built towers with six arrow/six ice, plus an all-ice stress case and preparation/active traversal through each district. Preserve practical actor counts in every report.
- [ ] **Step 5:** Compare matched warmed mean and p95. Investigate reproducible >5% mean or >2 ms p95 regression; fix the measured bottleneck and rerun only affected cases/checks. Retain VFX and weapon behavior. A locked Mac or no valid focused samples leaves performance verification incomplete; request unlock as needed rather than inventing results or altering permanent system settings. Use temporary caffeinate only during own benchmark runs.
- [ ] **Step 6:** Apply requesting-code-review skill and obtain one fresh reviewer after native execution, or the selected subagent workflow's final branch review. Review the diff against the spec plus evidence and focused risks. Fix actionable findings and rerun affected checks; do not use review as a replacement for rendered measurements.
- [ ] **Step 7:** Commit any demonstrated fixes with specific messages. Save final source results, visual evidence, model hash comparison and benchmark interpretation; do not commit ignored build output.

### Task 8: Export, packaged checks, and playable delivery

**Files:** Modify only crosshair preset version in `export_presets.cfg`; create `docs/fire-siege-mvp/exploration-v2500.md` and ignored packaging helper `build/exploration-shrine-ice/assemble_version.py`.

**Interfaces:**
- Version: 2.50.0, crosshair macOS preset only. App name remains `Goemon Fire Siege Crosshair.app`; preserve current crosshair bundle/save identity and custom_features `fire_siege,crosshair_aim`.
- Destination: `/Users/eric/Downloads/Goemon-Fire-Siege-v2.50.0-Exploration-Crosshair/`; archive `Goemon-Fire-Siege-v2.50.0-Exploration-Crosshair-macOS.zip`.
- Packaging helper accepts this explicit destination, reads verification evidence, and writes README-FIRST.txt, VERSION-NOTES.txt, PERFORMANCE.txt, verification/manifest.json and CHECKSUMS.txt. It must not import/run the v2.49.1 assembler, whose destination is hardcoded to the previous release.

- [ ] **Step 1:** Apply verification-before-completion skill, update crosshair version and release notes with new controls, shrine rules, caches, balance values and measured limits. Commit the final release source changes; record that source commit before export.
- [ ] **Step 2:** Run `"$goemon_engine" --headless --path . --export-release 'Fire Siege Crosshair macOS' build/exploration-shrine-ice/Goemon-Fire-Siege-v2.50.0.zip`; extract to the new destination using macOS ditto and preserve the application bundle. Require successful export; do not overwrite the older Downloads folders.
- [ ] **Step 3:** Run new suites and relevant affected regression suites against the exported PCK with `"$goemon_engine" --headless --main-pack "$goemon_pck" --script res://scripts/<suite>.gd` or the attached `-- <test-hook>` forms. Set goemon_pck to the new app's `Contents/Resources/Goemon Fire Siege Crosshair.pck`; use the absolute host path `/Users/eric/.codex/worktrees/fire-siege-spirit-effects/Sonic/build/aim-lag/crosshair_runner.gd` for the external crosshair wrapper because build/ is excluded from exports. Run rendered packaged smoke checks and launch the actual app to verify navigation, shrine attacks, F conversion, caches and Ranger air/crosshair behavior. If source or export changes after performance sampling, rerun affected packaged/performance cases and record matching PCK hash.
- [ ] **Step 4:** Verify `codesign --verify --deep --strict` succeeds and `lipo -archs` reports both arm64 and x86_64 for the app executable. Compare all sixteen protected character hashes to the prior manifest. Verify previous v2.49.1 ZIP SHA remains `ba027dc4692319505ed7cfa1e641fad482cdd6d3ecff94479a4feb79d6996375`.
- [ ] **Step 5:** Package app, notes and verification using ditto; validate ZIP CRC and SHA-256. Manifest must identify engine, source commit, PCK hash, architectures, source/package checks, matched performance cases and native launch status. Reject missing evidence rather than generating a success note.
- [ ] **Step 6:** Leave the new app available to try and provide clickable app/ZIP links with brief controls: explore between waves, hold Y to start, F converts arrow to ice. Report actual FPS range/limitations, known material issues, tests and source commit. No claim of constant 60 FPS or native-executable FPS unless that exact measurement was made.

## Self-review and execution handoff

Spec coverage: Task 1 covers coordinates/anchors/compatibility, Task 2 covers districts and preparation, Tasks 3–4 cover shrine lifecycle and accounting, Tasks 5–6 cover ice semantics and purchase, Task 7 covers visual/performance limits and review, Task 8 covers separate packaged delivery. Review Focus cases each have owning tests. Cross-task interfaces and exact balance values are defined above; custom maps keep their schema and source layouts.

Recommended execution: **Native**, implementing tasks in this session with one final independent reviewer. These tasks share the same world/director/enemy contracts and should proceed sequentially; per-task implementation/review agents would repeat the same context. The user must review this plan and select the execution method before implementation, as required by the writing-plans skill. Product code remains unchanged at this handoff.
