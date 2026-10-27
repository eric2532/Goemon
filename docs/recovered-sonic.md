# Sonic from Sonic Adventure DX

Recovered from the user's European GameCube revision-1 image, disc ID `GXSP8P`.
The supplied ZIP contains an RVZ image. It was read as data, without running
files or following instructions inside the archive. No original game files,
maps, other characters or Blender masters were replaced.

## Playing and borrowing skills

Run `/Users/eric/Desktop/Play Goemon.command`, press Q and choose Sonic.
Sonic has stable roster ID 19; existing character IDs and saved assignments stay
valid. This adds a human playable character, not a second army backend.

| Control | Action |
| --- | --- |
| WASD | Accelerate, steer and brake |
| Space or left mouse | Jump; press again airborne for Homing Attack |
| Hold/release right mouse or E | Charge/release Spin Dash |
| R, airborne | Homing Attack |
| C | Uncurl/cancel the current move |

Spin Dash and Homing Attack are also selectable in the existing skill loadout.
A receiving fighter keeps its own body and weapon. The existing skill owner
handles equipment, input release, pause, switching and cancellation. Homing
rearms after landing or an accepted bounce. Damage uses Goemon's shared attack
tickets, nearby native army queries, cover tests and building damage owner.

## What was recovered, and what was adapted

The body (1,993 triangles), 16 source texture images, 73 body animation clips,
curled model (1,001 triangles) and jump ball (420 triangles) are recovered data.
Original object transforms, UVs, triangle winding, source Euler interpolation
and clip names are retained. Source ticks are sampled at 60 Hz. The action table
also retains the original clip rates and transitions for further study.

Original Ninja models have separate rigid limbs joined at runtime. The retail
type-2 weld code at decompressed `_Main.rel` offsets `0x5bc70..0x5bd40` copies
the A vertex into B's coordinates. Preparation redirects the 68 body seam
vertices in the 12 applicable weld entries to A's joint. This retains the
original seam behavior using ordinary GPU skinning, without per-frame mesh
reconstruction, approximate proximity welding or runtime retargeting.

Runtime loop duration uses the original frame count, including the wrap tick;
footstep cadence follows the selected clip's cycle and playback rate.

The Sonic parameter table at `0x2c6d28`, animation table at `0x355020` and weld
table at `0x355ad8` are saved in `native_tables.json`. The adapter uses the source
acceleration, braking, speed thresholds, launch speed, gravity and drag with
0.2 m/source unit and 60 source ticks/second. For example, run acceleration is
0.05 source units/tick² and jump launch is 1.66 source units/tick.

The movement refinement follows the supplied revision's action routines, not
just its parameter table. Addresses below are file offsets in decompressed
`_Main.rel`; the disassembly and relocation annotations are retained under
`build/Other Files/Asset Toolkit/Sonic/Research/`.

| Behavior | Recovered rule and evidence |
| --- | --- |
| Running | `0xe54d8..0xe5818`: 3 is a soft threshold. Full input accelerates by .05 below it and .02 above it; flat-ground overspeed drag is `(speed-3)*-.008*1.7`. This approaches 4.47 units/tick, rather than stopping at 3. |
| Steering | `0xdd828..0xddae0`: large turns use a maximum 0x800 angular step per tick, with smaller steps near the desired direction. Ground and air retain different amounts of momentum. The adapter uses these on the horizontal plane. |
| Jump | `0x1a7740`: launch 1.66. `0x1ab4d8..0x1ab500` and `0xe63c4`: while held, add `.8*.076` for up to 60 held ticks. `0xe3d38`: vertical resistance -.01 plus gravity -.08. Release stops added lift; it does not halve velocity. |
| Spin Dash | `0x1a47a4..0x1a47e0`: start at max(forward speed, 2). `0x1a4430..0x1a44d4`: add .4 per tick while below 10 and release that stored speed. A stationary full charge takes about 20 ticks. Jumping carries the outgoing speed into the air. |
| Homing | `0x1a86e0..0x1a8e60`: normal speed 5, target distance squared below 10,000 and facing angle within 0x5000; yaw changes by at most 0x800 per tick. A miss retains vertical motion, slows horizontal speed by .9 per tick, and exits after six miss ticks (`0x1ab9b0`). The target chase has a 360-tick safety limit. |

