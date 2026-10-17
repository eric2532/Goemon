# Task 2 independent review

Reviewed 14 October 2026. Scope: Task 2 renderer, shader, visual tests and standalone tour; relevant role/timing/contact/actor contracts were read for integration compatibility. No implementation edits, commits or test-suite reruns.

## Spec compliance verdict: PASS

The implementation uses the four approved GLBs through `ForestEnemyRoles.PATHS`, retains their exported heights (4.62 / 4.455 / 23.10 / 5.115 m), transforms source normals correctly, copies source UVs, and carries source texture/color/roughness/metallic/emission properties into shared animated materials. Direct GLB inspection confirms these assets have POSITION/NORMAL/TEXCOORD_0 only, no discarded vertex-color or tangent data, and double-sided materials consistent with the shader. The original other-mode crowd and shader have no scoped diff.

Four shared mesh/MultiMesh batches replace imported per-actor scenes. Rigid groups and the seven affine transforms per instance are shared with fitted combat. The straight-line stance displacement cancels root travel with Task 1's phase advance and 3 m stride; sampled native walk frames show alternating lifted feet and restrained body rocking. The right-fist transform reaches the authoritative strike location at progress 1 and recovery -1, which matches the director's 1.5 s windup completion transition. Archer motion stays local to its own bow. Freeze caches the prior motion/attack pose (also while hidden), pause prevents updates, fog removes shared instances, and death/clear prune presentation state.

Per-species custom AABBs union transformed, animation-expanded bounds over the visible instances rather than remaining centered at origin. The off-origin native game screenshot shows the giant's feet/body/fists and low health display next to the player. Full navigation, five-wave gameplay and export acceptance remain Task 4 responsibilities.

## Code quality verdict: APPROVE WITH MINOR NITS

No important correctness, performance or scope findings identified in the reviewed Task 2 implementation. The shared pose helper avoids separate renderer/combat animation formulas; inverse-transpose normal handling also accounts for the stretched connecting arm. Reported isolated-renderer performance is appropriate evidence for batching, with its whole-game limitation stated.

Minor observations:

1. **The UV/normal checks prove array presence, not preservation.** `tests/forest-shrine/enemy_visual_test.gd:46-49` accepts any Texture2D and verifies only UV/normal array lengths. It would also pass a renderer that substituted a different texture, flattened normals, or zeroed UV values. Current implementation copies/transforms them correctly by inspection and native faces are visibly intact. A future regression check should compare representative source UVs/normals and texture resource identity against the merged surfaces.

2. **The exact fist-contact assertion uses a reference point rather than visible geometry.** `tests/forest-shrine/enemy_visual_test.gd:79-82` maps the same hard-coded reference used by `scripts/forest/forest_enemy_crowd.gd:112` onto the target. A read-only GLB triangle-distance calculation found `(10.637, 6.0, -4.20)` approximately 0.238 m from the nearest actual right-fist triangle. The broad building surface may still intersect adjacent fingers, so this is not evidence that production strikes miss. The standalone contact tour (`tests/forest-shrine/enemy_visual_tour.gd:35-38`) contains no struck structure and cannot independently prove exact building contact. Add a fitted fist/target-surface overlap check at the director's damage frame when extending these tests; avoid describing the arbitrary point assertion as proof of an exact visible surface contact.

3. **Unused instance payload and repeated empty-image allocation are avoidable work.** `scripts/forest/forest_enemy_crowd.gd:205,215` allocates images even for empty species and uploads walk phase/motion/progress through INSTANCE_CUSTOM although the shader consumes only its row index `.w`. This is a small cleanup opportunity, not a measured performance failure; the reported 200-actor average/max of 4.061/5.225 ms already meets the demonstrated isolated workload.

## Evidence reviewed

- Plan, linked redesign spec, Task 2 report and saved Task 2 diff; current renderer/shader/tests/tour and relevant simulation/actor/contact contracts.
- Native `small_front`, `small_side`, `small_back`, `giant_front`, `giant_side`, `giant_back`, `giant_windup`, `giant_contact`, `archer_bow_draw`, and `giant_off_origin_contact` PNGs.
- Native walk frames 00 / 04 / 08 / 12 / 16 / 20 from the 24-frame four-second gait sequence.
- Reported existing 160 headless checks, 17 native contact checks, and 200-actor / four-batch / 129-draw-call Metal performance evidence. These results were accepted as recorded evidence, not rerun or independently claimed as newly executed tests.
- Supplemental read-only GLB schema/material inspection and targeted fist-reference triangle-distance calculation. No runtime tests were repeated.
