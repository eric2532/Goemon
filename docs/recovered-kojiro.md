# Playable Kojiro

Kojiro is fighter **28**, selected with Q in the normal gallery. Run the current
source with `/Users/eric/Desktop/Play Goemon.command`. This work does not export an
app. Existing saved character IDs, maps and preferences keep their meaning.

| Input | Action |
| --- | --- |
| LMB | Cut → turning cut → somersault, one click per section; no jump input needed. Airborne clicks retain original cut/spin |
| RMB or T | Sword wave |
| E | Three homing shots |
| R | Four successive wind sheets |
| WASD, Shift, Space, C | Shared movement, sprint, jump and evade |

The three specials also appear in the existing skill equipment screen. They can
be assigned to another fighter without changing that fighter's normal weapon.
No additional skill framework or army simulation was added.

## Source and editable workbench

The supplied USA ROM's `SC03/FILE_014/0.4.dec` identifies the duel with the
`Kojiro, you....!` dialogue. Actor `0x265`, descriptor `0x80190490`, body list
`0x801d6d6c` and full list `0x801d6d2c` establish the model identity. All fifteen
rigid parts are present, including the independently animated long sword.

- Immutable recovery: `assets/characters/recovered_kojiro/`
- Authoritative editable source: `assets/blender/characters/kojiro/kojiro.blend`
- Workbench rules: `assets/blender/characters/kojiro/AGENTS.md`
- Authored export: `assets/models/characters/kojiro/kojiro.glb`
- Gameplay adapter: `scripts/kojiro_model.gd`, `kojiro_combat.gd`,
  `kojiro_projectile.gd`, `kojiro_audio.gd`
- Source combat addresses, events and timings: `combat.json` in the recovery

The master has 21 original clips: all eighteen sequential streams, two directly
referenced cinematic continuations and the externally held defeat pose. There
are 382 unique source poses. The rigid transform hierarchy is the original rig,
not a missing armature. Source motion is prepared at 30 FPS. The model uses the
shared standing-height reference; combat coordinates use the inner ROM root,
including its 0.01 scale, rather than Godot's outer import wrapper.

`tools/prepare_kojiro_blender.py` refuses to overwrite an existing master.
Export the saved master using the shared `tools/export_recovered_monster.py`.
Do not regenerate the master to publish edits. Preserve all named parts, UVs,
vertex colors and actions. Re-exporting animation does not change hit timing.
Kojiro's import settings disable the animation optimizer: simplifying very small
source rotations caused a measurable imported-pose mismatch during validation.

### Movement and click sections (2026-10-24 refinement)

Kojiro's default Space movement reuses the shared Musashi variable double jump:
hold to rise higher, release for a short hop, and press again for one midair
somersault. Explicit Jump Style equipment still overrides this default. The
model reuses `Source__801e2708` at Musashi's shared eight-tick flip duration;
its existing part and sword transforms stay together. This is presentation
only: jumping does not start an attack, and an actual air attack takes priority.
Landing resets the flip. No new asset, rig transfer or runtime retargeter is used.

The original forward run is `Source__801e22a0`, **not** `Source__801e2478`.
The duel movement handler at `0x80185ef8` selects table `0x801904f0` at
`0x8018638c`. Slot 3 selects the forward cycle; slots 6/7 select lateral runs.
The pose data confirms this: the forward cycle's right foot stays at X=8 and
travels from Z=-4 to 12, while the lateral cycles stride in X with constant Z.
The previous labels confused those motions. Walk remains `Source__801e21f8`;
the two lateral runs remain recovered and editable. Locomotion time now
accumulates each movement step, so changing speed cannot rescale elapsed history
and jump to an unrelated foot pose.

Ground LMB follows Ben's separate-click pattern with three distinct motions:
`Source__801e2b50` ticks `[0,24)`, `Ground__turning_cut` (24 ticks), then
`Ground__somersault_cut` (30 ticks). The user clarified that replaying the same
cut was the problem; the former reversed slash is superseded. The latter two
are prepared grounded variants of original aerial cut `801e2660` and somersault
`801e2708`. They preserve original part orientations and sword/hand relationships
during the cut, add whole-pose floor clearance and entry/recovery poses, and
retain contact tick 15. The somersault's visual lift is baked in Blender;
movement/collision remain in the shared controller. All 21 original actions,
geometry, paint and rig hierarchy are preserved alongside two editable variants.

One tap plays one section. An early second tap buffers one continuation; holding
alone does not repeat. The 0.85-second window resets on interruption or skill use.
The final pose waits while stationary inside that window. Grounded clicks now
reach the turning cut and somersault without requiring a jump. Their own original
voice cues play through shared audio.