**This remains a planar adaptation, not an engine-identical port.** Goemon's
CharacterBody, hills, walls, bridges, portals, damage and camera remain
authoritative. Host cover/visibility checks, attack damage and bounce are
preserved. The original terrain-dependent grip, steep-slope special cases and
late homing randomness are not fully emulated. Rolling uses the recovered drag,
bounded steering and host slope gravity. It has no arbitrary two-second expiry.
The original
loop/wall-running contact solver, rings, Light Speed Dash, Light Speed Attack,
Super Sonic, upgrades and facial/cutscene expression behavior are not ported.
Original movement constants alone do not establish engine-identical movement.

The blue effect uses the original `SON_EFF` texture bank and the original
12-triangle trail and 100-triangle jump-ball effect from `ModelsMiles.rel`
(`0x21b848`, `0x21c288` in the SA Tools model map). Both have editable Blender
masters and normal exports. The existing Godot mesh/material path supplies
alpha-blended aura and additive trails: one aura plus eight reusable trail instances per equipped
controller, shared meshes and owned materials prepared once. No mesh, material
or scene is rebuilt during a move. The same effect follows borrowed skills.
Effect placement/lifetime is a host presentation adaptation; the original
texture pixels and geometry are preserved, not a pixel-identical console draw.

GCAX banks provide the original DSP ADPCM/PCM samples and MIDI event pitch.
Jump, skid, landing, step, homing, spin charge/release, impacts and selected
English voice samples use those recovered WAVs through the existing audio
library. Samples are cached once; charge owns one reusable looping audio player.
The source instrument envelopes are preserved in the manifest, but the original
GCAX mixer envelopes, gain and DSP effects are not emulated. These are original
waveforms at the recovered event pitch, not bit-identical console audio output.

## Asset ownership and provenance

| Layer | Location |
| --- | --- |
| Disc reader and recovery/preparation | `tools/sonic/` |
| Immutable recovery and source manifest | `assets/characters/recovered_sonic/` |
| Editable masters and export instructions | `assets/blender/characters/sonic/START_HERE.md` |
| Normal Blender exports | `assets/models/characters/sonic/` |
| Generated active body derivative | `assets/optimized/sonic.glb` |
| Original audio and GCAX manifest | `assets/audio/recovered_sonic/` |
| Local research, tests and comparisons | `build/Other Files/Asset Toolkit/Sonic/` |

Source SHA-256 values:

| Disc file | SHA-256 |
| --- | --- |
| `ModelsMiles.rel` | `2e0457d29659590288a62fcd471a75e1cf392f7020f668c24d77046a0399f329` |
| `s_mot.rel` | `92fef716029996dc2976f1650631b43116ad52fde3694e3de0f39e7e51ddad7b` |
| `sonic.gvm` | `90b61be0edff0fcd8e903b04a923f7936bf7c92e34e302ffbefede1ea3e1cf35` |
| `_Main.rel` | `697cfdb4a9d97ff404cd176d8367bca6dfe7f43b0b16146d429d20aa74aa3604` |

