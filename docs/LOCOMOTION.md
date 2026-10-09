# Character locomotion — v1.6

## Audit and scope

The previous hero was a seven-bone rigid puppet: head, each entire arm and each entire leg were siblings under Root. The bones all used generic upward rest axes, there were no elbows/knees/ankles, and the gameplay wrapper replaced imported animation poses with a timer-driven sine wave. Phase advanced even without movement and did not measure ground distance. Foot sliding and straight-limb swinging followed directly from that setup. Root motion and mesh scale were not the cause.

Only the existing hero rig, skin weights, animations and movement adapter were changed. The 460 original mesh triangles, UV corners, texture atlas, materials and design remain intact. Hair variants, character dimensions, NPC assets, environments, combat damage/timing, camera and map systems retain their established roles. The previous source/export/scripts are archived in `backups/pre-locomotion.tgz` (initial rig upgrade), with the pre-anime version in `backups/pre-anime-motion.tgz`.

## Source and skeleton

Editable source: `assets/blender/characters/kai.blend`.
Game export: `assets/models/characters/kai.glb`.

The 22-bone hierarchy is:

- Root → Pelvis → Spine → SpineMid → Chest → Neck → Head
- Chest → Clavicle_L/R → Arm_L/R → Forearm_L/R → Hand_L/R
- Pelvis → Leg_L/R → Shin_L/R → Foot_L/R
- Pelvis → Sash (compatibility anchor)

Bone Y axes follow anatomical limb directions. Elbow, knee and wrist rings blend weights on the **existing** vertices; the shoes remain rigid. No subdivision, added vertices, remeshing, texture painting or proportion changes were used. The source remains in its original T-pose when no action is active. All gameplay translation belongs to CharacterBody3D; locomotion clips are in place.

## Animation set

The source contains 24 named, editable NLA actions. Locomotion actions share a one-second normalized cycle, keyed at 60 fps:

- Idle, Walk, Run, Sprint
- Back_Walk, Back_Run
- Strafe_L_Walk, Strafe_L_Run, Strafe_R_Walk, Strafe_R_Run
- JumpStart, JumpLoop, Fall, Land

The remaining compatible clip names are Attack_Left, Attack_Right, Attack_Finish, Heavy, Charge_Spin, Throw, Jump, Front_Flip, Hit and Death. Existing live combat timing and special-pose overlays remain controlled by the game.

The anime running cycles use authored drive/impact/rebound key poses with cubic interpolation. Pelvis rotation initiates the stride; the lower and middle spine carry it into a visibly counter-rotating chest. Clavicles lead the arms, followed by delayed elbow and wrist motion. The pipe-side arm has a slightly different amplitude and timing. Compression, lateral weight transfer, forward lean, larger knee recovery and strong rear arm arcs make the full body participate.

Run/sprint chest lean is about 14°/21°. Neck lean follows at 68% and head lean at 48% (about 7°/10°), plus small delayed rebound. The head retains subtle yaw counter-motion rather than being locked to its bind orientation. Original vertex coordinates, UVs and textures are unchanged; torso and shoulder weight distribution was extended to the additional bones.

Run/sprint foot travel is 0.94/1.04 m and swing clearance 0.32/0.40 m. Phase still follows actual traveled distance. The pelvis contact solver anticipates the toe-pivot target, including backward strides, before solving leg reach.

## Godot evaluation

`HeroLocomotion` in `scripts/hero_locomotion.gd` builds an active AnimationTree:

Ground BlendSpace2D → distance-driven TimeSeek → ground/air Blend2 → landing Blend2.

The ground space blends speed and local travel direction. An air BlendSpace1D mixes JumpStart, JumpLoop and Fall; Land overlays a brief crouch and recovers into movement. All loops share phase. The controller measures **actual displacement after move_and_slide**, so walls and blocked movement do not drive a running-in-place animation.

After AnimationTree evaluation, a two-bone analytical IK pass handles each leg. Ray queries find real collision surfaces. During stance, foot targets are world-space anchors. Swing feet lift/recover, toe-off rolls around the toe, and pelvis height compensates for capsule clearance and slopes without stretching a limb. Stopping uses a short corrective step when a foot is left behind. Knees keep a consistent forward bend pole. Airborne movement, evades and full-body spins release ground locks.

Combat poses are overlays above the authored pose. The existing pipe/coin visual attachments follow Hand_R after animation and IK. They no longer inherit the old rigid shoulder approximation. Double-jump rotation remains a forward flip around the established body pivot.

The old seven-bone wrapper path is retained exclusively for existing enemies. Room resets clear hero phase, air state and foot anchors to avoid carrying a plant into another area.

## Controls and movement

- WASD: camera-relative travel, with smooth full-body turning into every movement direction, including backward and all diagonals.
- Ctrl held: walk at up to 2.2 m/s.
- Shift held: sprint using the existing Prototype Lab speed setting.
- Space / double Space, attacks, Q evade and R retain their gameplay behavior.

Horizontal acceleration/deceleration is vector-based. Visual facing uses frame-rate-independent damping; movement input is never delayed for an animation. Ground phase follows distance rather than a fixed timer. Feet may enter a normal flight phase during fast running; that is distinct from sliding a supporting foot.

The Fire Siege camera follows backward travel immediately and buffers one metre of actual forward travel before following. Stopping recentres the view; starting forward again re-arms the buffer. Blocked input does not consume it. Camera-aimed attacks, held shields and committed movement abilities retain their aiming rules.

## Editing and export

Normal iteration: edit the saved Blender source and run `tools/export_blender.py`, then let Godot import the GLB. Preserve names, local scale 1 and the original T-pose bind geometry.

