# Dark Lumina 2

The green second-form battle boss is enemy role **17**, playable character **29**.
Choose **Dark Lumina 2** in the character selection. LMB uses the claw grab;
RMB or R uses the jump stomp and twin energy wave; press it during a jump
to stomp straight down. E fires the three paired
fireball releases; T uses the recovered spin attack. The four skills are also available
in the shared skill selector for other fighters. Existing movement, jump,
evade, hit, equipment and selection ownership remain with the player system.

The wave editor has a Dark Lumina 2 count. New and migrated waves start that
count at zero; existing ordinary enemies and Skullpion counts are preserved.
This does not silently add a boss to an existing saved wave.

## Source identity and recovered content

The preserved local disc extraction is under `build/Other Files/Musashi Asset
Recovery/`. The correct encounter is **SC07 / FILE_003 / 1.1**, module `0x72`,
loaded at **0x801A00D8**. The earlier chase overlay is not this battle, and
module `0x73` is the separate final form. The actor dispatcher is `801A01D4`,
initializer `801A026C`, descriptor `801A6874`, and 19-part mesh list `801AE21C`.

Recovered body: **714 triangles, 19 rigid parts, 21 motion streams**, including
walk, idle, lunge, missed-grab recovery, successful grab, fireball sequence,
jump slam, left/right spin poses, hit/recovery, rest transitions and defeat.
All 21 raw streams remain preserved; the reduced-part walking stream is kept
for research, rather than misapplied to the full-body death animation.
The raw mesh has 60 surfaces and 12 distinct material/texture combinations;
the existing rigid renderer batches compatible surfaces. Its full animations
are prepared into one shared pose texture, with no per-enemy retargeting.

The immutable recovery is:

- `assets/characters/recovered_monsters/dark_lumina_2.glb`
- `assets/characters/recovered_monsters/dark_lumina_2_motion.json`
- `assets/characters/recovered_monsters/audio/dark_lumina_2/`
- `assets/characters/recovered_monsters/dark_lumina_2_effects/`

Audio tracing follows all **22 referenced dispatch IDs**: **21 audible cues**
and one driver-control dispatch. This includes the layered throw, charge
fade-in, hurt/recovery, breathing, footstep, contact, projectile, slam and
multi-stage death sounds. All 18 owning-bank ADPCM samples are retained in
`build/Other Files/Asset Toolkit/Dark Lumina 2/Audio Catalog/`. The four
scripted cues use the retail sequence interpreter's note timing, pitch,
relative volume and charge envelope, rather than treating a sequence as a
single sample. All audible cues are available in the character's recording
hub; normal runtime cues honor its overrides, volume and mute settings.
The simultaneous throw and throw-layer cues are also mixed offline as
`throw_full.wav`, allowing the existing voice pool to play both layers together.

Effects preserve all **48 source sprite frames** (three streams of sixteen),
the shock dome, shock ring and textured breakup fragment. Some sprite pixels
are inherited from MAIN / FILE_003 and the chapter's preceding VRAM upload;
the battle package alone is incomplete. The actual source CLUTs and texture
coordinates are used, rather than substitute fire artwork.
The defeat meshes restore actor `801A5C34`'s `0x50000000` additive flag with
prepared owned materials; the immutable recovery and authored mesh stay intact.
They are not the stomp wave. Fresh tracing of the landing handler at 801A127C
calls shared actor 0x352 through 801830D8. That actor uses the textured sector
at 80197C6C nineteen times, with 227/4096-turn offsets, an eight-tick rise and
48-tick expansion/rotation. Its eight-frame UV scroll uses the original orange
flame page (tpage 188, 8-bit CLUT 32464), recovered as `stomp_wave.png`.
`tools/recover_dark_lumina_stomp.py` and `stomp_sources.json` retain the evidence.

## Editable masters and export

Open the existing masters; never regenerate them over artist edits:

- `assets/blender/enemies/recovered_monsters/dark_lumina_2.blend`
- `assets/blender/enemies/recovered_monsters/dark_lumina_2_effects.blend`
- `assets/blender/enemies/recovered_monsters/dark_lumina_2_stomp.blend`

