# Final combined Forest enemy review

Reviewed 14 October 2026. Scope: the authorized four-enemy integration, combined `final-diff.patch`, implementation plan and linked saved design, ledger, Task 1/2/3 reports, scoped reviews and final re-reviews, and current simulation/navigation/render/contact/game interfaces. Existing asset-script edits outside this integration were treated as baseline context. No implementation edits, commits or subagents. Only this review report was saved in the workspace.

## Spec/combat verdict: changes required

The combined implementation substantially satisfies the gameplay requirements: four primary target categories; stable Daruma tower/wall preference and temporary breach targets; 0.75 m/s, 3,000 HP, 120 damage, 1.5 s windup and 3.5 s recovery; fitted lower combat contact; ordinary damage and 90% knockback reduction; authoritative freeze pose shared by model, actor and renderer; traveling Archer arrows; and unchanged five-wave counts and startup setup. The previous yaw collision, frozen-contact, chain occlusion and legacy hurt-height findings have been addressed in the current code and approved scoped re-reviews.

One material cross-task presentation defect remains: the new fixed-facing turning retreat produces substantial grounded-foot sliding. This violates the saved design's explicit requirement that foot placement agree with movement and that a large model sliding on the ground does not satisfy the slow-walk requirement. It is a simulation/render integration seam that was not covered by either scoped test set.

The macOS export, signature and packaged startup checks remain outstanding root work; this review does not certify a delivered playable package.

## Quality verdict: request changes

Require the P2 below before approval. No P0/P1 finding was identified. Existing focused and regression evidence is relevant and broad; do not rerun the already-covered suites merely to repeat their results. A focused directional-gait regression and its affected pose/freeze/contact coverage are appropriate for the necessary correction.

## Material finding

### [P2] Compensate planted feet for the actual fixed-facing retreat direction

**Location:** `scripts/forest/forest_enemy_crowd.gd:123–133`, especially line 133; interacting with `scripts/forest/forest_waves.gd:197–211` and `scripts/forest/forest_enemy_navigation.gd:153–174`.

`retreat_tick` deliberately holds the last safe facing while translating along a validated escape path. Those paths can move sideways, diagonally or backward relative to the giant. It advances `walk_phase` by positive traveled distance. `part_pose`, however, reduces authoritative velocity to its magnitude, then always applies `walking_foot_offset` along local Z. That compensation cancels root translation only during local-forward walking. During retreat the nominal stance foot moves across the ground while staying at ground height; its fitted contact geometry slides with it because contact correctly shares the same pose helper.

This occurs in a valid normal director sequence, without forcing an overlapping pose or setting an artificial retreat path. New focused diagnostic `/tmp/sonic_final_retreat_pose_review.gd` recreates the existing Task 1 turning fixture: cleared model, tower at cell `(-1,12)`, Daruma root `(0,0,60)`, initial facing `0`, and normal `waves.tick(.1, Vector3.ZERO)`. The tighter variant adds the two southern towers from the accepted clearance regression. It compares world positions of the same foot while both samples are in its grounded stance phase and facing is unchanged; at fixed facing, measuring the part translation measures the displacement of every vertex of that rigid foot.

Observed output:

```text
RETREAT tight=false tick=22 facing=-0.927000
velocity=(0.0, 0.0, -0.750008)
local_velocity=(-0.599873, 0.0, -0.450182)
group=foot_l phase=0.157081->0.314162
planted_foot_delta=(-0.059987, 0.0, -0.029984)
slip_m=0.067063 root_m=0.075001
SUMMARY tight=false grounded_retreat_seconds=7.6 max_foot_slip_per_0.1s=0.067063
SUMMARY tight=true grounded_retreat_seconds=14.3 max_foot_slip_per_0.1s=0.142297
```

Thus the supposedly planted foot slides about **0.67 m/s** in the simple case and up to **1.42 m/s** in the tighter case. This is not only a minor turn-in-place discrepancy: the incorrect stance persists across seconds of deliberate retreat.