`tools/rig_locomotion.py` is the deterministic rig/clip authoring tool used for this upgrade. It never modifies mesh coordinates or materials. It stores original weight-region metadata so repeated rig generation does not reinterpret blended weights. It regenerates actions, so **do not run it over hand-edited animation actions unless deliberately rebuilding those actions**. `tools/import_reference_hero.py` is the older one-time seven-bone importer and is not the update/export workflow for this rig.

`tools/preview_locomotion.py` renders non-destructive side and three-quarter idle/run/sprint pose comparisons into `tests/`. It does not save changes to the Blender source.

Run Blender with `tools/verify_reference_hero.py` to compare all original triangles and UV corners and verify byte-identical original/packed textures, complete weights, 22 bones and 24 actions.

## Validation

`--locomotion-test` exercises walk/run/sprint, backward and sideways turns, reversals, jump/fall/landing, slopes, stopping and a blocking wall. It checks foot reach, stationary support anchors, fixed bone lengths, bent elbows, root-motion isolation and hand attachment. It also checks motion on all torso/clavicle/neck bones, visible chest twist and pelvis/chest counter-rotation.

`--locomotion-visual` runs those motions in the actual coastal scene and records both a three-quarter inspection pass and the normal collision-aware gameplay camera. It writes `tests/locomotion-metrics.json` and numbered review frames. The review video is `tests/locomotion-review.mp4`; it preserves capture timestamps and is not a performance benchmark. The close inspection pass can cross scenery; the normal camera pass retains collision handling.

Combat and smoke suites must continue to pass after changes. Source shape/texture verification is separate from runtime animation checks: passing an export alone does not validate movement.

## v1.7.1 directional upper-body response

Actual local sideways velocity now drives a smoothly blended additive turn/lean through Pelvis, Spine, Chest and Neck. Head steering is applied after the stride-stabilization pass so it is not cancelled. Full strafe adds about 11.5° chest turn, 16° head turn and a modest directional bank; acceleration adds a short weight-shift response. Reversals settle continuously rather than snapping, and airborne steering uses the same response. Full-body spins reduce it. Root facing/input/camera behavior is unchanged.

Authored clavicle poses open outward 0.025 m per side (roughly 6% shoulder stance width), including idle and motion. Strafe arms retain fore/aft swing instead of losing it when forward velocity is zero. These are rig/animation changes: source geometry, UVs, textures, normal/gold hair and supplied pipe are untouched.

Validation checks the modest shoulder-width increase and signed head-turn response on left/right strafes, in addition to existing stance contacts, torso rhythm, attachment and transition tests. The visual suite now includes both side directions with the normal gameplay camera.

During reversals the support solver may briefly lower the pelvis by up to 0.28 m (only when required for leg reach), returning smoothly as the stance catches up. This avoids pulling a planted foot off the floor during longer strafe reversals and landing recovery.

## v1.7.2 ready idle and breathing

Idle now has approximately 28–32° elbow flex and a mild outward upper-arm angle. Arms sit away from the torso while the existing hand attachment follows the supplied pipe. Idle alone uses a 4.55-second breathing cycle: subtle pelvis lift/lower, phased spine/chest rise, delayed neck/head response and small arm follow-through. Ground IK keeps feet planted while knees flex/recover. The measured initial runtime cycle spans about 2.7 cm at the pelvis, 4.4 cm at the head and 9° at the knees. No mesh, texture, rest proportions or running/attack clip poses were redesigned.

The locomotion suite samples a complete idle breath, checks arm clearance/elbow bend, pelvis/head vertical motion and knee response, and renders a complete breathing cycle from both the inspection and gameplay cameras.

## v1.7.3 compact idle arms

Idle upper/lower arm segments use 90% pose scale/length, rooted at the unchanged shoulder attachment. Global hand scale remains one so hands and the pipe do not shrink. Uniform segment scales avoid shear when exporting the rotated elbow chain; source mesh coordinates, textures and rest rig are unchanged. Other authored clips retain full-length arms.

The runtime smoothly restores normal reach during stationary attacks, charging and evades, and settles back after the action. Movement blends naturally from Idle to full-length locomotion clips. Hit timing/range/damage are unchanged. Tests check both arm segment ratios, hand size, full attack reach and recovery after the complete automatic three-hit chain.

## v1.7.4 relaxed compact idle

Idle arms are another 10% shorter than v1.7.3: both segments now use 0.81 of original length (0.90 × 0.90). Elbow flex increases from 0.52 to 0.64 radians with the same small breathing variation. Idle clavicles open 4 cm per side, compared with 2.5 cm during movement, and the upper arms angle slightly farther outward. Shoulder attachment, full-size hands, original source geometry/UVs/textures and breathing remain intact. Existing action extension restores full attack reach and blends back into compact idle.

## v1.9.3 non-accumulating procedural poses

Before each AnimationTree evaluation, reset the Skeleton3D local bone poses to their immutable rest transforms. Animation tracks then produce a fresh authored pose, followed by this frame's overlays/IK. Previously, procedural bone writes could feed the next evaluation, resulting in exponential deformation under repeated attacks. The GLB does contain scale tracks; the reproduced failure is feedback between runtime bone writes and repeated zero-delta evaluation. This is a baseline reset, not a clamp or a change to source assets/animations.

`-- --attack-soak` drives 7,200 controller/animation ticks at 60 Hz with ten clicks per simulated second, measuring every bone scale/extent. It asserts stable scale after warm-up and unchanged visual-root scale. Before the fix, scale exceeded 2× within the run. Afterward it stays bounded at the normal transient blend maximum (~1.011) with no accumulating growth.