The body master preserves `Part_00` through `Part_18`, their native pivots,
flat rigid hierarchy, source textures and every `Source__...` action at 30 FPS.
Use `tools/export_recovered_monster.py` on that open master. The effects master
preserves the three original mesh names and source dimensions; use
`tools/dark_lumina_effects_blender.py` on that open master. Runtime converts
source effect dimensions with the same `.018` world scale.
Export the separate stomp master with the same tool plus `--stomp`; it writes
`stomp_wave.glb` and `stomp_export.json` without replacing the older exports.
The shared shader prepares rise, rotation, UV scrolling and radial fade once;
instances supply only age and the existing 25.2/36-unit combat reach. This static
effect export does not change the body, its animation samples or its pose bake.

Authored exports live under `assets/models/enemies/recovered_monsters/`.
After an export, refresh Godot imports, then bake only this body:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/bake_recovered_monsters.gd -- dark_lumina_2
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

The scripts `recover_dark_lumina.py`, `recover_dark_lumina_audio.py`,
`recover_dark_lumina_effects.py`, and `recover_dark_lumina_spin.py` document
the byte-level recovery. They are
recovery tools, not the normal artist-edit workflow. Do not edit generated
pose resources. Sprite strips remain lossless PNGs beside their provenance.

## Shared runtime and adaptation

`scripts/forest/dark_lumina_kit.gd` is the common player/native contract.
The native `Combat` owner runs enemy targeting, health, statuses, animation
rows, grab contacts, jump movement and projectiles. The player uses the
existing recovered-enemy adapter and character projectile pool. Effects,
corpses and sounds use the existing bounded army presentation pools.

Source fireball releases are at animation ticks **47, 64 and 81**, with two
shots at each release and the original ±320-angle-unit spread. Each has a
prepared three-sprite trail, an initial outward leg, a turn toward the locked
point and a later tracking leg. Grab contacts retain the source sequence's
**62 and 134** follow-through markers after the initial claw contact. Misses
use the original recovery motion. The jump's airborne pose holds while the
existing terrain collision resolves the landing. Cancelling a grab expires
its short held status; cancelling a cast cannot emit later shots.
The claw approaches only until its target is within reach, so a nearby target
is not overrun before contact. The same prepared controller supplies borrowed
fireball, grab and slam skills; the receiving fighter keeps its own body.

This is an adaptation to Goemon's world and existing combat rules. Health,
world movement/reach, damage, encounter choice cadence and low shockwave
radius are game tuning, not a claim of emulating the original arena's entire
script. Original scene music/dialogue and the following transformation into
the third form are not assigned as this character's combat skills. Audio is
recovered dry SPU ADPCM with source pitch and sequence timing; hardware ADSR,
reverb and Gaussian interpolation are not emulated.

## Verification

Evidence belongs in `build/Other Files/Asset Toolkit/Dark Lumina 2/`.

- `test_dark_lumina_2_recovery.py`: source bytes/poses, all audio cues, sequence
  timing, all effect streams and original effect geometry.
- `test_vambee_wolf_recovery.py`: oriented triangles, vertex attributes and
  exact texture bytes survive this body's editable round trip.
- `dark_lumina_2_test.gd`: 23,275 source-part samples, baked hashes, save
  migration, native attacks at 20/30/60 steps per second and native death.
- `native/terrain_math/crowd/dark_lumina_test.cpp`: paired releases, actual
  jump/landing, both pulses, all grab contacts, cancellation and validation.
- `dark_lumina_2_gameplay_test.gd`: actual playable controls, borrowed skill,
  repeated pooled fire, grab, jump, interruption, death and rendered captures.
- `dark_lumina_2_live_test.gd`: focused painterly scene with twelve simultaneous
  native bosses; records frame/physics measurements and presentation growth.

Headless checks verify correctness, not visual smoothness. Use the desktop
launcher for the rendered tests and ordinary play. No app export is required.

The initial recovery desktop run, before the size/speed tuning below, passed 30 checks, including all three borrowed skills,
with unchanged recorded runtime inputs. The subsequent twelve-enemy live run
had zero resource/node growth after warmup. That native/pose verification
passed 16 checks and 23,275 source-part samples. See the dated Dark Lumina 2
section in `docs/goemon-performance-guide.md` for measured frame intervals,
the concurrent-work qualification and the remaining audio/long-session limits.