Derive the local stance/swing translation from actual authoritative movement direction, or otherwise provide directional retreat poses that cancel the real root displacement. Preserve the current safe facing, movement limit and route behavior. Keep renderer and fitted contact on the shared pose function and preserve the authoritative frozen snapshot. Add coverage for fixed-facing diagonal and backward movement, including actual director retreat, with a grounded world-foot displacement assertion. The existing forward-only stance assertion in `enemy_visual_test.gd:72–77` cannot detect this defect.

Diagnostic command: `/opt/homebrew/bin/godot --headless --path . --script /tmp/sonic_final_retreat_pose_review.gd`; exit 0, no script/resource errors. No existing covering suite was repeated.

## Combined integration assessment

- The root game swaps only Forest's crowd and adds the director-owned enemy-arrow presenter. The inherited crowd field loses its concrete old-crowd type so either renderer can be assigned; other modes still instantiate the existing renderer.
- The four original asset paths and exact exported scale remain explicit in role data. The renderer copies authored UVs, transforms normals and retains material textures/properties. Shared rigid part poses drive compound hurt shapes, including low feet and fists. The inspected native contact/frozen/Archer-flight screenshots show the massive model, painted face, low health display, selected wall contact and visible arrow flight.
- Root integration dispatches launch/impact events and uses authoritative arrow positions. Shared fog gates arrow meshes, impacts, actor visibility and inherited hit feedback; giant visibility admits a visible part of its broad footprint. Wave transitions clear projectile presenters and preparation clears actors/crowd. Retry creates/reset state with the testing treasury intact.
- Authored broad cardinal and diagonal lanes fit the conservative giant envelope. Near staging remains 80–100 m when available; farther validated staging preserves full-footprint fog and true slow speed. Its longer arrival under extensive vision is an acknowledged design tradeoff, not an unreported speed change. The finite wave counts remain 24/36/48/60/80 with one giant in waves 3–5.
- The actor/contact/renderer now consume the same authoritative `frozen_pose`; snapshot creation precedes clearing velocity and does not depend on a prior render. The shared capability checks retain ordinary actor fallbacks, including the corrected caller-specific chain/beam heights and beam endpoint guard. The recorded twelve-hero and other-mode regressions are appropriate evidence for this seam.
- Recorded evidence accepted, not independently rerun: roles 77; simulation 34; visual 160; native off-origin 17; contact 29 with twelve real hero inputs; focused review 14 headless/native; root integration 17 and native behavior; tower 15; projectile 9; modern combat 20; Rogue 64; equipment 63; Tower Defense; fog and original-crowd checks. Known fast-harness cleanup warnings and the preexisting Rogue Siege launch-fixture mismatch remain documented rather than relabeled as passes.

## Minor triage

1. **UV/normal tests — nonblocking P3.** The assertions check presence/length rather than representative source equality. Current copy/normal-transform code and reviewed native faces support the required preservation. Strengthen this when these tests are next extended; it is not evidence of current corrupted artwork.
2. **Fist reference 0.238 m from a source triangle — nonblocking test limitation.** The reference-point equality test alone does not prove exact visible triangle contact. The root actual-contact sequence adds the missing real selected-wall/damage-frame context, and the inspected frame visibly places the fist at the wall. It does not replace a geometric overlap assertion across all target orientations. Keep this as future coverage work and avoid describing the point-equality assertion as proof of mathematically exact triangle contact.
3. **Small image allocations and unused custom payload — defer.** Empty-species image allocation and unused custom-data XYZ add avoidable work, but no measured whole-game failure was identified. Existing isolated 200-actor measurements are explicitly limited and are adequate for the demonstrated workload.
4. **Duplicated arrow damage/building envelopes — defer.** Archer's hard-coded 20 damage agrees with the role stat today; building-height envelopes also agree. Centralizing them prevents future tuning drift. No current numerical mismatch.
5. **Dense state-transition formatting — defer.** Expand complex director/navigation branches during future edits for readability. This is not a gameplay finding.
6. **Contact approximations — accepted and documented.** Center-directed hull projection and conservative radius expansion are not exact closest-surface or swept-sphere corner solutions. They retain fitted source-scale contact and the tested empty foot gap; the reports now describe these limits accurately. No new material failure was found from those approximations.

The scoped Task 1 and Task 3 approvals stand for their reviewed corrections. The new P2 concerns their final combination with Task 2's forward-only stance and must be resolved before the combined change is approved.
