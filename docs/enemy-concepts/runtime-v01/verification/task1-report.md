# Task 1 — roles, navigation and attacks

Implemented in the existing authorized feature checkout, without commits. Existing uncommitted work was preserved.

## Files

- `scripts/forest/forest_waves.gd`: four role targets, deterministic `spawn_enemy`, finite wave composition, cached giant staging, actual swept locomotion, slow turns, readable windup/contact/recovery, live target validation, frozen pose snapshot, and director-owned traveling projectiles.
- `scripts/forest/forest_enemy_roles.gd`: required role stats/asset paths/heights/core footprint/visible contact APIs, shared stride and turn speeds, extra `visibility_radius`. Contact agent replaced the initial provisional hurt point with the shared fitted GLB contact helper.
- `scripts/forest/forest_enemy_navigation.gd`: core building clearance, 14m conservative fist/tree/edge clearance, inflated giant route grid, route-cost approach selection, fitted exported side-fist building sweeps, complete-footprint unseen staging and obstruction checks.
- `scripts/forest/forest_enemy_projectiles.gd`: 36m/s traveling arrows, worker/deck contact, tree/building interception, launch/impact events.
- `tests/forest-shrine/enemy_roles_test.gd`: 65 behavioral checks.
- `tests/forest-shrine/simulation_test.gd`: only the superseded shared-priority breach fixture was changed to use a deterministic Lantern instead of a hero-pursuing Raider. The file already contained unrelated uncommitted changes.

The root agent authored broad cardinal and diagonal approaches in `forest_model.gd`; that model file was not edited by this task.

## Interfaces and decisions

Variants: 0 Raider, 1 Archer, 2 Daruma, 3 Lantern. Stats are independent of wave number. Daruma is 3000HP,0.75m/s,120 damage,1.5s windup,3.5s recovery; normal values and stride match the saved plan.

Legacy enemy dictionary fields remain. Added required action, action_left, target_kind/id, facing, walk_phase, attack_progress and attack_point. The primary target stays unchanged while temporary `strike_kind/id` and `route_obstacle` allow fortification breaches. `walk_phase` advances TAU*actual locomotion distance/stride and stops while frozen or stationary. Freeze stores a shallow immutable `frozen_pose` snapshot before zeroing velocity; the snapshot excludes a recursive frozen_pose and is removed when freeze expires.

`footprint_radius(2)` is the17m body's8.5m core; `visibility_radius(2)` is14m. Tree/edge navigation conservatively reserves14m for the separately fitted fists. Building sweeps use core plus exact GLB-derived rest-pose fist bounds and building heights, rather than a uniform14m building radius that would prevent forward attacks. Side contact outside forward strike range turns and closes the short approach before windup. Only live selected targets can receive contact damage.

Giant staging prefers80–100m. Cached validated cardinal candidates extend to222m; diagonal corner candidates extend to(±222,±222) when permanent tower vision covers cardinal entries. Every candidate validates complete fitted building placement and a reachable objective route; unseen checks conservatively include the14m footprint and intersecting fog-cell extent. If no giant candidate is currently available, ordinary units continue arriving with the last finite slot reserved for the giant. One giant appears in each wave3–5, none in1–2; counts remain24/36/48/60/80.

Director arrows contain id/from/to/pos/direction/left/target_kind/target_id/damage. Launch emits `enemy_arrow{id,from,to}`; physical contact/expiration emits `enemy_arrow_impact{id,point}`. Worker arrows do not apply immediate worker damage; exposed garrison crews participate, and trees/other structures block flight. The target crew's own sparse timber tower is excluded from the conservative whole-building obstruction envelope.

## Red → green evidence

Initial focused suite failed cleanly on the missing deterministic spawn interface. Subsequent dedicated failures exposed permanently visible short staging rings, missing corner staging under full cardinal vision, side fists walking through trees, side fists passing beside walls, fitted spawn overlap beside towers, and loss of the frozen locomotion pose. Each was implemented and rerun successfully. A side-breach fixture originally expected an attack where the validated route correctly avoided the wall; it was corrected to represent an actual off-grid impulse stop beside the wall. A guessed fist-front extent was replaced with the inspected exported GLB extent in its assertion.

Final command:

`/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd`

Result: `FOREST_ENEMY_ROLES_RESULT checks=65 failures=0`, exit0. Final production-map staging measurement: first search80.36ms;20 cached searches59.60ms total. This is bounded to a fixed candidate list, with navigation inflation and candidate routes cached by navigation revision. Before inflation refactoring, the smaller original candidate set took148.69ms initially; obstacle-centric grid inflation reduced it substantially before the corner fallback was added.

