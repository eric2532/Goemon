# Final Daruma retreat gait fix

Completed 14 October 2026, uncommitted. Scope: final combined review's P2 grounded-foot sliding during fixed-facing Daruma retreat. No commits, subagents, approval pauses, source asset edits, or unrelated implementation changes.

## Change and root cause

The renderer's positive-distance phase and local-Z stance offset assumed forward movement. The authoritative turning retreat deliberately preserves a safe facing while moving diagonally or backward; at a waypoint, its movement direction can also change during the same stance. Replacing Z with instantaneous velocity alone would introduce a new foot jump at that bend.

The director now retains per-foot world stance anchors and swing state once retreat begins. A planted foot keeps its entire world transform, including orientation, until its swing starts. Swing interpolates toward a landing chosen from authoritative displacement and stride; changing an escape waypoint does not rewrite the planted anchor or an ongoing swing's destination. The initial anchors come from the physical pose before the director clears velocity. The state persists into subsequent walking, preserving the handoff instead of snapping back to a forward-only pose. A stopped swing settles vertically while its horizontal location stays fixed.

`ForestEnemyCrowd.part_pose` consumes these authoritative local foot transforms. The existing renderer texture upload, fitted actor CollisionShape3D transforms, actor combat queries, and model-owned tower-arrow contact all already call that same helper. Freeze snapshots include the pose metadata before velocity is cleared. Gait updates replace their dictionaries, preserving snapshot immutability when movement resumes.

The existing simulation body was moved under `_tick_enemy` without behavior edits; `tick_enemy` adds the pose metadata wrapper. Movement, retreat routing, safe facing, 0.75 m/s speed, 0.45 rad/s turn rate, target choice, fitted obstacle checks, damage, and dimensions remain unchanged. Ordinary forward walking without retreat retains the existing gait helper.

## RED → GREEN evidence

New regression: `tests/forest-shrine/enemy_retreat_gait_test.gd`. It uses real director normal and tight turning fixtures: tower cell `(-1,12)`, root `(0,0,60)`, initial facing zero, and `waves.tick(.1, Vector3.ZERO)`; the tight fixture adds towers at `(-5,7)` and `(2,7)`. It measures the same grounded foot's world transform origin and a source-space vertex, rather than only local Z. It explicitly observes diagonal movement, backward movement, and a real waypoint bend during a continuous stance.

Before production changes, the new 22-check regression exited 1 with exactly three expected gait failures:

- Normal maximum stance slip: **0.06706353 m per 0.1 s**.
- Tight maximum stance slip: **0.14229670 m per 0.1 s**.
- Tight grounded waypoint bend slip: **0.14186837 m**.

After the fix, the expanded 31-check regression exits 0 in both headless and native Metal runs:

| Fixture | Grounded samples | Backward samples | Diagonal samples | Grounded bends | Maximum stance slip | Bend slip |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary forward | 85 | — | — | — | 0.00000763 m | — |
| Normal retreat | 75 | 0 | 80 | 0 | 0.00000492 m | — |
| Tight retreat | 139 | 87 | 147 | 1 | 0.00000833 m | 0.00000450 m |

Maximum observed speed remains 0.750012 m/s within floating-point tolerance; maximum yaw step is 0.045 rad per 0.1 s. Both retreats retain fitted clearance and visible alternating lift. Added checks freeze during the real retreat bend before presentation, thaw without a grounded-foot jump, retain the original snapshot after resumed gait updates, and compare live/frozen physical collider transforms with rendered part transforms. The actual game actor, pose texture translation/orientation, and a model-owned arrow agree on the frozen retreat foot surface.

## Exact verification commands and results

All commands ran from `/Users/eric/Desktop/Projects_Codex/Sonic` with Godot 4.6.1. Final successful logs contain no script/resource/shader errors or cleanup warnings.

```sh
/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_retreat_gait_test.gd
# FOREST_ENEMY_RETREAT_GAIT_RESULT checks=31 failures=0; exit 0

/opt/homebrew/bin/godot --path . --script tests/forest-shrine/enemy_retreat_gait_test.gd
# Native Metal Forward+, Apple M3; checks=31 failures=0; exit 0

/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_visual_test.gd
# FOREST_ENEMY_VISUAL_RESULT checks=160 failures=0; exit 0

/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_roles_test.gd
# FOREST_ENEMY_ROLES_RESULT checks=77 failures=0; exit 0

/opt/homebrew/bin/godot --headless --path . --script tests/forest-shrine/enemy_contact_review_test.gd
# FOREST_ENEMY_CONTACT_REVIEW_RESULT checks=14 failures=0; exit 0

/opt/homebrew/bin/godot --headless --path . --script /tmp/sonic_final_retreat_pose_review.gd
# Original final-review reproducer; exit 0.
# Normal: 7.6 s grounded retreat, max slip 0.000005 m/0.1 s.
# Tight: 14.3 s grounded retreat, max slip 0.000008 m/0.1 s.

git diff --check -- scripts/forest/forest_waves.gd tests/forest-shrine/enemy_visual_test.gd
# exit 0
```

Logs: `/tmp/sonic_retreat_gait_red.log`, `/tmp/sonic_retreat_gait_green.log`, `/tmp/sonic_final_gait_native.log`, `/tmp/sonic_final_gait_visual.log`, `/tmp/sonic_final_gait_roles.log`, `/tmp/sonic_final_gait_contact.log`, `/tmp/sonic_final_gait_review_reproducer.log`.

One stale existing visual fixture was repaired explicitly. It changed phase while paused, set freeze without `frozen_pose`, and expected the renderer to restore an old cached phase/velocity. The current authoritative renderer contract takes the director/actor snapshot. The fixture now creates that snapshot before clearing velocity and compares its retained fields. All 160 checks remain. The unchanged pre-fix renderer was copied into `/tmp/sonic_final_visual_baseline_renderer.gd` and the original fixture into `/tmp/sonic_final_visual_baseline.gd`; running `/opt/homebrew/bin/godot --headless --path . --script /tmp/sonic_final_visual_baseline.gd` reproduced the same one stale freeze failure, exit 1. Its log is `/tmp/sonic_final_gait_visual_baseline.log`; no production files were reverted to obtain that evidence.

## Changed paths and visual evidence

- `scripts/forest/forest_enemy_crowd.gd`: authoritative stance/swing helper and shared pose consumption.
- `scripts/forest/forest_waves.gd`: gait metadata wrapper around the existing enemy tick.
- `tests/forest-shrine/enemy_retreat_gait_test.gd`: focused real-director gait, bend, freeze/thaw, physical collider, rendered texture and arrow-contact regression, also runnable natively.
- `tests/forest-shrine/enemy_visual_test.gd`: authoritative freeze snapshot fixture correction.
- `.superpowers/sdd/2026-10-14-forest-enemy-integration/final-fix-report.md`: this report.
- `.superpowers/sdd/2026-10-14-forest-enemy-integration/final-retreat-live.png`.
- `.superpowers/sdd/2026-10-14-forest-enemy-integration/final-retreat-freeze.png`.

Both native screenshots were visually inspected. The actual game preserves the painted face, massive model, rigid feet/fists and the same feet positions across freeze; the frozen frame adds the expected tint. These are static visual/contact evidence; quantitative stance-motion assertions above establish movement continuity. Root remains responsible for final combined approval, export, signature and packaged startup verification.
