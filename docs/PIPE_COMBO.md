# Pipe combo — v1.9.0

The approved character, rig, textures, Blender source, imported GLB and supplied pipe are unchanged. `scripts/pipe_combo.gd` defines runtime key poses and timing; `hero_locomotion.gd` applies the pose layer to the existing skeleton.

## Choreography

1. **Diagonal opener — 0.28 s.** Raise the pipe, take an aggressive short step, drive it forward/downward, and finish in a low right-side pose. Contact at 34%.
2. **Left sweep — 0.34 s.** Continue from that exact ending pose. Hips/chest reverse and carry the hand across a broad frontal arc; follow-through progressively loads the left-side finisher wind-up. Contact at 38%.
3. **Right finisher — 0.56 s.** Begin in that exact loaded pose, deepen the wind-up, then explosively unwind hips/chest to the right. Overshoot into a strong pose before the final recovery. Contact at 48%.

Endpoint-preserving delays separate hip, chest and wrist motion. Arm IK traces the continuous wrist path with fixed limb lengths; the existing hand attachment carries the original pipe. The torso/hip offsets and planted-foot IK provide weight transfer and knee bend. Short controller impulses create real collision-aware steps. Idle, running, strafing, jumping, charged attacks and coin controls retain their existing systems.

## Controls and impact

Per the user's explicit choice, **one click performs the entire three-hit combo**. Extra clicks during hits 1/2 buffer a successor without restarting or skipping the current stroke; automatic chaining already guarantees that successor. There is no reset to neutral between hits. Evade remains the explicit immediate cancel. Holding LMB still charges, RMB remains heavy, and the finishing recovery is longer than earlier hits.

Damage remains 22 + 22 + 30, preserving tuning. Feedback grows through all three strikes: 35 / 60 / 95 ms local hit-stop, progressively stronger camera kicks and contact bursts, and heavy impact audio/recoil/launch on hit 3. The left sweep knocks left; the right finisher knocks right and away. Slash planes are diagonal / nearly horizontal / broad angled right, with increasing width. Hit feedback only fires on confirmed, unoccluded hurt-volume contact. Each stroke can damage each target once.

## Validation

`-- --combo-test` checks choreography seam continuity, distinct timing, ordered automatic hits, escalating contact pauses, buffering without interruption/duplication, finisher knockback, and planted support. `-- --combo-visual` additionally records live gameplay and renders nine key poses from a closer three-quarter view in the actual coastal environment. Existing combat and locomotion suites remain regression checks. The signal `impact_confirmed` exposes the exact contact event to deterministic tests, independently of rendering FPS.

## v1.9.1 charge stance

Holding either weapon now blends into a compact right-side charge stance: lowered hips, coiled chest, raised free-hand guard, and the weapon aimed along the character's right axis. The old whole-arm Euler charge overlay was removed. The existing two-bone arm solver now accepts a charge-specific maximum reach of 88% of combined segment length, keeping the elbow bent without changing bone lengths, mesh geometry, or weapon scale. Charge intent drives action arm extension directly, avoiding a render-frame delay.

The pipe stays in this stance through the existing 360° charged release; a charged coin moves from right-side preparation into a bounded forward throw. Charge entry/recovery blend, and cancel, switching weapons, resetting, and Golden Surge preserve the same arm constraints. Ordinary three-hit combo choreography and uncharged attacks are unchanged. `-- --charge-test` validates direction, fixed bone lengths, minimum elbow bend, release and cancellation; `-- --charge-visual` additionally captures both weapons in the actual environment.
