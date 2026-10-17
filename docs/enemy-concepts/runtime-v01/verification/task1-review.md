# Task 1 independent review

Reviewed the plan, linked design spec, Task 1 report and saved diff, plus current roles, director, navigation, projectiles, role tests, and the actor/contact/crowd/game contracts. No production code or existing tests were changed. Existing covering suites were not rerun; their reported evidence (roles 65, simulation 34, worker/model/fog/regression suites) is accepted for this review. One new focused headless reproduction was run for the explicitly reported rotation concern.

## Spec verdict: changes required

Task 1 meets the reviewed role, numerical and state contracts, except for Daruma building clearance during turning. The primary categories are distinct; tower/wall selection uses approach routes and retains a valid committed target; separate route-obstacle strikes preserve that commitment. Stats do not scale with wave. Movement, full windup, selected live-target contact/cancel, recovery, freeze timers and finite wave composition are explicit. Archer arrows travel and physically intercept workers/obstacles. The full-footprint unseen staging checks include fitted side fists at spawn, validated shrine routes, and the authorized farther/corner fallback. The first normal staging remains approximately 80–100m; farther fallback's longer slow arrival is explicitly documented.

Frozen pose consumption was an acknowledged integration fix delegated separately. Current `part_pose` consumes `frozen_pose`, and actor freeze captures the pose before its impulse is cleared; I did not repeat that finding or independently certify the separate integration fix.

The remaining rotation gap violates the spec's fitted building clearance and acceptance criterion 2. It is concrete, rather than an untested theoretical limitation.

## Quality verdict: changes required

The director separates role data, navigation and projectile ownership coherently, preserves dictionary interfaces, and has useful behavioral coverage. Translation/impulse substeps and cached staging prevent the previously reported tunneling and staging failures. Require the P2 fix below before accepting Task 1. No P0/P1 finding was identified.

## Material finding

### [P2] Sweep fitted building clearance when changing giant facing

**Location:** `scripts/forest/forest_waves.gd:122–127`, especially the unconditional facing update at line 126. Callers at lines 211, 220, 227 and 233 all share this gap. `forest_enemy_navigation.gd:114–127` fits the rest fists, but it is called by translation sweeps, not the turn.

A giant can rotate its visible, collidable stone fist through a solid tower while its center stays still. The conservative 14m terrain envelope protects turns against trees/map edges, but building checks use the narrower body and orientation-dependent fists. Calling `turn` does not validate either the intermediate or resulting orientation. No swept locomotion occurs on the in-reach branch while the enemy is turning.

Focused reproduction: reset model, remove non-shrine buildings and trees/workers, create a tower at cell `(-1,12)`, rebuild navigation, start wave with automatic spawn clock disabled, spawn Daruma at `(0,0,60)` facing `0`, then call normal director `tick(.1, Vector3.ZERO)` repeatedly. Initially its fitted blocker is `-1`, and the tower surface is 9m away. At tick 20, facing `-0.945`, `fitted_blocker(e,e.pos)` returns the tower while `action == "walk"`, HP remains 500 and position remains unchanged. There are 41 overlapping sampled frames before windup begins at tick 65, facing `-2.97`. This is a valid initial clear pose and uses normal targeting/turning, without imposing an overlapping spawn.

Command: `/opt/homebrew/bin/godot --headless --path . --script /tmp/sonic_task1_turn_review.gd`; exit 0. Output:

```text
INITIAL blocker=-1 tower=10 distance=9.0
FIRST_OVERLAP tick=20 pos=(0.0, 0.0, 60.0) facing=-0.945 action=walk blocker=10 hp=500.0
START_WINDUP tick=65 facing=-2.97 pos=(0.0, 0.0, 60.0) hp=500.0
SUMMARY overlapping_frames=41 unchanged_position=true
```

Validate and sweep the fitted parts across yaw increments, then provide a valid reposition/approach or deliberate breach response if the required turn is blocked. Merely refusing the turn indefinitely would exchange clipping for a stuck giant and fail criterion 8. Add a focused turning fixture that starts in a clear pose and checks intermediate fitted geometry against neighboring structures, alongside eventual progress.

## Minor observations

- `forest_enemy_projectiles.gd:14` hardcodes arrow damage 20 while role damage also lives in `forest_enemy_roles.gd:8`. Use the role stat on launch to avoid a balancing edit silently leaving ranged damage unchanged. This does not currently produce a numerical mismatch.
- Building height envelopes are duplicated in navigation line-of-sight and fitted collision (`forest_enemy_navigation.gd:108,122`). A shared helper would prevent future collision/arrow divergence; current values agree.
- Much of the new code compresses multiple state transitions onto individual lines. Expanding complex attack/route branches would make future timing and cancellation review easier. No behavior change is required for this style observation.