## Larger body, faster claw and longer fire — 2026-10-24

The user requested these upgrades for both playable DL2 and native enemies;
borrowed skills use the same tuning. `scripts/forest/dark_lumina_kit.gd` owns
body scale 3, claw tempo 3, movement multiplier 1.2, fire size 3 and the shared
160 launch / 320 rise gravity / 720 fall gravity used by Skullpion's controls.
The 21 Blender actions, original GLBs, authored motion, pose bake, textures and
sound samples remain unchanged. Scaling uses the existing rigid shader's
role-size parameter, with matching hurt bounds, navigation footprint, spawn
clearance, construction clearance, camera and render bounds.

Fire travels at 25.92 units/s for the original 3.5 seconds (90.72 units of path,
formerly 30.24), with radius 1.95 and three-times-sized source sprites/trails.
The three source release pairs and homing timing stay intact. Its unchanged
lifetime retains the existing prepared 12-shot pool. Borrowed fire originates
at the receiving fighter's body height. The claw, successful grab and miss
recovery advance source pose and contact markers at 3×; damage and contact
counts are unchanged. The approach distance grows with the body and advances
with the faster clock, so a claw initiated at maximum reach still connects.
The fitted sweep stays low enough to catch ordinary-sized fighters. Walking
cadence accounts for the larger stride. Space/double/wall jumps and the slam
reuse the shared leap physics; the slam still waits for physical landing.

The native air sweep uses the scaled torso capsule (radius 6, height 15.552),
while ground navigation retains the full 12.096 footprint. Using the footprint
as capsule radius would make it wider than half its height and lift its feet
off the ground; the native jump/landing test guards against that regression.
Tuning evidence and the all-21-motion rendered sheet are under
`build/Other Files/Asset Toolkit/Dark Lumina 2/Tuning/`.

The follow-up passed 89 rendered gameplay checks, 21 native/pose/cancellation
checks and the shared-character/skill suites. The longer twelve-enemy run
kept resources flat after warmup, but its unfocused frame trace included spikes;
see the dated performance-guide section for the measurements and limitations.
Cancelled borrowed leaps clear their added launch momentum while retaining any
existing downward speed; ordinary fighters return to their own movement rules.

## Walking and spin source recheck — 2026-10-24

`tools/recover_dark_lumina_spin.py` validates original instructions and saves
`dark_lumina_2_effects/spin_sources.json`. This is additional recovery; the
editable body, authored animations and existing pose bake are unchanged.

Walking handler **801A079C** plays dispatch **B53** at frames **15 and 53** of
an 80-tick cycle. The existing `step.wav` was the correct bank-96, sample-4
sound (ADPCM identity `243c9420ba0b40ed`, pitch `3E00`). The player now integrates
walk distance into the pose clock, and both owners trigger steps from those
markers. Generic player footsteps and the held-victim status no longer produce
extra stomps. Its 195-unit audio range and 36-unit attenuation scale match the
already enlarged character/camera. Idle, air travel and paused clocks add no steps.

Spin is battle state **0F**, initializer **801A13A0**, update **801A143C**.
It selects **801F1898 / 801F1978** according to turn direction. Those 27-tick
motions were already in the Blender master and atlas, but previously mistaken
for hurt poses. The missing motion was code-owned world yaw: wind back 112
angle units at tick 4, then turn 240 units per tick on ticks 7–24 (4096 = 360°).
The shared player/native kit now supplies both pose rows and that rotation.
The actual hit pose is **801F0798**, with **801F0840** as the longer recovery.

Dispatch **B56** at **801A1410** is the spin's layered cry. `spin` aliases the
already recovered `hurt.wav` resource; historical filenames and saved hurt
recordings remain intact. The separate “Spin attack” recording slot supports
custom recordings, gain and mute through the existing sound library.

The source emits eight dust particles and one flying ground tile per active
tick. Tile actor **376**, dispatch **80183A70** in the battle scene overlay
`SC07 / FILE_002 / 0.4.dec`, samples 32 original 32×32 floor patches using
8-bit CLUT **7800**. They are retained losslessly in `spin_debris.png` (32×1024).
The renderer uses two existing MultiMesh effect batches for all emissions;
it does not create particle nodes or load resources during a spin. The dust
material and deterministic fragment flight use Goemon's presentation system;
these are adaptations, not a claim to emulate the PSX particle engine exactly.