All six attack actions use 2× playback, multiplied by the existing attack-speed
setting. The ground sections take 0.400, 0.400 and 0.500 seconds at default speed;
homing takes 0.500, wave 0.833 and wind 1.183 seconds, excluding impact pauses.
Melee/homing/wave contact or release is at 0.250 seconds; wind first releases at
0.667 seconds. Projectile speeds, counts, sounds and lifetimes keep their settings.
The shared rigid exporter includes both authored actions and their provenance;
optimized derivatives must be rebuilt from this saved master after motion edits.

The requested player tuning triples melee and spell base damage: sword 24→72,
homing 32→96, wave/wind 48→144. Existing receiving-fighter multipliers, upgrades
and shared chain bonuses still apply. Spell visuals and hit volumes scale 3×,
including pooled child sparks/dust; original wind size ratios remain. The ROM
combat data is unchanged. The phoenix launches centered at torso height with a
forward offset and follows the shared projectile aim. Ground casts stay level;
airborne casts can pitch toward the aim.

### Phoenix orientation correction (2026-10-24)

**Superseded by the 2026-10-26 flight correction below.** The ROM analysis and
the recorded checks describe the earlier camera-facing implementation.

Fresh inspection of the supplied USA ROM supersedes the previous upright-plane
interpretation. Wave initialization at `80185D70` selects sprite mode 3 and sets
flag `08000000`. Release `80186B68..70` copies caster yaw into the sprite's Z
rotation. Executable dispatch slot `8006350C` selects `8001EFE0`, which projects
the sprite center, builds a camera-facing quad, then calls `8001F730` to rotate
its screen-space corners. The eight 80×64 phoenix frames are already correct.

The shared atlas shader now optionally rotates a billboard so the bird's head
points along flight projected into the current camera. Kojiro's phoenix and
homing birds opt in. This projection adapts the original fixed-camera heading to Goemon's
rotatable camera; a shot directly toward/away from the camera keeps an upright
fallback because it has no screen-space heading. Existing aim, muzzle/quad
offsets, 3× size/damage, growth, travel, hit checks, timings and sounds remain
Goemon adaptations and are unchanged by this fix. No source art was re-exported.

`tests/asset-toolkit/test_kojiro_recovery.py` checks the relevant ROM words.
`tests/forest-shrine/kojiro_phoenix_render_test.gd` measures actual rendered
tip/tail pixels over 24 camera/flight combinations, including degenerate views.
It reproduced 21 failures in 45 checks before the fix and passed all 45 after.
Evidence and fresh disassembly: `build/Other Files/Asset Toolkit/Kojiro/Phoenix
Angle/`. This corrects presentation; it is not a full-game performance result.

### Phoenix flight correction (2026-10-26)

The user still saw the phoenix pointing right during forward casts. Projecting
velocity into the camera and rotating the entire sprite could pass the old
tip/tail test while visibly rolling the frontal bird artwork sideways. The
phoenix now uses an upright world-space quad facing velocity, with yaw and pitch
set on each pooled launch and no roll. Its wings stay level, including pitched
shots; vertical shots have a deterministic yaw. Homing birds retain their
separate directional billboard and steering. This deliberately replaces the
ROM-style screen rotation for this effect in Goemon's freely rotating camera.

The existing atlas, growth, size, muzzle, straight constant-speed movement,
damage, contact radius, release timing and pooling remain unchanged. No master,
animation, texture, optimized derivative or shader was edited. As a physical
single-plane effect it naturally foreshortens when viewed from the side.

The rendered test now checks the physical face/wing axes and perspective-projected
crown/tail markers, with actual-art captures at four camera positions including
the low shoulder view. `--before` reproduces the former presentation only in the
test fixture. Evidence is under
`build/Other Files/Asset Toolkit/Kojiro/Phoenix Flight/`. Run the same desktop
launcher commands below; normal gameplay still uses only the native army owner.

### Gradual phoenix growth (2026-10-26)

The phoenix now starts at half its previous launch width/height and grows
linearly to the same maximum over two seconds (previously 1.6 seconds).
It holds that size until its existing three-second lifetime ends. The original
hit-area growth remains separate from this visual reveal, preserving contacts,
damage, travel, release timing and independent visual-size/hit-area settings.
Each pooled launch resets both scales, including borrowed skills and allies.
The existing atlas, shader, materials and prepared projectile pool are reused.

`kojiro_gameplay_test.gd` checks the launch, intermediate growth, maximum,
unchanged contact scale, independent tuning and repeated simultaneous leases.
`kojiro_phoenix_render_test.gd` saves fixed-camera images at 0, 0.5, 1, 1.5, 2
and 2.9 seconds alongside the orientation checks. Run both through Play Goemon
using the commands below. Growth logs live in `Kojiro/Phoenix Growth/` under
the asset toolkit report folder; the six images use `Phoenix Flight/after-growth-*`.

