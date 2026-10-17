# Scoped final gait fix re-review

Reviewed 14 October 2026. Scope: the final P2 in `final-review.md`, `final-fix-report.md`, `final-fix-diff.patch`, the current production/test files, the saved before-final-fix sources, the recorded verification logs, and the two native retreat screenshots. No implementation edits, commits, subagents, or covering-suite reruns. Only this report was saved.

## Per-finding verdict

| Finding | Status | Spec verdict | Quality verdict |
| --- | --- | --- | --- |
| finalP2 — compensate planted feet for actual fixed-facing retreat direction | **ADDRESSED** | **Approved** | **Approved** |

No new material finding was identified in this fix. The scoped final correction is approved; this does not certify the macOS export, signing, or packaged startup, which remain root work.

## Why the finding is addressed

`ForestEnemyCrowd.advance_walk_feet` retains a full world transform per foot during stance. It converts that anchor back through the current root inverse for the shared part pose, so root translation, sideways/backward travel, and a waypoint direction change do not move a planted vertex. An ongoing swing retains its original destination through a bend. The gait state persists after retreat, preserving the handoff into later walking, and a stopped swing settles vertically without rewriting its horizontal anchor.

`ForestWaves.tick_enemy` captures the prior physical foot pose before the existing tick clears velocity, applies the wrapper only to Daruma, and starts tracking when a retreat is requested. Existing tracked feet remain tracked after the escape route ends. It skips gait advancement for a fully frozen interval and supplies only the unfrozen portion when thaw occurs inside a tick. I compared the saved pre-fix `tick_enemy` body against the current `_tick_enemy` body: they are byte-identical after the function rename. The wrapper and helper write gait metadata only; movement, route validation, facing/turn limits, targets, HP, damage, attack timing, and dimensions have no behavioral edits. Navigation continues to use the existing core footprint and rest-fist envelopes, rather than this new foot metadata.

The renderer uploads `part_pose` translations and basis columns; actor fitted CollisionShape3D transforms and contact queries delegate to that same helper. Model-owned tower arrows obtain `Roles.hurt_point`, which delegates to fitted contact. All therefore consume the authoritative local foot transform. Freeze resolves the retained `frozen_pose` before looking up `walk_feet`. Each gait update deep-copies the state dictionary and replaces both state and local-pose dictionaries, rather than mutating the dictionaries held by shallow frozen snapshots. Retained transforms are value data. No new snapshot aliasing or render/contact handoff defect was found.

## Witnessed evidence

I read the complete saved logs, rather than relying solely on the fix report or repeating covered tests:

- `/tmp/sonic_retreat_gait_red.log`: the original 22-check regression reports exactly three expected failures, with normal/tight maximum stance slip 0.06706353/0.14229670 m and grounded bend slip 0.14186837 m.
- `/tmp/sonic_retreat_gait_green.log` and `/tmp/sonic_final_gait_native.log`: both report 31 checks, zero failures. Normal retreat has 75 grounded samples and 80 diagonal samples, maximum slip 0.00000492 m. Tight retreat has 139 grounded samples, 87 backward samples, 147 diagonal samples, one grounded bend, maximum slip 0.00000833 m and bend slip 0.00000450 m. Ordinary forward gait has 85 stance samples, maximum slip 0.00000763 m. Maximum speed remains 0.750012 m/s and yaw step 0.045 rad per 0.1 s.
- The regression uses the real director fixtures and asserts both a foot origin and a source-space vertex during fixed-facing grounded stance. It also exercises bend freeze before presentation, thaw without grounded displacement, retained snapshot immutability, live/frozen physical collider alignment, uploaded render translation/orientation, and model-owned arrow surface agreement.
- `/tmp/sonic_final_gait_visual.log`: 160 checks, zero failures; `/tmp/sonic_final_gait_roles.log`: 77 checks, zero failures; `/tmp/sonic_final_gait_contact.log`: 14 checks, zero failures.
- `/tmp/sonic_final_gait_review_reproducer.log`: the original review diagnostic now reports normal/tight maximum grounded slip of 0.000005/0.000008 m per 0.1 s over 7.6/14.3 seconds.
- These successful logs contain no script/resource/shader errors or cleanup warnings. Exit-zero command results are documented in the fix report; I did not independently rerun them.

I inspected `final-retreat-live.png` and `final-retreat-freeze.png`: the painted giant, rigid feet/fists, and foot placements persist across the freeze image, with the expected frozen tint. Static images support presentation preservation; the recorded motion assertions establish stance continuity.

The existing visual-test fixture repair is accepted. Its former expectation depended on renderer-owned cached freeze data, whereas the production contract uses an authoritative snapshot. The repaired fixture constructs that snapshot before clearing velocity and retains all 160 checks. `/tmp/sonic_final_gait_visual_baseline.log` reproduces precisely the one old freeze assertion failure using the documented unchanged pre-fix renderer. This is evidence of a stale fixture, not a new production failure caused by this fix.

## Final scoped assessment

Spec/combat: **approved for the final gait correction**. Quality: **approved for the final gait correction**. Final P2: **ADDRESSED**. No additional fix wave is requested by this re-review. Prior minor triage remains outside this correction; export, signing, packaged startup, and overall delivery approval remain root responsibilities.