Regression commands used `/opt/homebrew/bin/godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/<name>.gd`:

| Suite | Result |
| --- | --- |
| simulation_test |34 checks,0 failures; latest rerun after frozen_pose patch exits0|
| automatic_workers_test |40 checks,0 failures,exit0|
| model_test |20 checks,0 failures,exit0|
| testing_start_test |13 checks,0 failures,exit0|
| settlement_update_test |17 checks,0 failures,exit0|
| rogue_test |64 checks,0 failures,exit0|
| fog_target_test |0 failures,exit0|
| review_regression_test |15 checks,0 failures,exit0|

The final Rogue rerun printed ObjectDB leak and13 resources still in use at exit. Fog targeting printed an ObjectDB leak warning. Review regression printed an ObjectDB warning and1 resource still in use. These accelerated harness teardown warnings are reported rather than counted as pristine output; earlier Rogue run exited without warnings. Root's combined validation/render/export workflow remains responsible for the full application suites and teardown inspection.

`git diff --check` over owned files returned no errors.

## Remaining integration considerations

- Shared frozen_pose must be consumed by actor/contact/render adapters; root and contact agent were notified and are integrating that reviewed P2 fix.
- The fallback preserves actual0.75m/s walking; extensively expanded tower vision can therefore force a longer approach. No teleport/catch-up speed is added.
- Impossible user-authored terrain fixtures with every giant route blocked cannot admit an unseen reachable giant. Ordinary arrivals continue; production broad approaches and far corner options are tested to prevent that condition for the authored map and friendly tower reach.
- Locomotion sweeps fit static exported fist bounds. Animated attack contact is owned by the shared contact/renderer pose; slow yaw rotation itself does not perform a continuous fist sweep against neighboring structures. Combined review should judge tightly packed building-turn cases if further coverage is needed.

## Task1 review fix round1 — fitted yaw clearance

Material finding: `turn()` changed Daruma's facing without sweeping its fists. The reviewer reproduced41 pre-windup overlap frames beside a tower at cell(-1,12), root(0,0,60), initial facing0.

Added the same clear-initial-pose regression before the fix. Its first run failed4 checks: fitted overlap and missing repositioning for both the plain and adjacent-structure fixture. No frozen-pose/contact/root/model files were edited during this fix.

`forest_enemy_navigation.gd` now sweeps prospective yaw in increments no larger than0.01rad, testing the exported fitted fists plus core at each intermediate orientation. A blocked yaw keeps the last valid facing. The director holds that facing while retreating at the existing0.75m/s to a position whose14.75m envelope clears all buildings for the full fist yaw. Fast direct retreat rays are validated by0.25m translation sweeps; a bounded connected search at the same facing handles retreats that need a bend. The primary target remains committed. A per-tick rotation budget prevents multiple turn callers from exceeding0.45rad/s.

The regression samples8 additional intermediate root/facing poses in each normal0.1s director tick, checks zero pre-windup fitted overlap, checks the numerical speed/yaw limits, requires actual repositioning and eventual completed damage, and verifies retained tower priority. The tighter fixture adds two southern towers that obstruct the simple straight retreat.

Final covering commands:

- `/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd`: `FOREST_ENEMY_ROLES_RESULT checks=75 failures=0`, exit0; no script/resource errors. Initial production staging83.31ms,20 cached searches60.49ms total.
- `/opt/homebrew/bin/godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/simulation_test.gd`: `FOREST_SIMULATION_RESULT checks=34 failures=0`, exit0; no script/resource errors.
- `git diff --check` on director/navigation/role test: exit0, no output.

This supersedes the earlier report limitation about unswept slow yaw. Attack animation's deliberate selected-building contact remains owned by the shared combat/renderer pose. The turning recovery first tries36m rays and a48m connected neighborhood, then a coarse fixed-facing search across the finite map if a valid corridor needs more distant clearance. Both successful and empty search results are cached by navigation revision, root position and facing, so a static blocked pose cannot repeat a map search every tick.

A further long-corridor regression failed with the48m-only search, then passed with the whole-map fallback. It starts with a valid fixed-facing pose between long parallel wall columns and requires an actual valid retreat destination farther than48m. Final reruns after caching: roles77 checks,0 failures (exit0, no errors; first staging93.11ms,20 cached searches62.82ms total), simulation34 checks,0 failures (exit0, no errors), and diff check clean. The owned director/navigation/test files are frozen for final re-review.