Audio manifests retain bank hashes, sample coefficients, loops, instrument splits
and MIDI events. Useful format references are the
[Dolphin RVZ specification](https://github.com/dolphin-emu/dolphin/blob/master/docs/WiaAndRvz.md),
[SA Tools GC_SADX templates](https://github.com/X-Hax/sa_tools/tree/master/GameConfig/GC_SADX),
[SA Tools audio research](https://github.com/X-Hax/sa_tools_research), and
[SADX Mod Loader structures](https://github.com/sonicretro/sadx-mod-loader).
These references describe data formats; the supplied disc remains the asset source.

## Reproduce recovery

The local research folder holds `source.rvz` extracted from the supplied ZIP.
`python3 tools/sonic/disc.py '.../source.rvz'` lists its file table. The reader
requires the installed libzstd and deliberately supports only this RVZ variant.
To extract the required records without expanding an ISO:

```python
from pathlib import Path
from tools.sonic.disc import Disc
folder = Path('build/Other Files/Asset Toolkit/Sonic/Research')
disc = Disc(folder / 'source.rvz')
files = disc.files()
for name in ('ModelsMiles.rel', 's_mot.rel', 'sonic.gvm', '_Main.rel',
             'son_eff.GVM', 'P_SONICTAILS.mlt', 'v_sonictails_e.mlt', 'windyvalley.mlt'):
    (folder / name).write_bytes(disc.read(*files[name]))
disc.file.close()
```

Use Python with NumPy and Pillow (the bundled workspace runtime has both):

```sh
python3 tools/sonic/recover.py --templates /path/to/sa_tools/GameConfig/GC_SADX
python3 tools/sonic/prepare.py
python3 tools/sonic/audio.py
python3 tools/sonic/effects.py # requires son_eff.GVM in the research folder
# First import only; existing masters are preserved:
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/sonic/create_blender_master.py
```

Subsequent edits use `tools/export_blender.py`, never the initial importer.
Run audit, optimization and staged motion/render review before activation.
The lossless body derivative retains every triangle, texture, joint and clip;
it reduces 28 mesh instances/42 surfaces to 1 mesh instance/10 surfaces. Ten
surfaces still exceed the warning budget; that is not permission to alter art.

```sh
python3 -m unittest discover -s tests/asset-toolkit -p 'test_*.py'
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/sonic_import.gd
python3 tools/goemon_assets.py activate --asset sonic
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 tools/goemon_assets.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/asset-toolkit/sonic_import.gd -- --packed
python3 tools/goemon_assets.py compare --asset sonic --capture --imported
'/Users/eric/Desktop/Play Goemon.command' --resolution 1280x800 --script res://tests/forest-shrine/sonic_gameplay_test.gd -- --profile
```

Also run the toolkit integration, Musashi outfit, structures and modular spell
tests from the toolkit README. Keep rendering focused and avoid simultaneous
editor/export jobs when collecting timings. The focused Sonic fixture pauses
world spawning only inside the test; it is not evidence of full-army smoothness.
See `docs/goemon-performance-guide.md` for dated measurements and their limits.
No app export is required for these source changes.

## Initial integration verification — 2026-10-24

The final source passed 40 focused checks headless and through the desktop
launcher using Metal at 1280×800. These cover source loop duration, visible-only
animation evaluation, acceleration/braking, jump/land, eight charge/release
cycles, existing node ownership, bounded resource growth, focus loss, native
enemy hits, cover, real castle damage, foreign-body skills, pause and reselection.
The final desktop run reports no script errors. Exit-time resource/RID warnings
remain; this is not a leak-free shutdown claim.

During this integration, the toolkit's 40 Python tests, 12,812 import checks,
102 Musashi outfit checks, 86 structure checks and 2,339 modular skill checks
passed. Sonic's staged and packed imports each passed 27,159 comparisons across
all 73 clips and their joints. The actual imported source/derivative rendering
sweep saved 96 image pairs across eight movement clips, three times and four
angles. Maximum image RMS difference was 0.123 on the 0–255 channel scale;
the reviewed silhouettes, textures and seams match. This is preservation
evidence, not a claim of pixel identity with the original console renderer.

Logs, captures, manifests and source hashes are in the evidence directory above.
The performance guide records the limited timing scope separately. No app was
exported and no full-army soak or other-hardware test was performed.


## Movement and blue-effect verification — 2026-10-24

The refined mechanics passed 58 focused assertions headless and 58 through
`Play Goemon.command` on desktop Metal at 1280×800. The final desktop command
adds `--visual --motion-profile` after `--` to use the existing visual-test
fixture and repeat full Spin Dashes. Captures of jump, charge and release were
reviewed with the final effect size, placement and blend settings. Physics,
model, effect, player/loadout and fixture hashes stayed unchanged during that
final desktop run (`Movement/inputs.json` and `inputs-after.json`).

Checks include the 60-tick running threshold, subsequent overspeed, bounded
turning, reverse braking, air momentum, short/held jump arcs, full charge and
jumping from a dash, homing miss recovery, native enemy and castle contacts,
cover, focus/pause cancellation, and borrowed skills. Equipped and native
Homing Attack on Sonic cannot give each other an extra airborne use. Completed
borrowed attacks retire their trails. The isolated platform measured jump
apex rises of 3.332 m for the short input and 8.751 m for the held input; these
are adapter measurements, not a console trace comparison.

The shared skill suite passed 3,040 assertions and movement-cancellation passed
106. The asset-toolkit run passed 46 Python tests, including exact preservation
of blue-effect triangle corners/UVs and decoded texture pixels across Blender
export; 12,812 toolkit import checks, 27,159 packed Sonic motion checks,
98 Musashi outfit checks and 86 structure checks also passed. Asset audit found
no read errors; the new effects each use one mesh/surface, at 12 and 100
triangles. Active derivative preservation passed. Existing body and audio
assets were retained.

Evidence is in `build/Other Files/Asset Toolkit/Sonic/Movement/`. The final
headless, desktop and shared-skill logs contain no script errors or failed
assertions; existing exit-time resource/RID diagnostics remain. Intermediate
focus-interrupted desktop attempts are excluded. The performance guide records
the focused workload and frame-time limits. No app export, full-army soak,
other-hardware run or engine-identical console comparison was performed.


## Unused audio audit before the sound hookup — 2026-10-24

This pass checked the runtime event map and callers against the recovered
Sonic/Tails SFX bank and English voice bank. It verified all 49 raw waveform
hashes, the prepared aliases' playback rates, and the character aliases' PCM
against their source samples. It did not change gameplay or assign new sounds.

The current map uses **eight effects and three voice samples**: jump, landing,
footstep, impact, skid, homing, Spin Dash charge and launch; damage voice 11 and
jump voices 14/15. Several sound slots share those same waveforms, so counting
slots or raw/alias WAV copies would exaggerate coverage.

There are **19 unused Sonic-specific cues** in the character banks:

| Group | Unused source events |
| --- | --- |
| 13 voices | Wall hit; falling/Yaba; idle wait; throw; push; Light Speed charge ready; Light Speed Dash; two item-pickup reactions; ladder; Oh reaction; fire damage; electric damage |
| 6 effects | Light Speed charge, Light Speed Dash, Light Speed Attack, Sonic Boom, Release, Sonic whistle |

The banks also contain **22 Tails samples and two silent placeholders**. These
are not missing Sonic sounds. Separately, prepared common `hurt.wav` is unused:
the current `hurt` slot plays Sonic's damage voice instead. Most other common
bank sounds were never exported into the runtime and belong to shared objects,
UI, pickups or environment behavior outside this character pass.

Event names come from the [SADX sound enumeration](https://github.com/sonicretro/sadx-mod-loader/blob/master/SADXModLoader/include/SADXEnumsNew.h).
The supplied REL confirms Sonic's wall-hit voice at `0x1a5ff0` (ID `0x4c6`)
and damage voice at `0x1a7a00` (ID `0x4d1`). Wall hit is the clearest candidate
for a later existing-action hookup. Spin Dash already uses `SE_SPINDASH` at
`0x1a4468`; the otherwise unused `SE_RELEASE` calls found at `0xb3cd8` and
`0xb3ff0` are outside that routine, so the file name alone does not justify
layering it over every dash. Likewise, the charge-ready voice belongs to the
original upgraded Light Speed behavior, not the adapter's ordinary full charge.

Detailed inventory and results:
`build/Other Files/Asset Toolkit/Sonic/Audio Audit/character-bank-inventory.csv`
and `summary.json`. This is a source/wiring audit, not an audible mix test or
a full-disc dialogue/music inventory. The voice slots currently reference raw
bank WAVs; their console playback pitch/timing was not independently calibrated
in this pass. Specialized reactions need their original trigger and playback
mapping verified before activation; they should not become random generic
hurt or attack variants. No source audio or Blender assets were changed.


## Wall hits, hurt and native audio pitch — 2026-10-24

The current Sonic map uses nine effect waveforms and four voice waveforms.
Fast running crashes, Spin Dash wall collisions and Homing Attack wall collisions
now play the original wall-hit reaction (`SE_SV_WALLHIT`, ID `0x4c6`, voice 0).
The existing collision transition emits it on contact. Continuing to push against
the wall does not retrigger it. Borrowing Sonic's movement on another fighter
does not give that fighter Sonic's wall voice. Walking and sliding contacts do
not add a repeated reaction.

An accepted hit now plays common `SE_DAMAGE2` (ID `0x17`) together with Sonic's
`SE_SV_DAMAGE` (ID `0x4d1`, voice 11). The supplied REL calls the damage voice
at `0x1a7a00` and the no-ring damage effect at `0xeb6bc`; Goemon's existing
health event supplies the host trigger. There is no added ring/death mechanic.
Both layers start in one cached Godot `AudioStreamSynchronized` through the
existing `hurt` slot. That preserves the hurt volume/mute setting, custom
recording replacement and recording suppression for the whole cue. Invulnerable
or otherwise rejected hits remain silent. Existing damage, knockback and
invulnerability timing are unchanged.

The pitch audit found a flaw in the first preparation pass: the exported raw
WAV header rate was treated as the event rate, and some aliases then applied
the instrument root adjustment a second time. The bank sequence notes also
differ from the normal native `SoundCall` driver. All affected prepared aliases
have now been regenerated by `tools/sonic/audio.py`; the 49 raw character-bank
WAV files remain byte-identical to their original recovery.

Evidence from the supplied image:

- Main's channel selection at `0x10a984..0x10ab44` keeps these event IDs on the
  ordinary sound channels; the banked and common paths send note 48 immediately
  at `0x108ed8..0x108f14` and `0x109134..0x109170`. The unused MSB note-5 tick
  delay is not added to these directly dispatched events.
- `main.dol` function `0x80071cc0` computes pitch from the instrument root and
  **positive** fine tuning in 1/128 semitone units. Its 44,100 Hz reference is
  `90316.8` in native 16.16 SRC units at a 32,000 Hz mixer clock. The reference
  and tuning constants were read using r2=`0x800ccc40`, initialized at
  `0x800054f0`.
- The native SRC values are 45,158 for ordinary root-60 effects and 33,647 for
  Sonic's root-66/fine-116 voices. These correspond to 22,049.8046875 Hz and
  16,429.19921875 Hz. Godot WAVs use the nearest integer rates: **22,050 Hz**
  and **16,429 Hz**, with fixed player pitch 1.0. The maximum rounding difference
  for these cues is below 0.2 Hz. The existing jump voices now use the corrected
  preparation too. Spin Dash charge/release, jump, skid, landing, footsteps and
  contact effects use the same recovered driver rules.

Prepared aliases preserve every PCM sample and source loop index, with no
normalization, trimming, randomized pitch or added onset delay. Their Godot
imports use uncompressed PCM. The charge loop retains sample indices
17,827..27,444 at its corrected playback rate. The old sequence note and time
are retained in the manifest separately from the native event note/time; they
are evidence, not the runtime timing source.

Fresh verification: seven focused recovery tests and the full 58-test asset
suite passed; 58 Sonic gameplay assertions passed headless; the focused audio
fixture passed 22 assertions headless and 28 through Play Goemon on desktop
Metal. Desktop checks capture real SFX output for hurt, wall-hit and jump,
verify collision/damage-frame release, reject repeated/blocked reactions,
exercise custom takes/mute/recording, and repeat 32 wall/hurt cycles. Audio
and effect ownership returned to the same node/resource counts after existing
hurt flashes expired. Runtime/input/audio hashes stayed unchanged during the
final desktop run. Asset audit reported no read errors and active derivative
preservation passed. Existing exit-time resource/RID diagnostics remain.

The captured wall cue has normalized waveform correlation **0.999729** against
voice 0 at the native rate, versus 0.109 at the former raw rate. This checks
our renderer's emitted pitch against the source-derived reference; it is not
a comparison with recorded console output. The test does not establish a
bit-identical console mix, original GCAX envelopes/DSP/reverb, or full-army
performance. Source pitch and action-frame timing are the verified scope.

Evidence, captures and source hashes:
`build/Other Files/Asset Toolkit/Sonic/Audio Integration/`.
Re-run `Play Goemon.command --resolution 1280x800 --script
res://tests/forest-shrine/sonic_audio_test.gd -- --visual` for the desktop check.
No app was exported and no Blender/model assets changed.