### Three homing birds — 2026-10-24

A fresh decode of SC03/14's VRAM and descriptor `0x80190590` matches the existing
32×32 homing PNG byte for byte (CLUT `0x5296`, source origin `[-16,-16]`). It is
one static bird sprite, with the beak toward the lower right and tail toward the
upper left. There is no missing wing-flap sequence. The release loop still emits
three projectiles at yaw offsets `-0x200`, `0`, `+0x200` (−45°, 0°, +45°).

The missing behavior was rotation: `0x80185C8C` enables the rotated screen-sprite
path, and every update at `0x801867B8..D4` clears sprite pitch/yaw and writes
current homing yaw plus `0x200` to screen roll. Our homing sprite previously kept
one fixed screen angle. It now uses the existing directional billboard and
updates its heading after steering each tick. The shader's `sprite_forward`
parameter accounts for this texture's diagonal beak direction in Godot's
right/up coordinates; it is not a literal copy of the ROM's fixed-camera angle.
Other shader users keep the original default orientation.

The same rendered fixture with `-- --homing` measures beak/tail marker pixels
across 24 camera/flight combinations. Before the correction, 21 of 45 assertions
failed; after it, all 45 passed. Fresh ROM disassembly, pixel verification and
before/after captures are in `build/Other Files/Asset Toolkit/Kojiro/Homing Review/`.
The desktop launcher's rendered gameplay run passed 395 assertions, including
same-tick steering orientation, the three-shot fan, repeated pool reuse, shared
native damage and borrowed skills. The existing phoenix render checks passed
all 45 assertions again. Toolkit unit, import, outfit, structure and preservation
checks also passed. Existing whole-scene shutdown RID/resource warnings remain;
this was not a long-duration stress run or an original-game emulator playthrough.
The original PNG, three-shot spread, target steering, trails, scale, speed, damage,
release timing and audio are unchanged. No asset export or new pool was needed.

### Piercing homing birds — 2026-10-24

At the user's request, each of the three homing birds now passes through enemies
and damages each enemy once per bird. The existing per-projectile hit ledger
prevents repeated damage while overlapping or returning through the same enemy.
After hitting its homing target, a bird clears that target and continues along
its current heading. Other enemies can still be hit along the way before that
target is reached. Solid cover and the existing three-second lifetime still
retire the projectile. Damage, size, speed, three-shot spread, release timing,
audio and contact sparks retain their existing settings. Borrowed Homing Shots
use this same projectile path; Kojiro is not a native NPC army kit.

`tests/forest-shrine/kojiro_piercing_test.gd` covers three overlapping birds,
three native targets in a row, per-bird deduplication, pool reset, solid cover
and lifetime at 20/30/60 Hz and a long physics step. Evidence is under
`build/Other Files/Asset Toolkit/Kojiro/Piercing/`.

## Combat, effects and sound coverage

The original boss slash and airborne cuts contact at source tick 15. Homing and wave release
at tick 15. Wind releases at ticks 40, 42, 44 and 46 with scales 1, .75, .5 and
.25. Homing launches at the original three headings and 24 source units/tick;
wave and wind travel at 16 units/tick, with 90-tick lifetimes. Host aiming,
homing steering, jump movement, walls, damage progression and enemy hurtboxes
are adapted to Goemon. The duel's enemy AI and hostage/cutscene choreography are
not a second playable simulation.

Recovered presentation includes the homing sprite and spark, all eight wave
frames, both indexed wind pages, original two-triangle wind geometry, magenta
sword trail and the wind's ten-frame dust animation. The dust is the same resident
sprite already recovered for Musashi's rocket trail, so its existing texture and
the shared atlas shader are reused. `effects/sources.json` records addresses,
palettes, dimensions and pixel hashes. Trails sample at 30 Hz with the original
16-tick lifetime. Shots, sparks and dust use `CharacterProjectilePool`; textures,
meshes, shaders and audio are prepared on selection, not in attack loops.

The duel loads its sound bank separately from the scenery. Loader `0x80184868`
selects resource 57 and CD table entry 195 (`SC03/FILE_017/0.2` + `1.3`),
using the sound owner in `SC03/FILE_014/4.7`. The current recovery retains all
23 samples and 26 resolved event entries from that bank. The previous recovery
incorrectly paired the same event list with the scenery bank in FILE_014;
FILE_015 was also scenery, not an alternate duel bank. Those historical catalogs
are not accepted Kojiro audio evidence.