T and the shared `dark-lumina-2/spin` skill use the source duration/rotation.
Native enemies add spin to their existing fire/slam/claw cycle. Goemon combat
applies one 360° contact at tick 7 through existing local queries and cover
checks, at radius 14.4 for the requested triple-size body. Damage and skill
multipliers use the current owners. This contact is an adaptation of the
source's limb hitboxes. Cancellation retires future emissions and restores
player facing; the native owner keeps its resulting world orientation.

A related label correction: **801F1FD8** is the walk stream for the 17-part
post-transition actor, not a breakup animation. The ordinary 19-part body
keeps its full-body walk, and death holds its proper final pose while the
existing breakup effects finish. No raw animation, master or texture is deleted.

Run `tests/forest-shrine/dark_lumina_2_spin_test.gd` through the desktop launcher
for walking/spin audio, both directions, contacts, borrowed skills, cancellation
and twelve overlapping effect bursts. `dark_lumina_2_spin_live_test.gd` checks
normal army combat with twelve bosses. Evidence belongs under
`build/Other Files/Asset Toolkit/Dark Lumina 2/Spin and Walking/`.

The walking/spin desktop review passed 49 functional assertions, including
non-clipped mixer recordings. The final twelve-boss scene exercised eight native
spinning enemies with fixed presentation nodes and zero resource growth after
warmup. That crowded scene still showed frame spikes; see the performance guide
for measurements, rejected paused attempts and concurrent-source limitations.

## Airborne jump stomp — 2026-10-24

RMB/R now works from a normal jump as well as the ground. An airborne press
uses the existing slam's descending frame 38, stops horizontal drift and
starts downward at at least 160 units/s. It consumes any pending jump windup
and cannot launch a second leap. Grounded casts retain their original leap;
player and native enemy stomps use the existing 720 falling gravity and clamp
the descent to the same minimum downward speed after the descending pose.

The first ground wave is released on physical landing, and the second
follows 0.3 animation seconds later. The player advances directly to the
source impact frame 54 after contact, matching the native landing gate, instead
of waiting through the old grounded animation delay. The prepared wave meshes and contact radii now follow the requested 3× body
scale: 25.2 for the first pulse and 36 for the second. Damage, source
meshes, audio and the stable `dark-lumina-2/shockwave` skill ID are preserved.
The skill picker now calls it “Jump Stomp & Energy Waves”; other fighters can
still borrow it. Cancellation uses the existing controller and emits no late wave.

The earlier implementation passed 41 rendered assertions (601/602 stepped frames focused),
including grounded and rising RMB/R casts, borrowed aerial stomp, cancellation,
the then-assigned dome/ring meshes and repeated twelve-way effects with stable resources/nodes.
Those checks certified contact and pooling, not the effect identity; the newer
source trace above corrects that visual mismatch while retaining both damage pulses.
The first wave followed landing within two physics frames. Native checks at
20/30/60 Hz verify both pulses after floor contact and twelve simultaneous native
stomps. The unchanged pose bake passed 23,275 original part samples; shared skill
checks and asset preservation passed. Evidence is under
`build/Other Files/Asset Toolkit/Dark Lumina 2/Jump Stomp/`.

## Physical stomp landing sound — 2026-10-24

Hero-owned DL2 landings now route the normal `land` event to his existing
`dark_lumina_2_slam` slot (ROM B52), labelled “Stomp landing” in his recording
hub. Previously his restricted source slots silenced the generic landing event.
The physical landing marks that cast's audio as delivered; its wave cue still
emits the original effects but skips a duplicate impact. Borrowed/native stomps
retain their own cue because the receiving Hero does not own the donor landing.
Native DL2 impacts use the army's existing priority audio path so an ordinary
crowd sound cannot suppress them. Existing recordings, gain and mute still apply.

