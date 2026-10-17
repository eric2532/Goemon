# Task 3 correction round 1 independent re-review

Reviewed the implementation plan, linked specification, all three P2 findings in `task3-review.md`, appended correction evidence in `task3-report.md`, `task3-fix1-diff.patch`, and relevant current actor/render/contact/model and legacy caller code. Scope is this correction diff and the simulation-owned authoritative frozen snapshot contract in `forest_waves.gd`. The concurrent swept-turning correction is outside this review. No gameplay edits, commits, or subagents.

## Per-finding verdicts

1. **Frozen tower contact: ADDRESSED.** `forest_waves.gd:182-191` captures `frozen_pose` before resetting velocity and removes it on expiry. `forest_raider.gd:93-102` also captures authoritative state before native freeze resets actor velocity, retaining the existing snapshot on repeated freeze. Nested snapshots are removed. Actor synchronization copies the authoritative dictionary every update (`forest_raider.gd:31`); renderer caching does likewise while frozen (`forest_enemy_crowd.gd:191-194`). Both contact and render `part_pose` resolve the same snapshot (`forest_enemy_contact.gd:67`, `forest_enemy_crowd.gd:117`). Model tower selection/impact still calls role `hurt_point`, which forwards to this contact helper. Consequently live zero velocity no longer lowers the model-query foot while the actor/render retain a raised foot. Capture occurs independently of presentation, covering freeze before the first actor/render update. Root position and facing remain authoritative live values.

2. **Chain obstruction check: ADDRESSED.** `chain_pipe_combat.gd:80-85` obtains the fitted hurt point or legacy center, then projects that point onto the actual attack segment and casts between those geometrically distinct locations. The ray spans the gap for an off-axis victim; it is no longer unconditionally `clear_hit(point, point)`. Legacy actors use precisely the previous root-based center and projection. A segment intersecting the hurt volume can naturally have coincident endpoints, because there is no intervening gap to test. The recorded real thin-wall blocked/unblocked regression confirms the relevant off-axis legacy case.

3. **Legacy hurt heights and Edo beam boundaries: ADDRESSED.** `AttackChain.segment_contact` accepts an optional legacy center, used only for actors without fitted contact capability. Chain and Edo beam supply root + 1.5 m for bosses and root + 1.1 m otherwise. Other existing helper callers retain their former default aim-point behavior. `fire_beam.gd:71-74` restores the original center projection guard (`along < 0` or `along > length_now`) for legacy actors before radius contact, preserving both original segment boundaries instead of accepting endpoint-adjacent centers through radius expansion. Current code matches the original caller logic captured in `task3-diff.patch`.

## Scoped spec compliance: PASS

The corrections satisfy the binding shared frozen geometry and other-mode compatibility requirements. They keep capability-gated fitted Forest contact, original asset dimensions, and authoritative model ownership. No unrelated hero behavior change was identified in this correction diff.

## Scoped quality verdict: APPROVE

No new material breakage found in the correction diff. All three prior P2 findings are addressed. The previously noted sampled-hull, center-directed contact, and conservative plane-expansion approximations remain nonblocking limitations; the appended report now describes them accurately.

## Verification evidence accepted

Read the focused review harness and inspected the recorded final logs: headless review **14/0**, native review **14/0**, headless and native contact **29/0**, projectile **9/0**, tower regression **15/0**. The native focused and full contact logs show clean teardown with no script/render/cleanup errors. Headless review/contact/tower logs retain reported resource cleanup warnings. The initial native fast-shutdown crash was followed by use of the established `quit_clean()` path and a clean native run; the current harness includes that correction.

These are accepted same-code regression results. No suite was rerun because code inspection revealed no concrete concern requiring a new diagnostic. This approval covers Task 3 correction round 1 only, not combined integration, simulation turning, or export acceptance.
