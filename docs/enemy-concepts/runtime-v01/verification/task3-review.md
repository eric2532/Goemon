# Task 3 independent review

Reviewed the implementation plan, linked full specification, Task 3 report, Task 3 patch, and relevant current actor/contact/combat/tower/render/simulation code. Preexisting changes in the three asset scripts were treated as context; findings below concern the new fitted-contact integration. No implementation edits or commits were made.

## Spec compliance verdict: changes required

The main implementation satisfies the intended structure: original-scale exported compound Daruma body/feet/fists; capability-gated Forest queries; low health display; model-owned 3,000 HP; direct hits inheriting pending authoritative HP; tower synchronization avoiding combo damage; 90% ordinary impulse resistance; routine actor flinch suppressed; model freeze/attack timers and actor pause respected. The existing real-input twelve-hero coverage and fitted hit/miss cases are relevant evidence.

However, frozen tower contact does not consume the same retained pose as the rendered/physical actor, and some ordinary actors no longer retain their former segment-query fallback. These violate binding Task 3 requirements. The obsolete Rogue Siege menu-fixture failures described in the report are not attributed to this patch.

## Quality verdict: request changes

Three material findings:

1. **[P2] Model-owned tower arrows target unfrozen geometry while a walking enemy is frozen.** `scripts/forest/forest_enemy_contact.gd:66-80` derives motion directly from the supplied live enemy dictionary; `scripts/forest/forest_workforce.gd:274-279` supplies that dictionary for arrow impact. `scripts/forest/forest_waves.gd:178-183` resets live velocity before returning during freeze, while actor `scripts/forest/forest_raider.gd:31` and renderer `scripts/forest/forest_enemy_crowd.gd:189-195` retain the pre-freeze pose. Because `part_pose` derives motion from velocity, these callers use different geometry despite sharing the function. A new focused diagnostic with Daruma walking phase 1.3π showed the rendered left-foot translation `(0, 0.566312, 0.426)` versus the arrow-query translation `(0, 0, 0)`. Its model contact `(-4.636579, 1.141263, -3.15484)` lies outside the frozen rendered hull; the frozen contact is `(-4.635666, 1.464234, -2.725832)`. Arrows can therefore damage and display impacts in empty space beside a frozen foot. Persist an authoritative retained pose that actor, renderer, and role `hurt_point` all consume while frozen (including an enemy frozen before its first presentation update).

2. **[P2] Chain-pipe segment contact loses its obstruction check.** `scripts/chain_pipe_combat.gd:80-84` assigns `point = contact.point`, then `nearest = point`, and calls `clear_hit(nearest, point)`. The obstruction ray now has identical endpoints for every victim. Previously it ran from the point nearest the attack segment to the enemy's hurt center. A chain segment within the attack radius of a victim across a thin wall can now damage it; ordinary Ninja fallbacks are affected too. Preserve a nonzero, meaningful terrain check for the contact path and keep the legacy fallback ray behavior.

3. **[P2] Shared segment fallback changes other-mode hurt heights.** `scripts/attack_chain.gd:78` uses the general `aim_point` fallback for the new segment helper, and both `scripts/chain_pipe_combat.gd:80` and `assets/vfx/fire_beam/fire_beam.gd:70` now consume it. Their previous centers were root + 1.5m for bosses and root + 1.1m for every other ordinary actor. General `aim_point` instead uses 1.65m for bosses, 1.76m for island elites, and 5m for ground giants. This changes airborne and low projectile/melee hit acceptance in non-Forest modes. For example, an old ground giant with radius 3.1m hit by a thin ground-level segment at y=1.1m previously has zero center separation, but now has 3.9m separation and can miss. Keep caller-specific old centers when `combat_segment_contact` is absent, or let the helper take an explicit legacy center.

## Minor observations

- `forest_enemy_contact.gd:79-80` projects toward each hull center rather than calculating the closest hull surface. It returns a fitted point but can overestimate melee/area reach near oblique rounded surfaces. This is an approximation, not a blocking finding by itself.
- `forest_enemy_contact.gd:103-115` offsets hull planes by projectile radius. This is a conservative convex-volume expansion, not exact swept-sphere distance at polyhedron edges/corners. The rounded sampled hull limits practical error, but documentation should avoid claiming mathematical exactness.
- The existing contact harness exercises freeze timers at a stationary windup pose; it does not cover freezing moving feet and then resolving model-owned tower contact. The new diagnostic explains why the current green results do not detect finding 1.

## Verification reviewed

The report records headless/native contact 29, modern 20, Rogue 64, tower regression 15, projectile 9, equipment 63, and full Tower Defense passing. Read final headless/native contact logs confirms 29 checks, zero failures; the native log has no script/render/cleanup errors. Existing suites were not rerun.

Only a new focused diagnostic was executed: `godot --headless --path . --script /tmp/task3-frozen-contact-review.gd -- --test` (exit 0). It directly compared frozen render pose and current model-query pose using the production contact helper and renderer contract, and confirmed model contacts outside the frozen hull. Findings 2–3 follow directly from the changed call sites and their captured baseline in the Task 3 patch.
