# Game feel — v1.8.0

The approved Blender source, GLB, rig, meshes, materials, textures and authored locomotion clips remain unchanged. This pass uses small runtime pose overlays and existing controller/collision systems.

## Movement

Ground acceleration remains 38 m/s², stopping 48 m/s², with 58 m/s² for opposing input so reversal does not linger. Real acceleration drives transient spine lean (−0.11 to +0.14 radians), a small hip shift, and delayed shoulder/arm follow-through. Yaw velocity drives a capped pelvis-led pivot with trailing chest/neck and a small lowered stance. Existing world-space foot anchors/IK resolve support after these overlays. Steady-state approved cycles and compact breathing idle are retained.

Jump input buffers for 150 ms with existing coyote time; ground takeoff has a 35 ms compression, followed by immediate launch and a brief arm release. The existing double-jump front flip and air steering remain. Landing uses preceding fall speed to scale the landing blend, hip compression, arm follow-through and camera impulse. No root/mesh scaling is added.

## Attacks and impacts

Swing ease accelerates through a short contact interval centered at 36% of a light attack / 47% of a heavy attack. Whoosh starts before contact. Damage is checked during a short active window, with one hit per victim per stroke and the existing wall occlusion checks. Automatic left/right/left chaining, charged sweep, coins, surge, damage and ranges are preserved. Evade cancels attacks immediately; heavy input buffers during the last 160 ms of recovery.

Confirmed damage is the sole trigger for impact audio, sparks, directional camera kick and local hit-stop. Light / finisher / heavy pauses are 35 / 60 / 95 ms, quantized to physics ticks. Pipe attacks pause the attacker and victim; projectiles pause only the victim. Neither global time scale nor camera/input is slowed. Multiple victims do not stack pause duration.

Enemy recoil uses incoming direction transformed into model space: torso pitch/roll/yaw, counter-moving head and arms, with stronger heavy recoil. Existing directional knockback, stagger and boss poise remain. Contact VFX originate on the gameplay hurt-volume surface for melee and the swept projectile segment for coins; these are forgiving gameplay collision volumes, not per-triangle pipe collisions.

Camera kicks are directional damped impulses, capped by hit strength, decaying within about 0.15 seconds. Compact flashes and 4–8 directional streaks keep silhouettes visible. Swing, impact, reaction and environment sounds are separate events. Sound Studio includes new Enemy reaction and Environment impact slots; defaults reuse local audio, and existing custom recordings remain available.

## Reproduction and validation

Run Godot with `-- --feel-test` for contact/miss, local freeze/release, one-hit-per-stroke, directional recoil, evade cancellation, acceleration, braking and jump checks. `-- --feel-visual` runs the same sequence in the real coastal scene and records frames to `tests/feel-frames`. Existing combat and locomotion suites cover combo damage, charges, walls, surge, tuning, grounded foot errors, arm proportions, attachment and transitions.

Tune transient movement constants in `hero_locomotion.gd`, input and contact windows in `player.gd`, swing poses in `hero_model.gd`, impact strengths in `game.gd`, and recoil in `enemy.gd`. Do not regenerate the approved Blender assets for feel-only changes.