Homing, phoenix wave and wind now use their correct original voices/releases;
both aerial voices, hurt variants and defeat use the same verified bank.
A83/A84 remain disabled source events available for inspection. A88/A89 are
also disabled and point beyond the supplied bank's populated tones, so the
previously labelled original sword/unused voice clips were removed from the
runtime catalog. The old WAVs/provenance are retained under
`build/Other Files/Asset Toolkit/Kojiro/Audio Correction/superseded-scenery-bank/`.

For audible player sword feedback, each grounded or aerial strike plays the
existing Musashi Fusion cut at the contact marker, including misses. Confirmed
hits use the shared Musashi sword impact. These two choices are explicit player
adaptations, not recovered Kojiro events; voices and spell releases retain their
source identity and prepared pitch. Sound Studio exposes the sword cut and keeps
recording, gain and mute controls. Prepared resources and existing bounded voices
are reused. Cancellation before the strike marker does not produce a late cut.

Kojiro's default footsteps reuse Musashi's prepared `foot_contact.wav` sample.
His existing stride events and playback level stay unchanged; Sound Studio
recordings, gain, mute and Restore default continue to work through SoundLibrary.

These are recovered combat assets, not a claim of full PlayStation emulation:
Godot blending/projection, homing steering and hit feedback differ; the audio
renderer preserves samples, pitch curves and layers but does not emulate the
entire PS1 SPU envelope/reverb pipeline. Streamed story dialogue is separate from
the combat bank and has not been mapped to player actions.

## Rebuild and verify

```sh
python3 tools/recover_kojiro.py
# Audio-only repairs preserve every editable model/motion file:
python3 tools/recover_kojiro.py --audio-only
# First creation only; never overwrite an edited master:
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/prepare_kojiro_blender.py
/Applications/Blender.app/Contents/MacOS/Blender -b assets/blender/characters/kojiro/kojiro.blend --python tools/export_recovered_monster.py
python3 tools/goemon_assets.py audit assets/characters/recovered_kojiro assets/models/characters/kojiro --out 'build/Other Files/Asset Toolkit/Kojiro/Audit'
python3 tools/goemon_assets.py optimize --asset kojiro
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 -m unittest discover -s tests/asset-toolkit -p 'test_kojiro_recovery.py'
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/asset-toolkit/kojiro_import.gd
python3 tools/goemon_assets.py compare --asset kojiro --capture --all-clips --out 'build/Other Files/Asset Toolkit/Kojiro/Comparison'
# Activate only after preservation, imported motion and rendered review pass:
python3 tools/goemon_assets.py activate --asset kojiro
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/goemon_assets.py check
'/Users/eric/Desktop/Play Goemon.command' --script tests/forest-shrine/kojiro_gameplay_test.gd
'/Users/eric/Desktop/Play Goemon.command' --script tests/forest-shrine/kojiro_phoenix_render_test.gd
'/Users/eric/Desktop/Play Goemon.command' --script tests/forest-shrine/kojiro_audio_test.gd
```

The asset audit reports 500 triangles and 20 surfaces across 15 animated parts.
Lossless optimization reduces vertices from 1,500 to 445 and materials from 20 to
4, retaining all triangles, part controls, texture bytes and animation samples.
The surface warning does not authorize merging animated body parts or decimating
the model. No army pose bake is required: Kojiro is a player/skill donor, not a
new army enemy type. Any future enemy version must use the existing native owner
and the rigid-enemy pose-bake workflow.

Evidence, complete audio banks, disassembly, renders and test logs are under
`build/Other Files/Asset Toolkit/Kojiro/`. The gameplay fixture checks release
timing/counts, real native damage, wall obstruction, aerial attacks, pool reset,
focus loss, switching, skill transfer and gallery selection. Its timing report
measures player/projectile CPU in a controlled scene; it is not an army stress
test or proof of full-game frame rate.

### Combined blade presentation — 2026-10-30

Kojiro retains the original additive RGB (240,120,240) physical-blade ribbon
alongside the newer strong ink crescent. The tick-15 hit marker occurs during
the first cut's rear windup, so it only arms the new visual. The long crescent
samples the subsequent front-facing blade movement and fades in .18 seconds.
Three recent authored poses seed missed render poses, restoring the animation
cursor afterward. A static forward endpoint receives a small .12-radian cap
bent toward the target. No full-range crescent is emitted from the rear windup.
The original compact glow retains its source cadence/window and 16/30-second
fade. Both layers keep their own prepared meshes/materials, clear on cancel/hide
and respect reduced flashes. Contact timing, hit queries and reach stay under
KojiroCombat. Evidence: `build/Other Files/Asset Toolkit/Kojiro Forward Cut/`.