Skullpion retains his original 560 ground-impact sound on physical landing, with
the timed duplicate suppressed. Desktop mixer captures for both bosses and the
DL2 aerial stomp are under `build/Other Files/Asset Toolkit/Boss Stomp Audio/`.
The initial captures contain no clipped samples. The focused suite also covers
borrowed DL2 impacts, normal falls, saved recordings/mutes and priority under a
busy voice pool. The shared skill suite and 72 Skullpion checks pass.

The final boss stomp audio run passed 18 assertions over 636 manually stepped
frames (635 focused), with four non-clipped mixer captures.


## Fire, attack reach, health and foreground audio — 2026-10-24

A later user request supersedes the earlier fire tuning above. Both playable
DL2 and native role 17 now have 5,000 base health and 400 base attack power
(previously 80). Existing per-character health overrides and progression still
apply; selecting another character preserves the health fraction as before.
Claw/grab reach, spin radius (28.8) and stomp radii (50.4 / 72) double. The body,
21 motions, source textures, original sound samples and editable masters remain
unchanged. Current movement multiplier 6 is preserved from concurrent tuning.

Fire uses six pairs at source ticks 47, 55.5, 64, 72.5, 81 and 89.5, on a 2×
source clock. Each cast emits twelve balls, with 200 base damage each. Flight
speed doubles to 51.84 units/s; the unchanged 3.5-second lifetime permits 181.44
units of path. Source sprites/trails are three times their previous size
(FIRE_SCALE 9), with radius 5.85. Target acquisition reaches 144 units. The
existing character pool prepares 36 shots for overlapping repeated casts;
no per-cast model/material loading or per-enemy scene was added.

The native profile remains positional: fields 1–3 now encode first fire tick,
interval and pair count, and fields 21–22 encode fire tempo and attack reach.
The shared GDScript producer, native consumer, validation and fixtures change
together. Validation rejects non-finite/non-positive fields, fractional or
excessive counts and release schedules outside the prepared motion.

Player/borrowed walking and attack cues now use the existing foreground sound
pool, preserving source character 29 and recording/mute/gain controls. They
previously competed with all army impacts for eight spatial voices and a global
35 ms gate. Army cues retain their bounded shared spatial mix. Fire cues are
classified with the existing foreground attack voices; walking uses the
ordinary movement voices, so neither requires a new audio pool.

Fresh evidence is saved under
`build/Other Files/Asset Toolkit/Dark Lumina 2/Fire and Audio Buffs/`.

## Source effects and glow restoration — 2026-10-24

The subsequent fire-breath correction supersedes the charge texture assignment:
`ember.png` contains patterned scenery from an unresolved VRAM page. Preserve
that recovery, but prepare the charge with the intact `fire.png` strip and its
round sprite aspect ratio. The existing presentation batch places it at
`Dark.MOUTH`, rotated with the caster. Shared spread is now ±400 source angle
units (±35.15625°); the existing homing turn rate follows that shared value.
Twelve releases, damage, speed, lifetime and attack clocks remain unchanged.
`dark_lumina_2_fire_breath_test.gd` verifies repeated player/borrowed casts,
transparent charge frames, facing, real contacts and twelve simultaneous native
casters. Evidence: `build/Other Files/Asset Toolkit/Dark Lumina 2/Fire Breath/`.

The shared sprite shader now exposes its existing 0.7 opacity as a parameter;
DL2 fire, impact and ember materials select full source strength during setup.
Other characters retain the old default. Source impact sprites replace duplicate
generic hit graphics while retaining the same contacts, sounds and feedback.

The recovered dome/ring are defeat energy, rather than stomp replacements.
Player and native deaths now schedule the same pooled dome, ring and fragment
at the existing frame-140 breakup marker. The dome/ring use their original
opposite 0x100-per-tick turns and 0x100-per-tick scale increase, additive vertex
colors and source backface culling. The presentation still uses a compact
80-tick defeat effect rather than transplanting the original ending/camera
sequence. Delayed records retire through the existing effect pool.

The stomp mesh, original texture, rise/rotation/scroll and both combat pulses
remain intact. No source GLB, texture, Blender master, body pose bake, combat
statistic, fire count or cooldown was changed. Current source/rendered checks
and captures are under `build/Other Files/Asset Toolkit/Dark Lumina Effects
Restoration/`; see the performance guide for fresh results and limits.
