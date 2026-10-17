# SDD ledger — plan: docs/superpowers/plans/2026-10-14-forest-enemy-integration.md

Implementation authorized by Eric: “ok implement these new enemies into the game”.
Existing branch feat/original-enemies-town-cap; scoped source baseline captured in baseline/.

| Tasks | Interface or self consistency | Result |
| --- | --- | --- |
| 1 | roles, timing, giant clearance and tests | Matches spec; prototype other-role numbers specified |
| 2 | models, batched rendering, rigid part animation | Exact exported scale; one shared mesh per material |
| 3 | actor, shared contact adapters, tower arrows | Capability checks preserve other modes |
| 4 | integration, fog, exports | Preserves startup setup and five waves |
| 1 / 2 | roles methods, action/facing/walk fields | Exact field names shared |
| 1 / 3 | actor authoritative state and role hurt_point | Simulation-owned damage, fitted lower contact |
| 2 / 4 | game/crowd/batches/clear | Existing diagnostics retained |
| 3 / 4 | actors and visibility | Root owns forest_game; agent owns actor |

Decisions: Use existing feature checkout to preserve approved uncommitted assets and unrelated work. No commits during this pass; baseline snapshots provide scoped diffs for review. User has authorized implementation, so execution continues without another design-approval step. Other-role stats and fallback rules are provisional balancing defaults and will be documented with the delivered build.

Tasks 1–3 in progress, non-overlapping ownership. Task 4 waits on contracts while root prepares integration.

Integration decisions: Widen cardinal approaches to30m and diagonal approaches to~34m for the14m conservative fist envelope. Near staging remains80–100m; when covered by vision use farther validated approaches/corners without speeding up or teleporting. Cost: exceptional fully watched settlements can have a longer giant arrival. Root changed inherited crowd property to support the dedicated Forest renderer; other modes still instantiate EnemyCrowd. Native tour and integration16checks passed clean after fixing the tour audio-mute setup.

Task 2: complete (uncommitted scoped snapshot; spec PASS, quality approved with minor nits). Deferred minor notes: test UV/normal presence rather than source-equality; contact reference0.238m from triangles lacks explicit target-overlap test; small empty-image allocations and unused instance payload. Final review will triage.
Task 3: fix round1/5 in progress: frozen model-arrow pose mismatch, chain-pipe zero-length occlusion, legacy shared hurt-height fallback. Implementer resumed; model snapshot coordinated with Task1.
Root: native atmosphere fog validation clean; existing integration clean; original other-mode renderer clean. Rootintegration17 checks clean. New exportversion2.55.0.

Task 3: complete (uncommitted scoped snapshot; fix round1 addressed all3 P2, independent re-review spec PASS/quality APPROVE). New targeted review14checks headless/native, contact29, projectile9,tower15 green.
Task 1: fix round1/5 in progress for swept yaw/fitted fist tower contact; reviewer reproduced41 overlapframes before windup.
Root actual behavior tour uses production build() after initial fixture bypassed revision; rerun required for clean render validation.

Task 1: complete (fix1 addressed swept yaw, distant connected retreat and caching; independent spec PASS/quality APPROVE).
Final review: one P2 gait seam fixed in single final fix wave, independent final-rereview spec/quality APPROVE. Grounded backward/diagonal/bend feet share world anchors with collisions/arrows/freeze. Deferred minor observations nonblocking per final review.
Fresh root checks: roles77, gait31, integration17, contactreview14 all clean/exit0. macOS2.55.0 export completed exit0; packaged signature/startup verification pending.
