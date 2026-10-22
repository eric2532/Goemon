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

## Softer cuts and energy-wave release — 2.30.2

The approved swing is retained with a slightly finer edge and playback gain
reduced from 1.0 to 0.68 (about 3.35 dB). Contact gain is reduced from 0.85 to
0.52; the source also has a lower peak and replaces the low metallic knock with
upper-mid shearing noise and a faint steel tail. Magic Swordsman's wave now uses
its own 0.72-second blade-release and fading energy-rush sound, at gain 0.64.
The original shared blade files, other heroes, gameplay timing and damage remain
unchanged. The generator includes all six editable sound sources.

The signed macOS 2.30.2 package passed 69 lean/audio, 134 control/combat and
11 compact-map/wave checks (214 total, zero failures). New checks first failed
against the previous implementation, then passed for actual voice gains and
wave event routing. The 8.97-second packaged gameplay capture shows empty swings,
combo contacts, wave flight and wave contact; its frames were inspected.
Recorded audio peaks at -12.1 dBFS with no clipping. The separate six-second
preview presents swing, cuts and wave at their relative playback gains; subjective
timbre remains for the user to judge. Existing test-exit resource warnings remain.

A second packaged recording exercises repeated waves and the ultimate against
180 live enemies: zero caster hit-stop frames, 11.285 ms physics p95, and
-10.6 dBFS maximum recorded audio. Its frames were also inspected. The native
app was then launched normally and verified at the Fire Siege selection screen.

## Fuller profiles, weapon carry and airflow — 2.31.0

All ten Rogue rigs have 15% more model-space depth, preserving front width,
height, the painted faces, clothes and attached equipment. This is a runtime
model transform in actor.gd; the approved editable Blender assets stay intact.
The physical Hero/collision scale and gameplay ranges remain unchanged.

Sideways movement now has up to 14.3 degrees of shoulder lean and 3.7 degrees
of neck follow-through. The carrying arm responds more slowly than the torso.
The right-handed claymore trails low to the character's right on left strafe;
on right strafe the arm opens outward. Staff, lance, bow and dual blades retain
appropriate carrying orientations. The weapon remains attached to its grip.
Attack entry blends over the moving carry, and full contact poses take priority.

MovementWind draws seven tapered, translucent airflow ribbons in one reusable
mesh. Actual movement speed and acceleration drive intensity; sprint is stronger
than cruise, collisions prevent stationary wind, and stopping fades it out.
It does not replace the ultimate body overlay. Reset clears both direction and
visibility. No effect nodes are spawned per frame.

The weight review tour records previous/current profiles, left/right strafes,
sprint and stops for every Rogue, plus Magic Swordsman movement-to-attack,
energy wave, double jump and ultimate. Its before comparison temporarily sets
only visual depth to 1.0; normal gameplay always uses the new 1.15 depth.

Both attack entry and recovery blend against the carrying pose; a contact pose
always has full priority. Separate failing regressions caught the initial entry
overwrite and upright recovery snap before these transitions were corrected.

Final signed macOS package: 84 weight/transition, 95 movement/utility, 134
controls/combat and 69 lean/audio checks passed (382 total, zero failures).
The 43.5-second packaged gameplay capture and all-hero profile/strafe/sprint
frames were inspected, including the corrected attack recovery sequence.
The final app was launched normally and verified at Fire Siege selection.
Existing Godot resource-cleanup warnings remain in test exit logs.

## Diagonal sidestep refinement — 2.31.1

Reduced side roll from 14.3 to 5.2 degrees, neck roll to 1.1 degrees, and lateral
body offset from 0.05 to 0.018. Pure strafe now eases the visible stepping stance
and shoulders about 30 degrees into travel; the head/neck follows to roughly
27 degrees. The stride is resolved in that turned frame with reduced lateral
leg spread. Actual movement direction, camera heading, collision and speeds are
unchanged. The turn blends out at attack contact and returns during recovery.
Existing weapon carry, 15% profile depth, wind and painted designs remain.

The signed macOS 2.31.1 package passed 453 checks (104 weight/diagonal pose,
51 turning, 134 controls/combat, 95 movement/utility, 69 lean/audio), zero
failures. Both strafe directions for all ten heroes and attack transitions were
visually inspected in the 43.5-second packaged recording. Normal app startup was
verified. Existing Godot test-exit resource-cleanup warnings remain.
