# Task 1 fix round 1 independent re-review

Reviewed the original Task 1 finding, appended final report, refreshed `task1-fix1-diff.patch`, binding implementation plan/design spec, and the current director/navigation/role tests. Scope is the fitted yaw-clearance fix and its retreat, speed and target contracts. No source or test edits, commits, or subagents. Covering tests were not rerun: the frozen report records roles **77 checks, 0 failures**, simulation **34 checks, 0 failures**, both exit 0 without errors, and a clean diff check. This supersedes the earlier 75-check handoff and includes the final corridor fallback/cache changes.

## Finding disposition: ADDRESSED

**[P2] Sweep fitted building clearance when changing giant facing** is addressed.

- `forest_enemy_navigation.gd:130–139` checks prospective yaw in increments at most 0.01 rad using the same fitted core/fist building geometry. `forest_waves.gd:128–140` retains the last clear facing when obstructed; all existing giant turn callers use this shared path.
- The response makes progress: direct retreat rays and connected searches preserve the blocked facing and validate each translation segment at 0.25 m intervals. The retreat destination reserves the full 14.75 m building-turn envelope. The final coarse search extends beyond the local 48 m neighborhood across the finite map; its edges receive the same segment validation. Cached successful and empty searches are invalidated by navigation revision, position or facing.
- `retreat_tick` consumes only the existing 0.75 m/s movement allowance and does not rotate. The normal tick grants one 0.45 rad/s yaw budget, and every turn consumes the actual accepted rotation from that budget. No teleport, accelerated retreat or second caller turn burst is introduced.
- Retreat keeps the committed primary target; on completion the director invalidates the approach path and resumes the ordinary turn/approach/windup/contact sequence. Navigation changes invalidate the escape path before it is followed.

The clear-pose regression retains the original tower at cell (-1,12), root (0,0,60), facing 0, and adds a tighter fixture with two southern towers obstructing straight retreat. Eight intermediate root/facing samples per tick check fitted clearance; the fixture also requires repositioning and actual tower damage within 650 normal 0.1 s ticks, enforces movement/yaw limits, and verifies the committed target. The additional long parallel-wall fixture requires a valid retreat destination farther than 48 m. The report records its failure with the local-only search and successful final verification with the coarse fallback. Together these cover clipping, permanent stall, rate limits and target continuity for the reported problem.

## Spec verdict: PASS

The scoped fix satisfies the reviewed fitted building clearance and eventual progress requirements in acceptance criteria 2 and 8, while retaining slow movement/turning and stable tower/wall preference. Deliberate attack animation/contact remains the separately reviewed shared combat/renderer contract.

## Quality verdict: APPROVE

No new material P0/P1/P2 breakage was identified in this fix scope. The earlier minor observations remain non-blocking; this re-review adds none. This is scoped Task 1 approval, not a replacement for the final combined integration/native/export review.
