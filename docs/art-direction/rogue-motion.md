# Rogue movement and ability presentation — 2.30.0

The approved 2.29.4 models and painted faces remain unchanged. This pass improves
movement feel and existing skill presentation in the original Fire Siege map.

- Ground motion accelerates over a short interval and brakes firmly. Cruise and
  sprint speeds, collision rules and jump velocities retain their original values.
- Joint animation uses actual movement speed and local travel direction. Strafe
  and backpedal strides, arm counter-swing, torso weight, airborne poses and a
  short landing compression replace the single time-driven walking swing.
- The second jump performs a 0.48-second tucked forward flip around the hips.
  Utility actions take priority over an aerial flip. Neither animation moves the
  collision body or changes the jump trajectory.
- C/E utilities accept a press within 0.16 seconds of readiness. Dash motion eases
  toward recovery while retaining total travel distance and original protection.
  Ranger leaps follow movement input. Explorer explains missing hook targets
  without spending cooldown. Master Thief's low stance blends smoothly.
- Magic Swordsman's secondary wave is 40% wider and launches 0.45 metres higher.
  Damage remains 79, piercing contacts remain once per target, and the existing
  wall collision, maximum range and bounded trail emission remain active.
- Every ultimate has an outfit-colored rim around the actual moving mesh and
  seven reusable rising wisps. Samurai's instant draw-cut has a brief crimson
  pulse; timed abilities keep their aura for their active duration. Reset and
  character lifecycle code clears the overlay immediately when power is removed.

Outfit colors: Pirate blue, Samurai crimson, Ninja violet, Mage blue, Knight blue,
Dragoon cyan, Magic Swordsman violet, Ranger green, Explorer teal, Master Thief red.
The shader is additive and does not modify the approved source textures.

Useful entry points:
- `--fire-siege-motion-test`: real-map movement/skill regression suite.
- `--fire-siege-motion-tour`: deterministic recording of all ten heroes.
- Existing controls, turn and compact-map suites check attack timings, camera
  facing, cover collision, original defense rules and wave performance.

Validation: the signed macOS 2.30.0 app passed 95 movement/ability checks,
134 existing control/combat checks, 51 turning checks and 11 compact-siege/wave
checks (291 total, zero failures). The 71.93-second all-hero gameplay recording,
flip frame sequence and all ten ultimate auras were visually inspected. Existing
Godot resource-cleanup warnings still appear when test processes exit.

## Shoulder/neck weight and claymore audio — 2.30.1

Sideways movement now adds up to eight degrees of shoulder roll and two degrees
of neck tilt toward travel, with a small upper-body weight shift. The neck follows
slightly later, both settle into the authored neutral stance, and their influence
reduces during attacks and guarding. Root facing, foot animation and gameplay
speeds remain unchanged. No approved model or face assets were edited.

Magic Swordsman has three dedicated claymore air sweeps and light/heavy cutting
impacts. A sweep starts before contact and its lead accounts for attack tempo and
playback pitch. Empty swings produce no impact; real blade and wave contacts use
the new cutting transient. Other classes and Goemon keep their previous sounds.
The original shared blade files are unchanged. Stereo 48 kHz PCM sources are
reproducible with tools/generate_claymore_audio.py (numpy); these are original
synthesized noise/metal layers without third-party samples.

The signed macOS package passed all 357 checks: 66 lean/audio, 95 motion,
134 controls/combat, 51 turning and 11 compact-siege/wave checks. The actual-game
recording shows all ten Rogues strafing and the claymore miss/contact sequence.
Its front-facing frames were visually inspected. Audio routing, timing, loaded
assets, non-clipping levels and PCM format were checked; the provided old/new
comparison lets the user judge the subjective sound character. Existing Godot
resource-cleanup warnings remain in test exit logs.
